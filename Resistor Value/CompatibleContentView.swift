import SwiftUI
import AVFoundation
import UIKit
import CoreImage

struct CompatibleContentView: View {
    // MARK: - State Properties
    @State private var filteredImage: UIImage?
    @State private var capturedImage: UIImage?
    @State private var analyzedImage: UIImage?
    
    @State private var isImageCaptured = false
    @State private var zoomFactor: CGFloat = 1.0
    @State private var isTorchOn: Bool = true
    @State private var shouldCaptureNextFrame = false
    @State private var isAnalyzing: Bool = false
    @State private var baseCIImage: CIImage? // RAW captured image - no filtering
    @State private var originalImageExtent: CGRect = .zero
    @State private var pendingNavigation = false
    
    // Detection parameters - these control the slider-based filtering
    // Start with neutral values so user sees unfiltered image initially
    @State private var contrastBoost: Double = 1.0  // No contrast boost initially
    @State private var edgeIntensity: Double = 0.5  // Minimal edge enhancement initially
    @State private var bodyColorThreshold: Double = 25.0 // Neutral saturation
    @State private var filteredCIImage: CIImage? // Image after slider adjustments
    
    @State private var showGuidance = true
    @State private var guidanceOpacity = 1.0
    @State private var pulseGuideBox = false
    
    private var context = CIContext()
    
    // ✅ Use the final analyzer with comprehensive approach
    private let detectionManager = IntegratedResistorAnalyzer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if isImageCaptured, let displayImage = filteredImage ?? capturedImage {
                    
                    VStack {
                        Text("Captured Image (Adjust with sliders below)")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Image(uiImage: displayImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 250, height: 125)
                            .clipped()
                            .border(Color.blue, width: 2)
                            .resistorBandOverlay(
                                detectedBands: detectionManager.detectedBands,
                                originalImageExtent: originalImageExtent,
                                bandColors: detectionManager.detectedColors
                            )
                    }
                    
                    // Parameter adjustment controls
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Detection Parameters")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Group {
                                Text("Contrast Boost: \(contrastBoost, specifier: "%.2f")")
                                Slider(value: $contrastBoost, in: 1.0...2.0)
                                    .onChange(of: contrastBoost) { _, _ in
                                        applySliderFilters()
                                    }
                                
                                Text("Edge Intensity: \(edgeIntensity, specifier: "%.2f")")
                                Slider(value: $edgeIntensity, in: 0.5...10.0)
                                    .onChange(of: edgeIntensity) { _, _ in
                                        applySliderFilters()
                                    }
                                
                                Text("Body Color Threshold: \(bodyColorThreshold, specifier: "%.2f")")
                                Slider(value: $bodyColorThreshold, in: 10.0...50.0)
                                    .onChange(of: bodyColorThreshold) { _, _ in
                                        applySliderFilters()
                                    }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .frame(height: 200)
                    
                    // ✅ ONLY Action buttons - NO camera controls here
                    HStack(spacing: 20) {
                        Button(action: {
                            analyzeResistorAndShowResults()
                        }) {
                            Text("Analyze")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(isAnalyzing)
                        
                        Button(action: {
                            reset()
                        }) {
                            Text("Reset")
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                } else {
                    // ✅ CAMERA VIEW SECTION
                    // Camera view for capturing resistor image
                    ZStack {
                        // 1. Camera preview (base layer)
                        CameraPreviewRepresentable(
                            zoomFactor: $zoomFactor,
                            onCroppedImage: { ciImage in
                                if shouldCaptureNextFrame {
                                    processRawImage(ciImage: ciImage)
                                    isImageCaptured = true
                                    shouldCaptureNextFrame = false
                                }
                            }
                        )
                        .edgesIgnoringSafeArea(.all)
                        
                        // 2. Guide box overlay
                        GeometryReader { geometry in
                            Rectangle()
                                .strokeBorder(Color.yellow, lineWidth: pulseGuideBox ? 4 : 3)
                                .frame(width: 250, height: 125)
                                .position(
                                    x: geometry.size.width / 2,
                                    y: geometry.size.height * 0.40
                                )
                                .shadow(color: .yellow, radius: pulseGuideBox ? 8 : 4)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseGuideBox)
                                .onAppear {
                                    pulseGuideBox = true
                                    
                                    
                                }
                        }
                    }
                    
                    // ✅ CAMERA CONTROLS - ONLY shown when in camera mode (inside else clause)
                    Toggle(isOn: $isTorchOn) {
                        HStack {
                            Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .foregroundColor(isTorchOn ? .yellow : .gray)
                            Text("Torch")
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: isTorchOn) { _, newValue in
                        setTorch(on: newValue)
                    }
                    
                    Slider(value: $zoomFactor, in: 1.0...5.0).padding(.horizontal)
                    Text(String(format: "Zoom: %.2fx", zoomFactor))
                    
                    Button(action: {
                        hapticFeedback()
                        shouldCaptureNextFrame = true
                    }) {
                        HStack {
                            Image(systemName: "camera.circle.fill")
                                .font(.title)
                            Text("Capture Image")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                } // ← End of else clause - camera controls are now properly contained
            } // ← End of main VStack
            .navigationTitle("Resistor Analyzer")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $pendingNavigation) {
                ImprovedResultsView(
                    colors: detectionManager.detectedColors,
                    resistance: detectionManager.resistanceValue,
                    analyzedImage: analyzedImage,
                    bandRects: detectionManager.detectedBands
                )
            }
        }
    }
    
    // MARK: - Raw Image Processing (NO FILTERING)
    
    private func processRawImage(ciImage: CIImage) {
        print("🔍 CAPTURE: Original image extent: \(ciImage.extent)")
        
        let imageWidth = ciImage.extent.width
        let imageHeight = ciImage.extent.height
        print("🔍 CAPTURE: Image dimensions: \(imageWidth)x\(imageHeight)")
        
        let cropWidth = imageWidth * 0.5
        let cropHeight = cropWidth / 2.0 // Maintain 2:1 ratio
        
        let cropX = (imageWidth - cropWidth) / 2.0
        let cropY = (imageHeight - cropHeight) / 2.0
        
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        print("🔍 CAPTURE: Crop rect: \(cropRect)")
        
        guard ciImage.extent.contains(cropRect) else {
            print("❌ CAPTURE: Crop rect out of bounds:", cropRect)
            return
        }
        
        let cropped = ciImage.cropped(to: cropRect)
        print("🔍 CAPTURE: Cropped extent: \(cropped.extent)")
        
        // Store the RAW cropped image - NO FILTERING
        baseCIImage = cropped
        originalImageExtent = cropped.extent
        
        // Test the raw cropped image
        testRawImage(cropped)
        
        // Create the initial display image (unfiltered)
        if let cgImage = context.createCGImage(cropped, from: cropped.extent) {
            let uiImage = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
            capturedImage = uiImage
            filteredImage = uiImage // Start with unfiltered image
            filteredCIImage = cropped // Store raw CIImage for initial analysis
            print("✅ CAPTURE: Successfully created raw UIImage: \(uiImage.size)")
        } else {
            print("⚠️ CAPTURE: Failed to create CGImage from cropped extent:", cropped.extent)
        }
        
        // DON'T apply filtering initially - let user control it with sliders
        print("🔍 CAPTURE: Image ready - no initial filtering applied")
    }
    
    private func testRawImage(_ ciImage: CIImage) {
        print("🔬 Testing raw captured image...")
        
        let uiImage = UIImage(ciImage: ciImage)
        
        if let cgImage = uiImage.cgImage,
           let pixelData = cgImage.dataProvider?.data,
           let data = CFDataGetBytePtr(pixelData) {
            
            let width = cgImage.width
            let height = cgImage.height
            print("   📐 Raw image size: \(width)x\(height)")
            
            if width > 0 && height > 0 {
                // Sample center pixel
                let centerX = width / 2
                let centerY = height / 2
                let pixelIndex = (centerY * width + centerX) * 4
                
                if CFDataGetLength(pixelData) > pixelIndex + 2 {
                    let r = data[pixelIndex]
                    let g = data[pixelIndex + 1]
                    let b = data[pixelIndex + 2]
                    print("   🎨 Raw center pixel: RGB(\(r), \(g), \(b))")
                    
                    // Sample multiple points for variety check
                    var nonBlackCount = 0
                    var colorSamples: [(Int, Int, Int)] = []
                    
                    for i in stride(from: 0, to: min(width * height, 1000), by: 250) {
                        let pixelIndex = i * 4
                        if CFDataGetLength(pixelData) > pixelIndex + 2 {
                            let r = Int(data[pixelIndex])
                            let g = Int(data[pixelIndex + 1])
                            let b = Int(data[pixelIndex + 2])
                            
                            if r > 10 || g > 10 || b > 10 {
                                nonBlackCount += 1
                            }
                            
                            if colorSamples.count < 5 {
                                colorSamples.append((r, g, b))
                            }
                        }
                    }
                    
                    print("   📊 Non-black pixels in sample: \(nonBlackCount)/4")
                    print("   🎨 Sample colors: \(colorSamples)")
                }
            }
        } else {
            print("   ❌ Could not access raw pixel data")
        }
    }
    
    // MARK: - Slider-Based Filtering (ONLY runs when sliders change)
    
    private func applySliderFilters() {
        guard let inputImage = baseCIImage else {
            print("❌ FILTER: No base CI image")
            return
        }
        
        print("🔍 FILTER: Applying slider filters...")
        print("   📊 Contrast: \(contrastBoost), Edge: \(edgeIntensity), Threshold: \(bodyColorThreshold)")
        
        var outputImage = inputImage
        
        // 1. Contrast filter (based on slider)
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(outputImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(contrastBoost, forKey: kCIInputContrastKey)
            if let result = contrastFilter.outputImage {
                outputImage = result
                print("   ✅ Contrast applied: \(contrastBoost)")
            } else {
                print("   ❌ Contrast filter failed")
            }
        }
        
        // 2. Sharpen filter (based on slider)
        if let sharpenFilter = CIFilter(name: "CIUnsharpMask") {
            sharpenFilter.setValue(outputImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(edgeIntensity, forKey: kCIInputIntensityKey)
            if let result = sharpenFilter.outputImage {
                outputImage = result
                print("   ✅ Sharpening applied: \(edgeIntensity)")
            } else {
                print("   ❌ Sharpening filter failed")
            }
        }
        
        // 3. Saturation adjustment (based on body color threshold slider)
        if let saturationFilter = CIFilter(name: "CIColorControls") {
            saturationFilter.setValue(outputImage, forKey: kCIInputImageKey)
            let saturationBoost = 1.0 + (bodyColorThreshold - 25.0) / 50.0
            saturationFilter.setValue(saturationBoost, forKey: kCIInputSaturationKey)
            if let result = saturationFilter.outputImage {
                outputImage = result
                print("   ✅ Saturation applied: \(saturationBoost)")
            } else {
                print("   ❌ Saturation filter failed")
            }
            
            // 4. Reduce highlights/reflections
            if let highlightFilter = CIFilter(name: "CIHighlightShadowAdjust") {
                highlightFilter.setValue(outputImage, forKey: kCIInputImageKey)
                highlightFilter.setValue(-1.0, forKey: "inputHighlightAmount") // Reduce highlights
                highlightFilter.setValue(0.5, forKey: "inputShadowAmount")
                if let result = highlightFilter.outputImage {
                    outputImage = result
                    print("   ✅ Highlight reduction applied")
                } else {
                    print("   ❌ Highlight reduction failed")
                }
            }
        }
        
        // Store the filtered result for analysis
        filteredCIImage = outputImage
        print("🔍 FILTER: Final filtered extent: \(outputImage.extent)")
        
        // Update the display image
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            let finalUIImage = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
            filteredImage = finalUIImage
            analyzedImage = finalUIImage
            print("✅ FILTER: Successfully created filtered UIImage: \(finalUIImage.size)")
        } else {
            print("❌ FILTER: Failed to create filtered CGImage")
        }
    }
    
    // MARK: - Analysis (Uses slider-adjusted image OR raw if no filtering)
    
    private func analyzeResistorAndShowResults() {
        // Use filtered image if available, otherwise use raw
        let imageToAnalyze = filteredCIImage ?? baseCIImage
        
        guard let ciImage = imageToAnalyze else {
            print("❌ ANALYZE: No image available for analysis")
            return
        }
        
        print("🔍 ANALYZE: Starting integrated analysis...")
        isAnalyzing = true
        
        // Use the integrated analyzer
        detectionManager.analyze(ciImage: ciImage) { colors, resistance in
            DispatchQueue.main.async {
                self.isAnalyzing = false
                print("🔍 ANALYZE: Integrated analysis completed")
                
                let success = !colors.filter { $0 != "Unknown" }.isEmpty
                if success {
                    self.pendingNavigation = true
                } else {
                    print("❌ ANALYZE: Analysis failed - no valid colors detected")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func reset() {
        capturedImage = nil
        filteredImage = nil
        isImageCaptured = false
        shouldCaptureNextFrame = false
        isAnalyzing = false
        analyzedImage = nil
        baseCIImage = nil
        filteredCIImage = nil
        detectionManager.resetResults()
        
        // Reset sliders to neutral defaults (no filtering)
        contrastBoost = 1.0    // No contrast adjustment
        edgeIntensity = 0.5    // Minimal edge enhancement
        bodyColorThreshold = 25.0  // Neutral saturation
        
        print("🔄 RESET: All state cleared")
    }
    
    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Band Overlay Extension (unchanged)

extension View {
    func resistorBandOverlay(
        detectedBands: [CGRect],
        originalImageExtent: CGRect,
        bandColors: [String] = [],
        luminanceProfile: [CGFloat] = []
    ) -> some View {
        self.overlay(
            GeometryReader { geo in
                let scaleX = geo.size.width / originalImageExtent.width
                let scaleY = geo.size.height / originalImageExtent.height

                let colorMap: [String: Color] = [
                    "Black": .black,
                    "Brown": Color(red: 0.4, green: 0.26, blue: 0.13),
                    "Red": .red,
                    "Orange": Color.orange,
                    "Yellow": Color.yellow,
                    "Green": .green,
                    "Blue": .blue,
                    "Violet": .purple,
                    "Gray": .gray,
                    "White": .white,
                    "Gold": Color(red: 0.85, green: 0.65, blue: 0.13),
                    "Silver": Color(red: 192/255, green: 192/255, blue: 192/255),
                    "Unknown": .clear
                ]

                ZStack {
                    ForEach(0..<detectedBands.count, id: \.self) { index in
                        let rect = detectedBands[index]
                        let flippedMidY = originalImageExtent.height - rect.midY
                        let bandColor = index < bandColors.count ? bandColors[index] : "Unknown"

                        Rectangle()
                            .fill(colorMap[bandColor, default: .gray].opacity(0.4))
                            .frame(width: rect.width * scaleX, height: rect.height * scaleY)
                            .position(
                                x: rect.midX * scaleX,
                                y: flippedMidY * scaleY
                            )
                            .overlay(
                                Rectangle()
                                    .stroke(Color.green, lineWidth: 2)
                            )
                    }
                }
            }
        )
    }
}
