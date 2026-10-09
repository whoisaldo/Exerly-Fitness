import Foundation
import ExerlyCore
import Combine

/// App composition: the account determines which Core store a screen can open.
@MainActor
final class TrainingWorkspace: ObservableObject {
    let identity = UUID()
    let accountID: String
    let url: URL
    let store: TrainingStore
    let programs: ProgramStore
    let gyms: GymStore
    let nutrition: NutritionStore
    let agent: AgentStore
    let entryChecks: TrainingEntryChecks
    private let persistence: SQLiteTrainingPersistence
    @Published private(set) var sync: ExerlyCore.SyncEngine?
    @Published private(set) var nutritionSetupError: String?
    private var accountAPI: AccountAPI?
    private var checkedLegacyTargets = false
    private var adoptingLegacyTargets = false
    let unreadableCount: Int

    enum AccessError: Error { case missingAccount }

    init(accountID: String, root: URL? = nil, api: AccountAPI? = nil) throws {
        self.accountID = accountID
        guard !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccessError.missingAccount
        }
        let canonical = try SQLiteTrainingPersistence.defaultURL(accountID: accountID)
        if let testRoot = try root ?? Self.testStorageRoot() {
            url = testRoot.appendingPathComponent(accountID, isDirectory: true)
                .appendingPathComponent(canonical.lastPathComponent)
        } else {
            url = canonical
        }
        persistence = try SQLiteTrainingPersistence(url: url)
        store = try TrainingStore(persistence: persistence)
        programs = try ProgramStore(persistence: persistence, training: store)
        gyms = try GymStore(persistence: persistence)
        nutrition = try NutritionStore(persistence: persistence)
        agent = try AgentStore(persistence: persistence, hosts: [store, programs, nutrition, gyms])
        entryChecks = TrainingEntryChecks(training: store, agent: agent, accountID: accountID)
        unreadableCount = persistence.unreadableRows.count
        if let api { resumeSync(api: api) }
    }

    func resumeSync(api: AccountAPI) {
        guard api.accountID == accountID, !persistence.isClosed else { return }
        accountAPI = api
        sync = ExerlyCore.SyncEngine(hosts: [store, programs, nutrition, gyms, agent], state: persistence, api: api)
    }

    func synchronize() async {
        // Core exposes the durable state to the UI; cancellation is expected at
        // account changes and when the scene moves to the background.
        guard !persistence.isClosed, !Task.isCancelled else { return }
        await entryChecks.refresh()
        do {
            try await sync?.sync()
            guard !persistence.isClosed, !Task.isCancelled else { return }
            if !checkedLegacyTargets, !adoptingLegacyTargets, let accountAPI {
                adoptingLegacyTargets = true
                defer { adoptingLegacyTargets = false }
                if nutrition.plans.isEmpty {
                    _ = try await accountAPI.adoptLegacyTargets()
                    guard !persistence.isClosed, !Task.isCancelled else { return }
                    try await sync?.sync()
                }
                checkedLegacyTargets = true
                nutritionSetupError = nil
            }
        } catch {
            if !checkedLegacyTargets, nutrition.plans.isEmpty, !persistence.isClosed {
                nutritionSetupError = "Your nutrition targets could not load. Pull down to retry."
            }
        }
        guard !persistence.isClosed, !Task.isCancelled else { return }
        if await entryChecks.refresh() { try? await sync?.sync() }
    }

    func nextWorkout(bodyweight: Mass?) -> WorkoutPlan? {
        programs.nextWorkout(bodyweight: bodyweight, increments: gyms.increments(for:))
    }

    /// The latest weigh-in, used for bodyweight exercises without asking.
    var latestBodyweight: Mass? { nutrition.weights.last?.weight }

    /// Starts the next workout of the active program, with the latest
    /// weigh-in. Returns false when the program has nothing left to do.
    @discardableResult
    func startNextWorkout(timeZone: TimeZone) throws -> Bool {
        guard let plan = nextWorkout(bodyweight: latestBodyweight) else { return false }
        try store.startSession(from: plan, bodyweight: latestBodyweight, timeZone: timeZone)
        return true
    }

    /// Each program slot's target for the cycle a session was planned from,
    /// by slot ID. Empty for a workout started without a program.
    func slotTargets(for session: WorkoutSession) -> [UUID: SlotTarget] {
        guard let reference = session.program, let program = programs.program(reference.programID) else { return [:] }
        var targets: [UUID: SlotTarget] = [:]
        for day in program.days {
            for slot in day.slots { targets[slot.id] = program.target(for: slot, cycle: reference.cycle) }
        }
        return targets
    }

    func close() async {
        accountAPI = nil
        entryChecks.stop()
        await sync?.shutdown()
        persistence.close()
    }

    func export(server: Data?, pending: [AccountExport.PendingRow] = []) throws -> Data {
        try AccountExport.merging(server: server, hosts: [store, programs, nutrition, gyms, agent], state: persistence, pending: pending)
    }

    func supportsChanges(in proposal: Proposal) -> Bool {
        let kinds = store.documentKinds + programs.documentKinds + nutrition.documentKinds + gyms.documentKinds
        return proposal.changes.allSatisfy { kinds.contains($0.kind) }
    }

    static func deleteStorage(accountID: String, root: URL? = nil) throws {
        _ = try SQLiteTrainingPersistence.defaultURL(accountID: accountID)
        if let root = try root ?? testStorageRoot() {
            let directory = root.appendingPathComponent(accountID, isDirectory: true)
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
        } else { try SQLiteTrainingPersistence.deleteDatabase(accountID: accountID) }
        TrainingEntryChecks.removePreference(accountID: accountID)
    }

    private static func testStorageRoot() throws -> URL? {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["EXERLY_TEST_STORE_ID"], UUID(uuidString: id) != nil {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
            return base.appendingPathComponent("SimulatorTests/\(id)/Training", isDirectory: true)
        }
        #endif
        return nil
    }
}

enum TrainingInput {
    // Input syntax belongs to the editor. Core still decides whether a set is loggable.
    static func number(_ text: String, locale: Locale = .current) -> Double? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = input.replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
        guard normalized.range(of: #"^[0-9]+(?:\.[0-9]*)?$"#, options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    static func reps(_ text: String) -> Int? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(input)
    }
}

enum TrainingFormat {
    static func number(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...3)))
    }

    static func mass(_ mass: Mass, unit: MassUnit) -> String {
        "\(number(mass.value(in: unit))) \(unit == .kilograms ? "kg" : "lb")"
    }

    static func set(_ set: PerformedSet, unit: MassUnit) -> String {
        let values = set.efforts.map { effort in
            var parts: [String] = []
            if let load = effort.load { parts.append(mass(load, unit: unit)) }
            if let reps = effort.reps { parts.append("\(reps) reps") }
            if let duration = effort.duration { parts.append("\(number(duration)) s") }
            if let distance = effort.distance { parts.append("\(number(distance)) m") }
            return parts.isEmpty ? "Enter values" : parts.joined(separator: " × ")
        }.joined(separator: " → ")
        return values
    }

    static func kind(_ kind: SetKind) -> String {
        switch kind {
        case .standard: "Working"
        case .warmUp: "Warm-up"
        case .drop: "Drop"
        case .myo: "Myo"
        case .failure: "To failure"
        }
    }

    /// The letter shown in place of the set number, for sets that aren't working sets.
    static func badge(_ kind: SetKind) -> String? {
        switch kind {
        case .standard: nil
        case .warmUp: "W"
        case .drop: "D"
        case .myo: "M"
        case .failure: "F"
        }
    }

    static func unitSymbol(_ unit: MassUnit) -> String { unit == .kilograms ? "kg" : "lb" }

    /// "3 × 5–8 · 2 RIR", or "3 sets" when the exercise doesn't count reps.
    static func compactTarget(_ target: SlotTarget, exercise: ExerlyCore.Exercise?) -> String {
        guard exercise?.metric.tracksReps == true else { return target.sets == 1 ? "1 set" : "\(target.sets) sets" }
        let reps = target.minReps == target.maxReps ? "\(target.minReps)" : "\(target.minReps)–\(target.maxReps)"
        return "\(target.sets) × \(reps) · \(number(target.rir)) RIR"
    }

    /// A set's values in a few characters, for the Previous column: "155 × 8",
    /// "BW × 9", "+10 × 8", "45 s", "400 m".
    static func compact(_ set: PerformedSet, metric: TrackingMetric, unit: MassUnit) -> String {
        let effort = set.primary
        let load = effort.load.map { number($0.value(in: unit)) }
        let text: String
        switch metric {
        case .weightReps: text = "\(load ?? "–") × \(effort.reps.map(String.init) ?? "–")"
        case .bodyweightReps: text = "\(load.map { "+" + $0 } ?? "BW") × \(effort.reps.map(String.init) ?? "–")"
        case .assistedReps: text = "\(load.map { "−" + $0 } ?? "BW") × \(effort.reps.map(String.init) ?? "–")"
        case .duration: text = effort.duration.map { "\(number($0)) s" } ?? "–"
        case .weightDuration: text = "\(load ?? "–") · \(effort.duration.map { "\(number($0)) s" } ?? "–")"
        case .distanceDuration: text = effort.distance.map { "\(number($0)) m" } ?? effort.duration.map { "\(number($0)) s" } ?? "–"
        case .weightDistance: text = "\(load ?? "–") · \(effort.distance.map { "\(number($0)) m" } ?? "–")"
        }
        return set.efforts.count > 1 ? text + " +\(set.efforts.count - 1)" : text
    }

    /// "4,520 lb" of volume.
    static func volume(_ tonnage: Tonnage, unit: MassUnit) -> String {
        "\(tonnage.total(in: unit).formatted(.number.precision(.fractionLength(0)))) \(unitSymbol(unit))"
    }

    /// "52 min" or "1 h 5 min".
    static func minutes(_ seconds: Double) -> String {
        let total = max(1, Int((seconds / 60).rounded()))
        return total < 60 ? "\(total) min" : "\(total / 60) h\(total % 60 == 0 ? "" : " \(total % 60) min")"
    }

    /// A name for a workout started without a plan, from the time of day.
    static func emptyWorkoutName(at date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        switch calendar.component(.hour, from: date) {
        case 4..<12: return "Morning workout"
        case 12..<17: return "Afternoon workout"
        default: return "Evening workout"
        }
    }

    static func words(_ raw: String) -> String {
        raw.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }

    static func date(_ session: WorkoutSession) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = session.timeZone
        return formatter.string(from: session.startedAt)
    }

    static func error(_ error: Error) -> String {
        if case TrainingStore.StoreError.edit(.incomplete) = error {
            return "Enter the required values before completing this set."
        }
        return "The change could not be saved. Your last saved workout is still on this device. Try again."
    }
}
