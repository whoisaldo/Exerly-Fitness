import SwiftUI

/// The set to do: its exercise, its place in the exercise, and its weight and
/// reps, large. The Digital Crown changes the reps, or the weight after a tap
/// on it; Done logs the set as shown.
struct SetView: View {
    let active: WatchState.Active
    let set: WatchSet
    let heartRate: Double?
    let waiting: Int
    let complete: (_ weight: Double?, _ reps: Int?) -> Void

    /// The weights the Crown steps through; empty unless the set is weight × reps.
    private let loads: [Double]
    @State private var weightIndex: Double
    @State private var reps: Double
    @State private var changedWeight = false
    @State private var changedReps = false
    /// The Crown starts on reps; the weight takes it once tapped.
    @State private var weightTapped = false
    @FocusState private var focus: Field?
    @Environment(\.dynamicTypeSize) private var typeSize

    private enum Field { case weight, reps }

    init(active: WatchState.Active, set: WatchSet, heartRate: Double?, waiting: Int,
         complete: @escaping (Double?, Int?) -> Void) {
        self.active = active
        self.set = set
        self.heartRate = heartRate
        self.waiting = waiting
        self.complete = complete
        let loads = active.loads[set.exerciseID.uuidString] ?? []
        self.loads = loads
        let start = set.weight.flatMap { weight in loads.firstIndex { $0 >= weight - 0.05 } } ?? 0
        _weightIndex = State(initialValue: Double(min(start, max(loads.count - 1, 0))))
        _reps = State(initialValue: Double(set.reps ?? 0))
    }

    private var weight: Double? {
        changedWeight && !loads.isEmpty ? loads[min(max(Int(weightIndex.rounded()), 0), loads.count - 1)] : set.weight
    }

    private var repCount: Int? { self.set.reps.map { _ in Int(reps.rounded()) } }

    private var canLog: Bool {
        if !loads.isEmpty { return weight != nil && (repCount ?? 0) >= 1 }
        if let repCount { return repCount >= 1 }
        return set.isLoggable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(set.exercise).font(.headline).foregroundStyle(WatchPalette.primaryText)
                        .accessibilityIdentifier("watch.exercise")
                    HStack(alignment: .firstTextBaseline) {
                        Text("Set \(set.number) of \(set.count)").font(.footnote.weight(.semibold))
                            .foregroundStyle(WatchPalette.textSecondary)
                            .accessibilityIdentifier("watch.setNumber")
                        Spacer(minLength: 4)
                        HeartRateView(bpm: heartRate)
                    }
                }
                values
                Button {
                    complete(changedWeight ? weight : nil, changedReps ? repCount : nil)
                } label: {
                    Label("Done", systemImage: "checkmark").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent).tint(WatchPalette.action).controlSize(.large)
                .disabled(!canLog)
                .accessibilityLabel("Done, log set \(set.number)")
                .accessibilityIdentifier("watch.done")
                WorkoutFooter(active: active, waiting: waiting)
            }
        }
        // Focus set once the fields are on screen reaches the Crown; a default focus only highlights.
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            if focus == nil, set.reps != nil { focus = .reps }
        }
    }

    @ViewBuilder
    private var values: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        layout {
            if !loads.isEmpty {
                field(.weight, value: weight.map(WatchFormat.load) ?? "–", unit: active.unit, label: "Weight")
                    .digitalCrownRotation($weightIndex, from: 0, through: Double(loads.count - 1), by: 1,
                                          sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    .onChange(of: weightIndex) { changedWeight = true }
            } else if set.reps != nil {
                // Bodyweight or assisted: the load is shown as planned, "BW" or "+10 kg".
                Text(set.values.components(separatedBy: " × ").first ?? set.values)
                    .font(.system(.title2, design: .rounded).weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
            }
            if set.reps != nil {
                if !typeSize.isAccessibilitySize {
                    Text("×").font(.title3.weight(.semibold)).foregroundStyle(WatchPalette.textSecondary).accessibilityHidden(true)
                }
                field(.reps, value: (repCount ?? 0) > 0 ? "\(repCount ?? 0)" : "–", unit: "reps", label: "Reps")
                    .digitalCrownRotation($reps, from: 0, through: 100, by: 1,
                                          sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    .onChange(of: reps) { changedReps = true }
            } else if loads.isEmpty {
                // Timed or distance sets show their values as planned.
                Text(set.values).font(.system(.title2, design: .rounded).weight(.bold))
                    .accessibilityLabel(set.spokenValues)
            }
        }
    }

    private func field(_ field: Field, value: String, unit: String, label: String) -> some View {
        let focused = focus == field
        return VStack(spacing: 0) {
            Text(value).font(.system(.title, design: .rounded).weight(.bold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5).contentTransition(.numericText())
            Text(unit).font(.caption2.weight(.semibold)).foregroundStyle(focused ? .white : WatchPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(focused ? WatchPalette.primary.opacity(0.35) : .white.opacity(0.08), in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(focused ? WatchPalette.primary : .clear, lineWidth: 2) }
        .focusable(field == .reps || weightTapped)
        .focusEffectDisabled()
        .focused($focus, equals: field)
        .onTapGesture {
            if field == .weight, !weightTapped {
                weightTapped = true
                Task { focus = .weight }
            } else {
                focus = field
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) \(unit)")
        .accessibilityAdjustableAction { direction in adjust(field, by: direction == .increment ? 1 : -1) }
        .accessibilityIdentifier(field == .weight ? "watch.weight" : "watch.reps")
    }

    private func adjust(_ field: Field, by step: Double) {
        switch field {
        case .weight: weightIndex = min(max(weightIndex + step, 0), Double(max(loads.count - 1, 0)))
        case .reps: reps = min(max(reps + step, 0), 100)
        }
    }
}

/// Sets done, time elapsed, and commands still waiting for the phone.
struct WorkoutFooter: View {
    let active: WatchState.Active
    let waiting: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("\(active.completedSets) of \(active.totalSets) sets")
                Text("·").accessibilityHidden(true)
                Text(active.startedAt, style: .timer).monospacedDigit()
            }
            if waiting > 0 {
                Label("Waiting for iPhone", systemImage: "iphone.slash").accessibilityIdentifier("watch.waiting")
            }
        }
        .font(.footnote).foregroundStyle(WatchPalette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
