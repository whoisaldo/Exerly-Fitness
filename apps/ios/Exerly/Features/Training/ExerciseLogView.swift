import ExerlyCore
import SwiftUI

struct ExerciseLogView: View {
    let store: TrainingStore
    let exerciseID: ExerciseID
    let unit: MassUnit
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        List {
            if let exercise = store.library.exercise(exerciseID) {
                if let stats = store.history.statistics(of: exerciseID) {
                    Section("All saved working sets") {
                        metric("Sets", value: String(stats.totalSets))
                        if let estimate = stats.estimatedOneRepMax {
                            metric("Best estimated 1RM", value: TrainingFormat.mass(estimate, unit: unit))
                        } else { Text("Estimated 1RM is unavailable for these sets.").foregroundStyle(.secondary) }
                        if !stats.isVolumeComplete {
                            Text("Bodyweight was missing from some sets. Volume is incomplete.").foregroundStyle(.secondary)
                        }
                        Text("Estimates depend on the logged load, reps and effort. Warm-ups are excluded.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                let records = store.history.sets(of: exerciseID)
                if records.isEmpty {
                    ContentUnavailableView("No working sets saved", systemImage: "dumbbell",
                                           description: Text("The source workouts may be missing from this device or may have been deleted."))
                } else {
                    Section("Completed working sets") {
                        ForEach(records.reversed(), id: \.set.id) { record in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(TrainingFormat.set(record.set, unit: unit)).font(.headline).monospacedDigit()
                                Text("\(TrainingFormat.kind(record.set.kind))\(record.set.side.map { " · " + $0.rawValue.capitalized } ?? "")")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                if let rir = record.set.rir {
                                    Text("\(rir == 6 ? "6+" : TrainingFormat.number(rir)) RIR")
                                } else { Text("RIR not recorded").foregroundStyle(.secondary) }
                                if let weight = record.bodyweight {
                                    Text("Bodyweight: \(TrainingFormat.mass(weight, unit: unit))")
                                } else { Text("Bodyweight not recorded").foregroundStyle(.secondary) }
                                if let session = store.history.session(record.sessionID) {
                                    NavigationLink {
                                        WorkoutDetailView(store: store, sessionID: session.id, unit: unit)
                                    } label: { Text("\(session.name) · \(TrainingFormat.date(session))") }
                                        .accessibilityIdentifier("exerciseLog.workout.\(session.id.uuidString)")
                                }
                            }.padding(.vertical, 6)
                        }
                    }
                }
                Section { Text(exercise.name).foregroundStyle(.secondary) }
            } else {
                ContentUnavailableView("Exercise unavailable", systemImage: "dumbbell",
                                       description: Text("This exercise is not in the saved library on this device."))
            }
        }
        .navigationTitle(store.library.exercise(exerciseID)?.name ?? "Exercise log")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(Color.exBackground)
    }

    @ViewBuilder
    private func metric(_ title: String, value: String) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                Text(value).foregroundStyle(.secondary).monospacedDigit()
            }
        } else { LabeledContent(title, value: value) }
    }
}
