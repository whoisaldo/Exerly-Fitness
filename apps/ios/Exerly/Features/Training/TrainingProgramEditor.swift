import ExerlyCore
import SwiftUI

struct TrainingProgramEditor: View {
    let workspace: TrainingWorkspace
    private let isNew: Bool
    @StateObject private var draft: TrainingProgramDraft
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDiscard = false
    @State private var editMode = EditMode.inactive
    @FocusState private var typing: Bool

    init(workspace: TrainingWorkspace, editing: Program? = nil) {
        self.workspace = workspace
        isNew = editing == nil
        _draft = StateObject(wrappedValue: TrainingProgramDraft(store: workspace.programs, editing: editing))
    }

    private var iconName: String {
        guard let icon = draft.program.icon else { return "Default" }
        return ProgramAppearance.icons.first { $0.symbol == icon }?.name ?? "Saved icon"
    }

    private var colorName: String {
        guard let color = draft.program.color else { return "Default" }
        return ProgramAppearance.colors.first { $0.hex == color }?.name ?? "Saved color \(color)"
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                Form {
                    Section(isNew ? "New program" : "Edit program") {
                        TextField("Program name", text: $draft.program.name, axis: .vertical)
                            .focused($typing).accessibilityIdentifier("program.name")
                        ProgramNumberField("Cycles", text: $draft.cycles, integer: true)
                            .focused($typing).accessibilityIdentifier("program.cycles")
                        ProgramChoiceField("Deload", value: TrainingProgramFormat.deload(draft.program.deload)) {
                            Picker("Deload", selection: $draft.program.deload) {
                                ForEach(DeloadPlacement.allCases, id: \.self) {
                                    Text(TrainingProgramFormat.deload($0)).tag($0)
                                }
                            }
                        }.accessibilityIdentifier("program.deload")
                    }
                    Section {
                        EditButton().accessibilityLabel("Reorder or remove days")
                        ForEach($draft.program.days) { $day in
                            NavigationLink {
                                TrainingProgramDayEditor(day: $day, store: workspace.store,
                                                         cycles: TrainingInput.reps(draft.cycles))
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(day.name.isEmpty ? "Unnamed day" : day.name)
                                    Text(day.isRest ? "Rest day" : day.slots.count == 1 ? "1 exercise" : "\(day.slots.count) exercises")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }.fixedSize(horizontal: false, vertical: true)
                            }.accessibilityIdentifier("program.day.\(day.id)")
                        }
                        .onMove { draft.program.days.move(fromOffsets: $0, toOffset: $1) }
                        .onDelete { draft.program.days.remove(atOffsets: $0) }
                        Button("Add training day", systemImage: "plus") {
                            draft.program.days.append(ProgramDay(name: "Day \(draft.program.days.count + 1)"))
                        }.accessibilityIdentifier("program.addDay")
                        Button("Add rest day", systemImage: "moon") {
                            draft.program.days.append(ProgramDay(name: "Rest"))
                        }.accessibilityIdentifier("program.addRest")
                    } header: { Text("Days in each cycle") } footer: {
                        Text("Add exercises to make a training day. Days without exercises are rest days. Finished workouts advance the program; rest days do not assign calendar dates.")
                    }
                    Section("Appearance") {
                        ProgramChoiceField("Icon", value: iconName) {
                            Picker("Icon", selection: $draft.program.icon) {
                                Text("Default").tag(String?.none)
                                ForEach(ProgramAppearance.icons, id: \.symbol) { choice in
                                    Label(choice.name, systemImage: choice.symbol).tag(Optional(choice.symbol))
                                }
                                if let icon = draft.program.icon, !ProgramAppearance.icons.contains(where: { $0.symbol == icon }) {
                                    Text("Saved icon").tag(Optional(icon))
                                }
                            }
                        }
                        ProgramChoiceField("Color", value: colorName) {
                            Picker("Color", selection: $draft.program.color) {
                                Text("Default").tag(String?.none)
                                ForEach(ProgramAppearance.colors, id: \.hex) { choice in
                                    Text(choice.name).tag(Optional(choice.hex))
                                }
                                if let color = draft.program.color, !ProgramAppearance.colors.contains(where: { $0.hex == color }) {
                                    Text("Saved color \(color)").tag(Optional(color))
                                }
                            }
                        }
                    }
                    Section {
                        Text("Saving changes future workouts. Completed workouts and any workout in progress keep their logged values.")
                            .foregroundStyle(.secondary)
                    }
                    if !draft.errors.isEmpty {
                        Section("Could not save") {
                            ForEach(draft.errors, id: \.self) { Text($0).foregroundStyle(Color.exError) }
                        }.id("errors").accessibilityIdentifier("program.errors")
                    }
                }
                .environment(\.editMode, $editMode)
                .onChange(of: draft.errors) { _, errors in
                    if !errors.isEmpty { scroll.scrollTo("errors", anchor: .bottom) }
                }
            }
            .navigationTitle("Program").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if draft.hasChanges { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        typing = false
                        if draft.save() {
                            Task { await workspace.synchronize() }
                            dismiss()
                        }
                    }.fontWeight(.semibold).accessibilityIdentifier("program.save")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } }
            }
        }
        .interactiveDismissDisabled(draft.hasChanges)
        .sheet(isPresented: $confirmingDiscard) {
            TrainingProgramConfirmation(title: "Discard program changes?", message: "Your unsaved changes will be discarded. The saved program will stay as it is.",
                                        confirm: "Discard changes", cancelLabel: "Keep editing", destructive: true) {
                confirmingDiscard = false
                dismiss()
            } cancel: {
                confirmingDiscard = false
            }
        }
    }
}

private struct ProgramChoiceField<Content: View>: View {
    let title: String
    let value: String
    let content: () -> Content

    init(_ title: String, value: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.value = value
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            Menu(content: content) {
                HStack(alignment: .firstTextBaseline) {
                    Text(value).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }.frame(minHeight: 44).padding(.vertical, 4)
            }.accessibilityLabel("\(title), \(value)")
        }
    }
}

private enum ProgramAppearance {
    static let icons = [(name: "Strength", symbol: "dumbbell"), (name: "Training", symbol: "figure.strengthtraining.traditional"),
                        (name: "Running", symbol: "figure.run"), (name: "Power", symbol: "bolt"), (name: "Fitness", symbol: "heart")]
    static let colors = [(name: "Purple", hex: "#7C3AFF"), (name: "Pink", hex: "#EC4899"),
                         (name: "Blue", hex: "#3478F6"), (name: "Orange", hex: "#B85C00")]
}

private struct TrainingProgramDayEditor: View {
    @Binding var day: ProgramDay
    let store: TrainingStore
    let cycles: Int?
    @State private var adding = false
    @FocusState private var typing: Bool

    var body: some View {
        Form {
            Section {
                TextField("Day name", text: $day.name, axis: .vertical).focused($typing).accessibilityIdentifier("program.dayName")
            }
            Section {
                ForEach($day.slots) { $slot in
                    NavigationLink {
                        TrainingProgramSlotEditor(slot: $slot, exercise: store.library.exercise(slot.exerciseID), cycles: cycles)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.library.exercise(slot.exerciseID)?.name ?? slot.exerciseID.rawValue)
                            Text(TrainingProgramFormat.target(slot.target, exercise: store.library.exercise(slot.exerciseID)))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.fixedSize(horizontal: false, vertical: true)
                    }.accessibilityIdentifier("program.slot.\(slot.id)")
                }
                .onMove { day.slots.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { day.slots.remove(atOffsets: $0) }
                Button("Add exercise", systemImage: "plus") { typing = false; adding = true }
                    .accessibilityIdentifier("program.addExercise")
            } header: { Text(day.isRest ? "Rest day" : "Exercises in order") } footer: {
                if day.isRest { Text("This day is a rest day until you add an exercise.") }
            }
        }
        .navigationTitle(day.name.isEmpty ? "Program day" : day.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { EditButton().accessibilityLabel("Reorder or remove exercises") }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } }
        }
        .sheet(isPresented: $adding) {
            ExercisePickerView(store: store) { exercise in
                day.slots.append(ProgramSlot(exerciseID: exercise.id, target: SlotTarget(sets: 3, minReps: 6, maxReps: 10, rir: 2)))
            }
        }
    }
}

private struct TrainingProgramSlotEditor: View {
    @Binding var slot: ProgramSlot
    let exercise: ExerlyCore.Exercise?
    let cycles: Int?
    @State private var selectedCycle = 0
    @FocusState private var typing: Bool

    private var availableCycles: [Int] {
        guard let cycles, (1...Program.maximumCycles).contains(cycles) else { return [] }
        return Array(0..<cycles).filter { slot.cycleTargets[$0] == nil }
    }

    var body: some View {
        Form {
            Section("Default targets") {
                NavigationLink {
                    ProgramTargetEditor(target: slot.target, exercise: exercise) { slot.target = $0 }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Edit targets")
                        Text(TrainingProgramFormat.target(slot.target, exercise: exercise))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.fixedSize(horizontal: false, vertical: true)
                }.accessibilityIdentifier("program.editTargets")
                if exercise?.metric.tracksReps == true {
                    Toggle("Expand rep range", isOn: $slot.expandRepRange)
                    Text("Allow up to two reps outside your range when equipment increments make the requested load unavailable.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                TextField("Exercise notes", text: $slot.notes, axis: .vertical).focused($typing)
                    .accessibilityIdentifier("program.slotNotes")
            }
            Section {
                ForEach(slot.cycleTargets.keys.sorted(), id: \.self) { cycle in
                    if let target = slot.cycleTargets[cycle] {
                        NavigationLink {
                            ProgramTargetEditor(target: target, exercise: exercise, title: "Cycle \(cycle + 1)") {
                                slot.cycleTargets[cycle] = $0
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Cycle \(cycle + 1)")
                                Text(TrainingProgramFormat.target(target, exercise: exercise))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }.fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityIdentifier("program.override.\(cycle)")
                        .swipeActions {
                            Button("Remove", role: .destructive) { slot.cycleTargets.removeValue(forKey: cycle) }
                        }
                    }
                }
                if !availableCycles.isEmpty {
                    ProgramChoiceField("Cycle to customize", value: "Cycle \(selectedCycle + 1)") {
                        Picker("Cycle to customize", selection: $selectedCycle) {
                            ForEach(availableCycles, id: \.self) { Text("Cycle \($0 + 1)").tag($0) }
                        }
                    }
                    Button("Add cycle targets") {
                        guard let cycle = availableCycles.contains(selectedCycle) ? selectedCycle : availableCycles.first else { return }
                        slot.cycleTargets[cycle] = slot.target
                    }.accessibilityIdentifier("program.addOverride")
                } else if cycles == nil {
                    Text("Enter a valid cycle count in the program to add cycle targets.")
                        .foregroundStyle(.secondary)
                }
            } header: { Text("Cycle targets") } footer: {
                Text("These targets replace the defaults for that cycle, including its deload adjustment. Remove an override to use the defaults again.")
            }
        }
        .navigationTitle(exercise?.name ?? "Exercise targets").navigationBarTitleDisplayMode(.inline)
        .onChange(of: availableCycles, initial: true) { _, available in
            if !available.contains(selectedCycle), let first = available.first { selectedCycle = first }
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } } }
    }
}

private struct ProgramTargetEditor: View {
    let exercise: ExerlyCore.Exercise?
    let title: String
    let apply: (SlotTarget) -> Void
    @State private var fields: ProgramTargetFields
    @State private var error: String?
    @FocusState private var typing: Bool
    @Environment(\.dismiss) private var dismiss

    init(target: SlotTarget, exercise: ExerlyCore.Exercise?, title: String = "Set targets", apply: @escaping (SlotTarget) -> Void) {
        self.exercise = exercise
        self.title = title
        self.apply = apply
        _fields = State(initialValue: ProgramTargetFields(target))
    }

    var body: some View {
        Form {
            Section {
                ProgramNumberField("Sets", text: $fields.sets, integer: true).focused($typing)
                    .accessibilityIdentifier("program.targetSets")
                if exercise?.metric.tracksReps == true {
                    ProgramNumberField("Minimum reps", text: $fields.minReps, integer: true).focused($typing)
                        .accessibilityIdentifier("program.minReps")
                    ProgramNumberField("Maximum reps", text: $fields.maxReps, integer: true).focused($typing)
                        .accessibilityIdentifier("program.maxReps")
                    ProgramNumberField("Reps in reserve", text: $fields.rir).focused($typing)
                        .accessibilityIdentifier("program.targetRIR")
                } else {
                    Text("Enter time, distance and any load while logging. Later workouts can repeat your last entry.")
                        .foregroundStyle(.secondary)
                }
                ProgramNumberField("Rest in seconds, optional", text: $fields.rest).focused($typing)
                Picker("Set type", selection: $fields.kind) {
                    ForEach(SetKind.allCases.filter { $0 != .warmUp }, id: \.self) {
                        Text(TrainingFormat.kind($0)).tag($0)
                    }
                }
            } footer: { Text("Leave rest empty to use your usual timer. Targets are checked when you save the program.") }
            if let error { Text(error).foregroundStyle(Color.exError) }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    do { apply(try fields.value()); dismiss() }
                    catch { self.error = error.localizedDescription }
                }.accessibilityIdentifier("program.applyTargets")
            }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } }
        }
    }
}

private struct ProgramNumberField: View {
    let title: String
    @Binding var text: String
    var integer: Bool

    init(_ title: String, text: Binding<String>, integer: Bool = false) {
        self.title = title
        _text = text
        self.integer = integer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            TextField(title, text: $text).keyboardType(integer ? .numberPad : .decimalPad)
                .accessibilityLabel(title)
        }
    }
}
