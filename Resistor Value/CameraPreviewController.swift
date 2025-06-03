import UIKit
import SwiftUI
import AVFoundation
import CoreImage

extension Notification.Name {
    static let didCaptureProcessedImage = Notification.Name("didCaptureProcessedImage")
}

class CameraPreviewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let session = AVCaptureSession()
    private let context = CIContext()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    var zoomFactor: CGFloat = 1.0 {
        didSet {
            updateZoom()
        }
    }

    var onCroppedImage: ((CIImage) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.main.async {
            self.setupCameraSession()
            self.setupPreviewLayer()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure the preview layer always fills the screen.
        previewLayer?.frame = view.layer.bounds
    }

    private func setupCameraSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("Error: Camera device not available")
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    print("Error: Could not add input to session")
                    self.session.commitConfiguration()
                    return
                }
            } catch {
                print("Error creating AVCaptureDeviceInput: \(error.localizedDescription)")
                self.session.commitConfiguration()
                return
            }

            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue"))
            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
            } else {
                print("Error: Could not add output to session")
                self.session.commitConfiguration()
                return
            }

            self.session.commitConfiguration()

            if !self.session.isRunning {
                self.session.startRunning()
            }

            // ✅ Explicitly set torch to ON by default
            DispatchQueue.main.async {
                self.setTorch(on: true)
            }
        }
    }

    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error.localizedDescription)")
        }
    }
    
    private func optimizeLightingForResistor() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Set exposure mode for consistent lighting
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            // Lock white balance for color consistency
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // Optimize focus for close-up shots
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to optimize camera settings: \(error)")
        }
    }


    private func setupPreviewLayer() {
        DispatchQueue.main.async {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
            guard let previewLayer = self.previewLayer else { return }
            previewLayer.frame = self.view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            self.view.layer.insertSublayer(previewLayer, at: 0)
        }
    }

    func updateSettings(zoomFactor: CGFloat) {
        self.zoomFactor = zoomFactor
    }

    private func updateZoom() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(1.0, min(zoomFactor, device.activeFormat.videoMaxZoomFactor))
            device.unlockForConfiguration()
        } catch {
            print("Zoom update failed: \(error.localizedDescription)")
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Set the correct orientation based on actual device orientation
        ciImage = ciImage.oriented(.right)

        DispatchQueue.main.async {
            self.onCroppedImage?(ciImage)
        }
    }
}
