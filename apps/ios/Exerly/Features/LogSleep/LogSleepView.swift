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
    private enum Field: Hashable { case bedtime, wakeTime }
    @FocusState private var focused: Field?

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
            ExScreen {
                ExCard(accent: true) {
                    ExEyebrow("Rest & recovery", color: .exPrimaryText)
                    ExQuantityControl(title: "Hours slept", text: $hours, step: 0.25, presets: [6, 7, 8], unit: "h", identifier: "sleep.hours")
                    Text("Log overnight sleep on the day you woke up. Add naps separately.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
                ExCard {
                    ExSectionHeading("How was your sleep?")
                    ExChoiceChips(values: qualityChoices, selection: $quality) { $0.isEmpty ? "Not recorded" : $0.capitalized }
                }
                ExCard {
                    ExSectionHeading("Sleep times", detail: "Optional")
                    LabeledContent("Bedtime") {
                        TextField("23:00", text: $bedtime, prompt: Text("23:00").foregroundColor(.exTextSecondary)).keyboardType(.numbersAndPunctuation).focused($focused, equals: .bedtime)
                            .frame(minHeight: 44).accessibilityIdentifier("sleep.bedtime")
                    }
                    Divider()
                    LabeledContent("Wake time") {
                        TextField("07:00", text: $wakeTime, prompt: Text("07:00").foregroundColor(.exTextSecondary)).keyboardType(.numbersAndPunctuation).focused($focused, equals: .wakeTime)
                            .frame(minHeight: 44).accessibilityIdentifier("sleep.wake-time")
                    }
                    Text("Times describe your sleep. Hours are recorded separately.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    CalendarDayPicker("Wake date", selection: $selectedDate, today: sync.today, timeZoneIdentifier: sync.calendar.timeZoneIdentifier)
                }
                if editing?.syncState == "pending" { Text("Saved on this device. Waiting to sync.").font(.exCaption) }
                if editing?.syncState == "attention" { NavigationLink("Review sleep changes") { SavedChangesReviewView() } }
                if editing != nil {
                    Button("Delete sleep entry", role: .destructive) { confirmingDelete = true }.frame(minHeight: 44)
                }
                if let error { Text(error).foregroundStyle(Color.exError) }
            }
            .navigationTitle(editing == nil ? "Log sleep" : "Edit sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save sleep") { save() }.disabled(isSaving) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = nil; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }
            .alert("Delete this sleep entry?", isPresented: $confirmingDelete) {
                Button("Delete sleep entry", role: .destructive) {
                    guard let editing else { return }
                    do { onDeleted(try sync.deleteSleep(editing)); onSaved(); dismiss() } catch { self.error = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("You can undo this after closing the form.") }
        }
    }
    private var qualityChoices: [String] {
        let choices = ["", "poor", "fair", "good", "great", "excellent"]
        return choices.contains(quality) ? choices : choices + [quality]
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
        do { try sync.saveSleep(request, editing: editing); onSaved(); dismiss() } catch { self.error = error.localizedDescription; isSaving = false }
    }
}
