import ExerlyCore
import SwiftUI

struct NextTrainingWorkoutSection: View {
    let workspace: TrainingWorkspace
    let review: () -> Void

    var body: some View {
        if let program = workspace.programs.active {
            ExCard(accent: true) {
                ExEyebrow("Next up", color: .exPrimaryText)
                if let next = ProgramSchedule.next(for: program, in: workspace.store.history) {
                    VStack(alignment: .leading, spacing: ExSpacing.small) {
                        Text(next.day.name).font(.exH1).foregroundStyle(Color.exTextPrimary)
                        Text(program.name).font(.exBody).foregroundStyle(Color.exTextSecondary)
                    }
                    HStack {
                        Label("Cycle \(next.cycle + 1) of \(program.cycles)", systemImage: "circle.lefthalf.filled")
                        if next.isDeload { Label("Deload", systemImage: "arrow.down.right") }
                    }.font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    Button("Review next workout", action: review).buttonStyle(ExActionStyle())
                        .accessibilityIdentifier("program.nextWorkout")
                } else {
                    Text(program.name).font(.exH2)
                    Text("Program complete").font(.exBodyMedium).foregroundStyle(Color.exPrimaryText)
                    Text("Duplicate it in Programs to begin again with separate progress.")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary)
                }
            }
        }
    }
}

struct PlannedWorkoutView: View {
    let workspace: TrainingWorkspace
    let unit: MassUnit
    let timeZone: TimeZone
    @State private var bodyweight = ""
    @State private var plan: WorkoutPlan?
    @State private var error: String?
    @FocusState private var typing: Bool
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
                            if let reference = plan.program { Text("Cycle \(reference.cycle + 1) · \(plan.exercises.count) exercises").font(.exCaption) }
                            Button("Start planned workout") { start(plan) }
                                .buttonStyle(ExActionStyle()).accessibilityIdentifier("program.startPlanned")
                        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    }
                    Section {
                        TextField("Bodyweight (\(unit == .kilograms ? "kg" : "lb"), optional)", text: $bodyweight)
                            .keyboardType(.decimalPad).focused($typing)
                            .accessibilityIdentifier("program.bodyweight")
                        Text("Enter today's bodyweight for bodyweight exercise estimates, or leave it empty. Your profile weight is not filled in automatically.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(Array(plan.exercises.enumerated()), id: \.offset) { _, planned in
                        PlannedExerciseSection(planned: planned, store: workspace.store, unit: unit)
                    }
                    Section {
                        Text("All sets start incomplete. The program advances only after you finish the workout.")
                            .font(.footnote).foregroundStyle(.secondary)
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
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } }
            }
            .task { refresh() }
            .onChange(of: bodyweight) { _, _ in refresh() }
            .onChange(of: workspace.programs.active) { _, _ in refresh() }
            .onChange(of: TrainingAnalysisInput(workspace.store.history)) { _, _ in refresh() }
        }
    }

    private func weight() throws -> Mass? {
        guard !bodyweight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let value = TrainingInput.number(bodyweight), value > 0 else { throw WeightInputError.invalid }
        return Mass(value, unit)
    }

    private func refresh() {
        do {
            plan = workspace.programs.nextWorkout(bodyweight: try weight())
            error = nil
        } catch {
            plan = nil
            self.error = "Enter a bodyweight greater than zero, or leave it empty."
        }
    }

    private func start(_ reviewed: WorkoutPlan) {
        do {
            let bodyweight = try weight()
            let latest = workspace.programs.nextWorkout(bodyweight: bodyweight)
            guard latest == reviewed else {
                plan = latest
                error = "Your program or workout history changed. Review the updated targets before starting."
                return
            }
            try workspace.store.startSession(from: reviewed, bodyweight: bodyweight, timeZone: timeZone)
            Task { await workspace.synchronize() }
            dismiss()
        } catch { self.error = "The workout could not start. Your saved program is still here. Try again." }
    }

    private enum WeightInputError: Error { case invalid }
}

private struct PlannedExerciseSection: View {
    let planned: ExerlyCore.PlannedExercise
    let store: TrainingStore
    let unit: MassUnit

    var body: some View {
        let exercise = store.library.exercise(planned.exerciseID)
        Section(exercise?.name ?? planned.exerciseID.rawValue) {
            Text(TrainingProgramFormat.target(planned.target, exercise: exercise))
            if let exercise {
                Text(TrainingProgramFormat.reason(planned.recommendation, exercise: exercise, target: planned.target))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(planned.recommendation.sets.enumerated()), id: \.offset) { index, set in
                VStack(alignment: .leading, spacing: 5) {
                    Text("Set \(index + 1) · \(TrainingFormat.kind(set.kind))").font(.subheadline).foregroundStyle(.secondary)
                    Text(TrainingFormat.set(PerformedSet(kind: set.kind, efforts: [set.effort], rir: set.rir), unit: unit))
                    if exercise?.metric.tracksReps == true {
                        Text("Target \(TrainingFormat.number(set.rir)) RIR").font(.subheadline)
                    }
                }.fixedSize(horizontal: false, vertical: true)
            }
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
