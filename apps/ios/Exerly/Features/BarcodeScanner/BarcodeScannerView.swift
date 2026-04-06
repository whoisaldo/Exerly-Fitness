import SwiftUI
import AVFoundation

// MARK: - Permission state

private enum CameraPermission {
    case unknown, granted, denied
}

struct BarcodeScannerView: View {
    @State private var scannedCode: String?
    @State private var foundFood: OpenFoodItem?
    @State private var isLoading = false
    @State private var notFound = false
    @State private var cameraPermission: CameraPermission = .unknown
    @State private var isTorchOn = false
    @State private var hasScanned = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            switch cameraPermission {
            case .unknown:
                Color.exBackground.ignoresSafeArea()
                ProgressView()
                    .tint(.exPrimary)
            case .denied:
                permissionDeniedView
            case .granted:
                cameraBody
            }
        }
        .navigationTitle("Scan Barcode")
        .navigationBarTitleDisplayMode(.inline)
        .task { await checkCameraPermission() }
        .onChange(of: scannedCode) { _, code in
            if let code {
                hasScanned = true
                Task { await lookup(code) }
            }
        }
    }

    // MARK: - Permission denied UI

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.exTextSecondary)
            Text("Camera Access Required")
                .font(.exH2)
                .foregroundStyle(.exTextPrimary)
            Text("Allow camera access in Settings to scan barcodes.")
                .font(.exBody)
                .foregroundStyle(.exTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.exBodyMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.exPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.exBackground.ignoresSafeArea())
    }

    // MARK: - Main camera body (only shown when permission granted)

    private var cameraBody: some View {
        ZStack {
            CameraPreview(scannedCode: $scannedCode, hasScanned: $hasScanned)
                .ignoresSafeArea()

            scanOverlay

            // Toolbar buttons at top-right
            VStack {
                HStack {
                    Spacer()
                    torchButton
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
                Spacer()
                bottomPanel
            }
        }
    }

    // MARK: - Flashlight toggle

    private var torchButton: some View {
        Button {
            toggleTorch()
        } label: {
            Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.system(size: 20))
                .foregroundStyle(isTorchOn ? .exPrimary : .white)
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }

    // MARK: - Scan overlay

    private var scanOverlay: some View {
        GeometryReader { geo in
            let size: CGFloat = 250
            let origin = CGPoint(
                x: (geo.size.width - size) / 2,
                y: (geo.size.height - size) / 2 - 40
            )
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .mask {
                        Rectangle()
                            .ignoresSafeArea()
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .frame(width: size, height: size)
                                    .position(x: geo.size.width / 2, y: geo.size.height / 2 - 40)
                                    .blendMode(.destinationOut)
                            }
                    }
                    .compositingGroup()

                // Corner brackets
                cornerBrackets(origin: origin, size: size)

                // Scan line
                ScanLineView()
                    .frame(width: size - 20, height: 2)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 - 40)
            }
        }
    }

    private func cornerBrackets(origin: CGPoint, size: CGFloat) -> some View {
        let len: CGFloat = 30
        let lw: CGFloat = 3
        let r: CGFloat = 16
        return ZStack {
            // Top-left
            Path { p in
                p.move(to: CGPoint(x: origin.x, y: origin.y + len))
                p.addLine(to: CGPoint(x: origin.x, y: origin.y + r))
                p.addQuadCurve(to: CGPoint(x: origin.x + r, y: origin.y),
                               control: CGPoint(x: origin.x, y: origin.y))
                p.addLine(to: CGPoint(x: origin.x + len, y: origin.y))
            }
            .stroke(Color.exPrimary, lineWidth: lw)

            // Top-right
            Path { p in
                p.move(to: CGPoint(x: origin.x + size - len, y: origin.y))
                p.addLine(to: CGPoint(x: origin.x + size - r, y: origin.y))
                p.addQuadCurve(to: CGPoint(x: origin.x + size, y: origin.y + r),
                               control: CGPoint(x: origin.x + size, y: origin.y))
                p.addLine(to: CGPoint(x: origin.x + size, y: origin.y + len))
            }
            .stroke(Color.exPrimary, lineWidth: lw)

            // Bottom-left
            Path { p in
                p.move(to: CGPoint(x: origin.x, y: origin.y + size - len))
                p.addLine(to: CGPoint(x: origin.x, y: origin.y + size - r))
                p.addQuadCurve(to: CGPoint(x: origin.x + r, y: origin.y + size),
                               control: CGPoint(x: origin.x, y: origin.y + size))
                p.addLine(to: CGPoint(x: origin.x + len, y: origin.y + size))
            }
            .stroke(Color.exPrimary, lineWidth: lw)

            // Bottom-right
            Path { p in
                p.move(to: CGPoint(x: origin.x + size - len, y: origin.y + size))
                p.addLine(to: CGPoint(x: origin.x + size - r, y: origin.y + size))
                p.addQuadCurve(to: CGPoint(x: origin.x + size, y: origin.y + size - r),
                               control: CGPoint(x: origin.x + size, y: origin.y + size))
                p.addLine(to: CGPoint(x: origin.x + size, y: origin.y + size - len))
            }
            .stroke(Color.exPrimary, lineWidth: lw)
        }
    }

    // MARK: - Bottom panel

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(.exPrimary)
                Text("Looking up barcode...")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
            } else if let food = foundFood {
                FoodCardView(food: food)
                    .padding(.horizontal, 20)
                scanAgainButton
            } else if notFound {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 28))
                            .foregroundStyle(.exWarning)
                        Text("Product not found")
                            .font(.exBodyMedium)
                            .foregroundStyle(.exTextPrimary)
                        Text("Try scanning again or search manually")
                            .font(.exCaption)
                            .foregroundStyle(.exTextSecondary)
                    }
                }
                .padding(.horizontal, 20)
                scanAgainButton
            } else {
                Text("Point camera at a barcode")
                    .font(.exBody)
                    .foregroundStyle(.exTextSecondary)
            }
        }
        .padding(.bottom, 40)
    }

    private var scanAgainButton: some View {
        Button {
            resetScan()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "barcode.viewfinder")
                Text("Scan Again")
            }
            .font(.exBodyMedium)
            .foregroundStyle(.exPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.exPrimary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func checkCameraPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermission = .granted
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermission = granted ? .granted : .denied
        default:
            cameraPermission = .denied
        }
    }

    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isTorchOn ? .off : .on
            device.unlockForConfiguration()
            isTorchOn.toggle()
        } catch {}
    }

    private func resetScan() {
        scannedCode = nil
        foundFood = nil
        notFound = false
        hasScanned = false
    }

    private func lookup(_ barcode: String) async {
        isLoading = true
        notFound = false
        // Try FatSecret first (verified data), fall back to Open Food Facts
        if let result = await FatSecretService.shared.fetchByBarcode(barcode) {
            foundFood = result
        } else if let result = await OpenFoodFactsService.shared.fetchByBarcode(barcode) {
            foundFood = result
        } else {
            notFound = true
        }
        isLoading = false
    }
}

// MARK: - Scan Line Animation

struct ScanLineView: View {
    @State private var offset: CGFloat = -100

    var body: some View {
        Rectangle()
            .fill(Color.exPrimary.opacity(0.6))
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    offset = 100
                }
            }
    }
}

// MARK: - Preview-layer UIView subclass (fixes frame sizing on device)

class CameraHostView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            guard let previewLayer else { return }
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreview: UIViewRepresentable {
    @Binding var scannedCode: String?
    @Binding var hasScanned: Bool

    func makeUIView(context: Context) -> CameraHostView {
        let view = CameraHostView()
        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }

        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        view.previewLayer = previewLayer
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: CameraHostView, context: Context) {
        // When hasScanned is reset to false, allow scanning again
        if !hasScanned {
            context.coordinator.hasScanned = false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(scannedCode: $scannedCode) }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        @Binding var scannedCode: String?
        var hasScanned = false

        init(scannedCode: Binding<String?>) {
            _scannedCode = scannedCode
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasScanned,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = object.stringValue else { return }
            hasScanned = true
            scannedCode = code
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
    }
}
