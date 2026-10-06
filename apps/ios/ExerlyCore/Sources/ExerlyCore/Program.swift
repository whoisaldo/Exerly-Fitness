import Foundation

/// What one exercise slot asks for in a cycle.
public struct SlotTarget: Sendable, Codable, Hashable {
    public var sets: Int
    public var minReps: Int
    public var maxReps: Int
    /// Target reps in reserve, 0 to 5.
    public var rir: Double
    /// Rest after each set, in seconds; nil uses the rest policy.
    public var rest: Double?
    public var kind: SetKind

    public init(sets: Int, minReps: Int, maxReps: Int, rir: Double, rest: Double? = nil, kind: SetKind = .standard) {
        self.sets = sets
        self.minReps = minReps
        self.maxReps = maxReps
        self.rir = rir
        self.rest = rest
        self.kind = kind
    }

    /// The reps the slot aims for: the middle of the range.
    public var targetReps: Double { Double(minReps + maxReps) / 2 }

    var problems: [String] {
        var problems: [String] = []
        if !(1...20).contains(sets) { problems.append("sets must be 1 to 20") }
        if !(1...100).contains(minReps) || maxReps < minReps || maxReps > 100 { problems.append("the rep range is invalid") }
        if !(rir.isFinite && (0...5).contains(rir)) { problems.append("target RIR must be 0 to 5") }
        if let rest, !(rest.isFinite && rest >= 0 && rest <= 3600) { problems.append("rest must be 0 to 3600 seconds") }
        if kind == .warmUp { problems.append("warm-ups aren't program sets") }
        return problems
    }
}

public struct ProgramSlot: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var exerciseID: ExerciseID
    public var notes: String
    public var supersetID: UUID?
    public var target: SlotTarget
    /// Targets for particular cycles, by cycle index from 0, when the program
    /// is periodized. Cycles without one use `target`.
    public var cycleTargets: [Int: SlotTarget]
    /// Allow reps up to two outside the range when equipment steps are coarse.
    public var expandRepRange: Bool
    /// Reserved for set-by-set adjustment: later sets keeping the first set's
    /// load. Plans don't read it yet; every set of a slot gets the same load and
    /// reps, so don't offer it as a control.
    public var weightMatch: Bool

    public init(id: UUID = UUID(), exerciseID: ExerciseID, notes: String = "", supersetID: UUID? = nil, target: SlotTarget,
                cycleTargets: [Int: SlotTarget] = [:], expandRepRange: Bool = false, weightMatch: Bool = true) {
        self.id = id
        self.exerciseID = exerciseID
        self.notes = notes
        self.supersetID = supersetID
        self.target = target
        self.cycleTargets = cycleTargets
        self.expandRepRange = expandRepRange
        self.weightMatch = weightMatch
    }
}

public struct ProgramDay: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    /// No slots makes a rest day.
    public var slots: [ProgramSlot]

    public init(id: UUID = UUID(), name: String, slots: [ProgramSlot] = []) {
        self.id = id
        self.name = name
        self.slots = slots
    }

    public var isRest: Bool { slots.isEmpty }
}

public enum DeloadPlacement: String, Sendable, Codable, Hashable, CaseIterable {
    case none, first, last
}

/// A training program: one cycle of days, repeated. See
/// docs/design/006-programs-progression.md.
public struct Program: Sendable, Codable, Hashable, Identifiable {
    public static let maximumCycles = 52
    public static let maximumTrainingDays = 14

    public var id: UUID
    public var name: String
    /// An SF Symbol name, chosen by the person.
    public var icon: String?
    /// A colour as `#RRGGBB`.
    public var color: String?
    public var days: [ProgramDay]
    public var cycles: Int
    public var deload: DeloadPlacement
    public var createdAt: Date
    public var activatedAt: Date?
    public var archivedAt: Date?

    public init(id: UUID = UUID(), name: String, icon: String? = nil, color: String? = nil, days: [ProgramDay],
                cycles: Int = 7, deload: DeloadPlacement = .none, createdAt: Date = Date().roundedToMilliseconds) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.days = days
        self.cycles = cycles
        self.deload = deload
        self.createdAt = createdAt
    }

    public var trainingDays: [ProgramDay] { days.filter { !$0.isRest } }

    public func isDeload(cycle: Int) -> Bool {
        switch deload {
        case .none: false
        case .first: cycle == 0 && cycles > 1
        case .last: cycle == cycles - 1 && cycles > 1
        }
    }

    /// The slot's target in a cycle. A deload cycle without its own target
    /// halves the sets (rounding up) and adds 2 RIR, up to 5.
    public func target(for slot: ProgramSlot, cycle: Int) -> SlotTarget {
        if let specific = slot.cycleTargets[cycle] { return specific }
        guard isDeload(cycle: cycle) else { return slot.target }
        var deload = slot.target
        deload.sets = max(1, (slot.target.sets + 1) / 2)
        deload.rir = min(5, slot.target.rir + 2)
        return deload
    }

    /// Problems that make the program unusable, given the exercise library.
    public func validationErrors(library: ExerciseLibrary) -> [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("name is empty") }
        if !(1...Self.maximumCycles).contains(cycles) { errors.append("cycles must be 1 to \(Self.maximumCycles)") }
        if trainingDays.isEmpty { errors.append("a program needs a training day") }
        if trainingDays.count > Self.maximumTrainingDays {
            errors.append("a cycle has at most \(Self.maximumTrainingDays) training days")
        }
        if let color, color.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) == nil {
            errors.append("color must be #RRGGBB")
        }
        var ids = Set<UUID>()
        for day in days {
            if !ids.insert(day.id).inserted { errors.append("an ID is used twice") }
            for slot in day.slots {
                if !ids.insert(slot.id).inserted { errors.append("an ID is used twice") }
                if library.exercise(slot.exerciseID) == nil { errors.append("\(slot.exerciseID) is not a known exercise") }
                // Shown to people as they edit, so exercises go by name.
                let exercise = library.exercise(slot.exerciseID)?.name ?? slot.exerciseID.rawValue
                errors += slot.target.problems.map { "\(exercise): \($0)" }
                for (cycle, target) in slot.cycleTargets.sorted(by: { $0.key < $1.key }) {
                    if !(0..<cycles).contains(cycle) {
                        errors.append("\(exercise) has targets for cycle \(cycle + 1), but the program has \(cycles) cycles")
                    }
                    errors += target.problems.map { "\(exercise), cycle \(cycle + 1): \($0)" }
                }
            }
        }
        var seen = Set<String>()
        return errors.filter { seen.insert($0).inserted }
    }
}

/// Where a session sits in a program.
public struct ProgramRef: Sendable, Codable, Hashable {
    public var programID: UUID
    public var dayID: UUID
    /// From 0.
    public var cycle: Int

    public init(programID: UUID, dayID: UUID, cycle: Int) {
        self.programID = programID
        self.dayID = dayID
        self.cycle = cycle
    }
}

public enum ProgramSchedule {
    public struct Position: Sendable, Hashable {
        public var day: ProgramDay
        public var cycle: Int
        public var isDeload: Bool
    }

    /// The next training day: the one after the latest session that referenced
    /// this program, wrapping into the next cycle. Nil once the last cycle is done.
    /// If that day has since been removed or emptied, the cycle continues at
    /// its first training day not done yet.
    public static func next(for program: Program, in history: TrainingHistory) -> Position? {
        let training = program.trainingDays
        guard !training.isEmpty else { return nil }
        let refs = history.sessions.compactMap(\.program).filter { $0.programID == program.id }
        guard let ref = refs.last else {
            return Position(day: training[0], cycle: 0, isDeload: program.isDeload(cycle: 0))
        }
        var cycle = ref.cycle
        var next: Int
        if let index = training.firstIndex(where: { $0.id == ref.dayID }) {
            next = index + 1
        } else {
            let done = Set(refs.filter { $0.cycle == cycle }.map(\.dayID))
            next = training.firstIndex { !done.contains($0.id) } ?? training.count
        }
        if next == training.count {
            next = 0
            cycle += 1
        }
        guard cycle < program.cycles else { return nil }
        return Position(day: training[next], cycle: cycle, isDeload: program.isDeload(cycle: cycle))
    }

    /// Sessions done and planned, for a progress bar. Sessions of days since
    /// removed from the program, or of cycles it no longer has, don't count.
    public static func progress(of program: Program, in history: TrainingHistory) -> (done: Int, total: Int) {
        let total = program.trainingDays.count * program.cycles
        let days = Set(program.trainingDays.map(\.id))
        let done = Set(history.sessions.compactMap { session -> String? in
            guard let ref = session.program, ref.programID == program.id, days.contains(ref.dayID),
                  ref.cycle < program.cycles else { return nil }
            return "\(ref.cycle)/\(ref.dayID)"
        }).count
        return (min(done, total), total)
    }
}

/// One exercise of a workout to do, with what progression recommends.
public struct PlannedExercise: Sendable, Hashable {
    public var slotID: UUID?
    public var exerciseID: ExerciseID
    public var notes: String
    public var supersetID: UUID?
    public var target: SlotTarget
    public var recommendation: Recommendation
}

/// A workout ready to start: from a program day, or ad hoc.
public struct WorkoutPlan: Sendable, Hashable {
    public var name: String
    public var program: ProgramRef?
    public var isDeload: Bool
    public var exercises: [PlannedExercise]
}

extension ProgramSchedule {
    /// The workout for a program position, with each slot's recommendation
    /// from the person's history.
    public static func plan(_ program: Program, at position: Position, history: TrainingHistory, bodyweight: Mass?,
                            increments: (Exercise) -> LoadIncrements = LoadIncrements.defaults(for:)) -> WorkoutPlan {
        let exercises = position.day.slots.compactMap { slot -> PlannedExercise? in
            guard let exercise = history.library.exercise(slot.exerciseID) else { return nil }
            let target = program.target(for: slot, cycle: position.cycle)
            let recommendation = Progression.recommend(target, exercise: exercise, history: history, bodyweight: bodyweight,
                                                       increments: increments(exercise), expandRepRange: slot.expandRepRange)
            return PlannedExercise(slotID: slot.id, exerciseID: slot.exerciseID, notes: slot.notes, supersetID: slot.supersetID,
                                   target: target, recommendation: recommendation)
        }
        return WorkoutPlan(name: "\(program.name): \(position.day.name)",
                           program: ProgramRef(programID: program.id, dayID: position.day.id, cycle: position.cycle),
                           isDeload: position.isDeload, exercises: exercises)
    }
}
