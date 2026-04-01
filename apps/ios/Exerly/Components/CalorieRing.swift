import SwiftUI

struct CalorieRing: View {
    let consumed: Double
    let target: Double
    var lineWidth: CGFloat = 12
    var size: CGFloat = 120

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(consumed / target, 1.0)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.exSurface2, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.exPrimary, .exSecondary, .exAccent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8), value: progress)

            VStack(spacing: 2) {
                Text("\(Int(consumed))")
                    .font(.exStatMedium)
                    .foregroundStyle(.exTextPrimary)
                Text("/ \(Int(target))")
                    .font(.exCaption)
                    .foregroundStyle(.exTextMuted)
                Text("kcal")
                    .font(.exSmall)
                    .foregroundStyle(.exTextSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}
