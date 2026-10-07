import Foundation

public enum SetKind: String, Sendable, Codable, Hashable, CaseIterable {
    case warmUp, standard, drop, myo, failure

    /// Warm-ups never count toward volume, statistics or records.
    public var isWorking: Bool { self != .warmUp }
    /// Drop and myo sets hold one effort per continuation.
    public var allowsContinuations: Bool { self == .drop || self == .myo }
}

public enum Side: String, Sendable, Codable, Hashable, CaseIterable {
    case left, right
    public var other: Side { self == .left ? .right : .left }
}

/// One continuous bout of work. A standard set has one; a drop or myo set has
/// one per continuation. Fields not tracked by the exercise's metric stay nil.
public struct Effort: Sendable, Codable, Hashable {
    public var reps: Int?
    /// External load, added load for bodyweight exercises, or assistance for
    /// assisted exercises.
    public var load: Mass?
    /// Seconds.
    public var duration: Double?
    /// Metres.
    public var distance: Double?

    public init(reps: Int? = nil, load: Mass? = nil, duration: Double? = nil, distance: Double? = nil) {
        self.reps = reps
        self.load = load
        self.duration = duration
        self.distance = distance
    }
}

public struct PerformedSet: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var kind: SetKind
    /// Set for unilateral exercises logged one side at a time.
    public var side: Side?
    public var efforts: [Effort]
    /// Reps in reserve, 0 to 6, where 6 means "6 or more".
    public var rir: Double?
    public var completedAt: Date?

    public init(
        id: UUID = UUID(), kind: SetKind = .standard, side: Side? = nil,
        efforts: [Effort] = [Effort()], rir: Double? = nil, completedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.side = side
        self.efforts = efforts.isEmpty ? [Effort()] : efforts
        self.rir = rir
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, side, efforts, rir, completedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(SetKind.self, forKey: .kind)
        side = try c.decodeIfPresent(Side.self, forKey: .side)
        efforts = try c.decode([Effort].self, forKey: .efforts)
        rir = try c.decodeIfPresent(Double.self, forKey: .rir)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        guard !efforts.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .efforts, in: c, debugDescription: "A set needs at least one effort")
        }
    }

    public var isCompleted: Bool { completedAt != nil }
    public var counts: Bool { isCompleted && kind.isWorking }

    /// The first effort: what a standard set records, and the top set of a
    /// drop or myo set.
    public var primary: Effort {
        get { efforts.first ?? Effort() }
        set {
            if efforts.isEmpty { efforts = [newValue] } else { efforts[0] = newValue }
        }
    }

    public var totalReps: Int { efforts.reduce(0) { $0 + ($1.reps ?? 0) } }
    public var totalDuration: Double { efforts.reduce(0) { $0 + ($1.duration ?? 0) } }
    public var totalDistance: Double { efforts.reduce(0) { $0 + ($1.distance ?? 0) } }

    /// RIR that applies to the primary effort. A failure set is RIR 0, and the
    /// top set of a drop or myo set is taken to or near failure.
    public var effectiveRIR: Double? {
        switch kind {
        case .failure: 0
        case .drop, .myo: rir ?? 0
        default: rir
        }
    }

    public static func rir(fromRPE rpe: Double) -> Double { max(0, min(6, 10 - rpe)) }
}

public struct PerformedExercise: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var exerciseID: ExerciseID
    public var sets: [PerformedSet]
    public var notes: String
    /// Exercises sharing a superset ID are performed as one round.
    public var supersetID: UUID?
    /// Overrides the policy's rest after each set of this exercise, in seconds.
    public var restOverride: Double?
    /// The program slot it was planned from, kept through a swap.
    public var slotID: UUID?

    public init(
        id: UUID = UUID(), exerciseID: ExerciseID, sets: [PerformedSet] = [],
        notes: String = "", supersetID: UUID? = nil, restOverride: Double? = nil, slotID: UUID? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.sets = sets
        self.notes = notes
        self.supersetID = supersetID
        self.restOverride = restOverride
        self.slotID = slotID
    }
}

public struct WorkoutSession: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var startedAt: Date
    public var endedAt: Date?
    /// IANA identifier of the zone the session started in.
    public var timeZoneID: String
    public var notes: String
    /// Bodyweight when the session started, used for bodyweight exercises.
    public var bodyweight: Mass?
    public var exercises: [PerformedExercise]
    /// The program day this session was started from, if any.
    public var program: ProgramRef?

    public init(
        id: UUID = UUID(), name: String = "", startedAt: Date = Date(), endedAt: Date? = nil,
        timeZone: TimeZone = .current, notes: String = "", bodyweight: Mass? = nil,
        exercises: [PerformedExercise] = [], program: ProgramRef? = nil
    ) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.timeZoneID = timeZone.identifier
        self.notes = notes
        self.bodyweight = bodyweight
        self.exercises = exercises
        self.program = program
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? TimeZone(identifier: "UTC")! }
    /// The calendar day the session belongs to, in the zone it started in.
    public var localDate: LocalDate { LocalDate(startedAt, in: timeZone) }
    public var isFinished: Bool { endedAt != nil }
    public var duration: Double? { endedAt.map { $0.timeIntervalSince(startedAt) } }
}
