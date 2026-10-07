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
    let onPicked: ((ExerlyCore.Food) -> Void)?
    @StateObject private var search: NutritionSearchModel
    @StateObject private var camera = CameraCaptureController()
    @State private var code = ""
    @State private var symbology: AccountAPI.BarcodeSymbology?
    @State private var cameraAllowed = false
    @State private var enteringDigits = false
    @State private var cameraMessage: String?
    @State private var selectedFood: ExerlyCore.Food?
    @State private var createdFood: ExerlyCore.Food?
    @State private var creating = false
    @State private var scanningLabel = false
    @State private var didLog = false
    @State private var lookupTask: Task<Void, Never>?
    @FocusState private var typing: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    init(workspace: TrainingWorkspace, api: AccountAPI, date: LocalDate, meal: String,
         timeZone: TimeZone, unit: MassUnit, actions: NutritionDiaryActions,
         onPicked: ((ExerlyCore.Food) -> Void)? = nil, onLogged: @escaping () -> Void) {
        self.workspace = workspace
        self.date = date
        self.meal = meal
        self.timeZone = timeZone
        self.unit = unit
        self.actions = actions
        self.onLogged = onLogged
        self.onPicked = onPicked
        _search = StateObject(wrappedValue: NutritionSearchModel(api: api))
    }

    var body: some View {
        ExScreen {
            cameraSection
            lookupResult
            if !barcodeMissing { searchAction }
            if search.request != nil {
                Button("Scan again", systemImage: "barcode.viewfinder") {
                    lookupTask?.cancel(); search.clear(); cameraMessage = nil
                    if cameraAllowed { enteringDigits = false; camera.resumeScanning() }
                }.buttonStyle(ExActionStyle(secondary: true))
            }
            VStack(alignment: .leading, spacing: ExSpacing.item) {
                Button { enteringDigits.toggle() } label: {
                    HStack {
                        Text("Enter barcode digits")
                        Spacer()
                        Image(systemName: enteringDigits ? "chevron.up" : "chevron.down").accessibilityHidden(true)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.font(.exLabel).buttonStyle(.plain).foregroundStyle(Color.exPrimaryText)
                    .accessibilityIdentifier("nutrition.enterBarcodeDigits")
                    .accessibilityValue(enteringDigits ? "Expanded" : "Collapsed")
                if enteringDigits { barcodeInput }
            }
            if !barcodeMissing {
                Menu {
                    Button("Scan nutrition label", systemImage: "text.viewfinder") { camera.stop(); scanningLabel = true }
                        .accessibilityIdentifier("nutrition.scanLabel")
                    Button("Enter food manually", systemImage: "square.and.pencil") { camera.stop(); creating = true }
                } label: {
                    Label("More food options", systemImage: "ellipsis").frame(minHeight: 44)
                }.font(.exLabel).accessibilityIdentifier("nutrition.barcodeMoreOptions")
            }
        }
        .navigationTitle("Scan barcode").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } } }
        .task { await checkCameraPermission() }
        .onChange(of: camera.detected) { _, detected in
            guard let detected else { return }
            code = detected.value
            symbology = AccountAPI.BarcodeSymbology(rawValue: detected.symbology)
            lookup(format: symbology, openMatch: true)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await checkCameraPermission() } } else { camera.stop() }
        }
        .onDisappear { camera.stop(); lookupTask?.cancel(); search.clear() }
        .sheet(isPresented: $creating, onDismiss: {
            if let createdFood { choose(createdFood); self.createdFood = nil }
        }, content: {
            NutritionFoodEditor(workspace: workspace) { createdFood = $0 }
        })
        .sheet(isPresented: $scanningLabel, onDismiss: {
            if let createdFood { choose(createdFood); self.createdFood = nil }
        }, content: {
            NutritionLabelCaptureView(workspace: workspace) { createdFood = $0 }
        })
        .sheet(item: $selectedFood, onDismiss: {
            if didLog { didLog = false; onLogged() }
        }, content: { food in
            NutritionEntryEditor(workspace: workspace, food: food, date: date, meal: meal,
                                 timeZone: timeZone, unit: unit, actions: actions) { _ in didLog = true }
        })
    }

    @ViewBuilder private var cameraSection: some View {
        if cameraAllowed && camera.error == nil {
            VStack(alignment: .leading, spacing: ExSpacing.small) {
                CameraPreview(controller: camera).frame(height: 250)
                    .overlay {
                        RoundedRectangle(cornerRadius: ExRadius.control)
                            .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                            .padding(.horizontal, 24).padding(.vertical, 52)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: ExRadius.card))
                    .accessibilityLabel("Camera barcode viewfinder")
                HStack(spacing: ExSpacing.item) {
                    Text("Point at the barcode. We'll find the food automatically.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    Spacer(minLength: 0)
                    Button(camera.torchOn ? "Turn flashlight off" : "Turn flashlight on", systemImage: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill") { camera.toggleTorch() }
                        .labelStyle(.iconOnly).frame(width: 44, height: 44)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: ExSpacing.item) {
                Image(systemName: "barcode.viewfinder").font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color.exPrimaryText).accessibilityHidden(true)
                Text(cameraDenied ? "Allow camera to scan" : "Search without a camera").font(.exH2)
                Text(cameraDenied
                     ? "Enable camera access to scan packages. You can still search for any food by name."
                     : "A camera isn't available here. Search for the food, or enter the digits printed under its barcode.")
                    .font(.exBody).foregroundStyle(Color.exTextSecondary)
                if cameraDenied {
                    Button("Open camera settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }.buttonStyle(ExActionStyle())
                }
                if let error = camera.error { Text(error).font(.exCaption).foregroundStyle(Color.exTextSecondary) }
            }
        }
    }

    @ViewBuilder private var lookupResult: some View {
        if search.isLoading {
            ProgressView("Finding your food…").frame(maxWidth: .infinity, minHeight: 60)
        } else if let error = search.error {
            ExCard {
                Text("Couldn't look up this barcode").font(.exH3)
                Text(error).font(.exBody).foregroundStyle(Color.exError)
                Button("Try barcode again") { lookup() }.frame(minHeight: 44)
            }
        } else if let result = search.result, !result.foods.isEmpty {
            ExCard {
                ExSectionHeading("Found your food")
                ForEach(result.foods) { food in
                    Button { choose(food) } label: {
                        VStack(alignment: .leading, spacing: ExSpacing.item) {
                            NutritionFoodRow(food: food)
                            Label(onPicked == nil ? "Review portion" : "Add to meal", systemImage: "arrow.right")
                                .font(.exBodyMedium).foregroundStyle(Color.exPrimaryText)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("nutrition.barcodeFood")
                }
                Text(result.attribution).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
        } else if barcodeMissing {
            ExCard {
                Text("Barcode not found").font(.exH2)
                Text("Try the food's name below. If you have its Nutrition Facts label, we can read a photo of it.")
                    .font(.exBody).foregroundStyle(Color.exTextSecondary)
                    .accessibilityIdentifier("nutrition.barcodeNotFound")
                searchAction
                Button("Scan nutrition label", systemImage: "text.viewfinder") { camera.stop(); scanningLabel = true }
                    .buttonStyle(ExActionStyle(secondary: true)).accessibilityIdentifier("nutrition.scanLabel")
                Button("Enter food manually") { camera.stop(); creating = true }
                    .font(.exLabel).frame(minHeight: 44).accessibilityIdentifier("nutrition.barcodeManualFood")
            }
        }
    }

    private var searchAction: some View {
        Button { dismiss() } label: { Label("Search by name", systemImage: "magnifyingglass") }
            .buttonStyle(ExActionStyle(secondary: (cameraAllowed && !barcodeMissing) || !(search.result?.foods.isEmpty ?? true)))
            .accessibilityIdentifier("nutrition.barcodeSearch")
    }

    private var barcodeInput: some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            TextField("Barcode digits", text: $code).keyboardType(.numberPad).focused($typing).font(.exStatSmall)
                .padding(ExSpacing.item).background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                .accessibilityIdentifier("nutrition.barcodeDigits")
                .onChange(of: code) { _, _ in if typing { symbology = nil } }
            if code.filter(\.isNumber).count == 8 {
                ExChoiceChips(values: [AccountAPI.BarcodeSymbology?.none, .ean8, .upcE], selection: $symbology) {
                    $0 == .ean8 ? "EAN-8" : $0 == .upcE ? "UPC-E" : "Choose format"
                }
                Text("Eight-digit barcodes need their format. Scan with the camera if you're unsure.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            Button("Look up barcode") { lookup() }.buttonStyle(ExActionStyle(secondary: true))
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || search.isLoading)
                .accessibilityIdentifier("nutrition.lookupBarcode")
            if let cameraMessage { Text(cameraMessage).font(.exCaption).foregroundStyle(Color.exTextSecondary) }
        }.padding(.top, ExSpacing.item)
    }

    private var cameraDenied: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .denied }
    private var barcodeMissing: Bool { search.request != nil && !search.isLoading && search.error == nil && (search.result?.foods.isEmpty ?? true) }

    private func choose(_ food: ExerlyCore.Food) {
        if let onPicked { onPicked(food); dismiss() } else { selectedFood = food }
    }

    private func lookup(format: AccountAPI.BarcodeSymbology? = nil, openMatch: Bool = false) {
        typing = false
        camera.stop()
        cameraMessage = nil
        lookupTask?.cancel()
        let digits = code
        let format = format ?? symbology
        lookupTask = Task {
            await search.lookup(digits, symbology: format)
            guard !Task.isCancelled, openMatch, let foods = search.result?.foods, foods.count == 1 else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            choose(foods[0])
        }
    }

    private func checkCameraPermission() async {
        guard AVCaptureDevice.default(for: .video) != nil else { cameraAllowed = false; return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed = status == .authorized ? true : status == .notDetermined ? await AVCaptureDevice.requestAccess(for: .video) : false
        guard !Task.isCancelled else { return }
        cameraAllowed = allowed
        if allowed && scenePhase == .active && search.request == nil && selectedFood == nil && !creating && !scanningLabel { camera.start() }
    }
}
