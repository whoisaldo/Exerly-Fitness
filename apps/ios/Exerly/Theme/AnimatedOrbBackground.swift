import SwiftUI

struct AnimatedOrbBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                drawOrbs(context: context, size: size, time: now)
            }
        }
        .ignoresSafeArea()
        .background(Color.exBackground)
    }

    private func drawOrbs(
        context: GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        let orbs: [(Color, CGFloat, CGFloat, CGFloat)] = [
            (.exPrimary, 0.3, 200, 0),
            (.exSecondary, 0.2, 160, 2.1),
            (.exAccent, 0.15, 140, 4.2),
        ]

        for (color, opacity, radius, offset) in orbs {
            let t = time * 0.3 + offset
            let x = size.width * 0.5 + cos(t) * size.width * 0.25
            let y = size.height * 0.35 + sin(t * 0.7) * size.height * 0.15

            let center = CGPoint(x: x, y: y)
            let gradient = Gradient(colors: [
                color.opacity(opacity),
                color.opacity(0),
            ])

            context.drawLayer { ctx in
                ctx.addFilter(.blur(radius: 60))
                ctx.fill(
                    Circle().path(in: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .radialGradient(
                        gradient,
                        center: center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
    }
}
