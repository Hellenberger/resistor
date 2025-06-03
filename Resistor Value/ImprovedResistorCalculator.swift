//
//  ImprovedResistorCalculator.swift
//  Resistor Value
//
//  Created by Howard Ellenberger on 6/3/25.
//


//
//  ImprovedResistorCalculator.swift
//  Resistor Value
//
//  Handles resistance calculation from color bands
//

import Foundation

class ImprovedResistorCalculator {
    var detectedBands: [CGRect] = []
    var luminanceProfile: [CGFloat] = []
    var lastDetectedBands: [CGRect] = []
    var lastLuminanceProfile: [CGFloat] = []
    
    private let resistorDigitValues: [String: Int] = [
        "Black": 0, "Brown": 1, "Red": 2, "Orange": 3, "Yellow": 4,
        "Green": 5, "Blue": 6, "Violet": 7, "Gray": 8, "White": 9
    ]
    
    private let resistorMultiplierValues: [String: Double] = [
        "Black": 1.0, "Brown": 10.0, "Red": 100.0, "Orange": 1000.0, "Yellow": 10000.0,
        "Green": 100000.0, "Blue": 1000000.0, "Violet": 10000000.0, "Gray": 100000000.0, "White": 1000000000.0,
        "Gold": 0.1, "Silver": 0.01
    ]
    
    func calculateResistance(from bandColors: [String]) -> Double? {
        print("🧮 Calculating resistance from: \(bandColors)")

        guard bandColors.count >= 3 else {
            print("🧮 Not enough bands detected")
            return nil
        }

        // Strictly use the first three bands for digits and multiplier
        let digit1Color = bandColors[0]
        let digit2Color = bandColors[1]
        let multiplierColor = bandColors[2]

        guard let digit1 = resistorDigitValues[digit1Color],
              let digit2 = resistorDigitValues[digit2Color],
              let multiplier = resistorMultiplierValues[multiplierColor] else {
            print("🧮 Invalid digit or multiplier detected. Digit1: \(digit1Color), Digit2: \(digit2Color), Multiplier: \(multiplierColor)")
            return nil
        }

        let resistance = Double(digit1 * 10 + digit2) * multiplier
        print("🧮 Calculated Resistance: \(digit1)\(digit2) × \(multiplier) = \(resistance)Ω")
        return resistance
    }
    
    func formatResistance(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.2f MΩ", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.2f KΩ", value / 1_000)
        } else {
            return String(format: "%.2f Ω", value)
        }
    }

    func getToleranceValue(from colors: [String]) -> Double? {
        guard let lastColor = colors.last else { return nil }
        return getToleranceValue(fromColor: lastColor)
    }

    func getToleranceValue(fromColor color: String) -> Double? {
        let tolerances: [String: Double] = [
            "Brown": 0.01,
            "Red": 0.02,
            "Orange": 0.03,
            "Yellow": 0.04,
            "Green": 0.005,
            "Blue": 0.0025,
            "Violet": 0.001,
            "Gray": 0.0005,
            "Gold": 0.05,
            "Silver": 0.10
        ]
        return tolerances[color]
    }
}