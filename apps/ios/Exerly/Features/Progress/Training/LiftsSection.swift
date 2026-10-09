import Charts
import ExerlyCore
import SwiftUI

/// The person's main lifts by estimated 1RM, most trained first. Each opens
/// its detail.
struct LiftsSection: View {
    let report: TrainingInsights.Report
    let store: TrainingStore
    let unit: MassUnit
    let timeZone: TimeZone
    @State private var showsAll = false

    static let shown = 5

    var body: some View {
        let lifts = showsAll ? report.lifts : Array(report.lifts.prefix(Self.shown))
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            ExSectionHeading("Strength", detail: "estimated 1RM")
            if report.lifts.isEmpty {
                ExCard {
                    Text("No lifts with weight and reps in \(InsightFormat.spanPhrase(report.span)).")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                InsightList {
                    ForEach(Array(lifts.enumerated()), id: \.element.exerciseID) { index, lift in
                        if index > 0 { InsightDivider() }
                        NavigationLink {
                            LiftDetailView(store: store, exerciseID: lift.exerciseID, unit: unit, timeZone: timeZone,
                                           initialSpan: report.span)
                        } label: {
                            LiftRow(lift: lift, name: name(lift.exerciseID), unit: unit, span: report.span)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("training.lift.\(lift.exerciseID.rawValue)")
                    }
                }
                if report.lifts.count > Self.shown {
                    Button(showsAll ? "Show fewer lifts" : "Show all \(report.lifts.count) lifts") {
                        withAnimation(.snappy) { showsAll.toggle() }
                    }
                    .font(.exBodyMedium).foregroundStyle(Color.exPrimaryText).frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("training.lifts.all")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("training.lifts")
    }

    private func name(_ id: ExerciseID) -> String { store.library.exercise(id)?.name ?? "Removed exercise" }
}

private struct LiftRow: View {
    let lift: TrainingInsights.LiftSummary
    let name: String
    let unit: MassUnit
    let span: TrainingInsights.Span
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                    Text(InsightFormat.estimate(lift.latest.oneRepMax, unit)).font(.exStatSmall).monospacedDigit()
                        .foregroundStyle(Color.exTextPrimary)
                    detail
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: ExSpacing.item) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary).lineLimit(2)
                        detail
                    }
                    Spacer(minLength: ExSpacing.small)
                    LiftSparkline(points: lift.points, line: lift.trendLine).frame(width: 64, height: 30)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(InsightFormat.estimate(lift.latest.oneRepMax, unit, withUnit: false)).font(.exStatSmall).monospacedDigit()
                            .foregroundStyle(Color.exTextPrimary)
                        Text(unit.rawValue).font(.exSmall).foregroundStyle(Color.exTextMuted)
                    }
                    .frame(minWidth: 44, alignment: .trailing)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.exTextMuted)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.vertical, ExSpacing.item).frame(minHeight: 60).contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityHint("Opens the lift's history")
    }

    private var detail: some View {
        HStack(spacing: 4) {
            if let change = lift.change {
                Image(systemName: LiftTone.symbol(change, unit: unit)).font(.caption2.weight(.bold)).accessibilityHidden(true)
                Text(InsightFormat.change(change, unit))
                    .monospacedDigit()
            }
            Text(lift.change == nil ? InsightFormat.sessions(lift.sessions) : "· \(InsightFormat.sessions(lift.sessions))")
                .foregroundStyle(Color.exTextSecondary)
        }
        .font(.exCaption).foregroundStyle(lift.change.map { LiftTone.color($0, unit: unit) } ?? Color.exTextSecondary)
    }

    private var spoken: String {
        var parts = ["\(name), estimated 1RM \(InsightFormat.spokenEstimate(lift.latest.oneRepMax, unit)) last session"]
        if let change = lift.change { parts.append("\(InsightFormat.spokenChange(change, unit)) over \(InsightFormat.spanPhrase(span))") }
        parts.append(InsightFormat.sessions(lift.sessions))
        if lift.best.sessionID != lift.latest.sessionID {
            parts.append("best \(InsightFormat.spokenEstimate(lift.best.oneRepMax, unit))")
        }
        return parts.joined(separator: ", ")
    }
}

/// Up, flat or down, as the lift rows and detail colour it. Flat is under
/// half a pound or a quarter kilo.
enum LiftTone {
    static func isFlat(_ kilograms: Double, unit: MassUnit) -> Bool { abs(Mass.kg(kilograms).value(in: unit)) < 0.5 }

    static func symbol(_ kilograms: Double, unit: MassUnit) -> String {
        isFlat(kilograms, unit: unit) ? "arrow.right" : kilograms > 0 ? "arrow.up.right" : "arrow.down.right"
    }

    static func color(_ kilograms: Double, unit: MassUnit) -> Color {
        isFlat(kilograms, unit: unit) ? .exTextSecondary : kilograms > 0 ? .exSuccess : .exWarning
    }
}

/// Session bests as a small line, with the fitted trend dashed.
struct LiftSparkline: View {
    let points: [TrainingInsights.LiftPoint]
    var line: TrainingInsights.TrendLine?
    var color: Color = .exPrimary

    var body: some View {
        let values = points.map(\.oneRepMax) + [line?.startValue, line?.endValue].compactMap { $0 }
        let low = values.min() ?? 0, high = values.max() ?? 1
        let pad = max((high - low) * 0.15, high * 0.01, 0.5)
        Chart {
            ForEach(points, id: \.sessionID) { point in
                LineMark(x: .value("Day", BodyDates.anchor(point.date)), y: .value("e1RM", point.oneRepMax),
                         series: .value("Series", "Sessions"))
                    .foregroundStyle(LinearGradient(colors: [color, .exAccent], startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let last = points.last {
                PointMark(x: .value("Day", BodyDates.anchor(last.date)), y: .value("e1RM", last.oneRepMax))
                    .symbolSize(18).foregroundStyle(Color.exAccent)
            }
            if let line {
                LineMark(x: .value("Day", BodyDates.anchor(line.start)), y: .value("Trend", line.startValue), series: .value("Series", "Trend"))
                    .foregroundStyle(Color.exTextMuted.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                LineMark(x: .value("Day", BodyDates.anchor(line.end)), y: .value("Trend", line.endValue), series: .value("Series", "Trend"))
                    .foregroundStyle(Color.exTextMuted.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
        .chartYScale(domain: (low - pad)...(high + pad))
        .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
        .environment(\.timeZone, BodyDates.utc).environment(\.calendar, BodyDates.calendar)
        .accessibilityHidden(true)
    }
}

/// A rounded surface holding rows separated by hairlines, like the weigh-in list.
struct InsightList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, ExSpacing.content)
            .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous).strokeBorder(Color.exBorder.opacity(0.5), lineWidth: 0.5)
            }
    }
}

struct InsightDivider: View {
    var body: some View { Rectangle().fill(Color.exBorder.opacity(0.5)).frame(height: 0.5).accessibilityHidden(true) }
}
