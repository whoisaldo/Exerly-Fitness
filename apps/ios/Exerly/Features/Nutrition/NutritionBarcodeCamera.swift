import AVFoundation
import SwiftUI

// The live barcode camera behind the Scan barcode screen.

struct DetectedBarcode: Equatable {
    let value: String
    let symbology: String
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
