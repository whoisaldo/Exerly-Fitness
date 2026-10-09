import Charts
import ExerlyCore
import SwiftUI

/// When calories were eaten: each hour's share across the span, and the
/// share in each part of the day.
struct IntakeTimingCard: View {
    let timing: IntakeTiming
    @State private var hour: Int?
    @State private var scrub: Double?
    @Environment(\.dynamicTypeSize) private var typeSize

    private static let parts = ["Morning", "Midday", "Evening", "Night"]

    var body: some View {
        ExCard {
            HStack(alignment: .firstTextBaseline) {
                ExEyebrow("When you ate", color: .exPrimaryText)
                Spacer(minLength: ExSpacing.small)
                if hour != nil {
                    Button("Clear") { hour = nil }.font(.exCaption.weight(.semibold)).foregroundStyle(Color.exPrimaryText)
                        .frame(minHeight: 44)
                }
            }
            Text(headline).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("nutrition.timing.readout")
            chart.frame(height: typeSize.isAccessibilitySize ? 200 : 140)
            windows
            Text(footnote).font(.exCaption).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headline: String {
        if let hour {
            let slot = timing.hours[hour]
            return "\(IntakeFormat.hours(hour, hour + 1)) · \(IntakeFormat.percent(timing.shares[hour])) of calories · "
                + "\(IntakeFormat.amount(slot.energy, .energy)) from \(IntakeFormat.entries(slot.entries))"
        }
        guard let peak = timing.peakHour else { return "No timed entries in this span." }
        return "Most calories between \(IntakeFormat.hour(peak)) and \(IntakeFormat.hour(peak + 1))"
    }

    private struct Slot: Identifiable {
        let hour: Int
        let percent: Double
        var id: Int { hour }
    }

    private var chart: some View {
        let slots = timing.shares.enumerated().map { Slot(hour: $0.offset, percent: $0.element * 100) }
        let top = max(10, (slots.map(\.percent).max() ?? 0) * 1.1)
        return Chart(slots) { slot in
            RectangleMark(xStart: .value("Start", Double(slot.hour) + 0.12), xEnd: .value("End", Double(slot.hour) + 0.88),
                          yStart: .value("Zero", 0.0), yEnd: .value("Share", slot.percent))
                .foregroundStyle(gradient)
                .cornerRadius(2)
                .opacity(hour == nil || hour == slot.hour ? 1 : 0.38)
        }
        .chartYScale(domain: 0...top)
        .chartXScale(domain: 0...24)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(Color.exBorder)
                AxisValueLabel(anchor: .top) {
                    if let number = value.as(Double.self) {
                        Text(IntakeFormat.hour(Int(number) % 24)).font(.exSmall).foregroundStyle(Color.exTextMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(Color.exBorder)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text("\(Int(number.rounded()))%").font(.exSmall).foregroundStyle(Color.exTextMuted)
                    }
                }
            }
        }
        .chartPicking($scrub) { (value: Double) in hour = min(max(Int(value.rounded(.down)), 0), 23) }
        .sensoryFeedback(.selection, trigger: hour)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Share of calories by hour")
        .accessibilityValue(timing.peakHour.map { "Most between \(IntakeFormat.spokenHours($0, $0 + 1))" } ?? "No timed entries")
        .accessibilityChartDescriptor(TimingChartDescriptor(timing: timing))
        .accessibilityIdentifier("nutrition.timing")
    }

    private var gradient: LinearGradient {
        LinearGradient(colors: [.exAccent, .exPrimary], startPoint: .top, endPoint: .bottom)
    }

    private var windows: some View {
        let windows = timing.windows()
        let columns = typeSize.isAccessibilitySize ? 1 : typeSize >= .xxLarge ? 2 : 4
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: ExSpacing.small, alignment: .leading), count: columns),
                         alignment: .leading, spacing: ExSpacing.small) {
            ForEach(Array(windows.enumerated()), id: \.offset) { index, window in
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.parts[index]).font(.exCaption.weight(.medium)).foregroundStyle(Color.exTextSecondary)
                    Text(IntakeFormat.percent(window.share)).font(.exStatSmall).monospacedDigit().foregroundStyle(Color.exTextPrimary)
                    Text(IntakeFormat.hours(window.start, window.end)).font(.exSmall).foregroundStyle(Color.exTextMuted)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Self.parts[index]), \(IntakeFormat.spokenHours(window.start, window.end)), "
                    + "\(IntakeFormat.spokenPercent(window.share)) of calories")
            }
        }
    }

    private var footnote: String {
        var text = "From \(IntakeFormat.entries(timing.timedEntries)) with a known time, partial days included."
        if timing.untimedEntries > 0 {
            text += " \(IntakeFormat.entries(timing.untimedEntries)) logged on another day \(timing.untimedEntries == 1 ? "has" : "have") "
                + "no known time and \(timing.untimedEntries == 1 ? "is" : "are") left out."
        }
        return text
    }
}

struct TimingChartDescriptor: AXChartDescriptorRepresentable {
    let timing: IntakeTiming

    func makeChartDescriptor() -> AXChartDescriptor {
        let shares = timing.shares.map { $0 * 100 }
        let x = AXNumericDataAxisDescriptor(title: "Hour", range: 0...23, gridlinePositions: []) { IntakeFormat.hour(Int($0)) }
        let y = AXNumericDataAxisDescriptor(title: "Share of calories", range: 0...max(shares.max() ?? 1, 1),
                                            gridlinePositions: []) { "\(Int($0.rounded())) percent" }
        let series = AXDataSeriesDescriptor(name: "Share of calories", isContinuous: false,
                                            dataPoints: shares.enumerated().map { AXDataPoint(x: Double($0.offset), y: $0.element) })
        return AXChartDescriptor(title: "Calories by hour", summary: nil, xAxis: x, yAxis: y, additionalAxes: [], series: [series])
    }
}
