import Foundation

/// Changes made during a workout started from a program, offered as a
/// proposal to keep them in the program. PARITY P06.
public enum ProgramChanges {
    public static let author = AgentIdentity(kind: .builtIn, name: "Exerly program")
    static let namespace = UUID(uuidString: "C3E1F0A2-7B4D-4E19-9A65-2D8B0F4C6E31")!

    /// The program with the workout's changes to its day, and the changes in
    /// words; nil when nothing changed or the result wouldn't be valid.
    /// - An exercise swapped for another takes over its slot.
    /// - A different number of working sets becomes the slot's sets in the
    ///   target for that cycle. A deload cycle without its own targets is left
    ///   alone, because its sets are derived.
    /// - An exercise added and done becomes a slot after the one before it,
    ///   with targets from what was done.
    /// Exercises skipped stay, since skipping once isn't removing, and the
    /// order is kept.
    public static func apply(_ session: WorkoutSession, to program: Program, library: ExerciseLibrary)
        -> (program: Program, changes: [String])? {
        guard let ref = session.program, ref.programID == program.id,
              let dayIndex = program.days.firstIndex(where: { $0.id == ref.dayID }) else { return nil }
        func name(_ id: ExerciseID) -> String { library.exercise(id)?.name ?? id.rawValue }
        var day = program.days[dayIndex]
        var changes: [String] = []
        var insertAt = 0
        for performed in session.exercises {
            let done = performed.sets.filter(\.counts)
            guard let slotIndex = day.slots.firstIndex(where: { $0.id == performed.slotID }) else {
                guard !done.isEmpty else { continue }
                day.slots.insert(ProgramSlot(exerciseID: performed.exerciseID, target: target(from: done, rest: performed.restOverride)),
                                 at: insertAt)
                insertAt += 1
                changes.append("added \(name(performed.exerciseID))")
                continue
            }
            insertAt = slotIndex + 1
            guard !done.isEmpty else { continue }
            var slot = day.slots[slotIndex]
            if slot.exerciseID != performed.exerciseID {
                changes.append("\(name(performed.exerciseID)) instead of \(name(slot.exerciseID))")
                slot.exerciseID = performed.exerciseID
            }
            let sets = min(20, setCount(done))
            let planned = program.target(for: slot, cycle: ref.cycle).sets
            if sets != planned, slot.cycleTargets[ref.cycle] != nil || !program.isDeload(cycle: ref.cycle) {
                if slot.cycleTargets[ref.cycle] != nil {
                    slot.cycleTargets[ref.cycle]?.sets = sets
                    changes.append("\(name(slot.exerciseID)): \(sets) sets instead of \(planned) in cycle \(ref.cycle + 1)")
                } else {
                    slot.target.sets = sets
                    changes.append("\(name(slot.exerciseID)): \(sets) sets instead of \(planned)")
                }
            }
            day.slots[slotIndex] = slot
        }
        var updated = program
        updated.days[dayIndex] = day
        guard !changes.isEmpty, updated.validationErrors(library: library).isEmpty else { return nil }
        return (updated, changes)
    }

    /// After a finished workout started from a program, a proposal to keep its
    /// changes in the program. Nil when the workout isn't finished, the program
    /// is gone or archived, nothing changed, or `existing` already has it.
    public static func proposal(for session: WorkoutSession, program: Program?, library: ExerciseLibrary,
                                existing: [Proposal], now: Date = Date()) -> Proposal? {
        let id = UUID(named: "\(session.id.uuidString)/program", in: namespace)
        guard session.endedAt != nil, let program, program.archivedAt == nil, !existing.contains(where: { $0.id == id }),
              let (updated, changes) = apply(session, to: program, library: library),
              let change = try? ProposedChange(kind: ProgramStore.kind, id: program.id.uuidString, before: program, after: updated)
        else { return nil }
        let day = program.days.first { $0.id == session.program?.dayID }?.name ?? "this day"
        let summary = changes.joined(separator: "; ")
        return Proposal(id: id, createdAt: now.roundedToMilliseconds, author: author,
                        title: "Keep today's changes in \(program.name)?",
                        summary: "\(day): \(summary.prefix(1).uppercased() + summary.dropFirst()).",
                        changes: [change],
                        evidence: [Evidence(claim: "You made these changes in the workout on \(session.localDate).",
                                            level: .personalData, caveats: ["One workout"],
                                            dataRefs: [DataRef(kind: "workout_session", id: session.id.uuidString)])],
                        confidence: .medium,
                        falsifier: "If they were for today only, decline, and the program stays as it is.")
    }

    /// Working sets, counting a left and right pair once.
    static func setCount(_ sets: [PerformedSet]) -> Int {
        sets.filter { $0.side == nil }.count + max(sets.filter { $0.side == .left }.count, sets.filter { $0.side == .right }.count)
    }

    /// Targets for an added exercise from what was done: its sets, the range of
    /// reps (8 to 12 without any), and the average RIR to the nearest half (2 without any).
    static func target(from done: [PerformedSet], rest: Double?) -> SlotTarget {
        let reps = done.compactMap(\.primary.reps).filter { $0 > 0 }
        let low = min(reps.min() ?? 8, 100)
        let high = min(max(reps.max() ?? 12, low), 100)
        let rirs = done.compactMap(\.rir)
        let rir = rirs.isEmpty ? 2 : min(5, max(0, (rirs.reduce(0, +) / Double(rirs.count) * 2).rounded() / 2))
        return SlotTarget(sets: min(20, setCount(done)), minReps: low, maxReps: high, rir: rir, rest: rest)
    }
}
