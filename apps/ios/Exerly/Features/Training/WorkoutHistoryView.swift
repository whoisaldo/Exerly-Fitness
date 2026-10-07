import SwiftUI
import ExerlyCore

struct WorkoutHistoryView: View {
    let store: TrainingStore
    let unit: MassUnit

    var body: some View {
        List {
            if store.history.sessions.isEmpty {
                ContentUnavailableView("No workouts yet", systemImage: "dumbbell",
                                       description: Text("Finished workouts appear here, with every completed set."))
            }
            ForEach(store.history.sessions.reversed()) { session in
                NavigationLink {
                    WorkoutDetailView(store: store, sessionID: session.id, unit: unit)
                } label: { WorkoutHistoryRow(session: session, library: store.library) }
            }
        }.navigationTitle("Workout history")
    }
}

struct WorkoutHistoryRow: View {
    let session: WorkoutSession
    let library: ExerlyCore.ExerciseLibrary
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.name).font(.headline)
            Text(TrainingFormat.date(session)).font(.subheadline).foregroundStyle(.secondary)
            Text(session.exercises.compactMap { library.exercise($0.exerciseID)?.name }.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 5)
    }
}

struct WorkoutDetailView: View {
    let store: TrainingStore
    let sessionID: UUID
    let unit: MassUnit
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        Group {
            if let session = store.history.session(sessionID) {
                List {
                    Section {
                        Text(TrainingFormat.date(session))
                        Text(session.timeZoneID).font(.caption).foregroundStyle(.secondary)
                        let summary = store.summary(of: session)
                        LabeledContent("Working sets", value: String(summary.workingSets))
                        LabeledContent("Volume", value: "\(TrainingFormat.number(summary.tonnage.total(in: unit))) \(unit == .kilograms ? "kg" : "lb")·reps")
                        if !summary.tonnage.isComplete {
                            Text("Volume is incomplete because bodyweight was not recorded.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if let duration = session.duration {
                            LabeledContent("Duration", value: Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond)))
                        }
                        if let weight = session.bodyweight { LabeledContent("Bodyweight", value: TrainingFormat.mass(weight, unit: unit)) }
                        if !session.notes.isEmpty { Text(session.notes) }
                    }
                    ForEach(session.exercises) { performed in
                        if let exercise = store.library.exercise(performed.exerciseID) {
                            Section(exercise.name) {
                                ForEach(Array(performed.sets.enumerated()), id: \.element.id) { index, set in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Set \(index + 1) · \(TrainingFormat.kind(set.kind))\(set.side.map { " · " + $0.rawValue.capitalized } ?? "")")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text(TrainingFormat.set(set, unit: unit)).monospacedDigit()
                                        if let rir = set.rir { Text("\(rir == 6 ? "6+" : TrainingFormat.number(rir)) RIR").font(.caption) }
                                    }.padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    if let error { Text(error).foregroundStyle(Color.exError) }
                    Section {
                        Button("Delete workout", role: .destructive) { deleting = true }.frame(minHeight: 44)
                    }
                }.navigationTitle(session.name).navigationBarTitleDisplayMode(.inline)
            } else { ContentUnavailableView("Workout not found", systemImage: "dumbbell") }
        }
        .confirmationDialog("Delete this workout?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) {
                do { try store.deleteSession(sessionID); dismiss() }
                catch { self.error = TrainingFormat.error(error) }
            }
        } message: { Text("This removes the workout and its sets from your training history.") }
    }
}
