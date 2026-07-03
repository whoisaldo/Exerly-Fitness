import SwiftUI

/// Signature background: a near-black field with a single thin EKG pulse
/// line drawn on. Replaces the old animated-orb canvas.
struct PulseBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    var body: some View {
        ZStack {
            Color.exBackground

            LinearGradient(
                colors: [Color.exSurface1.opacity(0.6), Color.exBackground],
                startPoint: .top,
                endPoint: .bottom
            )

            PulseLineShape()
                .trim(from: 0, to: (drawn || reduceMotion) ? 1 : 0)
                .stroke(
                    Color.exPrimary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                .frame(height: 44)
                .padding(.horizontal, 32)
                .offset(y: -140)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).delay(0.3)) {
                drawn = true
            }
        }
    }
}

/// The Exerly EKG pulse waveform (matches the web PulseLine path).
/// Reusable for dividers and loading states.
struct PulseLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Normalized waveform points (x: 0-1, y: 0-1, midline at 0.5).
        let points: [(CGFloat, CGFloat)] = [
            (0.00, 0.50), (0.29, 0.50), (0.33, 0.50), (0.36, 0.15),
            (0.40, 0.85), (0.43, 0.05), (0.46, 0.75), (0.49, 0.50),
            (0.56, 0.50), (0.60, 0.33), (0.64, 0.50), (1.00, 0.50),
        ]

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for (px, py) in points.dropFirst() {
            path.addLine(to: CGPoint(
                x: rect.minX + px * rect.width,
                y: rect.minY + py * rect.height
            ))
        }
        return path
    }
}
