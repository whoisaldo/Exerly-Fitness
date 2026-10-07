import AVFoundation
import ExerlyCore
import PhotosUI
import SwiftUI

struct NutritionLabelCaptureView: View {
    let workspace: TrainingWorkspace
    let onSaved: (ExerlyCore.Food) -> Void
    @StateObject private var scanner = NutritionLabelScanner()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var choosingPhoto = false
    @State private var loadingPhoto = false
    @State private var takingPhoto = false
    @State private var creatingManually = false
    @State private var reviewing: NutritionLabelScan?
    @State private var savedFood: ExerlyCore.Food?
    @State private var cameraMessage: String?
    @State private var photoTask: Task<Void, Never>?
    @State private var photoRequest = UUID()
    @AccessibilityFocusState private var errorFocused: Bool
    @AccessibilityFocusState private var cameraFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
            ExScreen {
                ExCard(accent: true) {
                    ExEyebrow("On your device", color: .exPrimaryText)
                    Text("Read a food label").font(.exH2)
                    Text("Photograph the Nutrition Facts panel. Review its serving size and nutrients before saving.")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary)
                    Button("Choose a photo", systemImage: "photo") {
                        cancelReading()
                        cameraMessage = nil
                        choosingPhoto = true
                    }
                        .buttonStyle(ExActionStyle()).accessibilityIdentifier("nutrition.labelChoosePhoto")
                    Button("Take a photo", systemImage: "camera") { Task { await openCamera() } }
                        .buttonStyle(ExActionStyle(secondary: true)).accessibilityIdentifier("nutrition.labelTakePhoto")
                }
                if scanner.isReading || loadingPhoto {
                    ExCard {
                        ProgressView(loadingPhoto ? "Opening your photo…" : "Reading your label…")
                        Button("Cancel reading") { cancelReading() }.frame(minHeight: 44)
                    }.accessibilityIdentifier("nutrition.labelReading")
                }
                if let error = scanner.error {
                    ExCard {
                        Text("Try another photo").font(.exH3)
                        Text(error).foregroundStyle(Color.exError).accessibilityFocused($errorFocused)
                    }.id("label-error").accessibilityIdentifier("nutrition.labelError")
                }
                if let cameraMessage {
                    ExCard {
                        Text(cameraMessage).font(.exBody).accessibilityFocused($cameraFocused)
                        if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                            Button("Open camera settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }.frame(minHeight: 44)
                        }
                    }.id("camera-message").accessibilityIdentifier("nutrition.labelCameraMessage")
                }
                ExCard {
                    ExSectionHeading("A clear label works best")
                    Text("Keep the whole panel in frame, with the serving size and amounts in focus. English nutrition labels are supported.")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary)
                    Text("Exerly reads the image on this device and keeps it only for this draft. It does not upload the photo.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
                Button("Enter the label manually") { cancelReading(); creatingManually = true }
                    .buttonStyle(ExActionStyle(secondary: true)).accessibilityIdentifier("nutrition.labelManual")
            }
            .onChange(of: scanner.error) { _, message in
                if message != nil { scroll.scrollTo("label-error", anchor: .center); errorFocused = true }
            }
            .onChange(of: cameraMessage) { _, message in
                if message != nil { scroll.scrollTo("camera-message", anchor: .center); cameraFocused = true }
            }
            }
            .navigationTitle("Scan label").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancelReading(); dismiss() }.accessibilityIdentifier("nutrition.cancelScanLabel") } }
            .photosPicker(isPresented: $choosingPhoto, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, photo in load(photo) }
            .onChange(of: scanner.result?.id) { _, _ in
                if let result = scanner.result { reviewing = result }
            }
            .fullScreenCover(isPresented: $takingPhoto) {
                NutritionLabelCamera { scanner.read($0) } onError: { scanner.fail($0) }
            }
            .sheet(item: $reviewing, onDismiss: completeReview) { scan in
                NutritionFoodEditor(workspace: workspace, scan: scan) { savedFood = $0 }
            }
            .sheet(isPresented: $creatingManually, onDismiss: completeReview) {
                NutritionFoodEditor(workspace: workspace) { savedFood = $0 }
            }
        }
        .onDisappear { cancelReading() }
    }

    private func load(_ photo: PhotosPickerItem?) {
        guard let photo else { return }
        selectedPhoto = nil
        cancelReading()
        loadingPhoto = true
        let request = photoRequest
        photoTask = Task {
            do {
                guard let image = try await photo.loadTransferable(type: NutritionLabelPhoto.self) else {
                    throw NutritionLabelRecognitionError.image
                }
                guard !Task.isCancelled, photoRequest == request else { return }
                loadingPhoto = false
                scanner.read(image.data)
            } catch {
                guard !Task.isCancelled, photoRequest == request else { return }
                loadingPhoto = false
                scanner.fail(error)
            }
        }
    }

    private func openCamera() async {
        cancelReading()
        let request = photoRequest
        guard UIImagePickerController.isSourceTypeAvailable(.camera), AVCaptureDevice.default(for: .video) != nil else {
            cameraMessage = "This device has no available camera. Choose a label photo or enter it manually."
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed = status == .authorized ? true : status == .notDetermined ? await AVCaptureDevice.requestAccess(for: .video) : false
        guard !Task.isCancelled, request == photoRequest else { return }
        cameraMessage = allowed ? nil : "Camera access is off. You can choose a label photo or enter the details manually."
        takingPhoto = allowed
    }

    private func cancelReading() {
        photoRequest = UUID()
        photoTask?.cancel()
        photoTask = nil
        loadingPhoto = false
        scanner.cancel()
    }

    private func completeReview() {
        cancelReading()
        selectedPhoto = nil
        if let savedFood { onSaved(savedFood); dismiss() }
    }
}
