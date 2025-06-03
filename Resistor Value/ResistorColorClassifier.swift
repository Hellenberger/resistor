//
//  ResistorColorClassifier.swift
//  Resistor Value
//
//  Handles classification of colors based on RGB values and band position
//

import SwiftUI
import UIKit

class ResistorColorClassifier {
    
    // MARK: - Position-Aware Classification
    func classifyColorByPosition(
        color: UIColor,
        bandIndex: Int,
        totalBands: Int,
        rgb: (Int, Int, Int)
    ) -> String {
        // Last band is tolerance band
        if bandIndex == totalBands - 1 {
            return classifyToleranceBand(color: color, rgb: rgb)
        }
        
        // Third band (index 2) is multiplier band
        if bandIndex == 2 {
            return classifyMultiplierBand(color: color, rgb: rgb)
        }
        
        // First two bands are digit bands - NO gold/silver allowed
        return classifyDigitBand(color: color, rgb: rgb)
    }
    
    // MARK: - Tolerance Band Classification
    private func classifyToleranceBand(color: UIColor, rgb: (Int, Int, Int)) -> String {
        // Check for gold first (most common tolerance)
        // Be more lenient for tolerance band gold detection
        if isGoldColorForTolerance(rgb: rgb) {
            return "Gold"
        }
        
        // Check for silver
        if isSilverColor(rgb: rgb) {
            return "Silver"
        }
        
        // For other tolerance colors, avoid misclassifying gold as brown
        let (r, g, b) = rgb
        
        // If it's a warm color with significant green component, likely gold not brown
        if r > 80 && g > 40 && b < 30 && Double(g) / Double(r) > 0.4 {
            return "Gold"
        }
        
        // Use general classification for other tolerance colors
        let generalColor = classifyByImprovedHeuristics(rgb)
        
        // Valid tolerance colors
        let validToleranceColors = ["Gold", "Silver", "Brown", "Red", "Green", "Blue", "Violet", "Gray"]
        
        return validToleranceColors.contains(generalColor) ? generalColor : "Gold" // Default to gold
    }
    
    // MARK: - Multiplier Band Classification
    private func classifyMultiplierBand(color: UIColor, rgb: (Int, Int, Int)) -> String {
        // For multiplier position, be more lenient with yellow detection
        // Dark yellow/orange-ish colors in multiplier position are likely yellow
        if isYellowColorForMultiplier(rgb: rgb) {
            return "Yellow"
        }
        
        // Then check gold (0.1x multiplier)
        if isGoldColor(rgb: rgb) {
            return "Gold"
        }
        
        // Then silver (0.01x multiplier)
        if isSilverColor(rgb: rgb) {
            return "Silver"
        }
        
        // Check if it might be a dark yellow that was missed
        let (r, g, b) = rgb
        if r > 70 && g > 30 && b < 20 && r > g && (r - b) > 50 {
            // This is likely a shadowed yellow
            return "Yellow"
        }
        
        // Use general classification for other multiplier colors
        return classifyByImprovedHeuristics(rgb)
    }
    
    // MARK: - Digit Band Classification
    private func classifyDigitBand(color: UIColor, rgb: (Int, Int, Int)) -> String {
        // For digit bands, prioritize yellow detection
        if isYellowColor(rgb: rgb) {
            return "Yellow"
        }
        
        // Check specifically for brown vs red on digit bands
        if isBrownColor(rgb: rgb) {
            return "Brown"
        }
        
        // Use general classification but exclude gold/silver
        let classified = classifyByImprovedHeuristics(rgb)
        
        // Digit bands cannot be gold or silver
        if classified == "Gold" || classified == "Silver" {
            // If it was classified as gold/silver but it's a digit band,
            // it's likely yellow or another color affected by lighting
            if rgb.0 > 180 && rgb.1 > 150 && rgb.2 < 100 {
                return "Yellow" // Bright yellow-ish color
            }
            return "Unknown"
        }
        
        return classified
    }
    
    // MARK: - General Heuristic Classification
    private func classifyByImprovedHeuristics(_ rgb: (r: Int, g: Int, b: Int)) -> String {
        let (r, g, b) = rgb
        
        // Black - very dark colors
        if r < 40 && g < 40 && b < 40 {
            return "Black"
        }
        
        // White - very bright colors
        if r > 200 && g > 200 && b > 200 {
            return "White"
        }
        
        // Yellow (PRIORITIZED - check before gold)
        if isYellowColor(rgb: rgb) {
            return "Yellow"
        }
        
        // Gold (after yellow check)
        if isGoldColor(rgb: rgb) {
            return "Gold"
        }
        
        // Silver
        if isSilverColor(rgb: rgb) {
            return "Silver"
        }
        
        // BROWN - Check BEFORE red to catch dark reddish-brown colors
        // Brown characteristics: red dominant but not too bright, very low blue
        if isBrownColor(rgb: rgb) {
            return "Brown"
        }
        
        // Orange - High red, medium green, low blue (but not yellow/gold)
        if r > 160 && g > 80 && g < 140 && b < 70 && (r - g) > 40 {
            return "Orange"
        }
        
        // Red - High red, low green and blue (but NOT brown)
        // Stricter red detection - must have higher red values and very low green
        if r > 140 && g < 60 && b < 60 && (r - g) > 80 {
            return "Red"
        }
        
        // Red with medium thresholds
        if r > 120 && g < 50 && b < 50 && (r - g) > 70 && (r - b) > 70 {
            return "Red"
        }
        
        // Green - High green, lower red and blue
        if g > 100 && r < 80 && b < 80 && (g - r) > 30 && (g - b) > 30 {
            return "Green"
        }
        
        // Blue - High blue, lower red and green
        if b > 120 && r < 80 && g < 80 && (b - r) > 50 && (b - g) > 50 {
            return "Blue"
        }
        
        // Violet/Purple - High blue and red, low green
        if b > 80 && r > 70 && g < 60 && abs(r - b) < 50 {
            return "Violet"
        }
        
        // Gray - Balanced RGB in middle range
        if abs(r - g) < 30 && abs(g - b) < 30 && abs(r - b) < 30 &&
           r > 60 && r < 140 && g > 60 && g < 140 && b > 60 && b < 140 {
            return "Gray"
        }
        
        return "Unknown"
    }
    
    // MARK: - Color Detection Helper Functions
    private func isYellowColor(rgb: (Int, Int, Int)) -> Bool {
        let (r, g, b) = rgb
        
        // Yellow characteristics:
        // 1. High red AND high green (both > 180)
        // 2. Low blue (< 100)
        // 3. Red and green are similar (difference < 50)
        // 4. Much brighter than gold
        
        let isHighRedGreen = r > 180 && g > 160
        let isLowBlue = b < 100
        let isSimilarRedGreen = abs(r - g) < 50
        let brightness = (r + g + b) / 3
        let isBrightEnough = brightness > 140
        
        // Additional check: ensure it's not too orange-ish
        let notTooOrange = (r - g) < 30
        
        return isHighRedGreen && isLowBlue && isSimilarRedGreen && isBrightEnough && notTooOrange
    }
    
    private func isGoldColor(rgb: (Int, Int, Int)) -> Bool {
        let (r, g, b) = rgb
        
        // Gold characteristics:
        // 1. High red (100-220)
        // 2. Medium-high green (50-180)
        // 3. Low blue (< 90)
        // 4. Red > green (gold is more orange-ish than yellow)
        // 5. Green/Red ratio between 0.35 and 0.7
        
        let isHighRed = r > 100 && r < 220
        let isMediumGreen = g > 50 && g < 180
        let isLowBlue = b < 90
        let redGreaterThanGreen = r > g
        let brightness = (r + g + b) / 3
        let isRightBrightness = brightness > 80 && brightness < 180
        
        // Check green to red ratio
        let greenToRedRatio = Double(g) / Double(r)
        let hasGoldRatio = greenToRedRatio > 0.35 && greenToRedRatio < 0.7
        
        return isHighRed && isMediumGreen && isLowBlue && redGreaterThanGreen && isRightBrightness && hasGoldRatio
    }
    
    private func isSilverColor(rgb: (Int, Int, Int)) -> Bool {
        let (r, g, b) = rgb
        
        // Silver characteristics:
        // 1. Balanced RGB values (similar to each other)
        // 2. Medium brightness (120-180 range)
        // 3. Low saturation
        
        let isBalanced = abs(r - g) < 30 && abs(g - b) < 30 && abs(r - b) < 30
        let isMediumBright = r > 120 && r < 180 && g > 120 && g < 180 && b > 120 && b < 180
        
        return isBalanced && isMediumBright
    }
    
    private func isBrownColor(rgb: (Int, Int, Int)) -> Bool {
        let (r, g, b) = rgb
        
        // Brown characteristics:
        // 1. Red dominant but not too high (60-140)
        // 2. Green much lower than red but not zero (0-70)
        // 3. Blue very low (< 30)
        // 4. Red should be roughly 2x green or more
        
        // IMPORTANT: Exclude colors that might be dark yellow or gold
        // If green is more than 40% of red, it's likely yellow/gold not brown
        if g > 20 && Double(g) / Double(r) > 0.4 {
            return false
        }
        
        // Dark reddish-brown (like RGB(67, 0, 0) or RGB(79, 0, 0))
        if r > 60 && r < 130 && g < 20 && b < 20 {
            return true
        }
        
        // Medium brown - but not if it could be dark yellow/gold
        // Tightened constraints to avoid gold colors
        if r > 80 && r < 140 && g > 20 && g < 50 && b < 30 &&
           r > g && (r - g) > 50 && (g - b) > 10 {
            return true
        }
        
        // Light brown (beige-ish) - but not gold
        if r > 120 && r < 180 && g > 60 && g < 100 && b > 20 && b < 60 &&
           r > g && r > b && (r - g) > 40 && (g - b) > 20 {
            return true
        }
        
        return false
    }
    
    private func isYellowColorForMultiplier(rgb: (Int, Int, Int)) -> Bool {
        let (r, g, b) = rgb
        
        // For multiplier position, be more lenient
        // Accept darker yellows that might be in shadow
        
        // Standard yellow
        if isYellowColor(rgb: rgb) {
            return true
        }
        
        // Dark yellow / orange-yellow (common in multiplier position)
        // Like RGB(87, 40, 0) or RGB(121, 73, 0)
        if r > 70 && g > 30 && b < 20 &&
           r > g && g > b &&
           Double(g) / Double(r) > 0.3 && Double(g) / Double(r) < 0.8 {
            return true
        }
        
        return false
    }
    
    private func isGoldColorForTolerance(rgb: (Int, Int, Int)) -> Bool {
        let (r, g, b) = rgb
        
        // Standard gold check
        if isGoldColor(rgb: rgb) {
            return true
        }
        
        // For tolerance band, be more lenient with gold detection
        // Gold tolerance bands can appear darker/browner under certain lighting
        // RGB(106, 52, 6) should be recognized as gold
        if r > 80 && r < 180 &&
           g > 40 && g < 120 &&
           b < 40 &&
           r > g && g > b &&
           Double(g) / Double(r) > 0.35 && Double(g) / Double(r) < 0.7 {
            return true
        }
        
        return false
    }
    
    // ✅ NEW: More lenient yellow detection for digit bands
    private func isYellowForDigitBand(rgb: (Int, Int, Int)) -> Bool {
        let (r, g, b) = rgb
        
        // Standard yellow check
        if isYellowColor(rgb: rgb) {
            return true
        }
        
        // For digit bands, be more lenient with yellow
        // RGB(224, 180, 78) should be recognized as yellow
        if r > 180 && g > 140 && b < 100 &&
           r > g && g > b &&
           (r - b) > 80 {
            return true
        }
        
        // Also check for darker yellows
        if r > 160 && g > 120 && b < 80 &&
           Double(g) / Double(r) > 0.65 && Double(g) / Double(r) < 0.9 {
            return true
        }
        
        return false
    }
}
