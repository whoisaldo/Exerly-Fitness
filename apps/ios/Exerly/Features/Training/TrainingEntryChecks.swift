import Combine
import ExerlyCore
import Foundation

/// A value snapshot also invalidates checks when a custom exercise changes.
struct TrainingAnalysisInput: Hashable, Sendable {
    let sessions: [WorkoutSession]
    let exercises: [ExerlyCore.Exercise]

    init(_ history: TrainingHistory) {
        sessions = history.sessions
        exercises = history.library.exercises
    }
}

/// Schedules Core's detector without blocking the workout editor or changing logs.
@MainActor
final class TrainingEntryChecks: ObservableObject {
    typealias Evaluator = @Sendable (TrainingHistory, [Proposal], Date) async throws -> [Proposal]

    @Published private(set) var isEnabled: Bool
    @Published private(set) var isChecking = false
    @Published private(set) var error: String?
    private let training: TrainingStore
    private let agent: AgentStore
    private let defaults: UserDefaults
    private let preferenceKey: String
    private let evaluate: Evaluator
    private var completedInput: TrainingAnalysisInput?
    private var pendingInput: TrainingAnalysisInput?
    private var pending: Task<[Proposal], Error>?
    private var generation = 0
    private var stopped = false

    init(training: TrainingStore, agent: AgentStore, accountID: String,
         defaults: UserDefaults = .standard, evaluate: @escaping Evaluator = TrainingEntryChecks.detect) {
        self.training = training
        self.agent = agent
        self.defaults = defaults
        preferenceKey = Self.key(accountID)
        isEnabled = defaults.object(forKey: preferenceKey) as? Bool ?? true
        self.evaluate = evaluate
    }

    func setEnabled(_ enabled: Bool) {
        guard !stopped else { return }
        isEnabled = enabled
        defaults.set(enabled, forKey: preferenceKey)
        cancel()
        completedInput = nil
        error = nil
    }

    /// True only when new suggestions were saved and need syncing.
    @discardableResult
    func refresh() async -> Bool {
        guard isEnabled, !stopped, !Task.isCancelled else { return false }
        let history = training.history
        let input = TrainingAnalysisInput(history)
        guard input != completedInput, input != pendingInput else { return false }
        cancel()
        let current = generation
        pendingInput = input
        isChecking = true
        let existing = agent.proposals
        let evaluate = evaluate
        let now = Date()
        let task = Task.detached(priority: .utility) { try await evaluate(history, existing, now) }
        pending = task
        do {
            let proposals = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            guard current == generation, !stopped, isEnabled else { return false }
            defer { if current == generation { finish() } }
            try Task.checkCancellation()
            // A manual edit or a sync may have arrived while Core was checking.
            guard input == TrainingAnalysisInput(training.history) else {
                finish()
                return await refresh()
            }
            var filed = false
            var failed = false
            for proposal in proposals where agent.proposal(proposal.id) == nil {
                do {
                    try agent.file(proposal)
                    filed = true
                } catch { failed = true }
            }
            completedInput = input
            error = failed ? "Some entry-check suggestions could not be saved. Your workouts are saved. You can retry." : nil
            return filed
        } catch {
            guard current == generation else { return false }
            finish()
            if !Task.isCancelled, !(error is CancellationError), !stopped, isEnabled {
                completedInput = input
                self.error = "Entry checks could not finish. Your workouts are saved. Try again."
            }
            return false
        }
    }

    @discardableResult
    func retry() async -> Bool {
        completedInput = nil
        return await refresh()
    }

    func stop() {
        stopped = true
        cancel()
    }

    static func removePreference(accountID: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(accountID))
    }

    private static func key(_ accountID: String) -> String { "training.entryChecks.\(accountID)" }

    private func cancel() {
        generation += 1
        pending?.cancel()
        finish()
    }

    private func finish() {
        pending = nil
        pendingInput = nil
        isChecking = false
    }

    nonisolated private static func detect(history: TrainingHistory, existing: [Proposal], now: Date) async throws -> [Proposal] {
        try Task.checkCancellation()
        let proposals = try EntryErrorDetector.proposals(in: history, existing: existing, now: now)
        try Task.checkCancellation()
        return proposals
    }
}
