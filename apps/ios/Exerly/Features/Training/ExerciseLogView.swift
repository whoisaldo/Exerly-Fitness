import ExerlyCore
import SwiftUI

struct ExerciseLogView: View {
    let store: TrainingStore
    let exerciseID: ExerciseID
    let unit: MassUnit
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ExList {
            if let exercise = store.library.exercise(exerciseID) {
                if let stats = store.history.statistics(of: exerciseID) {
                    Section {
                        ExCard(accent: true) {
                        ExEyebrow("All saved working sets", color: .exPrimaryText)
                        metric("Sets", value: String(stats.totalSets))
                        if let estimate = stats.estimatedOneRepMax {
                            metric("Best estimated 1RM", value: TrainingFormat.mass(estimate, unit: unit))
                        } else { Text("Estimated 1RM is unavailable for these sets.").foregroundStyle(.secondary) }
                        if !stats.isVolumeComplete {
                            Text("Bodyweight was missing from some sets. Volume is incomplete.").foregroundStyle(.secondary)
                        }
                        Text("Estimates depend on the logged load, reps and effort. Warm-ups are excluded.")
                            .font(.footnote).foregroundStyle(.secondary)
                        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
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
                                Text(TrainingFormat.set(record.set, unit: unit)).font(.exStatSmall)
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
        .exListStyle()
    }

    @ViewBuilder
    private func metric(_ title: String, value: String) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                Text(value).foregroundStyle(.secondary).font(.exStatSmall)
            }
        } else { LabeledContent(title, value: value) }
    }
}
