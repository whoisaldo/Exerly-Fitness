import AVFoundation
import ExerlyCore
import SwiftUI

struct NutritionBarcodeView: View {
    let workspace: TrainingWorkspace
    let date: LocalDate
    let meal: String
    let timeZone: TimeZone
    @ObservedObject var actions: NutritionDiaryActions
    let onLogged: () -> Void
    @StateObject private var search: NutritionSearchModel
    @StateObject private var camera = CameraCaptureController()
    @State private var code = ""
    @State private var cameraAllowed = false
    @State private var cameraMessage: String?
    @State private var selectedFood: ExerlyCore.Food?
    @State private var createdFood: ExerlyCore.Food?
    @State private var creating = false
    @State private var didLog = false
    @State private var lookupTask: Task<Void, Never>?
    @FocusState private var typing: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    init(workspace: TrainingWorkspace, api: AccountAPI, date: LocalDate, meal: String,
         timeZone: TimeZone, actions: NutritionDiaryActions, onLogged: @escaping () -> Void) {
        self.workspace = workspace
        self.date = date
        self.meal = meal
        self.timeZone = timeZone
        self.actions = actions
        self.onLogged = onLogged
        _search = StateObject(wrappedValue: NutritionSearchModel(api: api))
    }

    var body: some View {
        List {
            if cameraAllowed {
                Section {
                    CameraPreview(controller: camera).frame(height: 240)
                        .accessibilityLabel("Camera barcode viewfinder")
                    Text("Center the barcode in the frame. Tap the viewfinder to focus.")
                    Button(camera.torchOn ? "Turn flashlight off" : "Turn flashlight on") { camera.toggleTorch() }
                }
            } else {
                Section {
                    Text("Camera unavailable. Enter the barcode digits below or search by name.")
                    if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                        Button("Open camera settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }
            }
            Section("Barcode") {
                TextField("Barcode digits", text: $code).keyboardType(.numberPad).focused($typing)
                    .accessibilityIdentifier("nutrition.barcodeDigits")
                Button("Look up barcode") { lookup() }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || search.isLoading)
                    .accessibilityIdentifier("nutrition.lookupBarcode")
                if let message = cameraMessage ?? camera.error { Text(message).foregroundStyle(.secondary) }
            }
            if search.isLoading {
                Section { ProgressView("Looking up barcode…") }
            } else if let error = search.error {
                Section("Lookup unavailable") { Text(error).foregroundStyle(Color.exError) }
            } else if search.request != nil {
                Section("Result") {
                    if let result = search.result, !result.foods.isEmpty {
                        ForEach(result.foods) { food in
                            Button { selectedFood = food } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(food.name).font(.headline).foregroundStyle(Color.exTextPrimary)
                                    if let brand = food.brand { Text(brand).foregroundStyle(Color.exTextSecondary) }
                                    Text("Review amount and log").font(.callout)
                                }.fixedSize(horizontal: false, vertical: true)
                            }.accessibilityIdentifier("nutrition.barcodeFood")
                        }
                        Text(result.attribution).font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("No food was found for this barcode. Enter its label or search by name.")
                            .accessibilityIdentifier("nutrition.barcodeNotFound")
                    }
                }
            }
            Section {
                Button("Enter a food label") { camera.stop(); creating = true }
                Button("Scan again") {
                    lookupTask?.cancel()
                    search.clear()
                    cameraMessage = nil
                    if cameraAllowed { camera.resumeScanning() }
                }
                Button("Search by name") { dismiss() }
            }
        }
        .scrollContentBackground(.hidden).background(Color.exBackground)
        .navigationTitle("Scan barcode").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } } }
        .task { await checkCameraPermission() }
        .onChange(of: camera.detected) { _, detected in
            guard let detected else { return }
            code = detected.value
            if detected.symbology == "upce" {
                cameraMessage = "Enter the full UPC digits for this compact barcode, or search by name."
            } else { lookup() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await checkCameraPermission() } } else { camera.stop() }
        }
        .onDisappear { camera.stop(); lookupTask?.cancel(); search.clear() }
        .sheet(isPresented: $creating, onDismiss: {
            if let createdFood { selectedFood = createdFood; self.createdFood = nil }
        }, content: {
            NutritionFoodEditor(workspace: workspace) { createdFood = $0 }
        })
        .sheet(item: $selectedFood, onDismiss: {
            if didLog { didLog = false; onLogged() }
        }, content: { food in
            NutritionEntryEditor(workspace: workspace, food: food, date: date, meal: meal,
                                 timeZone: timeZone, actions: actions) { _ in didLog = true }
        })
    }

    private func lookup() {
        typing = false
        camera.stop()
        cameraMessage = nil
        lookupTask?.cancel()
        let digits = code
        lookupTask = Task { await search.lookup(digits) }
    }

    private func checkCameraPermission() async {
        guard AVCaptureDevice.default(for: .video) != nil else { cameraAllowed = false; return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed = status == .authorized ? true : status == .notDetermined ? await AVCaptureDevice.requestAccess(for: .video) : false
        guard !Task.isCancelled else { return }
        cameraAllowed = allowed
        if allowed && scenePhase == .active && search.request == nil && selectedFood == nil && !creating { camera.start() }
    }
}
