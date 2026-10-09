import SwiftUI
import ExerlyCore

struct WorkoutHistoryView: View {
    let store: TrainingStore
    let unit: MassUnit
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ExList {
            if store.history.sessions.isEmpty {
                ExEmptyState(icon: "dumbbell", title: "Your training, recorded",
                             message: "Finish a session to see every set here, ready to compare next time.", action: "Back to Training") {
                    dismiss()
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            if !store.history.sessions.isEmpty {
                Section {
                    ExCard(accent: true) {
                        ExEyebrow("Training history", color: .exPrimaryText)
                        Text("\(store.history.sessions.count) sessions").font(.exH1)
                        Text("Every completed set, in one place.").font(.exBody).foregroundStyle(Color.exTextSecondary)
                    }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
            }
            ForEach(store.history.sessions.reversed()) { session in
                NavigationLink {
                    WorkoutDetailView(store: store, sessionID: session.id, unit: unit)
                } label: { WorkoutHistoryRow(session: session, library: store.library) }
            }
        }.exListStyle().navigationTitle("Workout history").navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkoutHistoryRow: View {
    let session: WorkoutSession
    let library: ExerlyCore.ExerciseLibrary
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.name).font(.exH3)
            Text(TrainingFormat.date(session)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            Text(session.exercises.compactMap { library.exercise($0.exerciseID)?.name }.joined(separator: " · "))
                .font(.exCaption).foregroundStyle(Color.exTextSecondary)
        }.padding(.vertical, 5)
    }
}

struct WorkoutDetailView: View {
    let store: TrainingStore
    let sessionID: UUID
    let unit: MassUnit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accountTimeZone) private var accountTimeZone
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        Group {
            if let session = store.history.session(sessionID) {
                ExList {
                    Section {
                        ExCard(accent: true) {
                        ExEyebrow("Completed session", color: .exPrimaryText)
                        Text(session.name).font(.exH2)
                        Text(TrainingFormat.date(session))
                        if let zone = TrainingFormat.zoneNote(session.timeZone, account: accountTimeZone) {
                            Text(zone).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                        }
                        let summary = store.summary(of: session)
                        LabeledContent("Working sets", value: String(summary.workingSets))
                        LabeledContent("Volume", value: TrainingFormat.volume(summary.tonnage, unit: unit))
                        if !summary.tonnage.isComplete {
                            Text("Volume is incomplete because bodyweight was not recorded.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if let duration = session.duration {
                            LabeledContent("Duration", value: TrainingFormat.minutes(duration))
                        }
                        if let weight = session.bodyweight { LabeledContent("Bodyweight", value: TrainingFormat.mass(weight, unit: unit)) }
                        if !session.notes.isEmpty { Text(session.notes) }
                        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    }
                    ForEach(session.exercises) { performed in
                        if let exercise = store.library.exercise(performed.exerciseID) {
                            Section(exercise.name) {
                                ForEach(Array(performed.sets.enumerated()), id: \.element.id) { index, set in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Set \(index + 1) · \(TrainingFormat.kind(set.kind))\(set.side.map { " · " + $0.rawValue.capitalized } ?? "")")
                                            .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                                        Text(TrainingFormat.set(set, unit: unit)).font(.exStatSmall)
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
                do { try store.deleteSession(sessionID); dismiss() } catch { self.error = TrainingFormat.error(error) }
            }
        } message: { Text("This removes the workout and its sets from your training history.") }
    }
}
