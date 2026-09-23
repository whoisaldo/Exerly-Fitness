import SwiftUI

struct LogActivityView: View {
    let editing: ActivityDTO?
    let onDeleted: (String) -> Void
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sync: SyncEngine
    @State private var name: String
    @State private var duration: String
    @State private var calories: String
    @State private var intensity: String
    @State private var selectedDate: CalendarDay
    @State private var isSaving = false
    @State private var confirmingDelete = false
    @State private var error: String?
    @FocusState private var focused: Bool

    init(initialDate: CalendarDay, editing: ActivityDTO? = nil, onDeleted: @escaping (String) -> Void = { _ in }, onSaved: @escaping () -> Void = {}) {
        self.editing = editing; self.onDeleted = onDeleted; self.onSaved = onSaved
        _name = State(initialValue: editing?.type ?? "")
        _duration = State(initialValue: editing.map { $0.duration.formatted(.number.grouping(.never)) } ?? "")
        _calories = State(initialValue: editing?.calories.map { $0.formatted(.number.grouping(.never)) } ?? "")
        _intensity = State(initialValue: editing?.intensity ?? "")
        _selectedDate = State(initialValue: editing?.date.flatMap { CalendarDay(rawValue: $0) } ?? initialDate)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    LabeledContent("Name") {
                        TextField("Activity name", text: $name).focused($focused).accessibilityIdentifier("activity.name")
                    }
                    LabeledContent("Minutes") {
                        TextField("Duration in minutes", text: $duration).keyboardType(.decimalPad).focused($focused).accessibilityIdentifier("activity.minutes")
                    }
                    LabeledContent("Calories") {
                        TextField("Not recorded", text: $calories).keyboardType(.decimalPad).focused($focused).accessibilityIdentifier("activity.calories")
                    }
                    Text("Leave calories blank if you did not record them.").font(.callout).foregroundStyle(.secondary)
                    Picker("Intensity", selection: $intensity) {
                        Text("Not recorded").tag("")
                        ForEach(["light", "moderate", "intense"], id: \.self) { Text($0.capitalized).tag($0) }
                        if !["", "light", "moderate", "intense"].contains(intensity) { Text(intensity.capitalized).tag(intensity) }
                    }.accessibilityIdentifier("activity.intensity")
                    CalendarDayPicker("Activity date", selection: $selectedDate, today: sync.today, timeZoneIdentifier: sync.calendar.timeZoneIdentifier)
                }
                if editing?.syncState == "pending" { Text("Saved on this device. Waiting to sync.") }
                if editing?.syncState == "attention" { NavigationLink("Review activity changes") { SyncIssuesView() } }
                if editing != nil {
                    Section { Button("Delete activity", role: .destructive) { confirmingDelete = true }.frame(minHeight: 44) }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(editing == nil ? "Log activity" : "Edit activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save activity") { save() }.disabled(isSaving) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
            }
            .alert("Delete this activity?", isPresented: $confirmingDelete) {
                Button("Delete activity", role: .destructive) {
                    guard let editing else { return }
                    do { onDeleted(try sync.deleteActivity(editing)); onSaved(); dismiss() }
                    catch { self.error = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("You can undo this after closing the form.") }
        }
    }
    private func save() {
        guard !isSaving else { return }
        guard let minutes = UserEnteredNumber.parse(duration) else {
            error = "Enter the activity duration in minutes."; return
        }
        let energy = calories.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = UserEnteredNumber.parse(energy)
        guard energy.isEmpty || number != nil else { error = "Enter calories as a number, or leave the field blank."; return }
        isSaving = true; error = nil
        let request = ActivityRequest(type: name, duration: minutes, calories: number, intensity: intensity.isEmpty ? nil : intensity,
            entryDate: selectedDate.rawValue, category: editing?.category)
        do { try sync.saveActivity(request, editing: editing); onSaved(); dismiss() }
        catch { self.error = error.localizedDescription; isSaving = false }
    }
}
