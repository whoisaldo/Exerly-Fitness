import SwiftUI
import ExerlyCore

private struct SetEditorTarget: Identifiable {
    let performedID: UUID
    let exercise: ExerlyCore.Exercise
    let set: PerformedSet
    let number: Int
    var id: UUID { self.set.id }
}

struct ActiveWorkoutView: View {
    let store: TrainingStore
    let session: WorkoutSession
    let unit: MassUnit
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var adding = false
    @State private var editing: SetEditorTarget?
    @State private var details = false
    @State private var finishing = false
    @State private var discarding = false
    @State private var error: String?

    var body: some View {
        ExList {
            Section {
                ExCard(accent: true) {
                    HStack {
                        ExEyebrow("Session in progress", color: .exPrimary)
                        Spacer()
                        Text(session.startedAt, style: .timer).font(.exMono).foregroundStyle(Color.exTextSecondary)
                            .accessibilityLabel("Workout elapsed time")
                    }
                    let sets = session.exercises.flatMap(\.sets)
                    let completed = sets.filter(\.isCompleted).count
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(completed)").font(.exStatMedium)
                        Text("of \(sets.count) \(sets.count == 1 ? "set" : "sets") complete").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                        Spacer()
                        Button("Workout details", systemImage: "note.text") { details = true }
                            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    }
                    ExProgressBar(value: Double(completed), total: Double(sets.count))
                    if !session.notes.isEmpty { Text(session.notes).font(.exCaption).foregroundStyle(Color.exTextSecondary) }
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Color.exError) }
            }
            ForEach(session.exercises) { performed in
                if let exercise = store.library.exercise(performed.exerciseID) {
                    Section {
                        ForEach(Array(performed.sets.enumerated()), id: \.element.id) { index, set in
                            let previous = store.previousSets(for: performed.id)
                            TrainingSetRow(set: set, number: index + 1, exercise: exercise, unit: unit,
                                           previous: previous.indices.contains(index) ? previous[index] : nil,
                                           edit: { editing = SetEditorTarget(performedID: performed.id, exercise: exercise, set: set, number: index + 1) },
                                           complete: {
                                if set.isCompleted { save { try store.reopenSet(set.id) } }
                                else if set.isLoggable(for: exercise) {
                                    save { try store.completeSet(set.id) }
                                    if error == nil { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                                }
                                else { editing = SetEditorTarget(performedID: performed.id, exercise: exercise, set: set, number: index + 1) }
                            })
                            .swipeActions { Button("Delete set", role: .destructive) { save { try store.removeSet(set.id) } } }
                        }
                        Button("Add set", systemImage: "plus") { save { try store.addSet(to: performed.id) } }
                            .frame(minHeight: 44).accessibilityLabel("Add set to \(exercise.name)")
                    } header: {
                        Text(exercise.name).font(.headline).textCase(nil).foregroundStyle(.primary)
                    } footer: {
                        if !performed.notes.isEmpty { Text(performed.notes) }
                    }
                }
            }
            if typeSize.isAccessibilitySize, let timer = store.restTimer {
                Section("Rest") { restControls(timer) }
            }
            Section {
                Button("Add exercise", systemImage: "plus") { adding = true }.frame(minHeight: 44)
                    .accessibilityIdentifier("training.addExercise")
            }
            Section {
                Button("Discard workout", role: .destructive) { discarding = true }.frame(minHeight: 44)
            }
        }
        .exListStyle()
        .navigationTitle(session.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Finish") { finishing = true }.fontWeight(.semibold)
                    .accessibilityIdentifier("training.finish")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize, let timer = store.restTimer {
                restControls(timer)
            }
        }
        .sheet(isPresented: $adding) {
            ExercisePickerView(store: store) { exercise in try store.addExercise(exercise.id) }
        }
        .sheet(item: $editing) { target in
            TrainingSetEditor(exercise: target.exercise, original: target.set, number: target.number, unit: unit) { updated, propagate in
                try store.updateSet(updated, in: target.performedID, propagate: propagate)
            }
        }
        .sheet(isPresented: $details) { WorkoutNotesView(store: store, session: session, unit: unit) }
        .confirmationDialog("Finish this workout?", isPresented: $finishing, titleVisibility: .visible) {
            Button("Save workout") {
                save { try store.finishSession() }
                if error == nil { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            }
        } message: { Text("Completed sets will be saved in history. Uncompleted sets will be removed.") }
        .confirmationDialog("Discard this workout?", isPresented: $discarding, titleVisibility: .visible) {
            Button("Discard workout", role: .destructive) { save { try store.discardSession() } }
        } message: { Text("This removes the workout and all of its sets from this device.") }
    }

    private func save<T>(_ action: () throws -> T) {
        do { _ = try action(); error = nil }
        catch { self.error = TrainingFormat.error(error) }
    }

    private func restControls(_ timer: RestTimer) -> some View {
        RestTimerView(timer: timer, extend: { save { try store.extendRest(by: 30) } },
                      skip: { save { try store.skipRest() } })
    }
}

struct TrainingSetRow: View {
    let set: PerformedSet
    let number: Int
    let exercise: ExerlyCore.Exercise
    let unit: MassUnit
    let previous: PerformedSet?
    let edit: () -> Void
    let complete: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            Button(action: edit) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Set \(number) · \(TrainingFormat.kind(set.kind))\(set.side.map { " · " + $0.rawValue.capitalized } ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(TrainingFormat.set(set, unit: unit)).font(.exStatSmall)
                        .foregroundStyle(.primary)
                    if let rir = set.rir {
                        Text("\(rir == 6 ? "6+" : TrainingFormat.number(rir)) RIR").font(.caption).foregroundStyle(.secondary)
                    }
                    if let previous {
                        Text("Previous: \(TrainingFormat.set(previous, unit: unit))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit set \(number), \(exercise.name)")
            .accessibilityValue(TrainingFormat.set(set, unit: unit))
            Button(action: complete) {
                Label(set.isCompleted ? "Done" : "Log set", systemImage: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.medium))
                    .labelStyle(.titleAndIcon)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .background(Color.exPrimary.opacity(set.isCompleted ? 0.15 : 0.06), in: RoundedRectangle(cornerRadius: ExRadius.control))
            .tint(Color.exPrimary)
            .accessibilityLabel("\(set.isCompleted ? "Reopen" : "Complete") set \(number), \(exercise.name)")
        }.padding(.vertical, 4)
    }
}

private struct RestTimerView: View {
    let timer: RestTimer
    let extend: () -> Void
    let skip: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
            layout {
                HStack {
                    Image(systemName: "timer").accessibilityHidden(true)
                    if timer.isFinished(at: context.date) { Text("Rest complete").fontWeight(.semibold) }
                    else {
                        Text("Rest")
                        Text(timer.endsAt, style: .timer).monospacedDigit().fontWeight(.semibold)
                    }
                }.accessibilityElement(children: .combine)
                HStack {
                    Button("+30 s", action: extend).accessibilityLabel("Add 30 seconds of rest")
                    Button("Skip", action: skip).accessibilityLabel("Skip rest")
                }.buttonStyle(.bordered).controlSize(.regular)
            }.padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
        }
    }
}

private struct WorkoutNotesView: View {
    let store: TrainingStore
    let session: WorkoutSession
    let unit: MassUnit
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var notes = ""
    @State private var weight = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ExScreen {
                ExCard(accent: true) {
                    ExEyebrow("This session", color: .exPrimary)
                    TextField("Workout name", text: $name).font(.exH2)
                    NutritionNumberInput(title: "Bodyweight (\(unit == .kilograms ? "kg" : "lb"), optional)", text: $weight)
                }
                ExCard {
                    ExSectionHeading("Workout notes")
                    TextField("Workout notes", text: $notes, axis: .vertical).lineLimit(3...8)
                }
                if let error { Text(error).foregroundStyle(Color.exError) }
            }
            .navigationTitle("Workout details").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear {
                name = session.name; notes = session.notes
                weight = session.bodyweight.map { TrainingFormat.number($0.value(in: unit)) } ?? ""
            }
        }
    }

    private func save() {
        let mass: Mass?
        if weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { mass = nil }
        else if let value = TrainingInput.number(weight), value > 0 { mass = Mass(value, unit) }
        else { error = "Enter a bodyweight greater than zero, or leave it empty."; return }
        do {
            try store.updateActiveSession {
                $0.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Workout" : name
                $0.notes = notes
                $0.bodyweight = mass
            }
            dismiss()
        } catch { self.error = TrainingFormat.error(error) }
    }
}
