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
    let onLogged: (FoodEntry) -> Void
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
    @State private var logged: FoodEntry?
    @State private var lookupTask: Task<Void, Never>?
    @FocusState private var typing: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    init(workspace: TrainingWorkspace, api: AccountAPI, date: LocalDate, meal: String,
         timeZone: TimeZone, unit: MassUnit, actions: NutritionDiaryActions,
         onPicked: ((ExerlyCore.Food) -> Void)? = nil, onLogged: @escaping (FoodEntry) -> Void) {
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
            VStack(alignment: .leading, spacing: 0) {
                // Without a camera the digits are the only way in, so they stay open.
                if cameraAllowed {
                Button { withAnimation(.snappy) { enteringDigits.toggle() } } label: {
                    HStack {
                        Label("Enter barcode digits", systemImage: "keyboard")
                        Spacer()
                        Image(systemName: "chevron.down").rotationEffect(.degrees(enteringDigits ? 180 : 0))
                            .accessibilityHidden(true)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.font(.exLabel).buttonStyle(.plain).foregroundStyle(Color.exPrimaryText)
                    .accessibilityIdentifier("nutrition.enterBarcodeDigits")
                    .accessibilityValue(enteringDigits ? "Expanded" : "Collapsed")
                }
                if enteringDigits || !cameraAllowed { barcodeInput }
            }
            lookupResult
            if search.request != nil && cameraAllowed {
                Button("Scan again", systemImage: "barcode.viewfinder") {
                    lookupTask?.cancel(); search.clear(); cameraMessage = nil
                    enteringDigits = false; camera.resumeScanning()
                }.buttonStyle(ExActionStyle(secondary: true))
            }
            if !barcodeMissing {
                HStack(spacing: ExSpacing.small) {
                    searchAction
                    Button { camera.stop(); scanningLabel = true } label: { Label("Label", systemImage: "text.viewfinder") }
                        .buttonStyle(ExActionStyle(secondary: true)).accessibilityLabel("Scan nutrition label")
                        .accessibilityIdentifier("nutrition.scanLabel")
                }
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
            if let logged { self.logged = nil; onLogged(logged) }
        }, content: { food in
            NutritionEntryEditor(workspace: workspace, food: food, date: date, meal: meal,
                                 timeZone: timeZone, unit: unit, actions: actions) { logged = $0 }
        })
    }

    @ViewBuilder private var cameraSection: some View {
        if cameraAllowed && camera.error == nil {
            VStack(alignment: .leading, spacing: ExSpacing.small) {
                CameraPreview(controller: camera).frame(height: 300)
                    .overlay { ScanFrame().padding(.horizontal, 36).padding(.vertical, 70).allowsHitTesting(false).accessibilityHidden(true) }
                    .clipShape(RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button(camera.torchOn ? "Turn flashlight off" : "Turn flashlight on",
                               systemImage: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill") { camera.toggleTorch() }
                            .labelStyle(.iconOnly).font(.body.weight(.semibold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44).glassEffect(.regular.interactive(), in: Circle()).padding(ExSpacing.item)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Camera barcode viewfinder")
                Text("Point at the barcode. The food opens as soon as it's read.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
        } else {
            HStack(alignment: .top, spacing: ExSpacing.item) {
                if !typeSize.isAccessibilitySize {
                    Image(systemName: cameraDenied ? "camera.badge.ellipsis" : "barcode.viewfinder")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.exPrimaryText)
                        .frame(width: 48, height: 48).background(Color.exPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: ExRadius.control))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: ExSpacing.tight) {
                    Text(cameraDenied ? "Allow the camera to scan" : "No camera here").font(.exH3).foregroundStyle(Color.exTextPrimary)
                    Text(cameraDenied
                         ? "Turn on camera access to scan packages. You can also type the digits under the barcode."
                         : "Type the digits printed under the barcode instead.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                    if cameraDenied {
                        Button("Open camera settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }.font(.exLabel).frame(minHeight: 44)
                    }
                    if let error = camera.error { Text(error).font(.exCaption).foregroundStyle(Color.exTextSecondary) }
                }
            }
        }
    }

    @ViewBuilder private var lookupResult: some View {
        if search.isLoading {
            ProgressView("Finding your food…").frame(maxWidth: .infinity, minHeight: 60)
                .accessibilityIdentifier("nutrition.barcodeLoading")
        } else if let error = search.error {
            ExCard {
                Text("Couldn't look up this barcode").font(.exH3)
                Text(error).font(.exBody).foregroundStyle(Color.exError)
                Button("Try barcode again") { lookup(openMatch: true) }.frame(minHeight: 44)
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
            ExCard(accent: true) {
                Label("Not in the database yet", systemImage: "barcode").font(.exH3).foregroundStyle(Color.exTextPrimary)
                Text("Photograph the Nutrition Facts label and we'll read it, then this barcode is one scan away next time.")
                    .font(.exBody).foregroundStyle(Color.exTextSecondary)
                    .accessibilityIdentifier("nutrition.barcodeNotFound")
                Button("Scan nutrition label", systemImage: "text.viewfinder") { camera.stop(); scanningLabel = true }
                    .buttonStyle(ExActionStyle()).accessibilityIdentifier("nutrition.scanLabel")
                HStack(spacing: ExSpacing.small) {
                    Button("Type it in", systemImage: "square.and.pencil") { camera.stop(); creating = true }
                        .buttonStyle(ExActionStyle(secondary: true)).accessibilityIdentifier("nutrition.barcodeManualFood")
                    Button { dismiss() } label: { Label("Search", systemImage: "magnifyingglass") }
                        .buttonStyle(ExActionStyle(secondary: true)).accessibilityIdentifier("nutrition.barcodeSearch")
                }
            }
        }
    }

    private var searchAction: some View {
        Button { dismiss() } label: { Label("Search", systemImage: "magnifyingglass") }
            .buttonStyle(ExActionStyle(secondary: true)).accessibilityLabel("Search by name")
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
            Button("Look up barcode") { lookup(openMatch: true) }.buttonStyle(ExActionStyle())
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
        guard AVCaptureDevice.default(for: .video) != nil else {
            // Without a camera, the digits are the only way in: show them ready.
            cameraAllowed = false
            if search.request == nil { enteringDigits = true }
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed = status == .authorized ? true : status == .notDetermined ? await AVCaptureDevice.requestAccess(for: .video) : false
        guard !Task.isCancelled else { return }
        cameraAllowed = allowed
        if allowed && scenePhase == .active && search.request == nil && selectedFood == nil && !creating && !scanningLabel { camera.start() }
    }
}

/// Corner brackets for the barcode viewfinder.
private struct ScanFrame: View {
    var body: some View {
        GeometryReader { geometry in
            let length: CGFloat = 26
            Path { path in
                let rect = CGRect(origin: .zero, size: geometry.size)
                for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0), (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                         (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0), (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
                    path.move(to: CGPoint(x: corner.x + dx * length, y: corner.y))
                    path.addLine(to: corner)
                    path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * length))
                }
            }.stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
    }
}
