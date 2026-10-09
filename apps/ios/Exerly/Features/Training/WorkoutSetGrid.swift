import SwiftUI
import ExerlyCore

/// The columns an exercise's sets are logged in, from its metric.
enum SetGrid {
    static func fields(_ metric: TrackingMetric) -> [TrainingCell.Field] {
        switch metric {
        case .weightReps, .bodyweightReps, .assistedReps: [.load, .reps, .rir]
        case .duration: [.duration]
        case .weightDuration: [.load, .duration]
        case .distanceDuration: [.distance, .duration]
        case .weightDistance: [.load, .distance]
        }
    }

    /// Column heading: "LB", "+LB", "REPS".
    static func shortTitle(_ field: TrainingCell.Field, metric: TrackingMetric, unit: MassUnit) -> String {
        switch field {
        case .load:
            let symbol = TrainingFormat.unitSymbol(unit).uppercased()
            return metric == .bodyweightReps ? "+" + symbol : metric == .assistedReps ? "−" + symbol : symbol
        case .reps: return "REPS"
        case .rir: return "RIR"
        case .duration: return "SEC"
        case .distance: return "M"
        }
    }

    static func title(_ field: TrainingCell.Field, metric: TrackingMetric, unit: MassUnit) -> String {
        let symbol = TrainingFormat.unitSymbol(unit)
        switch field {
        case .load:
            return metric == .bodyweightReps ? "Added weight (\(symbol))" : metric == .assistedReps ? "Assistance (\(symbol))" : "Weight (\(symbol))"
        case .reps: return "Reps"
        case .rir: return "Reps in reserve"
        case .duration: return "Time (seconds)"
        case .distance: return "Distance (metres)"
        }
    }

    static func text(_ field: TrainingCell.Field, of set: PerformedSet, unit: MassUnit) -> String {
        let effort = set.primary
        switch field {
        case .load: return effort.load.map { TrainingFormat.number($0.value(in: unit)) } ?? ""
        case .reps: return effort.reps.map(String.init) ?? ""
        case .rir: return set.rir.map { $0 >= 6 ? "6+" : TrainingFormat.number($0) } ?? ""
        case .duration: return effort.duration.map(TrainingFormat.number) ?? ""
        case .distance: return effort.distance.map(TrainingFormat.number) ?? ""
        }
    }

    static func placeholder(_ field: TrainingCell.Field, metric: TrackingMetric) -> String {
        field == .load && metric.usesBodyweight ? "0" : "–"
    }

    /// Where to put the cursor when Core says a set can't be completed yet.
    static func missing(_ set: PerformedSet, exercise: ExerlyCore.Exercise) -> TrainingCell.Field? {
        let metric = exercise.metric
        let effort = set.primary
        if metric.requiresLoad && effort.load == nil { return .load }
        if metric.tracksReps && (effort.reps ?? 0) < 1 { return .reps }
        if metric.tracksDistance && (effort.distance ?? 0) <= 0 { return .distance }
        if metric.tracksDuration && (effort.duration ?? 0) <= 0 { return .duration }
        return fields(metric).first
    }
}

/// What a set row can ask the workout to do.
struct SetRowActions {
    var commit: (TrainingCell.Field, String) -> Void
    var step: (TrainingCell.Field, String, Bool) -> String?
    var stepLabel: (TrainingCell.Field) -> String
    var next: (TrainingCell.Field) -> (() -> Void)?
    var complete: () -> Void
    var usePrevious: () -> Void
    var changeKind: (SetKind) -> Void
    var moreOptions: () -> Void
    var delete: () -> Void
}

/// Column widths shared by the heading and every row of an exercise.
struct SetGridMetrics {
    @ScaledMetric(relativeTo: .body) var badge: CGFloat = 32
    @ScaledMetric(relativeTo: .body) var load: CGFloat = 66
    @ScaledMetric(relativeTo: .body) var reps: CGFloat = 50
    @ScaledMetric(relativeTo: .body) var rir: CGFloat = 44
    @ScaledMetric(relativeTo: .body) var wide: CGFloat = 70
    let check: CGFloat = 44
    let spacing: CGFloat = 6

    func width(_ field: TrainingCell.Field) -> CGFloat {
        switch field {
        case .load: load
        case .reps: reps
        case .rir: rir
        case .duration, .distance: wide
        }
    }
}

struct SetGridHeader: View {
    let metric: TrackingMetric
    let unit: MassUnit
    var metrics = SetGridMetrics()

    var body: some View {
        HStack(spacing: metrics.spacing) {
            Text("SET").frame(width: metrics.badge)
            Text("PREVIOUS").frame(maxWidth: .infinity)
            ForEach(SetGrid.fields(metric), id: \.self) { field in
                Text(SetGrid.shortTitle(field, metric: metric, unit: unit)).frame(width: metrics.width(field))
            }
            Color.clear.frame(width: metrics.check, height: 1)
        }
        .font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(Color.exTextMuted)
        .lineLimit(1).minimumScaleFactor(0.7)
        .accessibilityHidden(true)
    }
}

struct TrainingSetRow: View {
    let set: PerformedSet
    let number: Int
    let exercise: ExerlyCore.Exercise
    let unit: MassUnit
    let previous: PerformedSet?
    let isNext: Bool
    @Binding var focus: TrainingCell?
    let actions: SetRowActions
    var metrics = SetGridMetrics()
    @Environment(\.dynamicTypeSize) private var typeSize

    private var fields: [TrainingCell.Field] { SetGrid.fields(exercise.metric) }

    var body: some View {
        if typeSize.isAccessibilitySize { stacked } else { grid }
    }

    private var grid: some View {
        HStack(spacing: metrics.spacing) {
            badge.frame(width: metrics.badge)
            previousButton.frame(maxWidth: .infinity)
            ForEach(fields, id: \.self) { field in
                cell(field).frame(width: metrics.width(field))
            }
            checkButton
        }
        .padding(.vertical, 3)
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            badge
            previousButton
            ForEach(fields, id: \.self) { field in
                VStack(alignment: .leading, spacing: ExSpacing.tight) {
                    Text(SetGrid.title(field, metric: exercise.metric, unit: unit)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    cell(field).frame(maxWidth: .infinity)
                }
            }
            checkButton.frame(maxWidth: .infinity)
        }
        .padding(.vertical, ExSpacing.small)
    }

    private var kindColor: Color {
        switch set.kind {
        case .standard: Color.exTextSecondary
        case .warmUp: Color.exWarning
        case .drop: Color.exAccent
        case .myo: Color.exSecondary
        case .failure: Color.exError
        }
    }

    private var badge: some View {
        Menu {
            Picker("Set type", selection: Binding(get: { set.kind }, set: actions.changeKind)) {
                ForEach(SetKind.allCases, id: \.self) { Text(TrainingFormat.kind($0)).tag($0) }
            }
            Button("More options", systemImage: "slider.horizontal.3", action: actions.moreOptions)
            Button("Delete set", systemImage: "trash", role: .destructive, action: actions.delete)
        } label: {
            Group {
                if typeSize.isAccessibilitySize {
                    Text("Set \(number) · \(TrainingFormat.kind(set.kind))\(set.side.map { " · " + $0.rawValue.capitalized } ?? "")")
                        .font(.exLabel.weight(.semibold)).padding(.horizontal, ExSpacing.small)
                } else {
                    VStack(spacing: 0) {
                        Text(TrainingFormat.badge(set.kind) ?? "\(number)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        if let side = set.side {
                            Text(side == .left ? "L" : "R").font(.system(.caption2, design: .rounded, weight: .semibold))
                        }
                    }
                }
            }
            .foregroundStyle(kindColor)
            .frame(minWidth: 30, minHeight: 36)
            .background(set.kind == .standard ? Color.clear : kindColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Set \(number), \(TrainingFormat.kind(set.kind))\(set.side.map { ", \($0.rawValue)" } ?? "")")
        .accessibilityHint("Change the set type or delete it")
        .accessibilityIdentifier("set.\(exercise.id.rawValue).\(number).type")
    }

    private var previousButton: some View {
        Button(action: actions.usePrevious) {
            Text(previous.map { TrainingFormat.compact($0, metric: exercise.metric, unit: unit) } ?? "—")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.exTextMuted)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: typeSize.isAccessibilitySize ? .leading : .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(previous == nil || set.isCompleted)
        .accessibilityLabel(previous.map { "Previous: \(TrainingFormat.set($0, unit: unit))" } ?? "No previous set")
        .accessibilityHint(previous == nil || set.isCompleted ? "" : "Copies these values into this set")
    }

    private func cell(_ field: TrainingCell.Field) -> some View {
        let id = TrainingCell(setID: set.id, field: field)
        let focused = focus == id
        let title = SetGrid.title(field, metric: exercise.metric, unit: unit)
        return TrainingValueField(
            cell: id, text: SetGrid.text(field, of: set, unit: unit),
            placeholder: SetGrid.placeholder(field, metric: exercise.metric),
            title: "Set \(number) · \(title)",
            accessibilityLabel: "\(title), set \(number), \(exercise.name)",
            identifier: "set.\(exercise.id.rawValue).\(number).\(field)",
            decimal: field != .reps && field != .rir,
            stepLabel: actions.stepLabel(field), focus: $focus,
            step: { actions.step(field, $0, $1) }, next: actions.next(field),
            commit: { actions.commit(field, $0) })
        .frame(minHeight: 38)
        .background(focused ? Color.exPrimary.opacity(0.18) : set.isCompleted ? Color.clear : Color.exSurface2,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(focused ? Color.exPrimary : Color.clear, lineWidth: 1.5)
        }
        .animation(.easeOut(duration: 0.15), value: focused)
    }

    private var checkButton: some View {
        Button(action: actions.complete) {
            HStack(spacing: ExSpacing.small) {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                    .symbolEffect(.bounce, value: set.isCompleted)
                if typeSize.isAccessibilitySize { Text(set.isCompleted ? "Done" : "Complete set").font(.exBodyMedium) }
            }
            .foregroundStyle(set.isCompleted ? Color.white : isNext ? Color.exPrimaryText : Color.exTextMuted)
            .frame(minWidth: 36, maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 36)
            .padding(.horizontal, typeSize.isAccessibilitySize ? ExSpacing.content : 0)
            .background(set.isCompleted ? Color.exActionFill : Color.exSurface2,
                        in: RoundedRectangle(cornerRadius: typeSize.isAccessibilitySize ? ExRadius.control : 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: typeSize.isAccessibilitySize ? ExRadius.control : 18, style: .continuous)
                    .strokeBorder(isNext && !set.isCompleted ? Color.exPrimary : Color.clear, lineWidth: 1.5)
            }
            .frame(minWidth: metrics.check, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(set.isCompleted ? "Reopen" : "Complete") set \(number), \(exercise.name)")
        .accessibilityValue(TrainingFormat.set(set, unit: unit))
        .accessibilityIdentifier("set.\(exercise.id.rawValue).\(number).done")
    }
}
