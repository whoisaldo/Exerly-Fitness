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
                             unreadableCount: workspace.unreadableCount, workspace: workspace)
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
                        .buttonStyle(.borderedProminent).tint(Color.exActionFill)
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
    var workspace: TrainingWorkspace?
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var starting = false
    @State private var browsing = false
    @State private var reviewingPlan = false
    @State private var buildingPlan = false

    var body: some View {
        Group {
            if let session = store.activeSession {
                ActiveWorkoutView(store: store, session: session, unit: unit, gym: workspace?.gyms.active)
            } else {
                ExScreen {
                    if let workspace, workspace.programs.active != nil {
                        NextTrainingWorkoutSection(workspace: workspace) { reviewingPlan = true }
                        Button("Start a different workout", systemImage: "plus") { starting = true }
                            .buttonStyle(ExActionStyle(secondary: true)).accessibilityIdentifier("training.start")
                    } else if workspace != nil {
                        ExEmptyState(icon: "dumbbell", title: "Your first workout starts here",
                                     message: "Tell us your goal, time and equipment. Review a plan built around your answers.",
                                     action: "Build my workout plan", actionID: "planSetup.open") { buildingPlan = true }
                        Button("Start a workout yourself", systemImage: "plus") { starting = true }
                            .buttonStyle(ExActionStyle(secondary: true)).accessibilityIdentifier("training.start")
                    } else {
                        ExEmptyState(icon: "dumbbell", title: "No workout planned",
                                     message: "Choose your exercises. Your last sets will be ready to log again.", action: "Start workout", actionID: "training.start") {
                            starting = true
                        }
                    }
                    if let session = store.history.sessions.last {
                        VStack(alignment: .leading, spacing: ExSpacing.item) {
                            ExSectionHeading("Last session")
                            NavigationLink {
                                WorkoutDetailView(store: store, sessionID: session.id, unit: unit)
                            } label: {
                                ExCard {
                                    WorkoutHistoryRow(session: session, library: store.library)
                                        .foregroundStyle(Color.exTextPrimary)
                                    let summary = store.summary(of: session)
                                    Text("\(summary.workingSets) \(summary.workingSets == 1 ? "working set" : "working sets") · \(summary.tonnage.total(in: unit).formatted(.number.precision(.fractionLength(0)))) \(unit == .kilograms ? "kg" : "lb")·reps")
                                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                                    if !summary.tonnage.isComplete {
                                        Text("Volume excludes unrecorded bodyweight").font(.exSmall).foregroundStyle(Color.exTextMuted)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                    if let workspace {
                        VStack(alignment: .leading, spacing: ExSpacing.item) {
                            ExSectionHeading("Your training")
                            ExCard {
                                NavigationLink {
                                    TrainingProgramsView(workspace: workspace, unit: unit, timeZone: timeZone)
                                } label: { ExNavigationLabel(title: "Programs", icon: "square.stack.3d.up", detail: "Plan the next session") }
                                    .accessibilityIdentifier("programs.open")
                                Divider().overlay(Color.exBorder.opacity(0.3))
                                NavigationLink {
                                    TrainingGymsView(workspace: workspace, unit: unit)
                                } label: { ExNavigationLabel(title: "Gyms & equipment", icon: "building.2", detail: workspace.gyms.active?.name ?? "Use the weights you have") }
                                    .accessibilityIdentifier("gyms.open")
                                NavigationLink {
                                    AgentReviewView(workspace: workspace, unit: unit)
                                } label: { ExNavigationLabel(title: "Suggestions", icon: "tray", detail: "Review changes from your agents") }
                                    .accessibilityIdentifier("suggestions.open")
                                NavigationLink {
                                    TrainingObservationsView(workspace: workspace, unit: unit, timeZone: timeZone)
                                } label: { ExNavigationLabel(title: "Observations", icon: "chart.xyaxis.line", detail: "Patterns in your completed sets") }
                                    .accessibilityIdentifier("observations.open")
                            }
                        }
                    }
                    ExCard {
                        Button { browsing = true } label: { ExNavigationLabel(title: "Exercise library", icon: "dumbbell") }
                            .accessibilityLabel("Exercise library")
                        NavigationLink {
                            WorkoutHistoryView(store: store, unit: unit)
                        } label: { ExNavigationLabel(title: "Workout history", icon: "clock.arrow.circlepath") }
                    }
                    if unreadableCount > 0 {
                        Label("Some saved entries could not be read. They have been kept for recovery. Contact support before reinstalling.",
                              systemImage: "exclamationmark.triangle").font(.exCaption).foregroundStyle(Color.exWarning)
                    }
                }
                .navigationTitle("Training").navigationBarTitleDisplayMode(.inline)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.exBackground)
        .sheet(isPresented: $starting) {
            NewWorkoutView(store: store, unit: unit, timeZone: timeZone)
        }
        .sheet(isPresented: $browsing) {
            ExercisePickerView(store: store, onSelect: nil, gym: workspace?.gyms.active)
        }
        .sheet(isPresented: $reviewingPlan) {
            if let workspace { PlannedWorkoutView(workspace: workspace, unit: unit, timeZone: timeZone) }
        }
        .sheet(isPresented: $buildingPlan) {
            if let workspace { TrainingPlanSetupView(workspace: workspace, unit: unit) }
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
            ExScreen {
                ExCard(accent: true) {
                    ExEyebrow("Session name", color: .exPrimaryText)
                    TextField("Workout name", text: $name).font(.exH2).accessibilityIdentifier("training.name")
                    Text("Add exercises after you start. Each set saves as you go.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
                ExCard {
                    NutritionNumberInput(title: "Bodyweight (\(unit == .kilograms ? "kg" : "lb"), optional)", text: $bodyweight)
                    Text("Used for bodyweight exercise volume. You can leave this blank.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
                if let error { Text(error).foregroundStyle(Color.exError) }
                Button("Start workout") { start() }.buttonStyle(ExActionStyle())
                    .accessibilityIdentifier("training.confirmStart")
            }
            .navigationTitle("New workout").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }

    private func start() {
        let weight: Mass?
        if bodyweight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { weight = nil } else if let value = TrainingInput.number(bodyweight), value > 0 { weight = Mass(value, unit) } else { error = "Enter a bodyweight greater than zero, or leave it empty."; return }
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
    var gym: GymProfile?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var muscle: Muscle?
    @State private var error: String?
    @State private var useGym = true

    var body: some View {
        NavigationStack {
            ExList {
                Section {
                    VStack(alignment: .leading, spacing: ExSpacing.small) {
                        ExEyebrow("Exercise library", color: .exPrimaryText)
                        Text(onSelect == nil ? "Know your movements" : "Choose your next exercise").font(.exH2)
                    }.padding(.vertical, ExSpacing.small)
                }.listRowBackground(Color.clear)
                Section {
                    if let gym {
                        VStack(alignment: .leading, spacing: ExSpacing.small) {
                            Text(gym.name).font(.exLabel).foregroundStyle(Color.exTextSecondary)
                            ExChoiceChips(values: [true, false], selection: $useGym) { $0 ? "At this gym" : "All exercises" }
                        }.padding(.vertical, ExSpacing.small)
                    }
                    Picker("Target muscle", selection: $muscle) {
                        Text("All muscles").tag(Muscle?.none)
                        ForEach(Muscle.allCases, id: \.self) { Text($0.name).tag(Optional($0)) }
                    }
                }
                let matches = store.library.search(query, muscle: muscle).filter { !useGym || gym?.allows($0) != false }
                if matches.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(matches) { exercise in
                        if onSelect != nil {
                            Button {
                                do { try onSelect?(exercise); dismiss() } catch { self.error = TrainingFormat.error(error) }
                            } label: { ExerciseLibraryRow(exercise: exercise) }
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Add \(exercise.name)")
                        } else {
                            NavigationLink {
                                ExerciseGuideView(exercise: exercise)
                            } label: { ExerciseLibraryRow(exercise: exercise) }
                        }
                    }
                }
            }
            .exListStyle()
            .searchable(text: $query, prompt: "Search exercises")
            .modifier(ExerciseSearchToolbar())
            .onSubmit(of: .search) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .navigationTitle(onSelect == nil ? "Exercises" : "Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.accessibilityIdentifier("training.exerciseClose")
                }
            }
            .alert("Could not add exercise", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}

private struct ExerciseSearchToolbar: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.1, *) {
            content.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            content
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
