import ExerlyCore
import Foundation
import Observation
import WatchConnectivity

/// Keeps the watch app in step with the open account: publishes what it shows
/// as WatchConnectivity's application context whenever that changes, and runs
/// its commands, in the order sent, with the store calls the screens use. The
/// only code on the phone that calls WatchConnectivity.
@MainActor
final class WatchCoordinator: NSObject {
    static let shared = WatchCoordinator()

    private var session: WCSession? { WCSession.isSupported() ? .default : nil }
    private var unit = MassUnit.saved
    private var timeZone = TimeZone.current
    /// The last state published, sent again once the session can carry it.
    private var latest: WatchState?
    private var revision: Int64 = 0
    /// The command running now; the next one waits for it.
    private var running: Task<WatchState?, Never>?
    private let defaults = UserDefaults.standard

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Publishes the account's workout until the calling task is cancelled.
    func follow(_ workspace: TrainingWorkspace, unit: MassUnit, timeZone: TimeZone) async {
        self.unit = unit
        self.timeZone = timeZone
        for await state in Observations({ @MainActor in self.state(of: workspace, unit: unit) }) {
            publish(state)
        }
    }

    func signOut() { publish(WatchState(signedIn: false)) }

    private func state(of workspace: TrainingWorkspace, unit: MassUnit) -> WatchState {
        WatchState(workspace: workspace, unit: unit, savesToHealth: HealthSync.shared.writesWorkouts(accountID: workspace.accountID),
                   handled: defaults.string(forKey: Self.handledKey).flatMap(UUID.init))
    }

    private func publish(_ state: WatchState) {
        var state = state
        revision = max(revision + 1, Int64(Date().timeIntervalSince1970 * 1000))
        state.revision = revision
        latest = state
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(WatchLink.payload(state))
    }

    private func republish() {
        if let latest { publish(latest) }
    }

    /// Queues a command behind the ones before it. Returns the state after it.
    private func enqueue(_ command: WatchCommand) -> Task<WatchState?, Never> {
        let previous = running
        let task = Task { @MainActor in
            _ = await previous?.value
            return await self.perform(command)
        }
        running = task
        return task
    }

    /// With the account's screens open, the change goes through their
    /// workspace; after a launch in the background for the watch, the
    /// account's workspace is opened just for it.
    private func perform(_ command: WatchCommand) async -> WatchState? {
        // A message that timed out is sent again as a transfer; run it once.
        let fresh = !seen.contains(command.id.uuidString)
        seen = Array((seen + [command.id.uuidString]).suffix(50))
        defaults.set(command.id.uuidString, forKey: Self.handledKey)
        if let workspace = WorkoutActivityActions.account?.training {
            if fresh, Self.apply(command, to: workspace, unit: unit, timeZone: timeZone),
               [WatchCommand.Action.start, .finish].contains(command.action) {
                Task { await workspace.synchronize() }
            }
            publish(state(of: workspace, unit: unit))
            return latest
        }
        guard let accountID = APIClient.accountID(in: KeychainService.shared.getToken()) else {
            signOut()
            return latest
        }
        // Everything up to closing runs without suspending, so the screens
        // can't open the same database mid-change.
        guard let workspace = try? TrainingWorkspace(accountID: accountID) else { return nil }
        if fresh { Self.apply(command, to: workspace, unit: .saved, timeZone: timeZone) }
        let state = state(of: workspace, unit: .saved)
        let activity = WorkoutActivityContent(store: workspace.store, unit: .saved)
        await workspace.close()
        publish(state)
        await WorkoutActivityCoordinator.shared.show(activity)
        return latest
    }

    private static let handledKey = "watch.handledCommand"
    private var seen: [String] {
        get { defaults.stringArray(forKey: "watch.seenCommands") ?? [] }
        set { defaults.set(newValue, forKey: "watch.seenCommands") }
    }

    /// Applies a watch command if it's for the workout in progress, or starts
    /// the next workout when none is. Returns whether anything changed.
    @discardableResult
    static func apply(_ command: WatchCommand, to workspace: TrainingWorkspace, unit: MassUnit, timeZone: TimeZone,
                      defaults: UserDefaults = .standard) -> Bool {
        let store = workspace.store
        // Kept even after the workout ends, until the phone's Health export runs.
        if command.action == .recording, let id = command.workoutID {
            WatchHealthWorkouts.insert(id, defaults: defaults)
            return true
        }
        guard let session = store.activeSession else {
            guard command.action == .start else { return false }
            return (try? workspace.startNextWorkout(timeZone: timeZone, unit: unit)) ?? false
        }
        guard session.id == command.workoutID else { return false }
        do {
            switch command.action {
            case .start, .recording:
                return false
            case .completeSet(let setID, let weight, let reps, let unit):
                // A second message for a set already handled finds it done.
                guard let (performedID, original) = session.set(setID), !original.isCompleted else { return false }
                var set = original
                if let weight { set.primary.load = Mass(weight, unit == "kg" ? .kilograms : .pounds) }
                if let reps { set.primary.reps = reps }
                // Later sets still holding the old values follow, as when edited on the phone.
                if set != original { try store.updateSet(set, in: performedID, propagate: true) }
                try store.completeSet(setID)
            case .extendRest(let seconds):
                guard store.restTimer != nil else { return false }
                try store.extendRest(by: seconds)
            case .skipRest:
                guard store.restTimer != nil else { return false }
                try store.skipRest()
            case .finish:
                // Nothing logged is nothing to save.
                if store.summary(of: session).completedSets == 0 { try store.discardSession() } else { try store.finishSession() }
            }
            return true
        } catch {
            return false
        }
    }
}

extension WatchCoordinator: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.republish() }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.republish() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        guard let command = WatchLink.command(from: message) else { return replyHandler([:]) }
        // The main queue keeps arrival order; the reply carries the new state.
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let task = self.enqueue(command)
                Task { replyHandler((await task.value).map(WatchLink.payload) ?? [:]) }
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let command = WatchLink.command(from: userInfo) else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated { _ = self.enqueue(command) }
        }
    }
}

/// Workouts the watch records in Health itself, with heart rate and energy,
/// so the phone doesn't write them a second time.
enum WatchHealthWorkouts {
    private static let key = "watch.healthWorkouts"

    static func contains(_ id: UUID, defaults: UserDefaults = .standard) -> Bool {
        defaults.stringArray(forKey: key)?.contains(id.uuidString) == true
    }

    static func insert(_ id: UUID, defaults: UserDefaults = .standard) {
        let ids = (defaults.stringArray(forKey: key) ?? []).filter { $0 != id.uuidString }
        defaults.set(Array((ids + [id.uuidString]).suffix(50)), forKey: key)
    }
}

extension WatchState {
    /// What the watch shows for the account: the workout in progress with
    /// every set still to do, or the program's next workout.
    @MainActor
    init(workspace: TrainingWorkspace, unit: MassUnit, savesToHealth: Bool, handled: UUID?, now: Date = .now) {
        let store = workspace.store
        self.init(signedIn: true, savesToHealth: savesToHealth, handled: handled)
        finished = store.history.sessions.max { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) }?.id
        guard let session = store.activeSession else {
            planned = workspace.nextWorkout(bodyweight: workspace.latestBodyweight, unit: unit).map { plan in
                let title = TrainingFormat.title(plan.name, planned: plan.program != nil)
                return Planned(title: title.name, program: title.program, exercises: plan.exercises.count,
                               sets: plan.exercises.reduce(0) { $0 + $1.recommendation.sets.count })
            }
            return
        }
        let library = store.library
        var upcoming: [WatchSet] = []
        var cursor = session.nextSet(after: nil)
        while let position = cursor, !upcoming.contains(where: { $0.id == position.setID }),
              let performed = session.exercises.first(where: { $0.id == position.performedID }),
              let index = performed.sets.firstIndex(where: { $0.id == position.setID }),
              let exercise = library.exercise(performed.exerciseID) {
            let set = performed.sets[index]
            let values = WorkoutActivityContent.values(set, metric: exercise.metric, unit: unit)
            upcoming.append(WatchSet(
                id: set.id, exerciseID: performed.id, exercise: exercise.name, number: index + 1, count: performed.sets.count,
                weight: exercise.metric == .weightReps ? set.primary.load.map { Self.round($0.value(in: unit)) } : nil,
                reps: exercise.metric.tracksReps ? set.primary.reps ?? 0 : nil,
                values: values.text, spokenValues: values.spoken, isLoggable: set.isLoggable(for: exercise),
                rest: store.restPolicy.rest(after: set.id, in: session, library: library)))
            cursor = session.nextSet(after: position.setID)
        }
        var loads: [String: [Double]] = [:]
        for performed in session.exercises where performed.sets.contains(where: { !$0.isCompleted }) {
            guard let exercise = library.exercise(performed.exerciseID), exercise.metric == .weightReps else { continue }
            let planned = performed.sets.compactMap { $0.primary.load.map { Self.round($0.value(in: unit)) } }
            loads[performed.id.uuidString] = Self.loads(workspace.gyms.increments(for: exercise), around: planned, unit: unit)
        }
        let sets = session.exercises.flatMap(\.sets)
        let title = TrainingFormat.title(of: session)
        active = Active(id: session.id, title: title.name, startedAt: session.startedAt,
                        completedSets: sets.filter(\.isCompleted).count, totalSets: sets.count,
                        unit: TrainingFormat.unitSymbol(unit),
                        rest: store.restTimer.flatMap { $0.isFinished(at: now) ? nil : Rest(startedAt: $0.startedAt, endsAt: $0.endsAt) },
                        upcoming: upcoming, loads: loads)
    }

    /// Every weight the equipment allows, from the lightest to well past the
    /// heaviest planned, plus the planned weights themselves; at most 200.
    static func loads(_ increments: LoadIncrements, around planned: [Double], unit: MassUnit) -> [Double] {
        var load = increments.stepped(0, up: true, in: unit)
        let top = max(planned.max() ?? 0, load) * 1.5 + 40 * increments.step(in: unit)
        var loads: [Double] = []
        while loads.count < 200, load <= top, load > (loads.last ?? -1) {
            loads.append(load)
            load = increments.stepped(load, up: true, in: unit)
        }
        return Array(Set(loads + planned)).sorted()
    }

    /// A weight to the nearest 0.1, as the screens write it.
    private static func round(_ value: Double) -> Double { (value * 10).rounded() / 10 }
}
