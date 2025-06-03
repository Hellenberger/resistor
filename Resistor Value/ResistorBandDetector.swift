//
//  ResistorBandDetector.swift
//  Resistor Value
//
//  Created by Howard Ellenberger on 6/2/25.
//


//
//  ResistorBandDetector.swift
//  Resistor Value
//
//  Handles detection of resistor color bands
//

import SwiftUI
import CoreImage
import UIKit

class ResistorBandDetector {
    
    // MARK: - Main Band Detection
    func detectBands(ciImage: CIImage, bodyColor: (r: Int, g: Int, b: Int), context: CIContext) -> [Int] {
        // Create profiles using multiple methods
        let directProfile = createDirectPixelProfile(ciImage: ciImage, bodyColor: bodyColor, context: context)
        let areaProfile = createAreaAverageProfile(ciImage: ciImage, bodyColor: bodyColor, context: context)
        
        print("📊 DETECTOR: Direct profile length: \(directProfile.count)")
        print("📊 DETECTOR: Area profile length: \(areaProfile.count)")
        
        // Combine profiles with weighting
        let combinedProfile = combineProfiles(directProfile, areaProfile)
        
        // Apply adaptive smoothing
        let smoothedProfile = adaptiveSmooth(profile: combinedProfile)
        
        // Find bands using dynamic thresholding
        let bandPositions = findBandsDynamicThreshold(profile: smoothedProfile)
        
        // Validate and adjust if needed
        return validateBandPositions(bandPositions, imageWidth: Int(ciImage.extent.width))
    }
    
    // MARK: - Profile Creation
    private func createDirectPixelProfile(ciImage: CIImage, bodyColor: (r: Int, g: Int, b: Int), context: CIContext) -> [Double] {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
              let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            print("❌ DETECTOR: Cannot create direct pixel profile")
            return []
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let middleY = height / 2
        
        var profile: [Double] = []
        
        for x in 0..<width {
            let pixelIndex = (middleY * width + x) * 4
            
            let r = Int(data[pixelIndex])
            let g = Int(data[pixelIndex + 1])
            let b = Int(data[pixelIndex + 2])
            
            let distance = ColorUtilities.colorDistanceLAB((r, g, b), bodyColor)
            profile.append(distance)
        }
        
        return profile
    }
    
    private func createAreaAverageProfile(ciImage: CIImage, bodyColor: (r: Int, g: Int, b: Int), context: CIContext) -> [Double] {
        let width = Int(ciImage.extent.width)
        let height = Int(ciImage.extent.height)
        let centerY = CGFloat(height) / 2.0
        
        var profile: [Double] = []
        
        for x in stride(from: 0, to: width, by: 2) {
            let sampleRect = CGRect(
                x: ciImage.extent.minX + CGFloat(x) - 1,
                y: ciImage.extent.minY + centerY - 2,
                width: 2,
                height: 4
            )
            
            if let avgColor = ColorUtilities.averageColorInRegion(ciImage: ciImage, region: sampleRect, context: context) {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                avgColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                
                let sampleRGB = (Int(r * 255), Int(g * 255), Int(b * 255))
                let distance = ColorUtilities.colorDistanceLAB(sampleRGB, bodyColor)
                profile.append(distance)
            } else {
                profile.append(0)
            }
        }
        
        // Interpolate to full width
        var fullProfile: [Double] = []
        for i in 0..<width {
            let index = i / 2
            if index < profile.count {
                fullProfile.append(profile[index])
            }
        }
        
        return fullProfile
    }
    
    // MARK: - Profile Processing
    private func combineProfiles(_ profile1: [Double], _ profile2: [Double]) -> [Double] {
        guard !profile1.isEmpty && !profile2.isEmpty else {
            return profile1.isEmpty ? profile2 : profile1
        }
        
        let minLength = min(profile1.count, profile2.count)
        var combined: [Double] = []
        
        for i in 0..<minLength {
            // Give more weight to the profile with higher contrast at this point
            let weight1 = profile1[i] > 0 ? 0.6 : 0.4
            let weight2 = 1.0 - weight1
            
            combined.append(profile1[i] * weight1 + profile2[i] * weight2)
        }
        
        return combined
    }
    
    private func adaptiveSmooth(profile: [Double]) -> [Double] {
        let baseKernel = 3
        var smoothed: [Double] = []
        
        for i in 0..<profile.count {
            // Calculate local variance
            let start = max(0, i - 5)
            let end = min(profile.count - 1, i + 5)
            let localValues = Array(profile[start...end])
            let variance = ColorUtilities.calculateVariance(localValues)
            
            // Adjust kernel size based on variance
            let kernelSize = variance > 100 ? baseKernel : baseKernel + 2
            
            // Apply smoothing
            var sum = 0.0
            var count = 0
            
            for j in -kernelSize...kernelSize {
                let index = i + j
                if index >= 0 && index < profile.count {
                    sum += profile[index]
                    count += 1
                }
            }
            
            smoothed.append(count > 0 ? sum / Double(count) : 0)
        }
        
        return smoothed
    }
    
    // MARK: - Band Finding
    private func findBandsDynamicThreshold(profile: [Double]) -> [Int] {
        let sortedProfile = profile.sorted()
        
        // Calculate dynamic threshold using statistics
        let q1Index = sortedProfile.count / 4
        let q3Index = (sortedProfile.count * 3) / 4
        let q1 = sortedProfile[q1Index]
        let q3 = sortedProfile[q3Index]
        let iqr = q3 - q1
        
        let medianIndex = sortedProfile.count / 2
        let median = sortedProfile[medianIndex]
        let maxValue = sortedProfile.last ?? 0
        
        // More aggressive threshold
        let dynamicThreshold = max(median + 0.3 * iqr, maxValue * 0.20)
        
        print("📊 DETECTOR: Dynamic threshold: \(dynamicThreshold) (Median: \(median), Q3: \(q3), IQR: \(iqr), Max: \(maxValue))")
        
        // Find sustained high regions
        var regions: [(start: Int, end: Int, avgValue: Double)] = []
        var currentStart: Int? = nil
        
        for i in 0..<profile.count {
            if profile[i] > dynamicThreshold {
                if currentStart == nil {
                    currentStart = i
                }
            } else if let start = currentStart {
                let end = i - 1
                if end - start >= 3 { // Lower minimum band width
                    let avgValue = profile[start...end].reduce(0, +) / Double(end - start + 1)
                    regions.append((start: start, end: end, avgValue: avgValue))
                }
                currentStart = nil
            }
        }
        
        // Handle region at end
        if let start = currentStart, profile.count - start >= 3 {
            let avgValue = profile[start...].reduce(0, +) / Double(profile.count - start)
            regions.append((start: start, end: profile.count - 1, avgValue: avgValue))
        }
        
        print("📊 DETECTOR: Found \(regions.count) regions")
        
        // If we have too few regions, try with a lower threshold
        if regions.count < 4 && maxValue > 0 {
            print("📊 DETECTOR: Too few bands detected, trying lower threshold")
            let lowerThreshold = maxValue * 0.15
            regions = findRegionsWithThreshold(profile: profile, threshold: lowerThreshold)
            print("📊 DETECTOR: With lower threshold, found \(regions.count) regions")
        }
        
        // Sort by position (left to right)
        let sortedRegions = regions.sorted { $0.start < $1.start }
        
        // Take up to 5 bands (4-band or 5-band resistors)
        let topRegions = Array(sortedRegions.prefix(5))
        
        // Extract center positions
        let positions = topRegions.map { region in
            (region.start + region.end) / 2
        }
        
        return positions
    }
    
    private func findRegionsWithThreshold(profile: [Double], threshold: Double) -> [(start: Int, end: Int, avgValue: Double)] {
        var regions: [(start: Int, end: Int, avgValue: Double)] = []
        var currentStart: Int? = nil
        
        for i in 0..<profile.count {
            if profile[i] > threshold {
                if currentStart == nil {
                    currentStart = i
                }
            } else if let start = currentStart {
                let end = i - 1
                if end - start >= 3 {
                    let avgValue = profile[start...end].reduce(0, +) / Double(end - start + 1)
                    regions.append((start: start, end: end, avgValue: avgValue))
                }
                currentStart = nil
            }
        }
        
        if let start = currentStart, profile.count - start >= 3 {
            let avgValue = profile[start...].reduce(0, +) / Double(profile.count - start)
            regions.append((start: start, end: profile.count - 1, avgValue: avgValue))
        }
        
        return regions
    }
    
    // MARK: - Band Validation
    private func validateBandPositions(_ positions: [Int], imageWidth: Int) -> [Int] {
        // Check if we have reasonable number of bands
        if positions.count >= 3 && positions.count <= 5 {
            // Check spacing
            var validPositions: [Int] = []
            let minSpacing = imageWidth / 20 // 5% of image width
            
            for pos in positions {
                if validPositions.isEmpty || pos - validPositions.last! >= minSpacing {
                    validPositions.append(pos)
                }
            }
            
            if validPositions.count >= 3 {
                return validPositions
            }
        }
        
        // Fallback to even distribution
        print("⚠️ DETECTOR: Using fallback band positions")
        let bandCount = 4
        let spacing = imageWidth / (bandCount + 1)
        return (1...bandCount).map { i in spacing * i }
    }
}