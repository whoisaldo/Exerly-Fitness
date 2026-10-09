import ExerlyCore
import SwiftUI

/// Average hard sets a week for each muscle, ranked, against Exerly's weekly
/// range. Muscles under their range are named at the top.
struct MuscleVolumeSection: View {
    let report: TrainingInsights.Report
    let library: ExerlyCore.ExerciseLibrary
    @State private var showsOthers = false
    @State private var opened: TrainingInsights.MuscleLoad?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var ranged: [TrainingInsights.MuscleLoad] { report.muscles.filter { $0.range != nil } }
    private var others: [TrainingInsights.MuscleLoad] { report.muscles.filter { $0.range == nil } }

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
                    ForEach(ranged, id: \.muscle) { row($0) }
                }
                legend
                if !others.isEmpty {
                    Button { withAnimation(.snappy) { showsOthers.toggle() } } label: {
                        HStack {
                            Text(showsOthers ? "Hide muscles without a range" : "\(others.count) more muscles without a range")
                                .font(.exLabel).foregroundStyle(Color.exPrimaryText)
                            Spacer()
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                                .rotationEffect(.degrees(showsOthers ? 180 : 0)).foregroundStyle(Color.exPrimaryText)
                                .accessibilityHidden(true)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("training.muscles.others")
                    if showsOthers {
                        Text("Mostly trained by compound lifts. Exerly sets no target for them.")
                            .font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                        VStack(spacing: typeSize.isAccessibilitySize ? ExSpacing.item : 2) {
                            ForEach(others, id: \.muscle) { row($0) }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("training.muscles")
        .sheet(item: $opened) { load in
            MuscleDetailSheet(load: load, library: library, provisional: report.isVolumeProvisional,
                              weeks: report.completeWeeks)
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
                        MuscleBar(load: load, scale: scale).frame(height: 12)
                    }
                } else {
                    HStack(spacing: ExSpacing.item) {
                        Text(load.muscle.name).font(.exLabel).foregroundStyle(Color.exTextPrimary)
                            .lineLimit(1).minimumScaleFactor(0.85)
                            .frame(width: 92, alignment: .leading)
                        MuscleBar(load: load, scale: scale).frame(height: 12)
                        Text(InsightFormat.sets(load.averageSets)).font(.exStatSmall).monospacedDigit()
                            .foregroundStyle(MuscleColors.text(load.status))
                            .frame(minWidth: 34, alignment: .trailing)
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
                RoundedRectangle(cornerRadius: 2).fill(Color.exPrimary.opacity(0.22)).frame(width: 14, height: 8)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.exPrimary.opacity(0.5), lineWidth: 0.5))
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

/// A track with the muscle's range shaded and its average as a filled bar.
private struct MuscleBar: View {
    let load: TrainingInsights.MuscleLoad
    let scale: Double

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let x = { (value: Double) in width * min(max(value / scale, 0), 1) }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.exSurface3)
                if let range = load.range {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.exPrimary.opacity(0.22))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.exPrimary.opacity(0.5), lineWidth: 0.5))
                        .frame(width: max(2, x(range.upperBound) - x(range.lowerBound)), height: geometry.size.height + 4)
                        .offset(x: x(range.lowerBound))
                }
                Capsule().fill(MuscleColors.fill(load.status))
                    .frame(width: load.averageSets > 0 ? max(4, x(load.averageSets)) : 0, height: geometry.size.height * 0.6)
                    .padding(.leading, 0)
            }
            .frame(height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }
}

/// The exercises behind a muscle's sets.
private struct MuscleDetailSheet: View {
    let load: TrainingInsights.MuscleLoad
    let library: ExerlyCore.ExerciseLibrary
    let provisional: Bool
    let weeks: Int
    @Environment(\.dismiss) private var dismiss

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
