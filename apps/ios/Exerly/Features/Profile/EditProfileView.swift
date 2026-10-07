import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    var body: some View {
        NavigationStack {
            if let accountID = authVM.currentUser?.id {
                PreferencesEditor(accountID: accountID, auth: authVM)
                    .id("\(authVM.sessionID):\(accountID)")
            }
        }
    }
}

private struct PreferencesEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var notifications = NotificationService.shared
    @StateObject private var store: PreferencesStore
    @FocusState private var focusedField: String?
    @State private var showKeepConfirmation = false
    @State private var showReplaceConfirmation = false
    @State private var foodExpanded = false
    @State private var trainingExpanded = false
    @State private var sleepExpanded = false
    @State private var remindersExpanded = false
    @State private var editTask: Task<Void, Never>?

    init(accountID: String, auth: AuthViewModel) {
        let sessionID = auth.sessionID
        _store = StateObject(wrappedValue: PreferencesStore(
            accountID: accountID,
            ownerIsActive: { [weak auth] in auth?.currentUser?.id == accountID && auth?.sessionID == sessionID },
            onAccepted: { [weak auth] snapshot in
                auth?.acceptPreferences(snapshot.user, accountID: accountID, sessionID: sessionID)
                NotificationService.shared.accept(snapshot)
            }
        ))
    }

    private var fields: [String: String] { store.draft?.fields ?? [:] }
    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { fields[key] ?? "" }, set: { store.edit(key, value: $0) })
    }
    private func enabled(_ key: String) -> Binding<Bool> {
        Binding(get: { fields[key] == "true" }, set: { store.edit(key, value: String($0)) })
    }
    private func perform(_ action: @escaping @MainActor () async -> Void) {
        editTask?.cancel()
        editTask = Task { await action() }
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                statusSection.id("preferences-status")
                if store.conflict != nil { conflictSection }
                if store.draft != nil {
                    basicSection.disabled(store.isLocked)
                    foodSection.disabled(store.isLocked)
                    trainingSection.disabled(store.isLocked)
                    sleepSection.disabled(store.isLocked)
                    remindersSection.disabled(store.isLocked)
                }
                deliverySection
            }
            .scrollContentBackground(.hidden)
            .background(Color.exBackground)
            .onChange(of: store.error) { _, error in
                if error != nil { focusedField = nil; proxy.scrollTo("preferences-status", anchor: .top) }
            }
            .onChange(of: store.conflict?.revision) { _, revision in
                if revision != nil { focusedField = nil; proxy.scrollTo("preferences-status", anchor: .top) }
            }
        }
        .tint(.exTextPrimary)
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(store.draft?.pending == nil ? "Save" : "Retry save") {
                    focusedField = nil
                    perform { await store.save() }
                }
                .accessibilityLabel(store.draft?.pending == nil ? "Save preferences" : "Retry save")
                .accessibilityIdentifier("preferences.save")
                .disabled(store.isSaving || store.isLoading || !store.isReadable || store.conflict != nil || store.draft == nil)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Hide keyboard") { focusedField = nil }
            }
        }
        .confirmationDialog("Save these preference edits?", isPresented: $showKeepConfirmation, titleVisibility: .visible) {
            Button("Save reviewed edits") { perform { await store.resolve(useServer: false) } }
        } message: {
            Text("Only your edited fields replace the reviewed account values. Other preferences stay as they are.")
        }
        .confirmationDialog("Use the saved account preferences?", isPresented: $showReplaceConfirmation, titleVisibility: .visible) {
            Button("Use saved preferences", role: .destructive) { perform { await store.resolve(useServer: true) } }
        } message: {
            Text("This replaces the open draft with the account version shown here.")
        }
        .task { store.activate(); await store.load() }
        .onDisappear { editTask?.cancel(); store.stop() }
    }

    private var statusSection: some View {
        Section {
            if store.isLoading || store.isSaving {
                HStack {
                    ProgressView()
                    Text(store.isSaving ? "Saving preferences…" : "Refreshing preferences…")
                }
            } else if let message = store.message {
                Text(message).font(.subheadline).accessibilityIdentifier("preferences.status")
            }
            if let error = store.error {
                Text(error).foregroundStyle(Color.exError).accessibilityIdentifier("preferences.error")
            }
            if store.draft?.pending != nil {
                Text("Your last save has not been confirmed. Retry it before editing these preferences.")
                    .font(.subheadline)
            }
            Button("Refresh preferences") { focusedField = nil; perform { await store.load() } }
                .disabled(store.isLoading || store.isSaving || !store.isReadable)
        } footer: {
            Text("Edits stay on this iPhone until you save. You can close this screen and finish later.")
        }
    }

    private var conflictSection: some View {
        Section("Preferences changed on another device") {
            if let draft = store.draft, let remote = store.conflict {
                let changed = (try? PreferenceFields.changes(draft)) ?? [:]
                ForEach(PreferenceFields.definitions.filter { changed[$0.key] != nil }, id: \.key) { field in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(field.label).font(.headline)
                        Text("Your edit: \(PreferenceFields.describe(changed[field.key] ?? .null))")
                        Text("Saved on account: \(PreferenceFields.describe(remote.value(field.key)))")
                    }
                    .font(.subheadline)
                }
                ForEach(["reminders", "reminderTimes"].filter { changed[$0] != nil }, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(key == "reminders" ? "Reminder choices" : "Reminder times").font(.headline)
                        Text("Your edit: \(PreferenceFields.describe(changed[key] ?? .null))")
                        Text("Saved on account: \(PreferenceFields.describe(remote.value(key)))")
                    }.font(.subheadline)
                }
            }
            Button("Save my edits") { showKeepConfirmation = true }
            Button("Use account preferences") { showReplaceConfirmation = true }
        }
        .accessibilityIdentifier("preferences.conflict")
    }

    private var basicSection: some View {
        Section("About you") {
            field("name")
            field("age", keyboard: .numberPad)
            field("gender")
            picker("unitSystem", choices: [("metric", "Metric, kg and cm"), ("imperial", "Imperial, lb and inches")])
            field("height", label: "Height (\(fields["unitSystem"] == "imperial" ? "in" : "cm"))", keyboard: .decimalPad)
            picker("activityLevel", choices: [
                ("sedentary", "Mostly seated"), ("light", "Lightly active"),
                ("moderate", "Moderately active"), ("active", "Very active"), ("very_active", "Extremely active")
            ])
            field("timezone")
            Button("Use device time zone") { store.edit("timezone", value: TimeZone.current.identifier) }
            Text("Log new weight readings in Progress. Review nutrition goals and accepted targets in Nutrition Program.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
    private var foodSection: some View {
        Section {
            DisclosureGroup("Food preferences", isExpanded: $foodExpanded) {
                field("dietaryStyle")
                field("allergies", multiline: true)
                field("mealsPerDay", keyboard: .numberPad)
                Text("Enter one allergy per line. Check food labels when choosing products.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
    private var trainingSection: some View {
        Section {
            DisclosureGroup("Training preferences", isExpanded: $trainingExpanded) {
                picker("experienceLevel", choices: [("beginner", "Beginner"), ("intermediate", "Intermediate"), ("advanced", "Advanced")])
                picker("equipmentAccess", choices: [("bodyweight", "Bodyweight"), ("home", "Home"), ("full_gym", "Gym")])
                field("equipment", multiline: true)
                field("activityTypes", multiline: true)
                Text("Enter one item or activity per line.").font(.subheadline).foregroundStyle(.secondary)
                field("workoutDaysPerWeek", keyboard: .numberPad)
                ForEach(PreferenceFields.days, id: \.self) { day in
                    Toggle(day.capitalized, isOn: Binding(get: {
                        (fields["workoutDays"] ?? "").components(separatedBy: "\n").contains(day)
                    }, set: { selected in
                        var days = Set((fields["workoutDays"] ?? "").components(separatedBy: "\n").filter { !$0.isEmpty })
                        if selected { days.insert(day) } else { days.remove(day) }
                        store.edit("workoutDays", value: PreferenceFields.days.filter { days.contains($0) }.joined(separator: "\n"))
                    }))
                    .accessibilityIdentifier("preferences.day.\(day)")
                    .tint(.exPrimary)
                }
            }
        }
    }
    private var sleepSection: some View {
        Section {
            DisclosureGroup("Sleep preferences", isExpanded: $sleepExpanded) {
                field("sleepGoalHours", keyboard: .decimalPad)
                field("bedtime", keyboard: .numbersAndPunctuation)
                field("wakeTime", keyboard: .numbersAndPunctuation)
                Text("Use 24-hour times such as 22:30. Preferred times do not create sleep entries.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
    private var remindersSection: some View {
        Section {
            DisclosureGroup("Reminder preferences", isExpanded: $remindersExpanded) {
                ForEach(["meals", "workouts", "sleep"], id: \.self) { kind in
                    Toggle(PreferenceFields.label("reminders.\(kind)"), isOn: enabled("reminders.\(kind)"))
                        .accessibilityIdentifier("preferences.reminders.\(kind)")
                        .tint(.exPrimary)
                }
                field("reminderTimes.meals", multiline: true)
                field("reminderTimes.workout", keyboard: .numbersAndPunctuation)
                field("reminderTimes.sleep", keyboard: .numbersAndPunctuation)
                Text("Use 24-hour times, one meal time per line. These are your shared preferences. Notification delivery is enabled separately on each device.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
    private var deliverySection: some View {
        Section("Delivery on this iPhone") {
            Text(notifications.isDeviceEnabled ? "Delivery enabled on this iPhone" : "Delivery off on this iPhone")
            if notifications.isDeviceEnabled && notifications.authorization == .denied {
                Text("Notifications are denied in iOS Settings. Your reminder choices are saved.")
                    .font(.subheadline)
            } else if notifications.isDeviceEnabled {
                Text("\(notifications.scheduledCount) \(notifications.scheduledCount == 1 ? "reminder" : "reminders") scheduled")
                    .accessibilityIdentifier("preferences.scheduled-reminders")
            }
            ForEach(notifications.missing, id: \.self) { Text($0).font(.subheadline) }
            if let error = notifications.error { Text(error).foregroundStyle(Color.exError) }
            if notifications.isDeviceEnabled && notifications.authorization == .notDetermined {
                Button("Allow notifications") { Task { await notifications.setDeviceEnabled(true) } }
            }
            Button("Open notification settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
            Button(notifications.isDeviceEnabled ? "Turn off delivery on this iPhone" : "Enable reminders on this iPhone") {
                Task { await notifications.setDeviceEnabled(!notifications.isDeviceEnabled) }
            }.disabled(notifications.isUpdating || (!notifications.isDeviceEnabled &&
                (store.hasEdits || store.draft?.pending != nil || store.draft == nil || !store.isReadable)))
            Button("Refresh reminder delivery") {
                Task { await notifications.refresh(accountID: store.accountID) }
            }.disabled(notifications.isUpdating)
            Text("Save preference edits first. Reminder times use your saved time zone. Changes made on another device apply here when Exerly next connects.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func field(_ key: String, label: String? = nil, keyboard: UIKeyboardType = .default, multiline: Bool = false) -> some View {
        let title = label ?? PreferenceFields.label(key)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.medium))
            if multiline {
                TextField(title, text: binding(key), axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: key)
                    .accessibilityIdentifier("preferences.\(key)")
            } else {
                TextField(title, text: binding(key))
                    .keyboardType(keyboard)
                    .focused($focusedField, equals: key)
                    .accessibilityIdentifier("preferences.\(key)")
                    .textContentType(key == "name" ? .name : nil)
            }
        }
        .autocorrectionDisabled()
        .textInputAutocapitalization(key == "name" ? .words : .never)
        .padding(.vertical, 6)
        .frame(minHeight: 44)
    }
    private func picker(_ key: String, choices: [(String, String)]) -> some View {
        Picker(PreferenceFields.label(key), selection: binding(key)) {
            Text("Not set").tag("")
            ForEach(choices, id: \.0) { value, label in Text(label).tag(value) }
            if let value = fields[key], !value.isEmpty, !choices.contains(where: { $0.0 == value }) {
                Text(value).tag(value)
            }
        }
        .accessibilityIdentifier("preferences.\(key)")
        .frame(minHeight: 44)
    }
}
