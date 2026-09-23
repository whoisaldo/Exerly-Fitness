import SwiftUI

struct LogSleepView: View {
    let editing: SleepDTO?
    let onDeleted: (String) -> Void
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sync: SyncEngine
    @State private var hours: String
    @State private var quality: String
    @State private var bedtime: String
    @State private var wakeTime: String
    @State private var selectedDate: CalendarDay
    @State private var isSaving = false
    @State private var confirmingDelete = false
    @State private var error: String?
    @FocusState private var focused: Bool

    init(initialDate: CalendarDay, editing: SleepDTO? = nil, onDeleted: @escaping (String) -> Void = { _ in }, onSaved: @escaping () -> Void = {}) {
        self.editing = editing; self.onDeleted = onDeleted; self.onSaved = onSaved
        _hours = State(initialValue: editing.map { $0.hours.formatted(.number.grouping(.never)) } ?? "")
        _quality = State(initialValue: editing?.qualityLabel ?? "")
        _bedtime = State(initialValue: editing?.bedtime ?? "")
        _wakeTime = State(initialValue: editing?.wakeTime ?? "")
        _selectedDate = State(initialValue: editing?.date.flatMap { CalendarDay(rawValue: $0) } ?? initialDate)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Sleep entry") {
                    LabeledContent("Hours slept") {
                        TextField("Hours slept", text: $hours).keyboardType(.decimalPad).focused($focused).accessibilityIdentifier("sleep.hours")
                    }
                    Picker("Quality", selection: $quality) {
                        Text("Not recorded").tag("")
                        ForEach(["poor", "fair", "good", "great", "excellent"], id: \.self) { Text($0.capitalized).tag($0) }
                        if !["", "poor", "fair", "good", "great", "excellent"].contains(quality) { Text(quality.capitalized).tag(quality) }
                    }.accessibilityIdentifier("sleep.quality")
                    LabeledContent("Bedtime") {
                        TextField("Not recorded", text: $bedtime).focused($focused).accessibilityIdentifier("sleep.bedtime")
                    }
                    LabeledContent("Wake time") {
                        TextField("Not recorded", text: $wakeTime).focused($focused).accessibilityIdentifier("sleep.wake-time")
                    }
                    CalendarDayPicker("Wake date", selection: $selectedDate, today: sync.today, timeZoneIdentifier: sync.calendar.timeZoneIdentifier)
                    Text("Log overnight sleep on the day you woke up. Add naps separately. Hours are entered separately from the optional times.").font(.callout).foregroundStyle(.secondary)
                }
                if editing?.syncState == "pending" { Text("Saved on this device. Waiting to sync.") }
                if editing?.syncState == "attention" { NavigationLink("Review sleep changes") { SyncIssuesView() } }
                if editing != nil {
                    Section { Button("Delete sleep entry", role: .destructive) { confirmingDelete = true }.frame(minHeight: 44) }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(editing == nil ? "Log sleep" : "Edit sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save sleep") { save() }.disabled(isSaving) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
            }
            .alert("Delete this sleep entry?", isPresented: $confirmingDelete) {
                Button("Delete sleep entry", role: .destructive) {
                    guard let editing else { return }
                    do { onDeleted(try sync.deleteSleep(editing)); onSaved(); dismiss() }
                    catch { self.error = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("You can undo this after closing the form.") }
        }
    }
    private func save() {
        guard !isSaving else { return }
        guard let duration = UserEnteredNumber.parse(hours) else {
            error = "Enter how many hours you slept."; return
        }
        isSaving = true; error = nil
        let request = SleepRequest(hours: duration, quality: quality.isEmpty ? nil : quality,
            bedtime: bedtime.isEmpty ? nil : bedtime, wakeTime: wakeTime.isEmpty ? nil : wakeTime,
            entryDate: selectedDate.rawValue)
        do { try sync.saveSleep(request, editing: editing); onSaved(); dismiss() }
        catch { self.error = error.localizedDescription; isSaving = false }
    }
}
