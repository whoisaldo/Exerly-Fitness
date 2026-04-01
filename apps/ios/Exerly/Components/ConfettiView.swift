import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for particle in particles {
                    let age = now - particle.startTime
                    guard age < 3.0 else { continue }

                    let progress = age / 3.0
                    let x = particle.startX + sin(age * particle.wobble) * 30
                    let y = particle.startY + age * particle.speed
                    let opacity = 1.0 - progress
                    let rotation = age * particle.rotation

                    context.drawLayer { ctx in
                        ctx.opacity = opacity
                        ctx.translateBy(x: x, y: y)
                        ctx.rotate(by: .radians(rotation))
                        let rect = CGRect(x: -4, y: -6, width: 8, height: 12)
                        ctx.fill(
                            RoundedRectangle(cornerRadius: 2).path(in: rect),
                            with: .color(particle.color)
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { emit() }
    }

    private func emit() {
        let colors: [Color] = [.exPrimary, .exSecondary, .exAccent, .exSuccess, .exWarning]
        let now = Date.timeIntervalSinceReferenceDate
        particles = (0..<60).map { _ in
            ConfettiParticle(
                startX: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                startY: CGFloat.random(in: -100...(-20)),
                speed: CGFloat.random(in: 100...250),
                wobble: Double.random(in: 2...6),
                rotation: Double.random(in: -4...4),
                color: colors.randomElement() ?? .exPrimary,
                startTime: now + Double.random(in: 0...0.5)
            )
        }
    }
}

private struct ConfettiParticle {
    let startX: CGFloat
    let startY: CGFloat
    let speed: CGFloat
    let wobble: Double
    let rotation: Double
    let color: Color
    let startTime: TimeInterval
}
