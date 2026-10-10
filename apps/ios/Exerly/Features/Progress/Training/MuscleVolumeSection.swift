import Charts
import ExerlyCore
import SwiftUI

/// Average hard sets a week for each muscle, ranked, against Exerly's weekly
/// range. Muscles under their range are named at the top; the list shows the
/// top six until "Show all".
struct MuscleVolumeSection: View {
    let report: TrainingInsights.Report
    let library: ExerlyCore.ExerciseLibrary
    @State private var showsAll = false
    @State private var opened: TrainingInsights.MuscleLoad?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var valueWidth: CGFloat = 40
    @ScaledMetric(relativeTo: .subheadline) private var nameWidth: CGFloat = 92

    private var ranged: [TrainingInsights.MuscleLoad] { report.muscles.filter { $0.range != nil } }
    private var others: [TrainingInsights.MuscleLoad] { report.muscles.filter { $0.range == nil } }
    private static let collapsedCount = 6

    /// One axis for every row, so bar lengths compare honestly.
    private var scale: Double {
        let top = max(report.muscles.map(\.averageSets).max() ?? 0, report.muscles.compactMap(\.range?.upperBound).max() ?? 0)
        return max(10, (top * 1.08 / 5).rounded(.up) * 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            ExSectionHeading("Sets per muscle", detail: report.isVolumeProvisional ? "this week" : "a week")
            ExCard {
                summary
                VStack(spacing: typeSize.isAccessibilitySize ? ExSpacing.item : 2) {
                    ForEach(showsAll ? ranged : Array(ranged.prefix(Self.collapsedCount)), id: \.muscle) { row($0) }
                }
                legend
                if showsAll && !others.isEmpty {
                    Text("Without a range: mostly trained by compound lifts. Exerly sets no target for them.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: typeSize.isAccessibilitySize ? ExSpacing.item : 2) {
                        ForEach(others, id: \.muscle) { row($0) }
                    }
                }
                // Shown whenever a muscle is hidden: ranked past the top six, or without a range.
                if ranged.count > Self.collapsedCount || !others.isEmpty {
                    Button { withAnimation(.snappy) { showsAll.toggle() } } label: {
                        HStack {
                            Text(showsAll ? "Show fewer" : "Show all \(report.muscles.count) muscles")
                                .font(.exLabel).foregroundStyle(Color.exPrimaryText)
                            Spacer()
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                                .rotationEffect(.degrees(showsAll ? 180 : 0)).foregroundStyle(Color.exPrimaryText)
                                .accessibilityHidden(true)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("training.muscles.showAll")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("training.muscles")
        .sheet(item: $opened) { load in
            MuscleDetailSheet(load: load, library: library, provisional: report.isVolumeProvisional,
                              weeks: report.completeWeeks, span: report.span)
        }
    }

    // MARK: Summary

    private var below: [TrainingInsights.MuscleLoad] {
        ranged.filter { $0.status == .below }.sorted { share($0) < share($1) }
    }

    private func share(_ load: TrainingInsights.MuscleLoad) -> Double {
        load.averageSets / (load.range?.lowerBound ?? 1)
    }

    @ViewBuilder
    private var summary: some View {
        if report.isVolumeProvisional {
            Label {
                Text(report.completeWeeks == 0
                     ? "Your first week isn't over, so these are this week's sets so far. Exerly judges muscles against their range after \(TrainingInsights.minimumWeeksToJudge) full weeks."
                     : "One full week so far. Exerly judges muscles against their range after \(TrainingInsights.minimumWeeksToJudge) full weeks.")
            } icon: { Image(systemName: "hourglass").foregroundStyle(Color.exTextSecondary) }
                .font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("training.muscles.provisional")
        } else if below.isEmpty {
            Label("Every muscle with a range got at least its minimum.", systemImage: "checkmark.circle.fill")
                .font(.exLabel).foregroundStyle(Color.exSuccess).fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text(below.count == 1 ? "1 muscle under its range" : "\(below.count) muscles under their range")
                        .font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.exWarning) }
                Text(below.prefix(4).map { "\($0.muscle.name) \(InsightFormat.sets($0.averageSets)) of \(InsightFormat.sets($0.range!.lowerBound))" }
                    .joined(separator: " · ") + (below.count > 4 ? " · and \(below.count - 4) more" : ""))
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("training.muscles.below")
        }
    }

    // MARK: Rows

    private func row(_ load: TrainingInsights.MuscleLoad) -> some View {
        Button { opened = load } label: {
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(load.muscle.name).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                            Spacer(minLength: ExSpacing.small)
                            Text(InsightFormat.sets(load.averageSets)).font(.exStatSmall).monospacedDigit()
                                .foregroundStyle(MuscleColors.text(load.status))
                        }
                        MuscleBar(load: load, scale: scale).frame(height: 14)
                    }
                } else {
                    HStack(spacing: ExSpacing.item) {
                        Text(load.muscle.name).font(.exLabel).foregroundStyle(Color.exTextPrimary)
                            .lineLimit(1).minimumScaleFactor(0.85)
                            .frame(width: nameWidth, alignment: .leading)
                        MuscleBar(load: load, scale: scale).frame(height: 14)
                        Text(InsightFormat.sets(load.averageSets)).font(.exStatSmall).monospacedDigit()
                            .foregroundStyle(MuscleColors.text(load.status))
                            .frame(width: valueWidth, alignment: .trailing)
                    }
                }
            }
            .padding(.vertical, 6).frame(minHeight: 36).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken(load))
        .accessibilityHint("Shows the exercises behind it")
        .accessibilityIdentifier("training.muscle.\(load.muscle.rawValue)")
    }

    private func spoken(_ load: TrainingInsights.MuscleLoad) -> String {
        var parts = ["\(load.muscle.name), \(InsightFormat.sets(load.averageSets)) sets \(report.isVolumeProvisional ? "so far" : "a week")"]
        if let range = load.range {
            parts.append("range \(InsightFormat.sets(range.lowerBound)) to \(InsightFormat.sets(range.upperBound))")
            if !report.isVolumeProvisional { parts.append(MuscleColors.status(load.status)) }
        }
        if !report.isVolumeProvisional { parts.append("\(InsightFormat.sets(load.thisWeek)) this week so far") }
        return parts.joined(separator: ", ")
    }

    private var legend: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.tight))
            : AnyLayout(HStackLayout(spacing: ExSpacing.item))
        return layout {
            HStack(spacing: 5) {
                Rectangle().fill(Color.exPrimary.opacity(0.3)).frame(width: 14, height: 6)
                    .overlay(alignment: .leading) { Rectangle().fill(Color.exPrimaryText).frame(width: 1.5, height: 10) }
                    .overlay(alignment: .trailing) { Rectangle().fill(Color.exPrimaryText).frame(width: 1.5, height: 10) }
                Text("Exerly's range")
            }
            HStack(spacing: 5) {
                Capsule().fill(Color.exWarning).frame(width: 14, height: 4)
                Text("Under range")
            }
            HStack(spacing: 5) {
                Capsule().fill(Color.exTextMuted.opacity(0.6)).frame(width: 14, height: 4)
                Text("No range")
            }
        }
        .font(.exSmall).foregroundStyle(Color.exTextMuted)
        .padding(.top, ExSpacing.tight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The shaded band is Exerly's weekly range for each muscle. Amber bars are under it.")
    }
}

enum MuscleColors {
    static func fill(_ status: TrainingInsights.VolumeStatus) -> AnyShapeStyle {
        switch status {
        case .below: AnyShapeStyle(Color.exWarning)
        case .within, .above: AnyShapeStyle(LinearGradient(colors: [.exPrimary, .exAccent], startPoint: .leading, endPoint: .trailing))
        case .noRange: AnyShapeStyle(Color.exTextMuted.opacity(0.6))
        }
    }

    static func text(_ status: TrainingInsights.VolumeStatus) -> Color {
        status == .below ? .exWarning : .exTextPrimary
    }

    static func status(_ status: TrainingInsights.VolumeStatus) -> String {
        switch status {
        case .below: "under its range"
        case .within: "within its range"
        case .above: "above its range"
        case .noRange: "no range"
        }
    }
}

/// One track per muscle: the range as a tinted segment with ticks at its
/// ends, and the average as a bar from zero on the same track.
private struct MuscleBar: View {
    let load: TrainingInsights.MuscleLoad
    let scale: Double

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width, height = geometry.size.height
            let x = { (value: Double) in width * min(max(value / scale, 0), 1) }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.exSurface3).frame(height: height * 0.62)
                if let range = load.range {
                    Rectangle().fill(Color.exPrimary.opacity(0.3))
                        .frame(width: max(2, x(range.upperBound) - x(range.lowerBound)), height: height * 0.62)
                        .offset(x: x(range.lowerBound))
                    ForEach([range.lowerBound, range.upperBound], id: \.self) { bound in
                        Capsule().fill(Color.exPrimaryText.opacity(0.8)).frame(width: 1.5, height: height)
                            .offset(x: x(bound) - 0.75)
                    }
                }
                if load.averageSets > 0 {
                    Capsule().fill(MuscleColors.fill(load.status))
                        .frame(width: max(height * 0.62, x(load.averageSets)), height: height * 0.62)
                }
            }
            .frame(width: width, height: height, alignment: .leading)
        }
        .accessibilityHidden(true)
    }
}

/// A muscle's sets week by week, with its range shaded behind the bars.
private struct MuscleWeeksChart: View {
    let load: TrainingInsights.MuscleLoad
    let span: TrainingInsights.Span

    var body: some View {
        let top = max(load.weeks.map(\.sets).max() ?? 0, load.range?.upperBound ?? 0) * 1.1
        Chart {
            if let range = load.range {
                RectangleMark(yStart: .value("Low", range.lowerBound), yEnd: .value("High", range.upperBound))
                    .foregroundStyle(Color.exPrimary.opacity(0.14))
            }
            ForEach(load.weeks, id: \.start) { week in
                BarMark(x: .value("Week", BodyDates.anchor(week.start), unit: .weekOfYear), y: .value("Sets", week.sets), width: .ratio(0.62))
                    .foregroundStyle(week.start == load.weeks.last?.start ? AnyShapeStyle(Color.exPrimary.opacity(0.4))
                        : load.range.map { week.sets < $0.lowerBound } == true ? AnyShapeStyle(Color.exWarning)
                        : AnyShapeStyle(LinearGradient(colors: [.exPrimary, .exAccent], startPoint: .bottom, endPoint: .top)))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .chartYScale(domain: 0...max(top, 1))
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: InsightFormat.axisFormat(span), centered: false).font(.exSmall).foregroundStyle(Color.exTextMuted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(Color.exBorder)
                AxisValueLabel().font(.exSmall).foregroundStyle(Color.exTextMuted)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .environment(\.timeZone, BodyDates.utc).environment(\.calendar, calendar)
        .accessibilityElement(children: .ignore)
    }

    private var calendar: Calendar {
        var calendar = BodyDates.calendar
        calendar.firstWeekday = load.weeks.first?.start.weekday.rawValue ?? 2
        return calendar
    }
}

/// The exercises behind a muscle's sets.
private struct MuscleDetailSheet: View {
    let load: TrainingInsights.MuscleLoad
    let library: ExerlyCore.ExerciseLibrary
    let provisional: Bool
    let weeks: Int
    let span: TrainingInsights.Span
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ExScreen {
                ExCard {
                    ExEyebrow(provisional ? "Sets this week" : "Sets a week")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(InsightFormat.sets(load.averageSets)).font(.exStat).monospacedDigit().foregroundStyle(Color.exTextPrimary)
                        Text(provisional ? "so far" : "on average").font(.exBodyMedium).foregroundStyle(Color.exTextSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    if let range = load.range {
                        Text("Exerly's range is \(InsightFormat.sets(range.lowerBound)) to \(InsightFormat.sets(range.upperBound)) hard sets a week"
                            + (provisional ? "." : ", so this is \(MuscleColors.status(load.status))."))
                            .font(.exBody).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Exerly sets no weekly range for \(load.muscle.name.lowercased()); compound lifts usually cover it.")
                            .font(.exBody).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if !provisional {
                        Text("Averaged over \(InsightFormat.weeks(weeks)). This week so far: \(InsightFormat.sets(load.thisWeek)).")
                            .font(.exCaption).foregroundStyle(Color.exTextMuted)
                    }
                    if load.weeks.count >= 2 {
                        MuscleWeeksChart(load: load, span: span)
                            .frame(height: typeSize.isAccessibilitySize ? 220 : 150)
                            .accessibilityLabel("\(load.muscle.name) sets per week")
                            .accessibilityValue(load.weeks.map { "Week of \(InsightFormat.shortDate($0.start)), \(InsightFormat.sets($0.sets))" }
                                .joined(separator: "; "))
                            .accessibilityIdentifier("muscle.weeks")
                    }
                }
                ExSectionHeading("Where the sets came from")
                if load.contributors.isEmpty {
                    Text("No sets in this span.").font(.exBody).foregroundStyle(Color.exTextSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(load.contributors.enumerated()), id: \.element.exerciseID) { index, item in
                            if index > 0 { Rectangle().fill(Color.exBorder.opacity(0.5)).frame(height: 0.5) }
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(library.exercise(item.exerciseID)?.name ?? "Removed exercise").font(.exBodyMedium)
                                        .foregroundStyle(Color.exTextPrimary)
                                    Text(role(item.exerciseID)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                                }
                                Spacer(minLength: ExSpacing.small)
                                Text(InsightFormat.sets(item.sets)).font(.exStatSmall).monospacedDigit().foregroundStyle(Color.exTextPrimary)
                            }
                            .padding(.vertical, ExSpacing.item)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.horizontal, ExSpacing.content)
                    .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous))
                }
                Text("A set counts fully for the muscles an exercise targets and half for the ones it assists. One side of a one-arm set counts half. Warm-ups don't count.")
                    .font(.exCaption).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true)
            }
            .navigationTitle(load.muscle.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func role(_ id: ExerciseID) -> String {
        guard let share = library.exercise(id)?.muscles[load.muscle] else { return "" }
        return share >= 1 ? "Targets it" : "Assists, counts half"
    }
}
