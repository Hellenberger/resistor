//
//  ColorUtilities.swift
//  Resistor Value
//
//  Created by Howard Ellenberger on 6/3/25.
//


//
//  ColorUtilities.swift
//  Resistor Value
//
//  Shared utilities for color processing and analysis
//

import SwiftUI
import CoreImage
import UIKit

class ColorUtilities {
    
    // MARK: - Color Distance Calculations
    static func colorDistanceLAB(_ color1: (Int, Int, Int), _ color2: (Int, Int, Int)) -> Double {
        let uiColor1 = UIColor(
            red: CGFloat(color1.0) / 255.0,
            green: CGFloat(color1.1) / 255.0,
            blue: CGFloat(color1.2) / 255.0,
            alpha: 1.0
        )
        
        let uiColor2 = UIColor(
            red: CGFloat(color2.0) / 255.0,
            green: CGFloat(color2.1) / 255.0,
            blue: CGFloat(color2.2) / 255.0,
            alpha: 1.0
        )
        
        let lab1 = LABColor(from: uiColor1)
        let lab2 = LABColor(from: uiColor2)
        
        return lab1.distance(to: lab2)
    }
    
    static func colorDistanceFromBody(_ color: (Int, Int, Int), _ bodyColor: (Int, Int, Int)) -> Double {
        return colorDistanceLAB(color, bodyColor)
    }
    
    // MARK: - Statistical Calculations
    static func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count)
    }
    
    // MARK: - Color Region Averaging
    static func averageColorInRegion(ciImage: CIImage, region: CGRect, context: CIContext) -> UIColor? {
        // Ensure region is within image bounds
        let clampedRegion = region.intersection(ciImage.extent)
        guard !clampedRegion.isEmpty else { return nil }
        
        // Method 1: Try CIAreaAverage filter
        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(ciImage.cropped(to: clampedRegion), forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: clampedRegion), forKey: kCIInputExtentKey)
        
        if let output = filter?.outputImage {
            var bitmap = [UInt8](repeating: 0, count: 4)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            context.render(output, toBitmap: &bitmap, rowBytes: 4,
                          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                          format: CIFormat.RGBA8, colorSpace: colorSpace)
            
            // Check if we got valid data (not all black)
            if bitmap[0] > 0 || bitmap[1] > 0 || bitmap[2] > 0 {
                return UIColor(
                    red: CGFloat(bitmap[0]) / 255.0,
                    green: CGFloat(bitmap[1]) / 255.0,
                    blue: CGFloat(bitmap[2]) / 255.0,
                    alpha: 1.0
                )
            }
        }
        
        // Method 2: Direct pixel sampling if CIAreaAverage fails
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        
        // Convert region to pixel coordinates
        let scaleX = CGFloat(width) / ciImage.extent.width
        let scaleY = CGFloat(height) / ciImage.extent.height
        
        let pixelRect = CGRect(
            x: (clampedRegion.minX - ciImage.extent.minX) * scaleX,
            y: (clampedRegion.minY - ciImage.extent.minY) * scaleY,
            width: clampedRegion.width * scaleX,
            height: clampedRegion.height * scaleY
        )
        
        let minX = max(0, Int(pixelRect.minX))
        let maxX = min(width - 1, Int(pixelRect.maxX))
        let minY = max(0, Int(pixelRect.minY))
        let maxY = min(height - 1, Int(pixelRect.maxY))
        
        guard minX < maxX && minY < maxY else { return nil }
        
        var totalR = 0, totalG = 0, totalB = 0, count = 0
        
        for y in minY...maxY {
            for x in minX...maxX {
                let pixelIndex = (y * width + x) * bytesPerPixel
                totalR += Int(data[pixelIndex])
                totalG += Int(data[pixelIndex + 1])
                totalB += Int(data[pixelIndex + 2])
                count += 1
            }
        }
        
        guard count > 0 else { return nil }
        
        return UIColor(
            red: CGFloat(totalR) / CGFloat(count) / 255.0,
            green: CGFloat(totalG) / CGFloat(count) / 255.0,
            blue: CGFloat(totalB) / CGFloat(count) / 255.0,
            alpha: 1.0
        )
    }
}