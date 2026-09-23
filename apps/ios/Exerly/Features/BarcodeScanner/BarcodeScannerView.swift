import SwiftUI
import AVFoundation

struct DetectedBarcode: Equatable {
    let value: String
    let symbology: String
}

struct BarcodeScannerView: View {
    var initialDate: CalendarDay
    var initialMealType = "snack"
    var onLogged: () -> Void = {}
    @StateObject private var camera = CameraCaptureController()
    @State private var foundFood: OpenFoodItem?
    @State private var code = ""
    @State private var format = "ean13"
    @State private var message: String?
    @State private var isLoading = false
    @State private var cameraAllowed = false
    @State private var lookupTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if cameraAllowed {
                    CameraPreview(controller: camera)
                        .frame(height: 280)
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 2).padding(.horizontal, 24).padding(.vertical, 52).allowsHitTesting(false) }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Camera barcode viewfinder")
                    HStack {
                        Text("Center the barcode in the frame. Tap to focus.").font(.callout)
                        Spacer()
                        Button { camera.toggleTorch() } label: {
                            Image(systemName: camera.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .frame(width: 44, height: 44)
                        }.accessibilityLabel(camera.torchOn ? "Turn flashlight off" : "Turn flashlight on")
                    }
                } else {
                    Text("Camera unavailable. You can enter the barcode below or search for the food.")
                    if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                        Button("Open camera settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }.frame(minHeight: 44)
                    }
                }
                if let error = camera.error { Text(error).font(.callout) }
                TextField("Barcode digits", text: $code)
                    .keyboardType(.numberPad).textFieldStyle(.roundedBorder).frame(minHeight: 44)
                    .accessibilityIdentifier("barcode.digits")
                Picker("Barcode format", selection: $format) {
                    Text("EAN-13").tag("ean13")
                    Text("UPC-A").tag("upca")
                    Text("EAN-8").tag("ean8")
                    Text("UPC-E").tag("upce")
                    Text("GTIN-14").tag("gtin14")
                }.pickerStyle(.menu)
                ActionButton(title: "Look up barcode", isLoading: isLoading, isDisabled: code.isEmpty) { beginLookup() }
                if let message { Text(message).font(.callout).accessibilityIdentifier("barcode.result") }
                if let food = foundFood {
                    NavigationLink {
                        FoodDetailView(food: food, initialDate: initialDate, initialMealType: initialMealType) {
                            onLogged()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(food.name).font(.headline)
                            Text("Review quantity and log to \(initialMealType)").font(.callout)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.bordered)
                }
                Button("Scan again") {
                    lookupTask?.cancel()
                    foundFood = nil
                    message = nil
                    isLoading = false
                    camera.resumeScanning()
                }.frame(minHeight: 44)
                NavigationLink("Create food with this barcode") {
                    CreateFoodView(initialBarcode: code) { food in foundFood = food }
                }.frame(minHeight: 44)
                Button("Search by name") { dismiss() }.frame(minHeight: 44)
            }.padding(20)
        }
        .background(Color.exBackground)
        .navigationTitle("Scan barcode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
        .task { await checkPermission() }
        .onChange(of: camera.detected) { _, detected in
            guard let detected else { return }
            code = detected.value
            format = detected.symbology
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            beginLookup()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await checkPermission() } }
            else { camera.stop() }
        }
        .onDisappear { lookupTask?.cancel(); camera.stop() }
    }

    private func checkPermission() async {
        guard AVCaptureDevice.default(for: .video) != nil else { cameraAllowed = false; return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed = status == .authorized ? true : status == .notDetermined ? await AVCaptureDevice.requestAccess(for: .video) : false
        guard !Task.isCancelled else { return }
        cameraAllowed = allowed
        if allowed && scenePhase == .active && !isLoading && foundFood == nil { camera.start() }
    }

    private func beginLookup() {
        guard !isLoading else { return }
        camera.stop()
        lookupTask?.cancel()
        foundFood = nil
        message = nil
        isLoading = true
        let barcode = code
        let symbology = format
        lookupTask = Task {
            defer { isLoading = false }
            do {
                let response = try await APIClient.shared.barcodeLookup(barcode: barcode, symbology: symbology)
                try Task.checkCancellation()
                if response.found, let food = response.food { foundFood = food.toOpenFoodItem(); return }
                switch response.status {
                case "not_found": message = "This product is not in the available catalog. Create a personal food below."
                case "rate_limited": message = "The food provider is busy. Try again in a minute, or enter the food manually."
                case "invalid_code", "unsupported_format": message = response.message ?? "Check the digits and barcode format."
                default: message = "The food provider is unavailable. Try again, search by name, or create the food manually."
                }
            } catch is CancellationError { return }
            catch { message = error.localizedDescription }
        }
    }
}

final class CameraCaptureController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var detected: DetectedBarcode?
    @Published var torchOn = false
    @Published var error: String?
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.exerly.camera")
    private let output = AVCaptureMetadataOutput()
    private var device: AVCaptureDevice?
    private var configured = false
    private var wantsRunning = false
    private var accepted = false
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        for name in [AVCaptureSession.interruptionEndedNotification, AVCaptureSession.runtimeErrorNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
                self?.queue.async { [weak self] in
                    guard let self, self.wantsRunning, !self.accepted else { return }
                    self.session.startRunning()
                }
            })
        }
    }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = true
            if !self.configured {
                self.session.beginConfiguration()
                defer { self.session.commitConfiguration() }
                guard let device = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                    DispatchQueue.main.async { self.error = "Camera setup failed. Use manual barcode entry." }
                    return
                }
                self.device = device
                self.session.addInput(input)
                self.session.addOutput(self.output)
                self.output.setMetadataObjectsDelegate(self, queue: self.queue)
                self.output.metadataObjectTypes = [.ean8, .ean13, .upce].filter { self.output.availableMetadataObjectTypes.contains($0) }
                self.configured = true
            }
            if !self.accepted && !self.session.isRunning { self.session.startRunning() }
        }
    }
    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = false
            self.setTorch(false)
            if self.session.isRunning { self.session.stopRunning() }
        }
    }
    func resumeScanning() {
        queue.async { [weak self] in self?.accepted = false }
        detected = nil
        start()
    }
    func toggleTorch() {
        queue.async { [weak self] in
            guard let self else { return }
            self.setTorch(self.device?.torchMode != .on)
        }
    }
    private func setTorch(_ on: Bool) {
        guard let device, device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            DispatchQueue.main.async { self.torchOn = on }
        } catch { DispatchQueue.main.async { self.error = "Flashlight unavailable." } }
    }
    func region(_ rect: CGRect) { queue.async { [weak self] in self?.output.rectOfInterest = rect } }
    func focus(_ point: CGPoint) {
        queue.async { [weak self] in
            guard let device = self?.device, device.isFocusPointOfInterestSupported,
                  device.isFocusModeSupported(.autoFocus) else { return }
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                device.unlockForConfiguration()
            } catch { }
        }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard wantsRunning, !accepted,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else { return }
        let type: String
        switch object.type {
        case .upce: type = "upce"
        case .ean8: type = "ean8"
        case .ean13: type = "ean13"
        default: return
        }
        accepted = true
        setTorch(false)
        session.stopRunning()
        DispatchQueue.main.async { self.detected = DetectedBarcode(value: code, symbology: type) }
    }
}

final class CameraHostView: UIView {
    var controller: CameraCaptureController?
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        controller?.region(preview.metadataOutputRectConverted(fromLayerRect: bounds.insetBy(dx: 24, dy: 52)))
    }
    @objc func focusAtTap(_ tap: UITapGestureRecognizer) {
        controller?.focus(preview.captureDevicePointConverted(fromLayerPoint: tap.location(in: self)))
    }
}

struct CameraPreview: UIViewRepresentable {
    let controller: CameraCaptureController
    func makeUIView(context: Context) -> CameraHostView {
        let view = CameraHostView()
        view.controller = controller
        view.preview.session = controller.session
        view.preview.videoGravity = .resizeAspectFill
        view.addGestureRecognizer(UITapGestureRecognizer(target: view, action: #selector(CameraHostView.focusAtTap(_:))))
        return view
    }
    func updateUIView(_ uiView: CameraHostView, context: Context) { uiView.setNeedsLayout() }
    static func dismantleUIView(_ uiView: CameraHostView, coordinator: ()) {
        uiView.controller?.stop()
        uiView.preview.session = nil
    }
}
