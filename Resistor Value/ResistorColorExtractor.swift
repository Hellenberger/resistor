//
//  ResistorColorExtractor.swift
//  Resistor Value
//
//  Handles extraction of colors from detected band positions
//

import SwiftUI
import CoreImage
import UIKit

class ResistorColorExtractor {
    
    // MARK: - Main Color Extraction
    func extractColors(
        ciImage: CIImage,
        positions: [Int],
        bodyColor: (r: Int, g: Int, b: Int),
        context: CIContext,
        colorClassifier: ResistorColorClassifier
    ) -> [String] {
        return positions.enumerated().map { (index, x) in
            // Try area average first
            let areaColor = extractColorAreaAverage(ciImage: ciImage, x: x, context: context)
            
            // Also get direct pixel sample
            let directColor = extractColorDirect(ciImage: ciImage, x: x, context: context)
            
            // Choose the one with higher contrast from body
            let areaDistance = ColorUtilities.colorDistanceFromBody(areaColor, bodyColor)
            let directDistance = ColorUtilities.colorDistanceFromBody(directColor, bodyColor)
            
            // IMPORTANT: Prefer non-black colors
            var chosenColor: (Int, Int, Int)
            
            // If area average returns black (0,0,0), prefer direct sampling
            if areaColor.0 < 5 && areaColor.1 < 5 && areaColor.2 < 5 {
                // Area average failed, use direct or larger sample
                if directColor.0 > 10 || directColor.1 > 10 || directColor.2 > 10 {
                    chosenColor = directColor
                    print("   ⚠️ Area average returned black, using direct sample")
                } else {
                    // Both returned very dark, try larger area
                    let largerSample = extractColorLargerArea(ciImage: ciImage, x: x, context: context)
                    chosenColor = largerSample
                    print("   🔄 Both methods returned black, using larger area sample")
                }
            } else if directColor.0 < 5 && directColor.1 < 5 && directColor.2 < 5 {
                // Direct returned black, use area average
                chosenColor = areaColor
                print("   ⚠️ Direct sample returned black, using area average")
            } else {
                // Both have color, choose based on distance from body
                chosenColor = areaDistance > directDistance ? areaColor : directColor
            }
            
            // REFLECTION DETECTION: Check if this might be a specular reflection
            if isLikelyReflection(rgb: chosenColor) {
                print("   ⚠️ Detected possible reflection at band \(index)")
                // Try alternative sampling methods to avoid reflection
                let alternativeColor = extractColorAvoidingReflection(
                    ciImage: ciImage, x: x, centerColor: chosenColor, context: context
                )
                if !isLikelyReflection(rgb: alternativeColor) {
                    chosenColor = alternativeColor
                    print("   ✅ Found better color avoiding reflection: RGB(\(alternativeColor.0), \(alternativeColor.1), \(alternativeColor.2))")
                }
            }
            
            print("🎨 EXTRACTOR: Band \(index) at x=\(x):")
            print("   Area: RGB(\(areaColor.0), \(areaColor.1), \(areaColor.2)) - distance: \(areaDistance)")
            print("   Direct: RGB(\(directColor.0), \(directColor.1), \(directColor.2)) - distance: \(directDistance)")
            print("   Chosen: RGB(\(chosenColor.0), \(chosenColor.1), \(chosenColor.2))")
            
            // Classify the color using improved logic
            let uiColor = UIColor(
                red: CGFloat(chosenColor.0) / 255.0,
                green: CGFloat(chosenColor.1) / 255.0,
                blue: CGFloat(chosenColor.2) / 255.0,
                alpha: 1.0
            )
            
            // Use band position-aware classification
            let colorName = colorClassifier.classifyColorByPosition(
                color: uiColor,
                bandIndex: index,
                totalBands: positions.count,
                rgb: chosenColor
            )
            
            print("   → Classified as: \(colorName)")
            
            return colorName
        }
    }
    
    // MARK: - Color Extraction Methods
    private func extractColorAreaAverage(ciImage: CIImage, x: Int, context: CIContext) -> (Int, Int, Int) {
        let height = Int(ciImage.extent.height)
        let centerY = height / 2
        
        // Create sample rect accounting for image extent
        let sampleRect = CGRect(
            x: ciImage.extent.minX + CGFloat(x - 5),
            y: ciImage.extent.minY + CGFloat(centerY - 5),
            width: 10,
            height: 10
        )
        
        // Ensure rect is within bounds
        let clampedRect = sampleRect.intersection(ciImage.extent)
        guard !clampedRect.isEmpty else {
            print("   ❌ Area: Sample rect out of bounds")
            return (0, 0, 0)
        }
        
        // Try using the averageColorInRegion method
        if let avgColor = ColorUtilities.averageColorInRegion(ciImage: ciImage, region: clampedRect, context: context) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            avgColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Int(r * 255), Int(g * 255), Int(b * 255))
        }
        
        return (0, 0, 0)
    }
    
    private func extractColorDirect(ciImage: CIImage, x: Int, context: CIContext) -> (Int, Int, Int) {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
              let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            print("   ❌ Direct: Failed to create CGImage")
            return (0, 0, 0)
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let centerY = height / 2
        let bytesPerPixel = 4
        
        // Sample 5x5 area for better averaging
        var totalR = 0, totalG = 0, totalB = 0, count = 0
        
        for dy in -2...2 {
            for dx in -2...2 {
                let sampleX = x + dx
                let sampleY = centerY + dy
                
                if sampleX >= 0 && sampleX < width && sampleY >= 0 && sampleY < height {
                    let pixelIndex = (sampleY * width + sampleX) * bytesPerPixel
                    
                    let r = Int(data[pixelIndex])
                    let g = Int(data[pixelIndex + 1])
                    let b = Int(data[pixelIndex + 2])
                    
                    totalR += r
                    totalG += g
                    totalB += b
                    count += 1
                }
            }
        }
        
        if count > 0 {
            return (totalR / count, totalG / count, totalB / count)
        }
        
        return (0, 0, 0)
    }
    
    private func extractColorLargerArea(ciImage: CIImage, x: Int, context: CIContext) -> (Int, Int, Int) {
        let height = Int(ciImage.extent.height)
        let centerY = height / 2
        
        // Sample a larger 15x15 area
        let sampleRect = CGRect(
            x: ciImage.extent.minX + CGFloat(x - 7),
            y: ciImage.extent.minY + CGFloat(centerY - 7),
            width: 15,
            height: 15
        )
        
        if let avgColor = ColorUtilities.averageColorInRegion(ciImage: ciImage, region: sampleRect, context: context) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            avgColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Int(r * 255), Int(g * 255), Int(b * 255))
        }
        
        return (0, 0, 0)
    }
    
    // MARK: - Reflection Detection
    private func isLikelyReflection(rgb: (r: Int, g: Int, b: Int)) -> Bool {
        // High brightness with low saturation indicates reflection
        let brightness = (rgb.r + rgb.g + rgb.b) / 3
        let maxChannel = max(rgb.r, max(rgb.g, rgb.b))
        let minChannel = min(rgb.r, min(rgb.g, rgb.b))
        let saturation = maxChannel > 0 ? Double(maxChannel - minChannel) / Double(maxChannel) : 0
        
        // Reflection characteristics:
        // 1. High brightness (> 180)
        // 2. Low saturation (< 0.2)
        // 3. Channels are close together (within 20)
        let channelRange = maxChannel - minChannel
        
        return brightness > 180 && saturation < 0.2 && channelRange < 20
    }
    
    private func extractColorAvoidingReflection(
        ciImage: CIImage,
        x: Int,
        centerColor: (Int, Int, Int),
        context: CIContext
    ) -> (Int, Int, Int) {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
              let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return centerColor
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let centerY = height / 2
        let bytesPerPixel = 4
        
        // Sample a larger vertical area to find non-reflection pixels
        var validColors: [(Int, Int, Int)] = []
        
        for dy in -10...10 {
            let sampleY = centerY + dy
            if sampleY >= 0 && sampleY < height && x >= 0 && x < width {
                let pixelIndex = (sampleY * width + x) * bytesPerPixel
                
                let r = Int(data[pixelIndex])
                let g = Int(data[pixelIndex + 1])
                let b = Int(data[pixelIndex + 2])
                
                // Only include non-reflection colors
                if !isLikelyReflection(rgb: (r, g, b)) {
                    validColors.append((r, g, b))
                }
            }
        }
        
        // If we found valid colors, average them
        if !validColors.isEmpty {
            let avgR = validColors.map { $0.0 }.reduce(0, +) / validColors.count
            let avgG = validColors.map { $0.1 }.reduce(0, +) / validColors.count
            let avgB = validColors.map { $0.2 }.reduce(0, +) / validColors.count
            return (avgR, avgG, avgB)
        }
        
        // If all samples were reflections, return the original
        return centerColor
    }
}
