import AVFoundation
import ExerlyCore
import SwiftUI

struct NutritionBarcodeView: View {
    let workspace: TrainingWorkspace
    let date: LocalDate
    let meal: String
    let timeZone: TimeZone
    let unit: MassUnit
    @ObservedObject var actions: NutritionDiaryActions
    let onLogged: () -> Void
    @StateObject private var search: NutritionSearchModel
    @StateObject private var camera = CameraCaptureController()
    @State private var code = ""
    @State private var symbology: AccountAPI.BarcodeSymbology?
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
         timeZone: TimeZone, unit: MassUnit, actions: NutritionDiaryActions, onLogged: @escaping () -> Void) {
        self.workspace = workspace
        self.date = date
        self.meal = meal
        self.timeZone = timeZone
        self.unit = unit
        self.actions = actions
        self.onLogged = onLogged
        _search = StateObject(wrappedValue: NutritionSearchModel(api: api))
    }

    var body: some View {
        ExScreen {
            if cameraAllowed {
                CameraPreview(controller: camera).frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: ExRadius.card))
                    .accessibilityLabel("Camera barcode viewfinder")
                HStack {
                    Text("Center the barcode. Tap to focus.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    Spacer()
                    Button(camera.torchOn ? "Turn flashlight off" : "Turn flashlight on", systemImage: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill") { camera.toggleTorch() }
                        .labelStyle(.iconOnly).frame(width: 44, height: 44)
                }
            } else {
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    ExEyebrow("Food lookup", color: .exPrimaryText)
                    Text("Find it by barcode").font(.exH2)
                    Text("Enter the digits below. You can also search by name or enter the label.").font(.exBody).foregroundStyle(Color.exTextSecondary)
                    if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                        Button("Open camera settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }.frame(minHeight: 44)
                    }
                }
            }
            ExCard {
                ExSectionHeading("Barcode")
                TextField("Barcode digits", text: $code).keyboardType(.numberPad).focused($typing).font(.exStatSmall)
                    .padding(ExSpacing.item).background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                    .accessibilityIdentifier("nutrition.barcodeDigits")
                    .onChange(of: code) { _, _ in if typing { symbology = nil } }
                if code.filter(\.isNumber).count == 8 {
                    ExChoiceChips(values: [AccountAPI.BarcodeSymbology?.none, .ean8, .upcE], selection: $symbology) {
                        $0 == .ean8 ? "EAN-8" : $0 == .upcE ? "UPC-E" : "Choose format"
                    }
                    Text("Eight-digit barcodes need their format. Scan it with the camera if you're unsure.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
                Button("Look up barcode") { lookup() }.buttonStyle(ExActionStyle())
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || search.isLoading)
                    .accessibilityIdentifier("nutrition.lookupBarcode")
                if let message = cameraMessage ?? camera.error { Text(message).font(.exCaption).foregroundStyle(Color.exTextSecondary) }
            }
            if search.isLoading { ProgressView("Looking up barcode…") } else if let error = search.error {
                ExCard { Text("Lookup unavailable").font(.exH3); Text(error).foregroundStyle(Color.exError) }
            } else if search.request != nil {
                ExCard {
                    if let result = search.result, !result.foods.isEmpty {
                        ExSectionHeading("Found your food")
                        ForEach(result.foods) { food in
                            Button { selectedFood = food } label: { NutritionFoodRow(food: food) }
                                .accessibilityIdentifier("nutrition.barcodeFood")
                        }
                        Text(result.attribution).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    } else {
                        Text("Not in the database yet").font(.exH2)
                        Text("No food was found for this barcode. Enter its label or search by name.")
                            .accessibilityIdentifier("nutrition.barcodeNotFound")
                    }
                }
            }
            Button("Enter a food label") { camera.stop(); creating = true }.buttonStyle(ExActionStyle(secondary: true))
            HStack {
                Button("Scan again") {
                    lookupTask?.cancel(); search.clear(); cameraMessage = nil
                    if cameraAllowed { camera.resumeScanning() }
                }.frame(minHeight: 44)
                Spacer()
                Button("Search by name") { dismiss() }.frame(minHeight: 44)
            }.font(.exLabel)
        }
        .navigationTitle("Scan barcode").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } } }
        .task { await checkCameraPermission() }
        .onChange(of: camera.detected) { _, detected in
            guard let detected else { return }
            code = detected.value
            symbology = AccountAPI.BarcodeSymbology(rawValue: detected.symbology)
            lookup(format: symbology)
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
                                 timeZone: timeZone, unit: unit, actions: actions) { _ in didLog = true }
        })
    }

    private func lookup(format: AccountAPI.BarcodeSymbology? = nil) {
        typing = false
        camera.stop()
        cameraMessage = nil
        lookupTask?.cancel()
        let digits = code
        let format = format ?? symbology
        lookupTask = Task { await search.lookup(digits, symbology: format) }
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
