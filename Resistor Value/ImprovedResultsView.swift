//
//  ImprovedResultsView.swift
//  Resistor Value
//
//  Created by Howard Ellenberger on 4/19/25.
//

import SwiftUI

struct ImprovedResultsView: View {
    let colors: [String]
    let resistance: Double?
    let analyzedImage: UIImage?
    let bandRects: [CGRect]
    
    @Environment(\.presentationMode) var presentationMode
    
    // State for animations and interactions
    @State private var showReference: Bool = false
    @State private var animateEntrance: Bool = false
    
    var body: some View {

        ScrollView {
            VStack(spacing: 30) {
                // Image with green overlays
                
                if let img = analyzedImage {
                    BandOverlayImage(
                        uiImage: img,
                        bandRects: bandRects
                    )
                    .onAppear {
                            print("BANDRECTS PASSED:", bandRects)
                        }
                    .aspectRatio(img.size, contentMode: .fit)
                    .frame(maxWidth: 500, maxHeight: 300) // Try a larger size!
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding(.vertical)


                }
                // Title with animated appearance
                Text("Resistor Analysis")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top)
                    .opacity(animateEntrance ? 1 : 0)
                    .offset(y: animateEntrance ? 0 : -20)
                
                // Resistor visualization
                resistorVisualization
                    .opacity(animateEntrance ? 1 : 0)
                    .scaleEffect(animateEntrance ? 1 : 0.8)
                
                // Resistance value display
                resistanceValueView
                    .opacity(animateEntrance ? 1 : 0)
                    .offset(y: animateEntrance ? 0 : 20)
                
                // Tolerance display
                toleranceView
                    .opacity(animateEntrance ? 1 : 0)
                    .offset(y: animateEntrance ? 0 : 20)
                
                // Additional information
                VStack(spacing: 5) {
                    Button(action: {
                        withAnimation {
                            showReference.toggle()
                        }
                    }) {
                        HStack {
                            Text(showReference ? "Hide Reference" : "Show Color Code Reference")
                            Image(systemName: showReference ? "chevron.up" : "chevron.down")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    if showReference {
                        colorReferenceView
                            .transition(.opacity)
                    }
                }
                .opacity(animateEntrance ? 1 : 0)
                
                // Button row
                buttonRow
                    .opacity(animateEntrance ? 1 : 0)
                    .offset(y: animateEntrance ? 0 : 30)
                
                Spacer(minLength: 20)
            }
            .padding()
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateEntrance = true
                }
            }
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
    }

    
    struct BandOverlayImage: View {
        let uiImage: UIImage
        let bandRects: [CGRect]

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    ForEach(0..<bandRects.count, id: \.self) { idx in
                        let rect = bandRects[idx]
                        Rectangle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(
                                width: rect.width * geometry.size.width / uiImage.size.width,
                                height: rect.height * geometry.size.height / uiImage.size.height
                            )
                            .position(
                                x: rect.midX * geometry.size.width / uiImage.size.width,
                                y: rect.midY * geometry.size.height / uiImage.size.height
                            )
                    }
                }
                .onAppear {
                    print("BANDRECTS DRAWING:", bandRects)
                }
            }
        }
    }


    // Resistor visualization with color bands
    private var resistorVisualization: some View {
        VStack(spacing: 12) {
            Text("Detected Color Bands")
                .font(.headline)
            
            ZStack {
                // Resistor body
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.brown.opacity(0.7))
                    .frame(width: 300, height: 70)
                
                // Leads
                Rectangle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 40, height: 2)
                    .offset(x: -170, y: 0)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 40, height: 2)
                    .offset(x: 170, y: 0)
                
                // Color bands
                HStack(spacing: calculateBandSpacing()) {
                    ForEach(colors.indices, id: \.self) { index in
                        Rectangle()
                            .fill(colorFromName(colors[index]))
                            .frame(width: 20, height: 70)
                    }
                }
            }
            
            // Color labels
            HStack(spacing: calculateBandSpacing(extraSpace: 5)) {
                ForEach(colors.indices, id: \.self) { index in
                    Text(shortenColorName(colors[index]))
                        .font(.caption)
                        .frame(width: 30)
                        .fixedSize()
                }
            }
            .padding(.top, 5)
        }
    }
    
    // Resistance value display
    private var resistanceValueView: some View {
        VStack(spacing: 8) {
            Text("Resistance Value")
                .font(.headline)
            
            if let resistanceValue = resistance {
                Text(formatResistance(resistanceValue))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
                
                // Explain what the value means
                Text(explainResistorValue(resistanceValue))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text("Could not determine resistance")
                    .font(.title3)
                    .foregroundColor(.red)
                
                Text("Try adjusting the image or checking the resistor orientation")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // Tolerance display
    private var toleranceView: some View {
        VStack(spacing: 8) {
            if colors.count >= 4 {
                Text("Tolerance")
                    .font(.headline)
                
                HStack {
                    Text(getTolerance(fromColor: colors.last ?? "Unknown"))
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Spacer().frame(width: 10)
                    
                    Text("Precision")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if let tolerance = getToleranceValue(fromColor: colors.last ?? "Unknown"),
                   let resistanceValue = resistance {
                    let minVal = resistanceValue * (1.0 - tolerance)
                    let maxVal = resistanceValue * (1.0 + tolerance)
                    
                    Text("Range: \(formatResistance(minVal)) - \(formatResistance(maxVal))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                Text("No tolerance band detected")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // Color reference guide
    private var colorReferenceView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Resistor Color Code Reference")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Digit Values")
                    .font(.subheadline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(getDigitColors(), id: \.self) { color in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(colorFromName(color))
                                .frame(width: 15, height: 15)
                            Text("\(color): \(getColorDigitValue(color))")
                                .font(.caption)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Multiplier Values")
                    .font(.subheadline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(getMultiplierColors(), id: \.self) { color in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(colorFromName(color))
                                .frame(width: 15, height: 15)
                            Text("\(color): \(getMultiplierText(color))")
                                .font(.caption)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tolerance Values")
                    .font(.subheadline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(getToleranceColors(), id: \.self) { color in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(colorFromName(color))
                                .frame(width: 15, height: 15)
                            Text("\(color): \(getTolerance(fromColor: color))")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // Action buttons
    private var buttonRow: some View {
        HStack(spacing: 20) {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Back")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: {
                // Share functionality
                let shareText = "Resistor value: \(resistance.map { formatResistance($0) } ?? "Unknown")\nColors: \(colors.joined(separator: ", "))"
                
                let activityVC = UIActivityViewController(
                    activityItems: [shareText],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Formats resistance with appropriate unit (Ohm, KOhm, MOhm)
    private func formatResistance(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.2f MΩ", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.2f KΩ", value / 1_000)
        } else {
            return String(format: "%.2f Ω", value)
        }
    }
    
    /// Gets explanation text for the resistor value
    private func explainResistorValue(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "This resistor has a high resistance value suitable for voltage dividers or high impedance circuits."
        } else if value >= 10_000 {
            return "This resistor has a medium-high resistance, commonly used in timing circuits or pull-up/down resistors."
        } else if value >= 1_000 {
            return "This resistor has a medium resistance value, common in signal conditioning or biasing circuits."
        } else if value >= 100 {
            return "This resistor has a medium-low resistance, often used in filtering, LED current limiting, or audio circuits."
        } else {
            return "This resistor has a low resistance value, typically used for current sensing or power applications."
        }
    }
    
    /// Gets tolerance text from color
    private func getTolerance(fromColor color: String) -> String {
        let tolerances: [String: String] = [
            "Brown": "±1%",
            "Red": "±2%",
            "Orange": "±3%",
            "Yellow": "±4%",
            "Green": "±0.5%",
            "Blue": "±0.25%",
            "Violet": "±0.1%",
            "Gray": "±0.05%",
            "Gold": "±5%",
            "Silver": "±10%"
        ]
        
        return tolerances[color] ?? "Unknown"
    }
    
    /// Gets tolerance value as a decimal (for calculations)
    private func getToleranceValue(fromColor color: String) -> Double? {
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
    
    /// Converts color name to actual Color
    private func colorFromName(_ name: String) -> Color {
        switch name {
            case "Black": return .black
            case "Brown": return Color(red: 0.6, green: 0.3, blue: 0.1)
            case "Red": return .red
            case "Orange": return .orange
            case "Yellow": return .yellow
            case "Green": return .green
            case "Blue": return .blue
            case "Violet", "Purple": return Color(red: 0.6, green: 0.0, blue: 0.8)
            case "Gray": return .gray
            case "White": return .white
            case "Gold": return Color(red: 0.83, green: 0.68, blue: 0.21) // Proper gold
            case "Silver": return Color(red: 0.75, green: 0.75, blue: 0.75)
            case "Unknown": return Color.gray.opacity(0.5)
            default: return .clear
        }
    }
    
    /// Shortens color name for display
    private func shortenColorName(_ name: String) -> String {
        switch name {
        case "Black": return "Blk"
        case "Brown": return "Brn"
        case "Orange": return "Org"
        case "Yellow": return "Yel"
        case "Green": return "Grn"
        case "Blue": return "Blu"
        case "Violet": return "Vio"
        case "Gray": return "Gry"
        case "White": return "Wht"
        case "Silver": return "Sil"
        case "Unknown": return "Unk"
        default: return name.prefix(3).lowercased().capitalized
        }
    }
    
    /// Calculates spacing between bands
    private func calculateBandSpacing(extraSpace: CGFloat = 0) -> CGFloat {
        let totalBands = CGFloat(colors.count)
        if totalBands <= 1 { return 0 }
        
        let availableWidth: CGFloat = 200
        let bandWidth: CGFloat = 20
        
        let spacing = (availableWidth - (totalBands * bandWidth)) / (totalBands - 1)
        return spacing + extraSpace
    }
    
    /// Gets list of colors used for digit values
    private func getDigitColors() -> [String] {
        return ["Black", "Brown", "Red", "Orange", "Yellow", "Green", "Blue", "Violet", "Gray", "White"]
    }
    
    /// Gets list of colors used for multiplier values
    private func getMultiplierColors() -> [String] {
        return ["Black", "Brown", "Red", "Orange", "Yellow", "Green", "Blue", "Violet", "Gray", "White", "Gold", "Silver"]
    }
    
    /// Gets list of colors used for tolerance values
    private func getToleranceColors() -> [String] {
        return ["Brown", "Red", "Orange", "Yellow", "Green", "Blue", "Violet", "Gray", "Gold", "Silver"]
    }
    
    /// Gets digit value for a color
    private func getColorDigitValue(_ color: String) -> String {
        let values: [String: String] = [
            "Black": "0", "Brown": "1", "Red": "2", "Orange": "3", "Yellow": "4",
            "Green": "5", "Blue": "6", "Violet": "7", "Gray": "8", "White": "9"
        ]
        
        return values[color] ?? "?"
    }
    
    /// Gets multiplier text for a color
    private func getMultiplierText(_ color: String) -> String {
        let values: [String: String] = [
            "Black": "×1", "Brown": "×10", "Red": "×100", "Orange": "×1K", "Yellow": "×10K",
            "Green": "×100K", "Blue": "×1M", "Violet": "×10M", "Gray": "×100M", "White": "×1G",
            "Gold": "×0.1", "Silver": "×0.01"
        ]
        
        return values[color] ?? "?"
    }
}
