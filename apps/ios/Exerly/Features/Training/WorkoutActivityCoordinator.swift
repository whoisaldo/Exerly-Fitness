import ActivityKit
import ExerlyCore
import Foundation
import Observation

/// Keeps one Live Activity in step with the workout in progress: requested
/// when the workout starts, updated on every set and rest change, and ended
/// when the workout is finished or discarded. The only code that calls ActivityKit.
@MainActor
@Observable
final class WorkoutActivityCoordinator {
    static let shared = WorkoutActivityCoordinator()

    /// What ActivityKit holds, for the UI tests' debug readout.
    private(set) var readout = "none"
    /// The unit loads are written in, from the screens that follow the store.
    @ObservationIgnored private(set) var unit = MassUnit.saved
    /// Workouts an activity was requested for in this process, so one the
    /// person dismissed isn't brought back on their next set.
    @ObservationIgnored private var requested: Set<UUID> = []

    /// Shows the store's workout until the calling task is cancelled.
    func follow(_ store: TrainingStore, unit: MassUnit) async {
        self.unit = unit
        for await content in Observations({ @MainActor in WorkoutActivityContent(store: store, unit: unit) }) {
            await show(content)
        }
    }

    /// Makes ActivityKit match `content`: one activity for that workout, none for any other.
    func show(_ content: WorkoutActivityContent?) async {
        let activities = Activity<WorkoutActivityAttributes>.activities
        for activity in activities where activity.attributes.workoutID != content?.workoutID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        if let content {
            // Stale when rest ends, so the activity drops its countdown without the app.
            let update = ActivityContent(state: content.state, staleDate: content.state.rest?.endsAt)
            if let current = activities.first(where: { $0.attributes.workoutID == content.workoutID }) {
                let live = current.activityState == .active || current.activityState == .stale
                if live, current.content.state != update.state || current.content.staleDate != update.staleDate {
                    await current.update(update)
                }
            } else if !requested.contains(content.workoutID), ActivityAuthorizationInfo().areActivitiesEnabled {
                do {
                    _ = try Activity.request(attributes: WorkoutActivityAttributes(workoutID: content.workoutID), content: update)
                    requested.insert(content.workoutID)
                } catch {
                    // Activities start only while the app is in front; the next change tries again.
                }
            }
        }
        readout = Self.describe(Activity<WorkoutActivityAttributes>.activities)
    }

    func endAll() async { await show(nil) }

    private static func describe(_ activities: [Activity<WorkoutActivityAttributes>]) -> String {
        guard !activities.isEmpty else { return "none" }
        return activities.map { activity in
            let state = activity.content.state
            return "\(activity.activityState) \(state.title) \(state.setsLabel)\(state.rest == nil ? "" : " resting")"
        }.joined(separator: "; ")
    }
}

/// The Live Activity's buttons, run in the app's process. With the account's
/// screens open, the change goes through their store; after a launch in the
/// background for the button, the account's store is opened just for it.
@MainActor
enum WorkoutActivityActions {
    /// The app's account owner, registered by the root view.
    static weak var account: AppAccountWorkspace?

    static func install() {
        WorkoutActivityIntentHandler.perform = { workoutID, command in await perform(command, on: workoutID) }
    }

    static func perform(_ command: WorkoutActivityCommand, on workoutID: UUID) async {
        let coordinator = WorkoutActivityCoordinator.shared
        if let store = account?.training?.store {
            apply(command, to: workoutID, in: store)
            await coordinator.show(WorkoutActivityContent(store: store, unit: coordinator.unit))
            return
        }
        // Everything up to closing runs without suspending, so the screens
        // can't open the same database mid-change.
        guard let accountID = APIClient.accountID(in: KeychainService.shared.getToken()) else {
            await coordinator.endAll()
            return
        }
        guard let workspace = try? TrainingWorkspace(accountID: accountID) else { return }
        apply(command, to: workoutID, in: workspace.store)
        let content = WorkoutActivityContent(store: workspace.store, unit: .saved)
        await workspace.close()
        await coordinator.show(content)
    }

    /// Applies a button to the workout in progress if it's the one the button
    /// was drawn for. Returns whether the workout changed.
    @discardableResult
    static func apply(_ command: WorkoutActivityCommand, to workoutID: UUID, in store: TrainingStore) -> Bool {
        guard let session = store.activeSession, session.id == workoutID else { return false }
        do {
            switch command {
            case .completeSet(let setID):
                // A second tap on a button already handled finds the set done.
                guard let set = session.set(setID)?.set, !set.isCompleted else { return false }
                try store.completeSet(setID)
            case .extendRest(let seconds):
                guard store.restTimer != nil else { return false }
                try store.extendRest(by: seconds)
            case .skipRest:
                guard store.restTimer != nil else { return false }
                try store.skipRest()
            }
            return true
        } catch {
            return false
        }
    }
}

extension MassUnit {
    /// The signed-in person's unit as last saved on this device.
    static var saved: MassUnit {
        UserDefaults.standard.string(forKey: "unitSystem") == "metric" ? .kilograms : .pounds
    }
}
