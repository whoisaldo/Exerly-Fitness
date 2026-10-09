import ExerlyCore
import SwiftUI

/// Stalls and the deload signal as plain-language cards, each with its
/// numbers in the account's unit and the limits of what it can say.
struct TrainingSignalsSection: View {
    let signals: [TrainingInsights.Signal]
    let store: TrainingStore
    let unit: MassUnit
    let timeZone: TimeZone
    let span: TrainingInsights.Span
    @State private var showsAll = false

    static let shown = 2

    var body: some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            ExSectionHeading("Signals", detail: signals.isEmpty ? nil : signals.count == 1 ? "1 to look at" : "\(signals.count) to look at")
            if signals.isEmpty {
                ExCard {
                    HStack(alignment: .top, spacing: ExSpacing.item) {
                        InsightIcon(systemName: "checkmark", color: .exSuccess)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No stalls or slumps").font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                            Text("Exerly checks each lift's last \(TrainingSignals.stallWindowDays / 7) weeks for a stall, once it has "
                                + "\(TrainingSignals.stallMinimumSessions) sessions over \(TrainingSignals.stallMinimumSpanDays / 7) weeks, "
                                + "and the last \(TrainingSignals.deloadRecentDays) days for several lifts dropping together.")
                                .font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("training.signals.none")
                }
            } else {
                ForEach(Array((showsAll ? signals : Array(signals.prefix(Self.shown))).enumerated()), id: \.offset) { _, signal in
                    TrainingSignalCard(signal: signal, store: store, unit: unit, timeZone: timeZone, span: span)
                }
                if signals.count > Self.shown {
                    Button(showsAll ? "Show fewer signals" : "Show \(signals.count - Self.shown) more: "
                        + signals.dropFirst(Self.shown).flatMap(\.lifts).map { store.library.exercise($0.exerciseID)?.name ?? "a lift" }
                            .joined(separator: ", ")) {
                        withAnimation(.snappy) { showsAll.toggle() }
                    }
                    .font(.exLabel).foregroundStyle(Color.exPrimaryText).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("training.signals.all")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("training.signals")
    }
}

struct TrainingSignalCard: View {
    let signal: TrainingInsights.Signal
    let store: TrainingStore
    let unit: MassUnit
    let timeZone: TimeZone
    let span: TrainingInsights.Span
    @State private var showsLimits = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isDeload: Bool { signal.diagnosis.kind == .deload }

    var body: some View {
        ExCard {
            HStack(spacing: ExSpacing.small) {
                InsightIcon(systemName: isDeload ? "arrow.down.right" : "pause.fill", color: .exWarning)
                ExEyebrow(isDeload ? "Possible fatigue" : "Stall", color: .exWarning)
            }
            Text(signal.diagnosis.title).font(.exH3).foregroundStyle(Color.exTextPrimary)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(signal.diagnosis.summary).font(.exBody).foregroundStyle(Color.exTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(signal.lifts, id: \.exerciseID) { lift in
                NavigationLink {
                    LiftDetailView(store: store, exerciseID: lift.exerciseID, unit: unit, timeZone: timeZone,
                                   initialSpan: span == .fourWeeks ? .threeMonths : span)
                } label: { evidence(lift) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("training.signal.\(signal.diagnosis.kind.rawValue).\(lift.exerciseID.rawValue)")
            }
            limits
        }
        .accessibilityElement(children: .contain)
    }

    private func name(_ id: ExerciseID) -> String { store.library.exercise(id)?.name ?? "Removed exercise" }

    /// The lift's numbers, in the account's unit, with its sparkline.
    private func evidence(_ lift: TrainingInsights.SignalLift) -> some View {
        let text = numbers(lift)
        return HStack(spacing: ExSpacing.item) {
            if !typeSize.isAccessibilitySize {
                LiftSparkline(points: lift.points, line: nil, color: .exWarning).frame(width: 72, height: 34)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(isDeload ? name(lift.exerciseID) : text.headline).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                Text(isDeload ? text.headline : text.detail).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if isDeload { Text(text.detail).font(.exCaption).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.exTextMuted)
                .accessibilityHidden(true)
        }
        .padding(ExSpacing.item)
        .background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name(lift.exerciseID)). \(text.spoken)")
        .accessibilityHint("Opens the lift's history")
    }

    private func numbers(_ lift: TrainingInsights.SignalLift) -> (headline: String, detail: String, spoken: String) {
        if isDeload, let baseline = lift.baseline, let recent = lift.recent, let change = lift.recentChange {
            return ("\(InsightFormat.estimate(baseline, unit)) → \(InsightFormat.estimate(recent, unit)) (\(InsightFormat.percent(change)))",
                    "Mean e1RM, \(TrainingSignals.deloadBaselineDays) days before against the last \(TrainingSignals.deloadRecentDays)",
                    "Mean estimated 1RM went from \(InsightFormat.spokenEstimate(baseline, unit)) to "
                        + "\(InsightFormat.spokenEstimate(recent, unit)) in the last \(TrainingSignals.deloadRecentDays) days, "
                        + "\(InsightFormat.percent(change).replacingOccurrences(of: "−", with: "minus "))")
        }
        guard let trend = lift.trend else { return ("", "", "") }
        let weeks = max(1, trend.from.days(until: trend.through) / 7)
        let flat = InsightFormat.amount(trend.slopePerWeek, unit, withUnit: false) == InsightFormat.amount(0, unit, withUnit: false)
            && InsightFormat.amount(trend.standardError, unit, withUnit: false) == InsightFormat.amount(0, unit, withUnit: false)
        return ("e1RM about \(InsightFormat.estimate(trend.meanOneRepMax, unit))",
                (flat ? "Flat" : "\(InsightFormat.rate(trend.slopePerWeek, unit)) a week (± \(InsightFormat.amount(trend.standardError, unit)))")
                    + " · \(InsightFormat.sessions(trend.sessions)) in \(InsightFormat.weeks(weeks))",
                "Estimated 1RM about \(InsightFormat.spokenEstimate(trend.meanOneRepMax, unit)), "
                    + "\(InsightFormat.spokenRate(trend.slopePerWeek, unit)), give or take "
                    + "\(InsightFormat.amount(trend.standardError, unit, withUnit: false)) \(InsightFormat.unitName(unit)), "
                    + "over \(InsightFormat.sessions(trend.sessions)) in \(InsightFormat.weeks(weeks))")
    }

    @ViewBuilder
    private var limits: some View {
        let caveats = signal.caveats
        if !caveats.isEmpty {
            Button { withAnimation(.snappy) { showsLimits.toggle() } } label: {
                HStack {
                    Text("How sure is this?").font(.exLabel).foregroundStyle(Color.exPrimaryText)
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(Color.exPrimaryText)
                        .rotationEffect(.degrees(showsLimits ? 180 : 0)).accessibilityHidden(true)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(showsLimits ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("training.signal.limits")
            if showsLimits {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(caveats, id: \.self) { caveat in
                        Label { Text(caveat) } icon: { Image(systemName: "info.circle") }
                            .font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("An observation from your log. It doesn't establish a cause or change your plan.")
                        .font(.exCaption).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
