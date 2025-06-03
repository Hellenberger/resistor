import SwiftUI

struct CameraPreviewRepresentable: UIViewControllerRepresentable {
    
    @Binding var zoomFactor: CGFloat
    var onCroppedImage: (CIImage) -> Void
    
    func makeUIViewController(context: Context) -> CameraPreviewController {
        let controller = CameraPreviewController()
        controller.zoomFactor = zoomFactor
        controller.onCroppedImage = onCroppedImage
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraPreviewController, context: Context) {
        uiViewController.updateSettings(zoomFactor: zoomFactor)
    }
}
