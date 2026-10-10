import Charts
import ExerlyCore
import SwiftUI

/// Intake per day, or per week across a year, against each bar's goal: the
/// band that meets it, the target as a line, and the average dashed. A day
/// that doesn't count is drawn faded and apart. Touching a bar selects it.
struct IntakeBarChart: View {
    let bars: [IntakeBar]
    let nutrient: Nutrient
    let average: Double?
    let range: IntakeRange
    @Binding var selection: LocalDate?
    @State private var scrub: Date?

    private static let day: TimeInterval = 86_400

    var body: some View {
        Chart {
            ForEach(bars) { bar in
                if let goal = bar.goal {
                    let band = goal.band()
                    if let lower = band.lower, let upper = band.upper {
                        RectangleMark(xStart: .value("Start", slot(bar).lowerBound), xEnd: .value("End", slot(bar).upperBound),
                                      yStart: .value("Lower", lower), yEnd: .value("Upper", upper))
                            .foregroundStyle(Color.exTextSecondary.opacity(0.14))
                    }
                }
            }
            ForEach(bars) { bar in
                if let value = bar.value {
                    RectangleMark(xStart: .value("Start", column(bar).lowerBound), xEnd: .value("End", column(bar).upperBound),
                                  yStart: .value("Zero", 0.0), yEnd: .value(IntakeFormat.name(nutrient), value))
                        .foregroundStyle(fill)
                        .cornerRadius(bars.count > 40 ? 1 : 3)
                        .opacity(selection == nil || selection == bar.start ? 1 : 0.38)
                } else if let logged = bar.uncounted, logged > 0 {
                    RectangleMark(xStart: .value("Start", column(bar).lowerBound), xEnd: .value("End", column(bar).upperBound),
                                  yStart: .value("Zero", 0.0), yEnd: .value("Not counted", logged))
                        .foregroundStyle(Color.exTextMuted.opacity(selection == nil || selection == bar.start ? 0.42 : 0.2))
                        .cornerRadius(bars.count > 40 ? 1 : 3)
                }
            }
            ForEach(bars) { bar in
                if let goal = bar.goal {
                    if let target = goal.target {
                        RuleMark(xStart: .value("Start", slot(bar).lowerBound), xEnd: .value("End", slot(bar).upperBound),
                                 y: .value("Target", target))
                            .foregroundStyle(Color.exTextPrimary.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1.4))
                    }
                    if let floor = goal.floor, goal.target == nil || goal.ceiling == nil {
                        RuleMark(xStart: .value("Start", slot(bar).lowerBound), xEnd: .value("End", slot(bar).upperBound),
                                 y: .value("Floor", floor))
                            .foregroundStyle(Color.exTextSecondary).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    }
                    if let ceiling = goal.ceiling {
                        RuleMark(xStart: .value("Start", slot(bar).lowerBound), xEnd: .value("End", slot(bar).upperBound),
                                 y: .value("Limit", ceiling))
                            .foregroundStyle(Color.exWarning).lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                    }
                }
            }
            if let average, bars.count > 1 {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(Color.exAccent).lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...top)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: range == .week ? 7 : 4)) { _ in
                AxisValueLabel(format: axisFormat, centered: range == .week).font(.exSmall).foregroundStyle(Color.exTextMuted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(Color.exBorder)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(IntakeFormat.number(number, nutrient.unit)).font(.exSmall).foregroundStyle(Color.exTextMuted)
                    }
                }
            }
        }
        // A tap picks a day and a sideways drag scrubs; the pick stays until the readout clears it.
        .chartPicking($scrub) { (date: Date) in
            if let bar = bar(at: date) { selection = bar.start }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .intakeChartDates()
        .accessibilityElement(children: .ignore)
        .accessibilityChartDescriptor(IntakeChartDescriptor(bars: bars, nutrient: nutrient))
        .accessibilityAdjustableAction { direction in
            let usable = bars.filter { $0.value != nil || $0.uncounted != nil }
            guard !usable.isEmpty else { return }
            let index = selection.flatMap { day in usable.firstIndex { $0.start == day } }
            switch direction {
            case .increment: selection = usable[min((index ?? -1) + 1, usable.count - 1)].start
            case .decrement: selection = usable[max((index ?? usable.count) - 1, 0)].start
            @unknown default: break
            }
        }
    }

    private var fill: AnyShapeStyle {
        nutrient == .energy
            ? AnyShapeStyle(LinearGradient(colors: [.exAccent, .exPrimary], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(IntakeFormat.color(nutrient))
    }

    /// A bar's whole days, for its goal.
    private func slot(_ bar: IntakeBar) -> ClosedRange<Date> {
        BodyDates.anchor(bar.start).addingTimeInterval(-Self.day / 2)...BodyDates.anchor(bar.end).addingTimeInterval(Self.day / 2)
    }

    /// The bar itself, inset so neighbours don't touch.
    private func column(_ bar: IntakeBar) -> ClosedRange<Date> {
        let whole = slot(bar)
        let inset = whole.upperBound.timeIntervalSince(whole.lowerBound) * (bars.count > 60 ? 0.1 : bars.count > 20 ? 0.16 : 0.2)
        return whole.lowerBound.addingTimeInterval(inset)...whole.upperBound.addingTimeInterval(-inset)
    }

    private var domain: ClosedRange<Date> {
        guard let first = bars.first, let last = bars.last else { return Date()...Date().addingTimeInterval(Self.day) }
        return slot(first).lowerBound...slot(last).upperBound
    }

    /// Room for the tallest bar or goal line.
    private var top: Double {
        let values = bars.flatMap { bar -> [Double] in
            let goal = bar.goal
            return [bar.value, bar.uncounted, goal?.ceiling, goal?.target, goal?.floor, goal?.band().upper].compactMap { $0 }
        } + [average ?? 0]
        let highest = values.max() ?? 0
        return highest > 0 ? highest * 1.08 : 1
    }

    private var axisFormat: Date.FormatStyle {
        let style = Date.FormatStyle(timeZone: BodyDates.utc)
        return switch range {
        case .yesterday, .week: style.weekday(.abbreviated)
        case .thisMonth, .month, .quarter: style.month(.abbreviated).day()
        case .year: style.month(.abbreviated)
        }
    }

    private func bar(at date: Date) -> IntakeBar? {
        bars.first { slot($0).contains(date) } ?? (date < domain.lowerBound ? bars.first : bars.last)
    }
}

extension View {
    /// Picks the x value under a tap, and follows Charts' own selection while
    /// a finger scrubs. The last value stays picked when the finger lifts.
    /// Only a tap gesture sits over the chart, so the page still scrolls.
    func chartPicking<X: Plottable & Equatable>(_ scrub: Binding<X?>, _ pick: @escaping (X) -> Void) -> some View {
        chartXSelection(value: scrub)
            .onChange(of: scrub.wrappedValue) { _, value in if let value { pick(value) } }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let plot = proxy.plotFrame else { return }
                            if let x: X = proxy.value(atX: location.x - geometry[plot].origin.x) { pick(x) }
                        }
                }
            }
    }
}

/// VoiceOver's audio graph and data table: intake per bar, and the goal.
struct IntakeChartDescriptor: AXChartDescriptorRepresentable {
    let bars: [IntakeBar]
    let nutrient: Nutrient

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = bars.map { bar in
            bar.days == 1 ? BodyFormat.shortDate(bar.start) : "\(BodyFormat.shortDate(bar.start)) to \(BodyFormat.shortDate(bar.end))"
        }
        let values = bars.compactMap(\.value) + bars.compactMap { $0.goal?.reference }
        let x = AXNumericDataAxisDescriptor(title: bars.first?.days == 7 ? "Week" : "Day",
                                            range: 0...Double(max(bars.count - 1, 1)), gridlinePositions: []) { index in
            labels.indices.contains(Int(index)) ? labels[Int(index)] : ""
        }
        let y = AXNumericDataAxisDescriptor(title: IntakeFormat.name(nutrient), range: 0...max(values.max() ?? 1, 1),
                                            gridlinePositions: []) { IntakeFormat.spokenAmount($0, nutrient) }
        let intake = AXDataSeriesDescriptor(name: "Intake on counted days", isContinuous: false,
                                            dataPoints: bars.enumerated().compactMap { index, bar in
                                                bar.value.map { AXDataPoint(x: Double(index), y: $0) }
                                            })
        let goal = AXDataSeriesDescriptor(name: "Goal", isContinuous: true,
                                          dataPoints: bars.enumerated().compactMap { index, bar in
                                              bar.goal?.reference.map { AXDataPoint(x: Double(index), y: $0) }
                                          })
        return AXChartDescriptor(title: IntakeFormat.name(nutrient), summary: nil, xAxis: x, yAxis: y, additionalAxes: [],
                                 series: [intake, goal])
    }
}
