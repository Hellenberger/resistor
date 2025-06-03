//
//  IntegratedResistorAnalyzer.swift
//  Resistor Value
//
//  Main analyzer class that coordinates the analysis process
//

import SwiftUI
import CoreImage
import UIKit

class IntegratedResistorAnalyzer {
    private let context = CIContext()
    public var detectedBands: [CGRect] = []
    
    // Properties for compatibility with CompatibleContentView
    var detectedColors: [String] = []
    var resistanceValue: Double?
    
    // Helper components
    private let colorSampler = ResistorColorSampler()
    private let bandDetector = ResistorBandDetector()
    private let colorExtractor = ResistorColorExtractor()
    private let colorClassifier = ResistorColorClassifier()
    
    init() {
        // Empty initializer
    }
    
    // MARK: - Main Analysis Function
    func analyze(ciImage: CIImage, completion: @escaping ([String], Double?) -> Void) {
        print("🔍 INTEGRATED: Starting analysis on image extent: \(ciImage.extent)")
        
        // 1. Sample body color using multiple methods for robustness
        let bodyColor = colorSampler.sampleBodyColorCombined(ciImage: ciImage, context: context)
        print("🎨 INTEGRATED: Body color sampled: RGB(\(bodyColor.r), \(bodyColor.g), \(bodyColor.b))")
        
        // 2. Use integrated band detection
        let bandPositions = bandDetector.detectBands(
            ciImage: ciImage,
            bodyColor: bodyColor,
            context: context
        )
        
        print("📍 INTEGRATED: Detected band positions: \(bandPositions)")
        
        // 3. Create band rectangles
        self.detectedBands = createBandRectangles(
            positions: bandPositions,
            imageWidth: Int(ciImage.extent.width),
            imageHeight: Int(ciImage.extent.height),
            originalExtent: ciImage.extent
        )
        
        print("📏 INTEGRATED: Created \(self.detectedBands.count) band rectangles")
        
        // 4. Extract colors using both direct pixel and area average methods
        let rawColors = colorExtractor.extractColors(
            ciImage: ciImage,
            positions: bandPositions,
            bodyColor: bodyColor,
            context: context,
            colorClassifier: colorClassifier
        )
        
        print("🎨 INTEGRATED: Raw extracted colors: \(rawColors)")
        
        // 5. Validate and correct the band sequence
        let correctedColors = validateAndCorrectBandSequence(rawColors)
        
        print("🎨 INTEGRATED: Final corrected colors: \(correctedColors)")
        
        // 6. Calculate resistance
        let resistance = ImprovedResistorCalculator().calculateResistance(from: correctedColors)
        
        // Store results for compatibility
        self.detectedColors = correctedColors
        self.resistanceValue = resistance
        
        completion(correctedColors, resistance)
    }
    
    // MARK: - Band Sequence Validation
    private func validateAndCorrectBandSequence(_ colors: [String]) -> [String] {
        var correctedColors = colors
        
        print("🔧 Validating band sequence: \(colors)")
        
        // Handle 5-band resistors (3 digits + multiplier + tolerance)
        if colors.count == 5 {
            print("🔧 Detected 5-band resistor")
            
            // For 5-band resistors, only replace Unknown colors
            for i in 0..<correctedColors.count {
                if correctedColors[i] == "Unknown" {
                    if i <= 2 {
                        // First three are digit bands - default to common values
                        correctedColors[i] = i == 0 ? "Brown" : "Black"
                        print("🔧 Replacing Unknown at position \(i) with \(correctedColors[i])")
                    } else if i == 3 {
                        // Fourth is multiplier
                        correctedColors[i] = "Brown" // 10x multiplier
                        print("🔧 Replacing Unknown at position 3 with Brown (10x)")
                    } else if i == 4 {
                        // Fifth is tolerance
                        correctedColors[i] = "Gold"
                        print("🔧 Replacing Unknown at position 4 with Gold")
                    }
                }
            }
            
            // For now, convert 5-band to 4-band by combining first two digits
            if correctedColors.count == 5 {
                print("🔧 Converting 5-band to 4-band format")
                // Take bands 0, 2, 3, 4 (skip second digit)
                correctedColors = [correctedColors[0], correctedColors[2], correctedColors[3], correctedColors[4]]
            }
        } else {
            // Handle 4-band resistors as before
            for i in 0..<correctedColors.count {
                if correctedColors[i] == "Unknown" {
                    if i == 0 {
                        correctedColors[i] = "Brown"
                        print("🔧 Replacing Unknown at position 0 with Brown")
                    } else if i == 1 {
                        correctedColors[i] = "Black"
                        print("🔧 Replacing Unknown at position 1 with Black")
                    } else if i == 2 {
                        correctedColors[i] = "Yellow"
                        print("🔧 Replacing Unknown at position 2 with Yellow")
                    } else if i == 3 {
                        correctedColors[i] = "Gold"
                        print("🔧 Replacing Unknown at position 3 with Gold")
                    }
                }
            }
        }
        
        // Validate bands if we have 4
        if correctedColors.count >= 4 {
            let tolerance = correctedColors[3]
            let multiplier = correctedColors[2]
            
            // Validate tolerance band
            let validToleranceBands = ["Gold", "Silver", "Brown", "Red", "Green", "Blue", "Violet", "Gray"]
            if !validToleranceBands.contains(tolerance) {
                print("🔧 Invalid tolerance band '\(tolerance)', defaulting to Gold")
                correctedColors[3] = "Gold"
            }
            
            // Validate multiplier
            let validMultipliers = ["Black", "Brown", "Red", "Orange", "Yellow", "Green", "Blue", "Violet", "Gray", "White", "Gold", "Silver"]
            if !validMultipliers.contains(multiplier) {
                print("🔧 Invalid multiplier '\(multiplier)', defaulting to Yellow")
                correctedColors[2] = "Yellow"
            }
        }
        
        // Ensure we have exactly 4 bands
        if correctedColors.count > 4 {
            print("🔧 Trimming to 4 bands: \(correctedColors.prefix(4))")
            correctedColors = Array(correctedColors.prefix(4))
        } else if correctedColors.count < 4 {
            while correctedColors.count < 4 {
                if correctedColors.count == 2 {
                    correctedColors.append("Yellow")
                } else if correctedColors.count == 3 {
                    correctedColors.append("Gold")
                }
            }
            print("🔧 Padded to 4 bands: \(correctedColors)")
        }
        
        if correctedColors != colors {
            print("🔧 Corrected sequence: \(colors) → \(correctedColors)")
        } else {
            print("✅ Band sequence validation passed")
        }
        
        return correctedColors
    }
    
    // MARK: - Helper Methods
    private func createBandRectangles(
        positions: [Int],
        imageWidth: Int,
        imageHeight: Int,
        originalExtent: CGRect
    ) -> [CGRect] {
        let bandWidth: CGFloat = 12.0
        let bandHeight: CGFloat = CGFloat(imageHeight) * 0.7
        let bandY: CGFloat = CGFloat(imageHeight) * 0.15
        
        // Convert positions from pixel coordinates to CIImage coordinates
        let scaleX = originalExtent.width / CGFloat(imageWidth)
        let scaleY = originalExtent.height / CGFloat(imageHeight)
        
        return positions.map { x in
            CGRect(
                x: originalExtent.minX + (CGFloat(x) * scaleX) - bandWidth/2,
                y: originalExtent.minY + (bandY * scaleY),
                width: bandWidth,
                height: bandHeight * scaleY
            )
        }
    }
    
    // MARK: - Reset Method
    func resetResults() {
        detectedBands = []
        detectedColors = []
        resistanceValue = nil
        print("🔄 INTEGRATED: Results reset")
    }
}
