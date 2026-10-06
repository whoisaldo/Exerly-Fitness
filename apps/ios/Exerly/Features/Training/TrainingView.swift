import SwiftUI
import ExerlyCore

struct TrainingHostView: View {
    let accountID: String
    let unit: MassUnit
    let timeZone: TimeZone
    @EnvironmentObject private var account: AppAccountWorkspace
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            if let workspace = account.training, workspace.accountID == accountID {
                TrainingView(store: workspace.store, unit: unit, timeZone: timeZone,
                             unreadableCount: workspace.unreadableCount)
                    .onChange(of: workspace.store.activeSession?.id) { _, _ in
                        Task { await workspace.synchronize() }
                    }
            } else if account.openingError != nil {
                ContentUnavailableView {
                    Label("Training could not open", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved data is still on this device. Keep Exerly installed and try again.")
                } actions: {
                    Button("Try again") { Task { await account.configure(auth.accountAPI) } }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView("Opening training…")
            }
        }
    }
}

struct TrainingView: View {
    let store: TrainingStore
    let unit: MassUnit
    let timeZone: TimeZone
    let unreadableCount: Int
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var starting = false
    @State private var browsing = false

    var body: some View {
        Group {
            if let session = store.activeSession {
                ActiveWorkoutView(store: store, session: session, unit: unit)
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("No workout in progress").font(.title2.weight(.semibold))
                            Text("Log a workout at your own pace. Sets are saved as you go, even offline.")
                                .foregroundStyle(.secondary)
                            Button { starting = true } label: {
                                if typeSize.isAccessibilitySize {
                                    Text("Start workout").fixedSize(horizontal: false, vertical: true)
                                } else { Label("Start workout", systemImage: "plus") }
                            }
                                .buttonStyle(.borderedProminent).controlSize(.large)
                                .accessibilityIdentifier("training.start")
                        }.padding(.vertical, 8)
                    }
                    Section {
                        Button("Exercise library", systemImage: "dumbbell") { browsing = true }
                            .frame(minHeight: 44)
                        NavigationLink {
                            WorkoutHistoryView(store: store, unit: unit)
                        } label: { Label("Workout history", systemImage: "clock.arrow.circlepath") }
                    }
                    if let session = store.history.sessions.last {
                        Section("Last workout") {
                            NavigationLink {
                                WorkoutDetailView(store: store, sessionID: session.id, unit: unit)
                            } label: { WorkoutHistoryRow(session: session, library: store.library) }
                        }
                    }
                    Section {
                        Label("Workouts save on this device and sync with your account when connected.", systemImage: "icloud")
                            .font(.footnote).foregroundStyle(.secondary)
                        if unreadableCount > 0 {
                            Label("Some saved entries could not be read. They have been kept for recovery. Contact support before reinstalling.", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(Color.exWarning)
                        }
                    }
                }
                .navigationTitle("Training")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.exBackground)
        .sheet(isPresented: $starting) {
            NewWorkoutView(store: store, unit: unit, timeZone: timeZone)
        }
        .sheet(isPresented: $browsing) {
            ExercisePickerView(store: store, onSelect: nil)
        }
    }
}

private struct NewWorkoutView: View {
    let store: TrainingStore
    let unit: MassUnit
    let timeZone: TimeZone
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Workout"
    @State private var bodyweight = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout name", text: $name).accessibilityIdentifier("training.name")
                    TextField("Bodyweight (\(unit == .kilograms ? "kg" : "lb"), optional)", text: $bodyweight)
                        .keyboardType(.decimalPad)
                } footer: { Text("Bodyweight helps calculate volume for bodyweight exercises. You can log without it.") }
                if let error { Text(error).foregroundStyle(Color.exError) }
            }
            .navigationTitle("New workout").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { start() }.fontWeight(.semibold)
                        .accessibilityIdentifier("training.confirmStart")
                }
            }
        }
    }

    private func start() {
        let weight: Mass?
        if bodyweight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { weight = nil }
        else if let value = TrainingInput.number(bodyweight), value > 0 { weight = Mass(value, unit) }
        else { error = "Enter a bodyweight greater than zero, or leave it empty."; return }
        do {
            let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
            try store.startSession(name: title.isEmpty ? "Workout" : title, bodyweight: weight, timeZone: timeZone)
            dismiss()
        } catch { self.error = TrainingFormat.error(error) }
    }
}

struct ExercisePickerView: View {
    let store: TrainingStore
    let onSelect: ((ExerlyCore.Exercise) throws -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var muscle: Muscle?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Target muscle", selection: $muscle) {
                        Text("All muscles").tag(Muscle?.none)
                        ForEach(Muscle.allCases, id: \.self) { Text($0.name).tag(Optional($0)) }
                    }
                }
                let matches = store.library.search(query, muscle: muscle)
                if matches.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(matches) { exercise in
                        if onSelect != nil {
                            Button {
                                do { try onSelect?(exercise); dismiss() }
                                catch { self.error = TrainingFormat.error(error) }
                            } label: { ExerciseLibraryRow(exercise: exercise) }
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Add \(exercise.name)")
                        } else {
                            NavigationLink {
                                ExerciseInformationView(exercise: exercise)
                            } label: { ExerciseLibraryRow(exercise: exercise) }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search exercises")
            .navigationTitle(onSelect == nil ? "Exercises" : "Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .alert("Could not add exercise", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}

private struct ExerciseLibraryRow: View {
    let exercise: ExerlyCore.Exercise
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(exercise.name).font(.body.weight(.medium))
            Text(exercise.targetMuscles.map(\.name).joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary)
            Text(exercise.equipment.map { TrainingFormat.words($0.rawValue) }.joined(separator: ", "))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 5).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

private struct ExerciseInformationView: View {
    let exercise: ExerlyCore.Exercise
    var body: some View {
        List {
            Section("Target muscles") { Text(exercise.targetMuscles.map(\.name).joined(separator: ", ")) }
            if !exercise.synergistMuscles.isEmpty {
                Section("Assisting muscles") { Text(exercise.synergistMuscles.map(\.name).joined(separator: ", ")) }
            }
            Section("Equipment") {
                ForEach(exercise.equipment + exercise.support, id: \.self) { Text(TrainingFormat.words($0.rawValue)) }
            }
            Section("Movement") {
                LabeledContent("Laterality", value: TrainingFormat.words(exercise.laterality.rawValue))
                LabeledContent("Tracking", value: TrainingFormat.words(exercise.metric.rawValue))
                ForEach(exercise.actions, id: \.self) { Text(TrainingFormat.words($0.rawValue)) }
            }
        }.navigationTitle(exercise.name).navigationBarTitleDisplayMode(.inline)
    }
}
