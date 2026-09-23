import Foundation
import UserNotifications
import CryptoKit

struct ReminderSpec: Equatable {
    let id: String
    let title: String
    let body: String
    let components: DateComponents
}
struct ReminderPlan {
    let reminders: [ReminderSpec]
    let missing: [String]

    static func make(_ snapshot: PreferencesSnapshot, namespace: String) throws -> ReminderPlan {
        guard case .string(let zone) = snapshot.value("timezone"), let timezone = TimeZone(identifier: zone) else {
            throw PreferencesError.message("Choose a valid time zone before scheduling reminders.")
        }
        let owner = SHA256.hash(data: Data("\(namespace):\(snapshot.accountID)".utf8)).map { String(format: "%02x", $0) }.joined()
        let prefix = "exerly.reminder.\(owner)."
        var reminders: [ReminderSpec] = []
        var missing: [String] = []
        func components(_ raw: JSONValue, weekday: Int? = nil) -> DateComponents? {
            guard case .string(let text) = raw, text.range(of: #"^([01]\d|2[0-3]):[0-5]\d$"#, options: .regularExpression) != nil else { return nil }
            let parts = text.split(separator: ":").compactMap { Int($0) }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timezone
            var result = DateComponents()
            result.calendar = calendar
            result.timeZone = timezone
            result.hour = parts[0]
            result.minute = parts[1]
            result.weekday = weekday
            return result
        }
        if snapshot.value("reminders.meals") == .bool(true) {
            var seen = Set<String>()
            let times: [JSONValue]
            if case .array(let values) = snapshot.value("reminderTimes.meals") { times = values } else { times = [] }
            for time in times.prefix(10) {
                let text = PreferenceFields.text(time)
                if let date = components(time), seen.insert(text).inserted {
                    reminders.append(ReminderSpec(id: prefix + "meal." + text, title: "Meal reminder", body: "Ready to log your meal?", components: date))
                }
            }
            if reminders.isEmpty { missing.append("Choose meal reminder times.") }
        }
        if snapshot.value("reminders.workouts") == .bool(true) {
            let days: [JSONValue]
            if case .array(let values) = snapshot.value("workoutDays") { days = values } else { days = [] }
            let weekdayMap = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
            var seen = Set<Int>()
            for day in days {
                if let weekday = weekdayMap[PreferenceFields.text(day)], seen.insert(weekday).inserted,
                   let date = components(snapshot.value("reminderTimes.workout"), weekday: weekday) {
                    reminders.append(ReminderSpec(id: prefix + "workout.\(weekday)", title: "Workout reminder", body: "Your planned workout is ready when you are.", components: date))
                }
            }
            if !reminders.contains(where: { $0.id.contains(".workout.") }) { missing.append("Choose workout days and a reminder time.") }
        }
        if snapshot.value("reminders.sleep") == .bool(true) {
            if let date = components(snapshot.value("reminderTimes.sleep")) {
                reminders.append(ReminderSpec(id: prefix + "sleep", title: "Sleep reminder", body: "Time to start your bedtime routine.", components: date))
            } else { missing.append("Choose a sleep reminder time.") }
        }
        return ReminderPlan(reminders: reminders, missing: missing)
    }
}

@MainActor
protocol ReminderScheduling {
    func authorization() async -> UNAuthorizationStatus
    func requestPermission() async throws
    func pendingIDs() async -> [String]
    func remove(_ ids: [String])
    func add(_ reminder: ReminderSpec) async throws
}
@MainActor
struct SystemReminderScheduler: ReminderScheduling {
    private let center = UNUserNotificationCenter.current()
    func authorization() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestPermission() async throws { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
    func pendingIDs() async -> [String] { await center.pendingNotificationRequests().map(\.identifier) }
    func remove(_ ids: [String]) { center.removePendingNotificationRequests(withIdentifiers: ids) }
    func add(_ reminder: ReminderSpec) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.components, repeats: true)
        try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
    }
}

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    @Published private(set) var accountID: String?
    @Published private(set) var isDeviceEnabled = false
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var scheduledCount = 0
    @Published private(set) var missing: [String] = []
    @Published private(set) var error: String?
    @Published private(set) var isUpdating = false
    private var snapshot: PreferencesSnapshot?
    private let api: APIClient
    private let defaults: UserDefaults
    private let keychain: any SessionCredentials
    private let scheduler: any ReminderScheduling
    private var ownerGeneration = UUID()
    private var scheduleGeneration = UUID()
    private var scheduleTask: Task<Void, Never>?
    private var didConfigure = false

    init(api: APIClient = .shared, defaults: UserDefaults = .standard,
         keychain: any SessionCredentials = KeychainService.shared, scheduler: (any ReminderScheduling)? = nil) {
        self.api = api
        self.defaults = defaults
        self.keychain = keychain
        self.scheduler = scheduler ?? SystemReminderScheduler()
    }
    private func key(_ accountID: String, suffix: String) -> String { "reminders.v1.\(api.storageNamespace).\(accountID).\(suffix)" }
    private func owns(_ accountID: String) -> Bool { APIClient.accountID(in: keychain.getToken()) == accountID }
    func configure(accountID: String?) {
        guard accountID == nil || owns(accountID!) else { return }
        guard !didConfigure || self.accountID != accountID else { return }
        didConfigure = true
        ownerGeneration = UUID()
        self.accountID = accountID
        snapshot = nil
        scheduledCount = 0
        missing = []
        error = nil
        isDeviceEnabled = accountID.map { defaults.bool(forKey: key($0, suffix: "enabled")) } ?? false
        if let accountID, let data = defaults.data(forKey: key(accountID, suffix: "snapshot")),
           let saved = try? JSONDecoder().decode(PreferencesSnapshot.self, from: data),
           saved.schemaVersion == 1, saved.accountID == accountID, saved.user.id == accountID { snapshot = saved }
        enqueueSchedule()
    }
    func accept(_ snapshot: PreferencesSnapshot) {
        guard snapshot.schemaVersion == 1, snapshot.accountID == accountID, snapshot.user.id == accountID,
              owns(snapshot.accountID),
              snapshot.revision >= (self.snapshot?.revision ?? 0) else { return }
        self.snapshot = snapshot
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: key(snapshot.accountID, suffix: "snapshot")) }
        error = nil
        enqueueSchedule()
    }
    func refresh(accountID: String?) async {
        guard accountID == nil || owns(accountID!) else { return }
        configure(accountID: accountID)
        let generation = ownerGeneration
        guard let accountID else { await waitForSchedule(); return }
        // Permission changes in Settings apply even before a network read
        // finishes. Saved intent remains usable during a connection failure.
        enqueueSchedule()
        do {
            let saved: PreferencesSnapshot = try await api.request("GET", path: "/api/preferences", expectedAccountID: accountID)
            guard generation == ownerGeneration else { return }
            accept(saved)
        } catch is CancellationError { return } catch {
            guard generation == ownerGeneration else { return }
            self.error = "Could not refresh reminder preferences. The saved schedule is kept. Retry when connected."
            enqueueSchedule()
        }
        await waitForSchedule()
    }
    func setDeviceEnabled(_ enabled: Bool) async {
        guard let accountID, owns(accountID) else { return }
        let generation = ownerGeneration
        defaults.set(enabled, forKey: key(accountID, suffix: "enabled"))
        guard defaults.bool(forKey: key(accountID, suffix: "enabled")) == enabled else {
            error = "The reminder setting could not be saved on this iPhone. Try again."
            return
        }
        isDeviceEnabled = enabled
        error = nil
        if enabled {
            let status = await scheduler.authorization()
            guard generation == ownerGeneration else { return }
            if status == .notDetermined {
                do { try await scheduler.requestPermission() } catch { self.error = "Notification permission could not be requested. Try again." }
            }
        }
        guard generation == ownerGeneration else { return }
        enqueueSchedule()
        await waitForSchedule()
    }
    func waitForSchedule() async { await scheduleTask?.value }

    private func enqueueSchedule() {
        let previous = scheduleTask
        scheduleGeneration = UUID()
        let generation = scheduleGeneration
        isUpdating = true
        // Serialize changes so an in-flight add cannot resurrect a reminder
        // after sign-out or after another account has taken over the scheduler.
        scheduleTask = Task { [weak self] in
            await previous?.value
            guard let self, generation == self.scheduleGeneration else { return }
            await self.reconcile(generation)
            if generation == self.scheduleGeneration { self.isUpdating = false }
        }
    }
    private func reconcile(_ generation: UUID) async {
        let status = await scheduler.authorization()
        guard generation == scheduleGeneration else { return }
        if let accountID, !owns(accountID) { configure(accountID: nil); return }
        authorization = status
        var desired: [ReminderSpec] = []
        missing = []
        if isDeviceEnabled, let snapshot,
           status == .authorized || status == .provisional || status == .ephemeral {
            do {
                let plan = try ReminderPlan.make(snapshot, namespace: api.storageNamespace)
                desired = plan.reminders
                missing = plan.missing
            } catch { self.error = error.localizedDescription }
        }
        let desiredIDs = Set(desired.map(\.id))
        let existing = await scheduler.pendingIDs()
        guard generation == scheduleGeneration else { return }
        scheduler.remove(existing.filter { $0.hasPrefix("exerly.reminder.") && !desiredIDs.contains($0) })
        for reminder in desired {
            guard generation == scheduleGeneration else { return }
            if let accountID, !owns(accountID) { configure(accountID: nil); return }
            do { try await scheduler.add(reminder) } catch {
                guard generation == scheduleGeneration else { return }
                self.error = "Some reminders could not be scheduled. Your preferences are saved. Try again."
            }
        }
        let pending = await scheduler.pendingIDs()
        guard generation == scheduleGeneration else { return }
        scheduledCount = pending.filter { desiredIDs.contains($0) }.count
    }
}
