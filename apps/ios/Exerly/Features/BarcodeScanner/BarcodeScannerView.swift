import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @State private var scannedCode: String?
    @State private var foundFood: OpenFoodItem?
    @State private var isLoading = false
    @State private var notFound = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CameraPreview(scannedCode: $scannedCode)
                .ignoresSafeArea()

            scanOverlay

            VStack {
                Spacer()
                bottomPanel
            }
        }
        .navigationTitle("Scan Barcode")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scannedCode) { _, code in
            if let code { Task { await lookup(code) } }
        }
    }

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
            } else {
                Text("Point camera at a barcode")
                    .font(.exBody)
                    .foregroundStyle(.exTextSecondary)
            }
        }
        .padding(.bottom, 40)
    }

    private func lookup(_ barcode: String) async {
        isLoading = true
        notFound = false
        foundFood = await OpenFoodFactsService.shared.fetchByBarcode(barcode)
        if foundFood == nil { notFound = true }
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

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreview: UIViewRepresentable {
    @Binding var scannedCode: String?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
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
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator(scannedCode: $scannedCode) }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        @Binding var scannedCode: String?
        private var hasScanned = false

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
