import ExerlyCore
import SwiftUI

struct PlannedWorkoutView: View {
    let workspace: TrainingWorkspace
    let unit: MassUnit
    let timeZone: TimeZone
    @State private var plan: WorkoutPlan?
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ExList {
                if workspace.store.activeSession != nil {
                    Section {
                        Text("A workout is already in progress. Close this preview to continue it in Training.")
                    }
                } else if let plan {
                    Section {
                        ExCard(accent: true) {
                            ExEyebrow(plan.isDeload ? "Deload session" : "Up next", color: .exPrimaryText)
                            Text(plan.name).font(.exH2)
                            if let gym = workspace.gyms.active {
                                NavigationLink {
                                    TrainingGymsView(workspace: workspace, unit: unit)
                                } label: {
                                    Label(gym.name, systemImage: "building.2").font(.exBodyMedium)
                                        .foregroundStyle(Color.exPrimaryText).frame(minHeight: 44)
                                }.accessibilityLabel("Change gym, currently \(gym.name)").accessibilityIdentifier("program.gym")
                            }
                            if let reference = plan.program {
                                Text("Cycle \(reference.cycle + 1) · \(plan.exercises.count) \(plan.exercises.count == 1 ? "exercise" : "exercises")").font(.exCaption)
                            }
                            Button("Start planned workout") { start(plan) }
                                .buttonStyle(ExActionStyle()).accessibilityIdentifier("program.startPlanned")
                        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    }
                    ForEach(Array(plan.exercises.enumerated()), id: \.offset) { _, planned in
                        PlannedExerciseSection(planned: planned, store: workspace.store, unit: unit, gym: workspace.gyms.active)
                    }
                } else if error == nil {
                    Section { Text("No next workout is available. Check the program selected in Training.") }
                }
                if let error { Text(error).foregroundStyle(Color.exError).accessibilityIdentifier("program.planError") }
            }
            .exListStyle()
            .navigationTitle("Next workout").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task { refresh() }
            .onChange(of: workspace.programs.active) { _, _ in refresh() }
            .onChange(of: workspace.gyms.active) { _, _ in refresh() }
            .onChange(of: TrainingAnalysisInput(workspace.store.history)) { _, _ in refresh() }
        }
    }

    private func refresh() {
        plan = workspace.nextWorkout(bodyweight: workspace.latestBodyweight)
        error = nil
    }

    private func start(_ reviewed: WorkoutPlan) {
        do {
            // The latest weigh-in stands in for bodyweight; change it in the workout's details.
            let bodyweight = workspace.latestBodyweight
            let latest = workspace.nextWorkout(bodyweight: bodyweight)
            guard latest == reviewed else {
                plan = latest
                error = "Your program, gym or workout history changed. Review the updated targets before starting."
                return
            }
            try workspace.store.startSession(from: reviewed, bodyweight: bodyweight, timeZone: timeZone)
            Task { await workspace.synchronize() }
            dismiss()
        } catch { self.error = "The workout could not start. Your saved program is still here. Try again." }
    }
}

private struct PlannedExerciseSection: View {
    let planned: ExerlyCore.PlannedExercise
    let store: TrainingStore
    let unit: MassUnit
    let gym: GymProfile?

    var body: some View {
        let exercise = store.library.exercise(planned.exerciseID)
        Section(exercise?.name ?? planned.exerciseID.rawValue) {
            Text(TrainingProgramFormat.target(planned.target, exercise: exercise))
            if let exercise {
                if let gym, !gym.allows(exercise) {
                    Label("Not available at \(gym.name). Change gyms or edit this program if you need a different exercise.", systemImage: "exclamationmark.triangle")
                        .font(.exCaption).foregroundStyle(Color.exWarning)
                }
                Text(TrainingProgramFormat.reason(planned.recommendation, exercise: exercise, target: planned.target))
                    .foregroundStyle(.secondary)
            }
            PlannedSetsPreview(sets: planned.recommendation.sets, tracksReps: exercise?.metric.tracksReps == true, unit: unit)
            if let rest = planned.target.rest { Text("Rest \(TrainingFormat.number(rest)) seconds") }
            if !planned.notes.isEmpty { Text(planned.notes) }
            if planned.recommendation.outsideRange {
                Text("Equipment increments put these reps outside the requested range. Review the load before starting.")
                    .foregroundStyle(Color.exWarning)
            }
            if let estimate = planned.recommendation.oneRepMax {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Estimated 1RM used").font(.subheadline).foregroundStyle(.secondary)
                    Text(TrainingFormat.mass(.kg(estimate), unit: unit))
                }
            }
            if let basisID = planned.recommendation.basisSetID {
                if let record = store.history.sets(of: planned.exerciseID).first(where: { $0.set.id == basisID }) {
                    if record.set.rir == nil && record.set.kind != .failure {
                        Text("RIR was not recorded for this set. The estimate assumes your target of \(TrainingFormat.number(planned.target.rir)) RIR.")
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink {
                        WorkoutDetailView(store: store, sessionID: record.sessionID, unit: unit)
                    } label: { Text("Source workout").fixedSize(horizontal: false, vertical: true) }
                    .accessibilityIdentifier("program.source.\(planned.exerciseID.rawValue)")
                } else {
                    Text("The source set is unavailable on this device.").foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PlannedSetsPreview: View {
    let sets: [PlannedSet]
    let tracksReps: Bool
    let unit: MassUnit
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if tracksReps && !typeSize.isAccessibilitySize {
            Grid(alignment: .leading, horizontalSpacing: ExSpacing.content, verticalSpacing: ExSpacing.item) {
                GridRow {
                    Text("Set")
                    Text(unit == .kilograms ? "kg" : "lb")
                    Text("Reps")
                    Text("RIR")
                }.font(.exCaption).foregroundStyle(Color.exTextSecondary).accessibilityHidden(true)
                ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                    row(set, index: index)
                }
            }.font(.exBody).padding(.vertical, ExSpacing.small)
        } else {
            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    Text("Set \(index + 1) · \(TrainingFormat.kind(set.kind))")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    Text(TrainingFormat.set(PerformedSet(kind: set.kind, efforts: [set.effort], rir: set.rir), unit: unit))
                        .font(.exBodyMedium)
                    if tracksReps {
                        Text("Target \(TrainingFormat.number(set.rir)) RIR").font(.exCaption).foregroundStyle(Color.exPrimaryText)
                    }
                }.fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func row(_ set: PlannedSet, index: Int) -> some View {
        let load = set.effort.load.map { TrainingFormat.number($0.value(in: unit)) } ?? "Choose"
        let loadLabel = set.effort.load.map { "Load \(TrainingFormat.mass($0, unit: unit))" } ?? "Choose your load"
        let reps = set.effort.reps.map { String($0) } ?? "Not set"
        return GridRow {
            VStack(alignment: .leading, spacing: ExSpacing.tight) {
                Text("\(index + 1)").accessibilityLabel("Set \(index + 1)")
                if set.kind != .standard { Text(TrainingFormat.kind(set.kind)).font(.exCaption) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(load).accessibilityLabel(loadLabel)
            Text(reps).font(.exBodyMedium).accessibilityLabel("\(reps) reps")
            Text(TrainingFormat.number(set.rir)).foregroundStyle(Color.exPrimaryText)
                .accessibilityLabel("Target \(TrainingFormat.number(set.rir)) RIR")
        }
    }
}
