import Foundation

/// Where a set sits in a session.
public struct SetPosition: Sendable, Hashable {
    public var performedID: UUID
    public var setID: UUID
}

extension PerformedSet {
    /// Whether every value present is meaningful: at least one effort, one
    /// effort unless the kind allows continuations, no negative or non-finite
    /// numbers, and RIR from 0 to 6. Drafts may leave fields empty.
    public var isSane: Bool {
        if efforts.isEmpty { return false }
        if let rir, !(rir.isFinite && (0...6).contains(rir)) { return false }
        if efforts.count > 1 && !kind.allowsContinuations { return false }
        return efforts.allSatisfy { effort in
            if let reps = effort.reps, reps < 0 { return false }
            if let load = effort.load, !(load.value.isFinite && load.value >= 0) { return false }
            if let duration = effort.duration, !(duration.isFinite && duration >= 0) { return false }
            if let distance = effort.distance, !(distance.isFinite && distance >= 0) { return false }
            return true
        }
    }

    /// Whether the set is sane and has what its exercise's metric needs to be
    /// completed.
    public func isLoggable(for exercise: Exercise) -> Bool {
        guard isSane else { return false }
        let metric = exercise.metric
        return efforts.allSatisfy { effort in
            let hasDuration = (effort.duration ?? 0) > 0
            let hasDistance = (effort.distance ?? 0) > 0
            if metric.tracksReps && (effort.reps ?? 0) < 1 { return false }
            if metric.requiresLoad && effort.load == nil { return false }
            switch metric {
            case .duration, .weightDuration: return hasDuration
            case .distanceDuration: return hasDuration || hasDistance
            case .weightDistance: return hasDistance
            case .weightReps, .bodyweightReps, .assistedReps: return true
            }
        }
    }

    /// A fresh, incomplete copy for the next set or the next session.
    func prefilledCopy(side: Side?? = .none, kind: SetKind? = nil) -> PerformedSet {
        let kind = kind ?? self.kind
        let efforts = kind.allowsContinuations ? efforts : [primary]
        return PerformedSet(kind: kind, side: side ?? self.side, efforts: efforts)
    }
}

extension WorkoutSession {
    public enum EditError: Error, Equatable {
        case unknownExercise(ExerciseID)
        case exerciseNotFound(UUID)
        case setNotFound(UUID)
        case incomplete(UUID)
        case invalidSet(UUID)
        case duplicateID(UUID)
        case invalidTimeZone(String)
        case endsBeforeStart
        case supersetNeedsTwoExercises
        /// A set of the exercise is already done, so it can't be swapped.
        case alreadyStarted(UUID)
    }

    /// Throws the first problem that would make the session untrustworthy:
    /// duplicate IDs, unknown exercises or zones, an end before the start,
    /// nonsense values in any set, or a completed set missing what its metric
    /// needs. Incomplete sets may leave fields empty.
    public func validate(library: ExerciseLibrary) throws {
        guard TimeZone(identifier: timeZoneID) != nil else { throw EditError.invalidTimeZone(timeZoneID) }
        if let endedAt, endedAt < startedAt { throw EditError.endsBeforeStart }
        var seen = Set<UUID>()
        for performed in exercises {
            guard seen.insert(performed.id).inserted else { throw EditError.duplicateID(performed.id) }
            guard let exercise = library.exercise(performed.exerciseID) else {
                throw EditError.unknownExercise(performed.exerciseID)
            }
            for set in performed.sets {
                guard seen.insert(set.id).inserted else { throw EditError.duplicateID(set.id) }
                guard set.isSane else { throw EditError.invalidSet(set.id) }
                if set.isCompleted && !set.isLoggable(for: exercise) { throw EditError.incomplete(set.id) }
            }
        }
    }

    // MARK: Lookup

    public func set(_ setID: UUID) -> (performedID: UUID, set: PerformedSet)? {
        for performed in exercises {
            if let set = performed.sets.first(where: { $0.id == setID }) { return (performed.id, set) }
        }
        return nil
    }

    private func exerciseIndex(_ id: UUID) throws -> Int {
        guard let index = exercises.firstIndex(where: { $0.id == id }) else { throw EditError.exerciseNotFound(id) }
        return index
    }

    private func setIndex(_ setID: UUID) throws -> (exercise: Int, set: Int) {
        for (e, performed) in exercises.enumerated() {
            if let s = performed.sets.firstIndex(where: { $0.id == setID }) { return (e, s) }
        }
        throw EditError.setNotFound(setID)
    }

    // MARK: Exercises

    /// Adds an exercise at `index` (default: the end). With `previous`, its
    /// sets are copied as incomplete sets with the same kinds and values;
    /// otherwise one empty set is added, or a left and right set for a
    /// unilateral exercise.
    @discardableResult
    public mutating func addExercise(
        _ exerciseID: ExerciseID, at index: Int? = nil, previous: PerformedExercise? = nil, library: ExerciseLibrary
    ) throws -> UUID {
        guard let exercise = library.exercise(exerciseID) else { throw EditError.unknownExercise(exerciseID) }
        let performed = PerformedExercise(exerciseID: exerciseID, sets: Self.startingSets(exercise, previous: previous),
                                          restOverride: previous?.restOverride)
        exercises.insert(performed, at: min(max(index ?? exercises.count, 0), exercises.count))
        return performed.id
    }

    private static func startingSets(_ exercise: Exercise, previous: PerformedExercise?) -> [PerformedSet] {
        let sets = previous?.sets.map { $0.prefilledCopy() } ?? []
        guard sets.isEmpty else { return sets }
        return exercise.laterality == .unilateral ? [PerformedSet(side: .left), PerformedSet(side: .right)] : [PerformedSet()]
    }

    /// Swaps an exercise for another in place, before any of its sets is done.
    /// It keeps its position, superset, program slot, notes and rest. Its sets
    /// keep their number and kinds, prefilled from `previous`, the new
    /// exercise's last performance; a unilateral one starts as when added.
    public mutating func replaceExercise(_ performedID: UUID, with exerciseID: ExerciseID, previous: PerformedExercise? = nil,
                                         library: ExerciseLibrary) throws {
        let index = try exerciseIndex(performedID)
        guard let exercise = library.exercise(exerciseID) else { throw EditError.unknownExercise(exerciseID) }
        let current = exercises[index].sets
        guard !current.contains(where: \.isCompleted) else { throw EditError.alreadyStarted(performedID) }
        let template = previous?.sets ?? []
        if exercise.laterality == .unilateral || current.isEmpty {
            exercises[index].sets = Self.startingSets(exercise, previous: previous)
        } else {
            exercises[index].sets = current.indices.map { i in
                template.isEmpty ? PerformedSet(kind: current[i].kind)
                    : template[min(i, template.count - 1)].prefilledCopy(side: .some(nil), kind: current[i].kind)
            }
        }
        exercises[index].exerciseID = exerciseID
    }

    public mutating func removeExercise(_ performedID: UUID) throws {
        let index = try exerciseIndex(performedID)
        let group = exercises[index].supersetID
        exercises.remove(at: index)
        dissolveSmallSupersets(group)
    }

    public mutating func moveExercise(_ performedID: UUID, to index: Int) throws {
        let from = try exerciseIndex(performedID)
        let performed = exercises.remove(at: from)
        exercises.insert(performed, at: min(max(index, 0), exercises.count))
    }

    // MARK: Sets

    /// Appends a set copying the previous set's values. For a unilateral
    /// exercise the side alternates and the copy comes from the last set on
    /// that side.
    @discardableResult
    public mutating func addSet(to performedID: UUID, kind: SetKind? = nil) throws -> UUID {
        let index = try exerciseIndex(performedID)
        let sets = exercises[index].sets
        let set: PerformedSet
        if let last = sets.last {
            let side = last.side?.other
            let source = side.flatMap { side in sets.last { $0.side == side } } ?? last
            set = source.prefilledCopy(side: .some(side), kind: kind)
        } else {
            set = PerformedSet(kind: kind ?? .standard)
        }
        exercises[index].sets.append(set)
        return set.id
    }

    /// Replaces the set with the same ID. With `propagate`, each changed
    /// field of the primary effort is copied down to the following
    /// incomplete sets that still hold the old value, stopping at the first
    /// incomplete set whose value differs. Completed sets are never changed.
    public mutating func updateSet(_ set: PerformedSet, in performedID: UUID, propagate: Bool = false) throws {
        let e = try exerciseIndex(performedID)
        guard let s = exercises[e].sets.firstIndex(where: { $0.id == set.id }) else { throw EditError.setNotFound(set.id) }
        let old = exercises[e].sets[s].primary
        exercises[e].sets[s] = set
        guard propagate else { return }
        let new = set.primary
        propagateField(\.reps, from: old, to: new, after: s, in: e)
        propagateField(\.load, from: old, to: new, after: s, in: e)
        propagateField(\.duration, from: old, to: new, after: s, in: e)
        propagateField(\.distance, from: old, to: new, after: s, in: e)
    }

    private mutating func propagateField<Value: Equatable>(
        _ field: WritableKeyPath<Effort, Value>, from old: Effort, to new: Effort, after s: Int, in e: Int
    ) {
        guard old[keyPath: field] != new[keyPath: field] else { return }
        for index in exercises[e].sets.indices where index > s {
            if exercises[e].sets[index].isCompleted { continue }
            guard exercises[e].sets[index].primary[keyPath: field] == old[keyPath: field] else { return }
            exercises[e].sets[index].primary[keyPath: field] = new[keyPath: field]
        }
    }

    /// Marks a set done. Throws `incomplete` when the set lacks a field its
    /// exercise's metric needs.
    public mutating func completeSet(_ setID: UUID, at date: Date, library: ExerciseLibrary) throws {
        let (e, s) = try setIndex(setID)
        let id = exercises[e].exerciseID
        guard let exercise = library.exercise(id) else { throw EditError.unknownExercise(id) }
        guard exercises[e].sets[s].isLoggable(for: exercise) else { throw EditError.incomplete(setID) }
        exercises[e].sets[s].completedAt = date
    }

    public mutating func reopenSet(_ setID: UUID) throws {
        let (e, s) = try setIndex(setID)
        exercises[e].sets[s].completedAt = nil
    }

    public mutating func removeSet(_ setID: UUID) throws {
        let (e, s) = try setIndex(setID)
        exercises[e].sets.remove(at: s)
    }

    // MARK: Supersets

    /// Groups exercises into a superset, moving them together at the position
    /// of the first one. Returns the superset ID.
    @discardableResult
    public mutating func makeSuperset(_ performedIDs: [UUID]) throws -> UUID {
        let ids = performedIDs.reduce(into: [UUID]()) { if !$0.contains($1) { $0.append($1) } }
        guard ids.count >= 2 else { throw EditError.supersetNeedsTwoExercises }
        let indices = try ids.map(exerciseIndex)
        let group = UUID()
        let previousGroups = Set(indices.compactMap { exercises[$0].supersetID })
        let insertAt = indices.min()!
        var members = indices.map { exercises[$0] }
        for i in members.indices { members[i].supersetID = group }
        exercises.removeAll { ids.contains($0.id) }
        // No member sits before the first one, so its index is unchanged.
        exercises.insert(contentsOf: members, at: min(insertAt, exercises.count))
        for previous in previousGroups { dissolveSmallSupersets(previous) }
        return group
    }

    public mutating func removeFromSuperset(_ performedID: UUID) throws {
        let index = try exerciseIndex(performedID)
        let group = exercises[index].supersetID
        exercises[index].supersetID = nil
        dissolveSmallSupersets(group)
    }

    private mutating func dissolveSmallSupersets(_ group: UUID?) {
        guard let group, exercises.filter({ $0.supersetID == group }).count < 2 else { return }
        for i in exercises.indices where exercises[i].supersetID == group { exercises[i].supersetID = nil }
    }

    // MARK: Order of work

    /// Every set in the order it should be performed: straight sets exercise
    /// by exercise, and superset members round by round.
    public var performanceOrder: [SetPosition] {
        var order: [SetPosition] = []
        var i = 0
        while i < exercises.count {
            var block = [exercises[i]]
            if let group = exercises[i].supersetID {
                while i + block.count < exercises.count, exercises[i + block.count].supersetID == group {
                    block.append(exercises[i + block.count])
                }
            }
            let rounds = block.map(\.sets.count).max() ?? 0
            for round in 0..<rounds {
                for member in block where round < member.sets.count {
                    order.append(SetPosition(performedID: member.id, setID: member.sets[round].id))
                }
            }
            i += block.count
        }
        return order
    }

    /// The next incomplete set after `setID` in performance order, wrapping
    /// around to sets skipped earlier. With nil, the first incomplete set.
    public func nextSet(after setID: UUID?) -> SetPosition? {
        let order = performanceOrder
        let start = setID.flatMap { id in order.firstIndex { $0.setID == id } }
        let candidates = start.map { Array(order[($0 + 1)...] + order[..<$0]) } ?? order
        return candidates.first { position in
            self.set(position.setID).map { !$0.set.isCompleted } ?? false
        }
    }

    /// Ends the session. With `discardIncompleteSets`, sets never completed
    /// are removed, then exercises left without sets.
    public mutating func finish(at date: Date, discardIncompleteSets: Bool) {
        endedAt = date
        guard discardIncompleteSets else { return }
        for i in exercises.indices { exercises[i].sets.removeAll { !$0.isCompleted } }
        let emptied = exercises.filter(\.sets.isEmpty).compactMap(\.supersetID)
        exercises.removeAll(where: \.sets.isEmpty)
        for group in Set(emptied) { dissolveSmallSupersets(group) }
    }
}
