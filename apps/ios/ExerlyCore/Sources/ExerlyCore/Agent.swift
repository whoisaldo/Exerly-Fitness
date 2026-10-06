import Foundation

/// Who filed a proposal.
public struct AgentIdentity: Sendable, Codable, Hashable {
    public enum Kind: String, Sendable, Codable, Hashable {
        /// Exerly's own on-device features.
        case builtIn
        /// The person's agent through the MCP server.
        case mcp
        /// The person's agent through the REST API.
        case api
    }

    public var kind: Kind
    public var name: String
    /// The personal access token used, for MCP and API agents.
    public var tokenID: String?

    public init(kind: Kind, name: String, tokenID: String? = nil) {
        self.kind = kind
        self.name = name
        self.tokenID = tokenID
    }
}

/// One document a proposal creates, changes or deletes. `before` is the
/// canonical payload the change was computed against (nil to create);
/// `after` is what it proposes (nil to delete). A UUID `id` is kept in
/// uppercase, however it arrived.
public struct ProposedChange: Sendable, Codable, Hashable {
    public var kind: String
    public var id: String
    public var before: JSONValue?
    public var after: JSONValue?

    public init(kind: String, id: String, before: JSONValue?, after: JSONValue?) {
        self.kind = kind
        self.id = DocumentWrite.canonicalID(id)
        self.before = before
        self.after = after
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(kind: c.decode(String.self, forKey: .kind), id: c.decode(String.self, forKey: .id),
                      before: c.decodeIfPresent(JSONValue.self, forKey: .before),
                      after: c.decodeIfPresent(JSONValue.self, forKey: .after))
    }

    public init<T: Encodable>(kind: String, id: String, before: T?, after: T?) throws {
        var encodedBefore: JSONValue?
        var encodedAfter: JSONValue?
        if let before { encodedBefore = try JSONValue(encoding: before) }
        if let after { encodedAfter = try JSONValue(encoding: after) }
        self.init(kind: kind, id: id, before: encodedBefore, after: encodedAfter)
    }
}

/// How strong a piece of evidence is.
public enum EvidenceLevel: String, Sendable, Codable, Hashable, CaseIterable {
    case humanRCT, observational, mechanism, anecdote
    /// The person's own logged data: n=1.
    case personalData
}

/// A reference to a document. A UUID `id` is kept in uppercase.
public struct DataRef: Sendable, Codable, Hashable {
    public var kind: String
    public var id: String
    public init(kind: String, id: String) {
        self.kind = kind
        self.id = DocumentWrite.canonicalID(id)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(kind: c.decode(String.self, forKey: .kind), id: c.decode(String.self, forKey: .id))
    }
}

public struct Evidence: Sendable, Codable, Hashable {
    public var claim: String
    public var level: EvidenceLevel
    /// Limits such as "n=1", "confounded by sleep" or "three weeks of data".
    public var caveats: [String]
    public var dataRefs: [DataRef]
    /// A number the claim rests on, which ExerlyCore can recompute.
    public var metric: MetricReference?
    /// A citation for research claims.
    public var source: String?

    public init(claim: String, level: EvidenceLevel, caveats: [String] = [], dataRefs: [DataRef] = [],
                metric: MetricReference? = nil, source: String? = nil) {
        self.claim = claim
        self.level = level
        self.caveats = caveats
        self.dataRefs = dataRefs
        self.metric = metric
        self.source = source
    }
}

public enum Confidence: String, Sendable, Codable, Hashable, CaseIterable {
    case low, medium, high
}

public enum ProposalStatus: String, Sendable, Codable, Hashable {
    case pending, accepted, rejected, undone
    /// The data changed after the proposal was made, so it can no longer apply.
    case stale
}

/// A reviewable change from an agent. Nothing changes until the person accepts.
public struct Proposal: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var createdAt: Date
    public var author: AgentIdentity
    public var title: String
    public var summary: String
    public var changes: [ProposedChange]
    public var evidence: [Evidence]
    public var confidence: Confidence
    /// What would show this proposal is wrong.
    public var falsifier: String
    public var status: ProposalStatus
    public var decidedAt: Date?

    public init(id: UUID = UUID(), createdAt: Date = Date().roundedToMilliseconds, author: AgentIdentity, title: String,
                summary: String, changes: [ProposedChange], evidence: [Evidence], confidence: Confidence, falsifier: String) {
        self.id = id
        self.createdAt = createdAt
        self.author = author
        self.title = title
        self.summary = summary
        self.changes = changes
        self.evidence = evidence
        self.confidence = confidence
        self.falsifier = falsifier
        status = .pending
        decidedAt = nil
    }
}

/// An append-only record of something an agent or the person did with agents.
public struct AuditEvent: Sendable, Codable, Hashable, Identifiable {
    public enum Action: String, Sendable, Codable, Hashable {
        case proposalFiled, proposalAccepted, proposalRejected, proposalUndone, proposalStale
        case directWrite, tokenCreated, tokenRevoked
    }

    public var id: UUID
    public var at: Date
    public var action: Action
    public var actor: AgentIdentity
    public var proposalID: UUID?
    public var targets: [DataRef]
    public var note: String?

    public init(id: UUID = UUID(), at: Date, action: Action, actor: AgentIdentity, proposalID: UUID? = nil,
                targets: [DataRef] = [], note: String? = nil) {
        self.id = id
        self.at = at
        self.action = action
        self.actor = actor
        self.proposalID = proposalID
        self.targets = targets
        self.note = note
    }
}

// MARK: Metric references

/// A number an agent's claim rests on, named so ExerlyCore can recompute it.
public struct MetricReference: Sendable, Codable, Hashable {
    public var name: String
    public var parameters: [String: String]
    public var claimed: Double

    public init(name: String, parameters: [String: String], claimed: Double) {
        self.name = name
        self.parameters = parameters
        self.claimed = claimed
    }

    public enum Verification: Sendable, Hashable {
        case verified(actual: Double)
        case mismatch(actual: Double)
        /// ExerlyCore doesn't know this metric, or the data doesn't support it.
        case unverifiable
    }

    /// Best estimated 1RM, in kilograms, for sessions with local dates in the range.
    public static func bestOneRepMax(exercise: ExerciseID, from: LocalDate, through: LocalDate, claimedKilograms: Double) -> MetricReference {
        MetricReference(name: "exercise.e1rm.best",
                        parameters: ["exercise": exercise.rawValue, "from": from.description, "through": through.description],
                        claimed: claimedKilograms)
    }

    /// Total volume in kilogram-reps for sessions with local dates in the range.
    public static func totalVolume(exercise: ExerciseID, from: LocalDate, through: LocalDate, claimedKilogramReps: Double) -> MetricReference {
        MetricReference(name: "exercise.volume.total",
                        parameters: ["exercise": exercise.rawValue, "from": from.description, "through": through.description],
                        claimed: claimedKilogramReps)
    }

    /// Fractional sets for a muscle in the week starting on a date.
    public static func weeklySets(muscle: Muscle, weekStarting: LocalDate, firstWeekday: Weekday, claimed: Double) -> MetricReference {
        MetricReference(name: "muscle.sets.week",
                        parameters: ["muscle": muscle.rawValue, "week": weekStarting.description,
                                     "firstWeekday": String(firstWeekday.rawValue)],
                        claimed: claimed)
    }

    /// Recomputes the metric. Values agree within 0.5 % or 0.01.
    public func verify(against history: TrainingHistory) -> Verification {
        guard let actual = compute(history) else { return .unverifiable }
        let tolerance = max(0.01, abs(actual) * 0.005)
        return abs(actual - claimed) <= tolerance ? .verified(actual: actual) : .mismatch(actual: actual)
    }

    private func compute(_ history: TrainingHistory) -> Double? {
        switch name {
        case "exercise.e1rm.best", "exercise.volume.total":
            guard let exercise = parameters["exercise"], let from = parameters["from"].flatMap(LocalDate.init),
                  let through = parameters["through"].flatMap(LocalDate.init),
                  let stats = history.statistics(of: ExerciseID(exercise), from: from, through: through)
            else { return nil }
            return name == "exercise.e1rm.best" ? stats.estimatedOneRepMax?.kilograms : stats.totalVolume
        case "muscle.sets.week":
            guard let muscle = parameters["muscle"].flatMap(Muscle.init(rawValue:)),
                  let week = parameters["week"].flatMap(LocalDate.init),
                  let weekday = parameters["firstWeekday"].flatMap(Int.init).flatMap(Weekday.init(rawValue:))
            else { return nil }
            return history.weeklyMuscleVolume(firstWeekday: weekday)[week]?[muscle]?.sets ?? 0
        default:
            return nil
        }
    }
}
