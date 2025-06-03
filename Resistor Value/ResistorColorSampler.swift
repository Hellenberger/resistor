//
//  ResistorColorSampler.swift
//  Resistor Value
//
//  Created by Howard Ellenberger on 6/2/25.
//


//
//  ResistorColorSampler.swift
//  Resistor Value
//
//  Handles sampling the resistor body color
//

import SwiftUI
import CoreImage
import UIKit

class ResistorColorSampler {
    
    // MARK: - Combined Body Color Sampling
    func sampleBodyColorCombined(ciImage: CIImage, context: CIContext) -> (r: Int, g: Int, b: Int) {
        // Method 1: Direct pixel sampling from edges
        let directSample = sampleBodyColorDirect(ciImage: ciImage, context: context)
        
        // Method 2: Area average sampling
        let areaSample = sampleBodyColorAreaAverage(ciImage: ciImage, context: context)
        
        // Average the two methods for robustness
        let avgR = (directSample.r + areaSample.r) / 2
        let avgG = (directSample.g + areaSample.g) / 2
        let avgB = (directSample.b + areaSample.b) / 2
        
        print("🎨 SAMPLER: Direct sample: RGB(\(directSample.r), \(directSample.g), \(directSample.b))")
        print("🎨 SAMPLER: Area sample: RGB(\(areaSample.r), \(areaSample.g), \(areaSample.b))")
        print("🎨 SAMPLER: Combined: RGB(\(avgR), \(avgG), \(avgB))")
        
        return (avgR, avgG, avgB)
    }
    
    // MARK: - Direct Pixel Sampling
    private func sampleBodyColorDirect(ciImage: CIImage, context: CIContext) -> (r: Int, g: Int, b: Int) {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
              let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            print("❌ SAMPLER: Direct sampling failed, using default")
            return (120, 70, 40) // Default brown
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let middleY = height / 2
        
        var samples: [(Int, Int, Int)] = []
        
        // Sample from edges
        let samplePoints = [
            (width / 10, middleY),
            ((width * 9) / 10, middleY),
            (width / 10, middleY - 5),
            ((width * 9) / 10, middleY + 5)
        ]
        
        for (x, y) in samplePoints {
            if x >= 0 && x < width && y >= 0 && y < height {
                let pixelIndex = (y * width + x) * 4
                let r = Int(data[pixelIndex])
                let g = Int(data[pixelIndex + 1])
                let b = Int(data[pixelIndex + 2])
                
                if r > 20 || g > 20 || b > 20 {
                    samples.append((r, g, b))
                }
            }
        }
        
        if samples.isEmpty {
            return (120, 70, 40) // Default
        }
        
        let avgR = samples.map { $0.0 }.reduce(0, +) / samples.count
        let avgG = samples.map { $0.1 }.reduce(0, +) / samples.count
        let avgB = samples.map { $0.2 }.reduce(0, +) / samples.count
        
        return (avgR, avgG, avgB)
    }
    
    // MARK: - Area Average Sampling
    private func sampleBodyColorAreaAverage(ciImage: CIImage, context: CIContext) -> (r: Int, g: Int, b: Int) {
        let extent = ciImage.extent
        
        // Sample regions at edges - avoid areas that might have bands
        let sampleRegions = [
            CGRect(x: extent.minX + extent.width * 0.02, y: extent.minY + extent.height * 0.4,
                   width: extent.width * 0.05, height: extent.height * 0.2),
            CGRect(x: extent.minX + extent.width * 0.93, y: extent.minY + extent.height * 0.4,
                   width: extent.width * 0.05, height: extent.height * 0.2),
            CGRect(x: extent.minX + extent.width * 0.4, y: extent.minY + extent.height * 0.05,
                   width: extent.width * 0.2, height: extent.height * 0.05),
            CGRect(x: extent.minX + extent.width * 0.4, y: extent.minY + extent.height * 0.90,
                   width: extent.width * 0.2, height: extent.height * 0.05)
        ]
        
        var totalR = 0, totalG = 0, totalB = 0
        var validSamples = 0
        
        for region in sampleRegions {
            let clampedRegion = region.intersection(extent)
            guard !clampedRegion.isEmpty else { continue }
            
            if let avgColor = ColorUtilities.averageColorInRegion(ciImage: ciImage, region: clampedRegion, context: context) {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                avgColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                
                // Only use if it's not black (which might indicate an issue)
                if r > 0.05 || g > 0.05 || b > 0.05 {
                    totalR += Int(r * 255)
                    totalG += Int(g * 255)
                    totalB += Int(b * 255)
                    validSamples += 1
                }
            }
        }
        
        if validSamples == 0 {
            return (120, 70, 40) // Default brown resistor body
        }
        
        return (totalR / validSamples, totalG / validSamples, totalB / validSamples)
    }
}