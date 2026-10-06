import Foundation
import Testing
@testable import ExerlyCore

@MainActor
@Suite struct ProgramChangesTests {
    func complete(_ training: TrainingStore, _ performedID: UUID, reps: Int = 8, load: Double = 60, rir: Double? = 2) throws {
        let performed = try #require(training.activeSession?.exercises.first { $0.id == performedID })
        for set in performed.sets where !set.isCompleted {
            var done = set
            done.primary = Effort(reps: reps, load: .kg(load))
            done.rir = rir
            try training.updateSet(done, in: performedID)
            try training.completeSet(set.id)
        }
    }

    @Test func aSwapKeepsItsPlaceAndSlotAndRefusesOnceStarted() throws {
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let programs = try ProgramStore(persistence: persistence, training: training)
        let program = fullBody()
        try programs.save(program)
        try programs.activate(program.id)
        let session = try training.startSession(from: #require(programs.nextWorkout(bodyweight: nil)), bodyweight: nil)
        #expect(session.exercises.map(\.slotID) == program.days[0].slots.map(\.id))
        let bench = session.exercises[1]
        try training.replaceExercise(bench.id, with: "dumbbell-bench-press")
        let swapped = try #require(training.activeSession?.exercises[1])
        #expect(swapped.id == bench.id && swapped.exerciseID == "dumbbell-bench-press" && swapped.slotID == bench.slotID)
        #expect(swapped.sets.count == 3 && swapped.restOverride == 150 && !swapped.sets.contains(where: \.isCompleted))
        try complete(training, swapped.id)
        #expect(throws: TrainingStore.StoreError.edit(.alreadyStarted(bench.id))) {
            try training.replaceExercise(bench.id, with: "barbell-bench-press")
        }
    }

    @Test func todaysChangesBecomeAProgramProposalThatCanBeAcceptedAndUndone() throws {
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let programs = try ProgramStore(persistence: persistence, training: training)
        let agent = try AgentStore(persistence: persistence, hosts: [training, programs])
        let program = fullBody()
        try programs.save(program)
        try programs.activate(program.id)
        let session = try training.startSession(from: #require(programs.nextWorkout(bodyweight: nil)), bodyweight: nil)
        let squat = session.exercises[0], bench = session.exercises[1]
        try training.addSet(to: squat.id)
        try complete(training, squat.id, reps: 6, load: 100)
        try training.replaceExercise(bench.id, with: "dumbbell-bench-press")
        try complete(training, bench.id, reps: 10, load: 30)
        let curl = try training.addExercise("barbell-curl")
        try training.addSet(to: curl)
        try complete(training, curl, reps: 12, load: 30, rir: 1.4)
        _ = try training.addExercise("deadlift")
        let finished = try training.finishSession().session

        let proposal = try #require(programs.proposal(applying: finished, existing: agent.proposals))
        #expect(proposal.title == "Keep today's changes in Full body?")
        #expect(proposal.summary == "A: Back Squat: 4 sets instead of 3; Dumbbell Bench Press instead of Barbell Bench Press; added Barbell Curl.")
        #expect(programs.proposal(applying: finished, existing: [proposal]) == nil, "Filed once")
        let followed = try #require(programs.program(program.id))
        try agent.file(proposal)
        try agent.accept(proposal.id)
        let slots = try #require(programs.program(program.id)).days[0].slots
        #expect(slots.map(\.exerciseID) == ["back-squat", "dumbbell-bench-press", "barbell-curl"], "The deadlift was never done")
        #expect(slots[0].target.sets == 4 && slots[1].id == program.days[0].slots[1].id)
        #expect(slots[2].target == SlotTarget(sets: 2, minReps: 12, maxReps: 12, rir: 1.5))
        try agent.undo(proposal.id)
        #expect(programs.program(program.id) == followed)
    }

    @Test func aDeloadCycleKeepsItsDerivedSetsAndNoChangeMeansNoProposal() throws {
        var program = fullBody(cycles: 2, deload: .last)
        let day = program.days[0]
        func session(sets: Int, cycle: Int) -> WorkoutSession {
            var session = Fixture.session(day.slots.map { slot in (slot.exerciseID, (0..<sets).map { _ in Fixture.set(6, 100, rir: 2) }) })
            session.program = ProgramRef(programID: program.id, dayID: day.id, cycle: cycle)
            for index in session.exercises.indices { session.exercises[index].slotID = day.slots[index].id }
            return session
        }
        // The deload cycle plans 2 of the 3 sets: doing 3 there isn't a change to the program.
        #expect(ProgramChanges.apply(session(sets: 3, cycle: 1), to: program, library: .bundled) == nil)
        #expect(ProgramChanges.apply(session(sets: 3, cycle: 0), to: program, library: .bundled) == nil)
        program.days[0].slots[0].cycleTargets[1] = SlotTarget(sets: 1, minReps: 6, maxReps: 8, rir: 3)
        let changed = try #require(ProgramChanges.apply(session(sets: 3, cycle: 1), to: program, library: .bundled))
        #expect(changed.changes == ["Back Squat: 3 sets instead of 1 in cycle 2"])
        #expect(changed.program.days[0].slots[0].cycleTargets[1]?.sets == 3 && changed.program.days[0].slots[0].target.sets == 3)
        var unfinished = session(sets: 4, cycle: 0)
        unfinished.endedAt = nil
        #expect(ProgramChanges.proposal(for: unfinished, program: program, library: .bundled, existing: []) == nil)
    }
}
