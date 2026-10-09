import ExerlyCore
import SwiftUI

/// A horizontal scale under a fixed needle: drag it to move the weight one
/// step per tick, with a haptic tick each step. VoiceOver adjusts it by a step.
struct WeightRuler: View {
    @Binding var value: Double
    let unit: MassUnit
    var range: ClosedRange<Double>
    /// Points between ticks.
    var spacing: CGFloat = 10
    @State private var dragStart: Double?
    @Environment(\.colorScheme) private var colorScheme

    private var step: Double { WeightTrend.step(for: unit) }
    /// Ticks per whole unit: whole numbers get a label.
    private var ticksPerUnit: Int { Int((1 / step).rounded()) }

    var body: some View {
        Canvas { context, size in
            let middle = size.width / 2
            let position = ((value / step) * 1_000).rounded() / 1_000
            let base = position.rounded(.down)
            let offset = position - base
            let reach = Int(middle / spacing) + 2
            let baseline = size.height - 22
            for tick in -reach...reach {
                let index = Int(base) + tick
                let tickValue = Double(index) * step
                guard tickValue >= range.lowerBound - step / 2, tickValue <= range.upperBound + step / 2 else { continue }
                let x = middle + (CGFloat(tick) - offset) * spacing
                let whole = index % ticksPerUnit == 0
                let half = unit == .kilograms && index % (ticksPerUnit / 2) == 0
                let height: CGFloat = whole ? 26 : half ? 17 : 10
                var line = Path()
                line.move(to: CGPoint(x: x, y: baseline - height))
                line.addLine(to: CGPoint(x: x, y: baseline))
                context.stroke(line, with: .color(whole ? Color.exTextSecondary : Color.exTextMuted.opacity(0.55)),
                               style: StrokeStyle(lineWidth: whole ? 2 : 1.2, lineCap: .round))
                if whole {
                    let label = Text("\(index / ticksPerUnit)").font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.exTextSecondary)
                    context.draw(label, at: CGPoint(x: x, y: baseline + 12))
                }
            }
        }
        .overlay(alignment: .top) {
            Capsule().fill(LinearGradient(colors: [.exPrimary, .exAccent], startPoint: .top, endPoint: .bottom))
                .frame(width: 4, height: 38).padding(.top, 2)
                .shadow(color: Color.exAccent.opacity(colorScheme == .dark ? 0.45 : 0.2), radius: 6)
                .accessibilityHidden(true)
        }
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18),
                                   .init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        }
        .frame(height: 64)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { drag in
                    let start = dragStart ?? value
                    if dragStart == nil { dragStart = value }
                    set(start - Double(drag.translation.width / spacing) * step)
                }
                .onEnded { _ in dragStart = nil }
        )
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement()
        .accessibilityLabel("Weight")
        .accessibilityValue("\(BodyFormat.number(value)) \(BodyFormat.unitName(unit))")
        .accessibilityHint("Swipe up or down to change it by \(BodyFormat.number(step)) \(BodyFormat.unitName(unit)).")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(by: 1)
            case .decrement: nudge(by: -1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("weighIn.ruler")
    }

    private func nudge(by ticks: Int) { value = Self.nudged(value, by: ticks, unit: unit, range: range) }

    private func set(_ raw: Double) {
        let next = Self.snapped(raw, unit: unit, range: range)
        if next != value { value = next }
    }

    /// The next tick up or down; a typed value between ticks moves to its neighbour.
    static func nudged(_ value: Double, by ticks: Int, unit: MassUnit, range: ClosedRange<Double>) -> Double {
        let step = WeightTrend.step(for: unit)
        let position = ((value / step) * 1_000).rounded() / 1_000
        let next = ticks > 0 ? position.rounded(.down) + Double(ticks) : position.rounded(.up) + Double(ticks)
        return snapped(next * step, unit: unit, range: range)
    }

    static func snapped(_ raw: Double, unit: MassUnit, range: ClosedRange<Double>) -> Double {
        let step = WeightTrend.step(for: unit)
        let snapped = ((raw / step).rounded() * step * 100).rounded() / 100
        return min(max(snapped, range.lowerBound), range.upperBound)
    }

    /// What a weigh-in may be, in `unit`: ExerlyCore's 20 to 400 kg.
    static func range(for unit: MassUnit) -> ClosedRange<Double> {
        (Mass.kg(20).value(in: unit) * 10).rounded(.up) / 10...(Mass.kg(400).value(in: unit) * 10).rounded(.down) / 10
    }
}
