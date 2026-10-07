import SwiftUI
import ExerlyCore

enum TrainingSetInputError: Error { case invalid(String) }

struct EffortFields: Identifiable {
    let id = UUID()
    let original: Effort
    let initialLoad: String
    let initialDuration: String
    let initialDistance: String
    var reps: String
    var load: String
    var duration: String
    var distance: String

    init(_ effort: Effort, unit: MassUnit) {
        original = effort
        initialLoad = effort.load.map { TrainingFormat.number($0.value(in: unit)) } ?? ""
        initialDuration = effort.duration.map(TrainingFormat.number) ?? ""
        initialDistance = effort.distance.map(TrainingFormat.number) ?? ""
        reps = effort.reps.map(String.init) ?? ""
        load = initialLoad
        duration = initialDuration
        distance = initialDistance
    }

    func value(for metric: TrackingMetric, unit: MassUnit) throws -> Effort {
        var effort = Effort()
        if metric.tracksReps && !reps.isEmpty {
            guard let value = TrainingInput.reps(reps) else {
                throw TrainingSetInputError.invalid("Enter a whole number of reps.")
            }
            effort.reps = value
        }
        if metric.tracksLoad {
            effort.load = load == initialLoad ? original.load : try parse(load, label: "weight").map { Mass($0, unit) }
        }
        if metric.tracksDuration {
            effort.duration = duration == initialDuration ? original.duration : try parse(duration, label: "duration")
        }
        if metric.tracksDistance {
            effort.distance = distance == initialDistance ? original.distance : try parse(distance, label: "distance")
        }
        return effort
    }

    private func parse(_ text: String, label: String) throws -> Double? {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        guard let value = TrainingInput.number(text) else { throw TrainingSetInputError.invalid("Enter a valid \(label).") }
        return value
    }
}

struct TrainingSetEditor: View {
    let exercise: ExerlyCore.Exercise
    let original: PerformedSet
    let number: Int
    let unit: MassUnit
    let onSave: (PerformedSet, Bool) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var efforts: [EffortFields]
    @State private var kind: SetKind
    @State private var rir: Double?
    @State private var side: Side?
    @State private var propagate = false
    @State private var error: String?
    @FocusState private var editing: Bool

    init(exercise: ExerlyCore.Exercise, original: PerformedSet, number: Int, unit: MassUnit,
         onSave: @escaping (PerformedSet, Bool) throws -> Void) {
        self.exercise = exercise; self.original = original; self.number = number; self.unit = unit; self.onSave = onSave
        _efforts = State(initialValue: original.efforts.map { EffortFields($0, unit: unit) })
        _kind = State(initialValue: original.kind)
        _rir = State(initialValue: original.rir)
        _side = State(initialValue: original.side)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(exercise.name).font(.headline)
                    Picker("Set type", selection: $kind) {
                        ForEach(SetKind.allCases, id: \.self) { Text(TrainingFormat.kind($0)).tag($0) }
                    }
                    if exercise.laterality == .unilateral {
                        Picker("Side", selection: $side) {
                            Text("Left").tag(Optional(Side.left))
                            Text("Right").tag(Optional(Side.right))
                        }
                    }
                }
                ForEach(Array(efforts.enumerated()), id: \.element.id) { index, effort in
                    Section(index == 0 ? "Set values" : "Continuation \(index)") {
                        if exercise.metric.tracksLoad {
                            numericField(loadLabel, text: $efforts[index].load, id: "training.load.\(index)")
                        }
                        if exercise.metric.tracksReps {
                            numericField("Reps", text: $efforts[index].reps, id: "training.reps.\(index)", integer: true)
                        }
                        if exercise.metric.tracksDuration {
                            numericField("Duration (seconds)", text: $efforts[index].duration, id: "training.duration.\(index)")
                        }
                        if exercise.metric.tracksDistance {
                            numericField("Distance (metres)", text: $efforts[index].distance, id: "training.distance.\(index)")
                        }
                        if index > 0 {
                            Button("Remove continuation", role: .destructive) { efforts.removeAll { $0.id == effort.id } }
                        }
                    }
                }
                if kind.allowsContinuations {
                    Button("Add continuation", systemImage: "plus") { efforts.append(EffortFields(Effort(), unit: unit)) }
                }
                Section {
                    Picker("Reps in reserve", selection: $rir) {
                        Text("Not recorded").tag(Double?.none)
                        ForEach(0...6, id: \.self) { Text($0 == 6 ? "6+" : String($0)).tag(Optional(Double($0))) }
                    }
                    Toggle("Apply edits to matching later sets", isOn: $propagate)
                } footer: {
                    Text("Reps in reserve (RIR) estimates how many more reps you could do. Later incomplete sets are updated only when their old values match.")
                }
                if let error { Text(error).foregroundStyle(Color.exError).accessibilityIdentifier("training.setError") }
            }
            .navigationTitle("Set \(number)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save set") { save() }.fontWeight(.semibold).accessibilityIdentifier("training.saveSet")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } }
            }
            .onChange(of: kind) { old, new in
                if !new.allowsContinuations && efforts.count > 1 {
                    kind = old
                    error = "Remove the continuation efforts before choosing this set type."
                }
            }
        }
    }

    private var loadLabel: String {
        let suffix = unit == .kilograms ? "kg" : "lb"
        if exercise.metric == .assistedReps { return "Assistance (\(suffix))" }
        if exercise.metric == .bodyweightReps { return "Added weight (\(suffix)), optional" }
        return "Weight (\(suffix))"
    }

    private func numericField(_ label: String, text: Binding<String>, id: String, integer: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            TextField(label, text: text).keyboardType(integer ? .numberPad : .decimalPad)
                .focused($editing).monospacedDigit().accessibilityIdentifier(id)
                .frame(minHeight: 44)
        }
    }

    private func save() {
        do {
            var set = original
            set.kind = kind; set.rir = rir; set.side = side
            set.efforts = try efforts.map { try $0.value(for: exercise.metric, unit: unit) }
            if set.isCompleted && !set.isLoggable(for: exercise) {
                throw TrainingSetInputError.invalid("A completed set needs valid values. Reopen the set before clearing them.")
            }
            try onSave(set, propagate)
            dismiss()
        } catch let TrainingSetInputError.invalid(message) { error = message }
        catch { self.error = TrainingFormat.error(error) }
    }

}
