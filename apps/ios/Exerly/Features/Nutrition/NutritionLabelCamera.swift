import SwiftUI
import UIKit

struct NutritionLabelCamera: UIViewControllerRepresentable {
    let onImage: (Data) -> Void
    let onError: (Error) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: NutritionLabelCamera
        init(parent: NutritionLabelCamera) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.dismiss()
            guard let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.92) else {
                parent.onError(NutritionLabelRecognitionError.image)
                return
            }
            parent.onImage(data)
        }
    }
}
