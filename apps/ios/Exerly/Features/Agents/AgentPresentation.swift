import Combine
import ExerlyCore
import Foundation

@MainActor
final class AgentReviewModel: ObservableObject {
    enum Decision { case accept, reject, undo }
    @Published private(set) var error: String?
    private let store: AgentStore
    private let onDecision: () -> Void

    init(store: AgentStore, onDecision: @escaping () -> Void) {
        self.store = store
        self.onDecision = onDecision
    }

    func decide(_ decision: Decision, proposal id: UUID) {
        error = nil
        do {
            switch decision {
            case .accept: try store.accept(id)
            case .reject: try store.reject(id)
            case .undo: try store.undo(id)
            }
        } catch AgentStore.AgentError.stale {
            error = decision == .undo
                ? "These records changed after the suggestion was accepted. Your later changes were kept."
                : "These records changed after the suggestion was made. Nothing was applied."
        } catch AgentStore.AgentError.invalid(let reason) {
            error = "This suggestion could not be applied. \(reason)"
        } catch AgentStore.AgentError.alreadyDecided {
            error = "This suggestion already has a decision. Open it again to see the latest status."
        } catch {
            self.error = "The decision could not be saved. Your data has not changed. Try again."
        }
        // A refused stale acceptance also records an event that needs syncing.
        onDecision()
    }
}

/// Names and values for a diff computed by Core. Never computes or applies changes.
struct ProposalFieldPresentation {
    let title: String
    let before: String
    let after: String

    init(field: FieldChange, change: ProposedChange, library: ExerlyCore.ExerciseLibrary, unit: MassUnit) {
        let oldSession = try? change.before?.decode(WorkoutSession.self)
        let newSession = try? change.after?.decode(WorkoutSession.self)
        let context = newSession ?? oldSession
        let indices = Self.indices(field.path)
        var labels: [String] = []
        if let index = indices.exercise, let session = context, session.exercises.indices.contains(index) {
            let exercise = session.exercises[index]
            labels.append(library.exercise(exercise.exerciseID)?.name ?? "Exercise \(index + 1)")
        }
        if let index = indices.set { labels.append("Set \(index + 1)") }
        if let index = indices.effort, index > 0 { labels.append("Continuation \(index)") }
        let leaf = field.path.components(separatedBy: ".").last ?? ""
        if field.path.contains(".load") {
            labels.append("Load")
            before = Self.load(in: oldSession, indices: indices, unit: unit) ?? AgentFormat.value(field.before)
            after = Self.load(in: newSession, indices: indices, unit: unit) ?? AgentFormat.value(field.after)
        } else {
            labels.append(Self.label(leaf))
            before = Self.display(field.before, leaf: leaf)
            after = Self.display(field.after, leaf: leaf)
        }
        title = labels.joined(separator: " · ")
    }

    private struct Indices { var exercise: Int?; var set: Int?; var effort: Int? }

    private static func indices(_ path: String) -> Indices {
        func index(_ name: String) -> Int? {
            let pattern = NSRegularExpression.escapedPattern(for: name) + #"\[(\d+)\]"#
            guard let expression = try? NSRegularExpression(pattern: pattern),
                  let match = expression.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
                  let range = Range(match.range(at: 1), in: path) else { return nil }
            return Int(path[range])
        }
        return Indices(exercise: index("exercises"), set: index("sets"), effort: index("efforts"))
    }

    private static func load(in session: WorkoutSession?, indices: Indices, unit: MassUnit) -> String? {
        guard let session, let exercise = indices.exercise, let set = indices.set, let effort = indices.effort,
              session.exercises.indices.contains(exercise),
              session.exercises[exercise].sets.indices.contains(set),
              session.exercises[exercise].sets[set].efforts.indices.contains(effort),
              let load = session.exercises[exercise].sets[set].efforts[effort].load else { return nil }
        return TrainingFormat.mass(load, unit: unit)
    }

    private static func label(_ leaf: String) -> String {
        switch leaf {
        case "": "Whole record"
        case "rir": "Reps in reserve"
        case "reps": "Reps"
        case "duration": "Duration"
        case "distance": "Distance"
        case "kind": "Set type"
        case "side": "Side"
        case "notes": "Notes"
        case "name": "Name"
        case "completedAt": "Completion time"
        case "startedAt": "Start time"
        case "endedAt": "End time"
        case "timeZoneID": "Time zone"
        case "exerciseID": "Exercise"
        case "restOverride": "Rest time"
        default: TrainingFormat.words(leaf)
        }
    }

    private static func display(_ value: ExerlyCore.JSONValue?, leaf: String) -> String {
        guard case .number(let number) = value else { return AgentFormat.value(value) }
        switch leaf {
        case "duration", "restOverride": return "\(TrainingFormat.number(number)) seconds"
        case "distance": return "\(TrainingFormat.number(number)) metres"
        default: return AgentFormat.value(value)
        }
    }
}

struct MetricPresentation {
    enum Status { case verified, mismatch, unavailable }
    let status: Status
    let title: String
    let claimed: String
    let actual: String?

    init(metric: MetricReference, history: TrainingHistory, unit: MassUnit) {
        func format(_ value: Double) -> String {
            switch metric.name {
            case "exercise.e1rm.best": TrainingFormat.mass(.kg(value), unit: unit)
            case "exercise.volume.total": "\(TrainingFormat.number(value)) kg·reps"
            case "muscle.sets.week": "\(TrainingFormat.number(value)) sets"
            default: TrainingFormat.number(value)
            }
        }
        title = switch metric.name {
        case "exercise.e1rm.best": "Best estimated one-rep max"
        case "exercise.volume.total": "Total training volume"
        case "muscle.sets.week": "Weekly muscle sets"
        default: "Reported metric"
        }
        claimed = format(metric.claimed)
        switch metric.verify(against: history) {
        case .verified(let number): status = .verified; actual = format(number)
        case .mismatch(let number): status = .mismatch; actual = format(number)
        case .unverifiable: status = .unavailable; actual = nil
        }
    }
}

enum AgentFormat {
    static func value(_ value: ExerlyCore.JSONValue?) -> String {
        guard let value else { return "Not present" }
        switch value {
        case .null: return "Not set"
        case .string(let string): return string.isEmpty ? "Empty" : string
        case .bool(let flag): return flag ? "Yes" : "No"
        case .number(let number): return number.formatted(.number.grouping(.never).precision(.fractionLength(0...12)))
        case .array, .object:
            return String(data: value.canonicalData, encoding: .utf8) ?? "Could not display value"
        }
    }

    static func status(_ status: ProposalStatus) -> String {
        switch status {
        case .pending: "Awaiting your review"
        case .accepted: "Accepted"
        case .rejected: "Rejected"
        case .undone: "Undone"
        case .stale: "Data changed"
        }
    }

    static func level(_ level: EvidenceLevel) -> String {
        switch level {
        case .humanRCT: "Human randomized trial"
        case .observational: "Observational research"
        case .mechanism: "Proposed mechanism"
        case .anecdote: "Anecdote"
        case .personalData: "Your logged data · n=1"
        }
    }

    static func action(_ action: AuditEvent.Action) -> String {
        switch action {
        case .proposalFiled: "Suggestion received"
        case .proposalAccepted: "Suggestion accepted"
        case .proposalRejected: "Suggestion rejected"
        case .proposalUndone: "Suggestion undone"
        case .proposalStale: "Suggestion no longer applies"
        case .directWrite: "Records changed directly"
        case .tokenCreated: "Agent access created"
        case .tokenRevoked: "Agent access revoked"
        }
    }
}
