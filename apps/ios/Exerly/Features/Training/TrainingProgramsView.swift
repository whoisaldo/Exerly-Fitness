import ExerlyCore
import SwiftUI

struct TrainingProgramsView: View {
    let workspace: TrainingWorkspace
    let unit: MassUnit
    let timeZone: TimeZone
    @State private var creating = false

    var body: some View {
        ExList {
            Section {
                if workspace.programs.programs.isEmpty {
                    ExEmptyState(icon: "square.stack.3d.up", title: "Build your first program",
                                 message: "Arrange your training days, choose exercises, and set the targets you want to repeat.",
                                 action: "Create program", actionID: "program.create") { creating = true }
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                } else {
                    ExCard(accent: true) {
                        ExEyebrow("Training plans", color: .exPrimaryText)
                        Text(workspace.programs.active?.name ?? "Find your rhythm").font(.exH2)
                        if let active = workspace.programs.active {
                            let progress = ProgramSchedule.progress(of: active, in: workspace.store.history)
                            Text("\(progress.done) of \(progress.total) sessions completed").font(.exCaption)
                                .foregroundStyle(Color.exTextSecondary)
                            ExProgressBar(value: Double(progress.done), total: Double(progress.total))
                        } else {
                            Text("Follow a saved program to see your next workout in Training.")
                                .font(.exBody).foregroundStyle(Color.exTextSecondary)
                        }
                    }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
            }
            programSection("Programs", archived: false)
            programSection("Archived", archived: true)
            Section {
                Text("Programs save on this device and sync with your account when connected. Finished workouts advance the schedule; rest days do not assign calendar dates.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Programs").navigationBarTitleDisplayMode(.inline)
        .exListStyle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New program", systemImage: "plus") { creating = true }
                    .accessibilityIdentifier("program.new")
            }
        }
        .sheet(isPresented: $creating) { TrainingProgramEditor(workspace: workspace) }
        .refreshable { await workspace.synchronize() }
    }

    @ViewBuilder
    private func programSection(_ title: String, archived: Bool) -> some View {
        let programs = workspace.programs.programs.filter { ($0.archivedAt != nil) == archived }
        if !programs.isEmpty {
            Section(title) {
                ForEach(programs) { program in
                    NavigationLink {
                        TrainingProgramDetailView(workspace: workspace, programID: program.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Label {
                                Text(program.name)
                            } icon: {
                                Image(systemName: program.icon ?? "dumbbell")
                                    .foregroundStyle(program.color.map(Color.init(hex:)) ?? Color.exPrimary)
                            }
                            Text("\(program.cycles) \(program.cycles == 1 ? "cycle" : "cycles") · \(program.trainingDays.count) \(program.trainingDays.count == 1 ? "training day" : "training days") per cycle")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if workspace.programs.active?.id == program.id {
                                Text("Following").font(.subheadline.weight(.semibold))
                            }
                        }.fixedSize(horizontal: false, vertical: true).padding(.vertical, 4)
                    }.accessibilityIdentifier("program.open.\(program.id)")
                }
            }
        }
    }
}

private struct TrainingProgramDetailView: View {
    let workspace: TrainingWorkspace
    let programID: UUID
    @State private var editing: Program?
    @State private var action: ProgramLifecycleAction?
    @State private var error: String?
    @State private var copiedName: String?

    var body: some View {
        ExList {
            if let program = workspace.programs.program(programID) {
                Section {
                    ExCard(accent: true) {
                    ExEyebrow("Program", color: .exPrimaryText)
                    Text(program.name).font(.exH1)
                    Text("\(program.cycles) cycles · \(TrainingProgramFormat.deload(program.deload))")
                    let progress = ProgramSchedule.progress(of: program, in: workspace.store.history)
                    Text("\(progress.done) of \(progress.total) workouts completed")
                    if progress.total > 0 {
                        ProgressView(value: Double(progress.done), total: Double(progress.total))
                            .accessibilityLabel("Program progress")
                            .accessibilityValue("\(progress.done) of \(progress.total) workouts completed")
                    }
                    if workspace.programs.active?.id == program.id {
                        Label("Following this program", systemImage: "checkmark.circle")
                        Text("Open Next workout in Training to review your targets and start.")
                            .foregroundStyle(.secondary)
                    }
                    }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                TrainingProgramDays(program: program, library: workspace.store.library)
                Section("Manage program") {
                    Button("Edit program") { editing = program }.accessibilityIdentifier("program.edit")
                    if program.archivedAt != nil {
                        Button("Restore program") { prepare(.restore, program: program) }
                            .accessibilityIdentifier("program.restore")
                    } else {
                        if workspace.programs.active?.id != program.id {
                            Button("Follow program") { prepare(.activate, program: program) }
                                .accessibilityIdentifier("program.activate")
                        }
                        Button("Archive program") { prepare(.archive, program: program) }
                            .accessibilityIdentifier("program.archive")
                    }
                    Button("Duplicate program") {
                        do {
                            let copy = try workspace.programs.duplicate(program.id, name: "\(program.name) copy")
                            copiedName = copy.name
                            error = nil
                            Task { await workspace.synchronize() }
                        } catch { self.error = "The copy could not be saved. Try again." }
                    }.accessibilityIdentifier("program.duplicate")
                }
                if let copiedName {
                    Text("Created \(copiedName). Find it in Programs. It has its own workout history and is not selected automatically.")
                        .accessibilityIdentifier("program.duplicateResult")
                }
            } else {
                ContentUnavailableView("Program unavailable", systemImage: "doc.questionmark",
                                       description: Text("This program is no longer saved in this account."))
            }
            if let error { Text(error).foregroundStyle(Color.exError).accessibilityIdentifier("program.actionError") }
        }
        .navigationTitle("Program").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { TrainingProgramEditor(workspace: workspace, editing: $0) }
        .sheet(item: $action) { pending in
            TrainingProgramConfirmation(title: pending.title, message: pending.message, confirm: pending.button) {
                action = nil
                perform(pending)
            } cancel: {
                action = nil
            }
        }
    }

    private func prepare(_ kind: ProgramLifecycleAction.Kind, program: Program) {
        action = ProgramLifecycleAction(kind: kind, program: program, current: workspace.programs.active,
                                        next: nextProgram(kind, program: program))
    }

    private func nextProgram(_ kind: ProgramLifecycleAction.Kind, program: Program) -> Program? {
        switch kind {
        case .activate: program
        case .archive: workspace.programs.activeAfterArchiving(program.id)
        case .restore: workspace.programs.activeAfterRestoring(program.id)
        }
    }

    private func perform(_ pending: ProgramLifecycleAction) {
        guard workspace.programs.program(programID) == pending.program,
              workspace.programs.active == pending.current,
              nextProgram(pending.kind, program: pending.program) == pending.next else {
            error = "Your programs changed while this confirmation was open. Review them and try again."
            return
        }
        do {
            switch pending.kind {
            case .activate: try workspace.programs.activate(programID)
            case .archive: try workspace.programs.archive(programID)
            case .restore: try workspace.programs.restore(programID)
            }
            error = nil
            Task { await workspace.synchronize() }
        } catch { self.error = "The program change could not be saved. Try again." }
    }
}

private struct ProgramLifecycleAction: Identifiable {
    enum Kind { case activate, archive, restore }
    let kind: Kind
    let program: Program
    let current: Program?
    let next: Program?
    var id: UUID { program.id }

    var button: String {
        switch kind { case .activate: "Follow program"; case .archive: "Archive program"; case .restore: "Restore program" }
    }
    var title: String { "\(button)?" }
    var message: String {
        let following = next.map { "You will be following \($0.name)." } ?? "No program will be selected."
        return "\(program.name). \(following) Completed workouts and any workout in progress stay saved."
    }
}

/// Full-width confirmation keeps the explanation and Cancel reachable at
/// accessibility sizes, where the system's compact popover can hide them.
struct TrainingProgramConfirmation: View {
    let title: String
    let message: String
    let confirm: String
    var cancelLabel = "Cancel"
    var destructive = false
    let perform: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(title).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    Text(message)
                    Button(role: destructive ? .destructive : nil, action: perform) {
                        Text(confirm).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent).tint(Color.exActionFill)
                    .accessibilityIdentifier("program.confirm")
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding()
            }
            .navigationTitle("Confirm").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelLabel, action: cancel).accessibilityIdentifier("program.confirmCancel")
                }
            }
        }
    }
}

/// Also used to read a complete program in a proposal without entering its editor.
struct TrainingProgramDays: View {
    let program: Program
    let library: ExerlyCore.ExerciseLibrary

    var body: some View {
        ForEach(Array(program.days.enumerated()), id: \.element.id) { index, day in
            Section("Day \(index + 1) · \(day.name)") {
                if day.isRest { Text("Rest day").foregroundStyle(.secondary) }
                ForEach(day.slots) { slot in
                    VStack(alignment: .leading, spacing: 7) {
                        let exercise = library.exercise(slot.exerciseID)
                        Text(exercise?.name ?? slot.exerciseID.rawValue).font(.headline)
                        target(slot.target, exercise: exercise)
                        if !slot.notes.isEmpty { Text(slot.notes) }
                        ForEach(slot.cycleTargets.keys.sorted(), id: \.self) { cycle in
                            if let override = slot.cycleTargets[cycle] {
                                Text("Cycle \(cycle + 1)").font(.subheadline.weight(.semibold))
                                target(override, exercise: exercise)
                            }
                        }
                        if slot.expandRepRange { Text("Rep range can expand by up to two reps.").font(.footnote).foregroundStyle(.secondary) }
                        if slot.supersetID != nil { Text("Part of a superset").font(.footnote).foregroundStyle(.secondary) }
                    }.fixedSize(horizontal: false, vertical: true).padding(.vertical, 5)
                }
            }
        }
    }

    private func target(_ target: SlotTarget, exercise: ExerlyCore.Exercise?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(TrainingProgramFormat.target(target, exercise: exercise))
            Text("\(TrainingFormat.kind(target.kind)) · \(target.rest.map { TrainingFormat.number($0) + " s rest" } ?? "Usual rest timer")")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
