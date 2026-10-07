import Foundation
import Testing
@testable import ExerlyCore

/// A three-day full-body program with a rest day, for tests. Synthetic.
func fullBody(cycles: Int = 4, deload: DeloadPlacement = .none) -> Program {
    let target = SlotTarget(sets: 3, minReps: 6, maxReps: 8, rir: 2, rest: 150)
    return Program(name: "Full body", icon: "figure.strengthtraining.traditional", color: "#7C3AED", days: [
        ProgramDay(name: "A", slots: [ProgramSlot(exerciseID: "back-squat", target: target),
                                      ProgramSlot(exerciseID: "barbell-bench-press", target: target)]),
        ProgramDay(name: "Rest"),
        ProgramDay(name: "B", slots: [ProgramSlot(exerciseID: "deadlift", target: SlotTarget(sets: 2, minReps: 4, maxReps: 6, rir: 2)),
                                      ProgramSlot(exerciseID: "pull-up", target: target)]),
    ], cycles: cycles, deload: deload, createdAt: Fixture.instant())
}

@Suite struct ProgramModelTests {
    @Test func aValidProgramHasNoErrorsAndBadOnesAreExplained() {
        #expect(fullBody().validationErrors(library: .bundled).isEmpty)
        var bad = fullBody(cycles: 60)
        bad.name = " "
        bad.color = "purple"
        bad.days[0].slots[0].target.minReps = 9
        bad.days[0].slots[1].exerciseID = "not-an-exercise"
        bad.days[2].slots[0].cycleTargets = [70: SlotTarget(sets: 1, minReps: 1, maxReps: 1, rir: 9)]
        let errors = bad.validationErrors(library: .bundled)
        #expect(errors.contains("name is empty"))
        #expect(errors.contains("cycles must be 1 to 52"))
        #expect(errors.contains("color must be #RRGGBB"))
        #expect(errors.contains("Back Squat: the rep range is invalid"))
        #expect(errors.contains("not-an-exercise is not a known exercise"))
        #expect(errors.contains("Deadlift has targets for cycle 71, but the program has \(bad.cycles) cycles"))
        #expect(errors.contains("Deadlift, cycle 71: target RIR must be 0 to 5"))
        let rest = Program(name: "Rest only", days: [ProgramDay(name: "Rest")])
        #expect(rest.validationErrors(library: .bundled) == ["a program needs a training day"])
    }

    @Test func deloadCyclesHalveSetsAndAddReserveUnlessACycleSaysOtherwise() {
        var program = fullBody(cycles: 5, deload: .last)
        let slot = program.days[0].slots[0]
        #expect(program.target(for: slot, cycle: 0) == slot.target)
        let deload = program.target(for: slot, cycle: 4)
        #expect(deload.sets == 2 && deload.rir == 4 && deload.minReps == 6 && deload.maxReps == 8)
        program.deload = .first
        #expect(program.isDeload(cycle: 0) && !program.isDeload(cycle: 4))
        program.days[0].slots[0].cycleTargets = [0: SlotTarget(sets: 4, minReps: 3, maxReps: 5, rir: 1)]
        #expect(program.target(for: program.days[0].slots[0], cycle: 0).sets == 4)
        #expect(!Program(name: "One", days: program.days, cycles: 1, deload: .last).isDeload(cycle: 0))
    }

    func history(_ program: Program, _ refs: [(ProgramDay, Int)]) -> TrainingHistory {
        let sessions = refs.enumerated().map { index, ref in
            var session = Fixture.session(days: Double(index), [("back-squat", [Fixture.set(5, 100)])])
            session.program = ProgramRef(programID: program.id, dayID: ref.0.id, cycle: ref.1)
            return session
        }
        return TrainingHistory(sessions: sessions, library: .bundled)
    }

    @Test func theScheduleSkipsRestDaysWrapsCyclesAndEnds() {
        let program = fullBody(cycles: 2)
        let a = program.days[0], b = program.days[2]
        func history(_ refs: [(ProgramDay, Int)]) -> TrainingHistory { self.history(program, refs) }
        #expect(ProgramSchedule.next(for: program, in: history([]))?.day == a)
        #expect(ProgramSchedule.next(for: program, in: history([(a, 0)]))?.day == b)
        let wrapped = ProgramSchedule.next(for: program, in: history([(a, 0), (b, 0)]))
        #expect(wrapped?.day == a && wrapped?.cycle == 1)
        #expect(ProgramSchedule.next(for: program, in: history([(a, 0), (b, 0), (a, 1), (b, 1)])) == nil)
        #expect(ProgramSchedule.progress(of: program, in: history([(a, 0), (b, 0), (a, 1)])) == (3, 4))
    }

    @Test func removingTheLastDayDoneContinuesTheCycleInsteadOfRestarting() {
        var program = fullBody(cycles: 3)
        let c = ProgramDay(name: "C", slots: [ProgramSlot(exerciseID: "deadlift", target: SlotTarget(sets: 3, minReps: 5, maxReps: 8, rir: 2))])
        program.days.append(c)
        let a = program.days[0], b = program.days[2]
        let middle = history(program, [(a, 0), (b, 0), (c, 0), (a, 1), (b, 1)])
        let end = history(program, [(a, 0), (b, 0), (c, 0)])
        program.days.removeAll { $0.id == b.id }
        let next = ProgramSchedule.next(for: program, in: middle)
        #expect(next?.day == c && next?.cycle == 1)
        #expect(ProgramSchedule.progress(of: program, in: middle) == (3, 6), "b's sessions no longer count")
        program.days.removeAll { $0.id == c.id }
        let wrapped = ProgramSchedule.next(for: program, in: end)
        #expect(wrapped?.day == a && wrapped?.cycle == 1, "Everything left in cycle 1 is done")
        program.cycles = 1
        #expect(ProgramSchedule.next(for: program, in: end) == nil)
        #expect(ProgramSchedule.progress(of: program, in: middle) == (1, 1))
    }
}

@Suite struct ProgressionTests {
    let target = SlotTarget(sets: 3, minReps: 6, maxReps: 8, rir: 2)
    var bench: Exercise { ExerciseLibrary.bundled.exercise("barbell-bench-press")! }

    func history(_ exercise: ExerciseID, _ sessions: [[PerformedSet]], bodyweight: Double? = 80) -> TrainingHistory {
        TrainingHistory(sessions: sessions.enumerated().map { index, sets in
            Fixture.session(days: Double(index * 3), bodyweight: bodyweight, [(exercise, sets)])
        }, library: .bundled)
    }

    func set(_ reps: Int, _ load: Mass?, rir: Double? = 2) -> PerformedSet {
        PerformedSet(efforts: [Effort(reps: reps, load: load)], rir: rir, completedAt: Fixture.instant())
    }

    @Test func theFirstSessionAsksForTheTargetRepsWithoutGuessingALoad() {
        let plan = Progression.recommend(target, exercise: bench, history: history("barbell-bench-press", []), bodyweight: nil)
        #expect(plan.reason == .firstSession)
        #expect(plan.sets.count == 3 && plan.sets.allSatisfy { $0.effort == Effort(reps: 7) && $0.rir == 2 })
    }

    @Test func beatingThePredictionMovesTheLoadUp() {
        let log = history("barbell-bench-press", [[set(7, .kg(100)), set(7, .kg(100))], [set(8, .kg(100)), set(8, .kg(100))]])
        let plan = Progression.recommend(target, exercise: bench, history: log, bodyweight: nil)
        #expect(plan.reason == .progress)
        #expect(plan.sets[0].effort == Effort(reps: 7, load: .kg(102.5)))
        #expect(close(plan.oneRepMax, 100 * 36 / 27, tolerance: 1e-9))
    }

    @Test func aSmallShortfallHoldsTheLoadAndABigOneLowersItGently() {
        let small = history("barbell-bench-press", [[set(8, .kg(100))], [set(7, .kg(100), rir: 2)]])
        let held = Progression.recommend(target, exercise: bench, history: small, bodyweight: nil)
        #expect(held.reason == .hold && held.sets[0].effort.load == .kg(100))

        let big = history("barbell-bench-press", [[set(8, .kg(100))], [set(3, .kg(100), rir: 0)]])
        let lowered = Progression.recommend(target, exercise: bench, history: big, bodyweight: nil)
        #expect(lowered.reason == .reduce)
        let load = lowered.sets[0].effort.load!.kilograms
        #expect(load < 100 && load >= 100 * 0.85, "Lighter, but never a punishing drop")
        #expect(close(lowered.oneRepMax, 100 * 36 / 27 * 0.9, tolerance: 1e-9))
    }

    @Test func aMistypedSetCantCauseAJump() {
        let log = history("barbell-bench-press", [[set(8, .kg(100))], [set(8, .kg(100))], [set(8, .kg(1000))]])
        let plan = Progression.recommend(target, exercise: bench, history: log, bodyweight: nil)
        #expect(close(plan.oneRepMax, 100 * 36 / 27 * 1.05, tolerance: 1e-9))
        #expect(plan.sets[0].effort.load!.kilograms <= 110)
    }

    @Test func coarseStepsStayInTheRangeOrExpandItWhenAllowed() {
        let machine = ExerciseLibrary.bundled.exercise("machine-chest-press")!
        let log = history("machine-chest-press", [[set(8, .kg(60))], [set(8, .kg(60))]])
        let narrow = SlotTarget(sets: 3, minReps: 8, maxReps: 8, rir: 2)
        let steps = LoadIncrements(kilograms: 10, pounds: 20)
        let strict = Progression.recommend(narrow, exercise: machine, history: log, bodyweight: nil, increments: steps)
        #expect(strict.sets[0].effort.reps == 8)
        let expanded = Progression.recommend(narrow, exercise: machine, history: log, bodyweight: nil, increments: steps,
                                             expandRepRange: true)
        #expect(expanded.sets[0].effort.reps.map { (6...10).contains($0) } == true)
    }

    @Test func poundsLiftersGetPoundLoadsOnFivePoundSteps() {
        let log = history("barbell-bench-press", [[set(8, .lb(225))], [set(8, .lb(225))]])
        let plan = Progression.recommend(target, exercise: bench, history: log, bodyweight: nil)
        let load = plan.sets[0].effort.load!
        #expect(load.unit == .pounds && load.value.truncatingRemainder(dividingBy: 5) == 0)
    }

    @Test func bodyweightLiftsAddLoadOnlyWhenNeeded() {
        let pullUp = ExerciseLibrary.bundled.exercise("pull-up")!
        let strong = history("pull-up", [[set(8, .kg(20))], [set(9, .kg(20))]])
        let loaded = Progression.recommend(target, exercise: pullUp, history: strong, bodyweight: .kg(80))
        #expect((loaded.sets[0].effort.load?.kilograms ?? 0) >= 20)
        let light = history("pull-up", [[set(5, nil, rir: 1)], [set(6, nil, rir: 1)]])
        let unloaded = Progression.recommend(target, exercise: pullUp, history: light, bodyweight: .kg(80))
        #expect(unloaded.sets[0].effort.load == nil)
        #expect(unloaded.sets[0].effort.reps.map { (6...8).contains($0) } == true)
    }

    @Test func anEmptyBarIsTheLightestBarbellLoad() {
        let log = history("barbell-bench-press", [[set(8, .kg(20), rir: 5)], [set(8, .kg(20), rir: 5)]])
        let heavy = SlotTarget(sets: 3, minReps: 15, maxReps: 20, rir: 4)
        let plan = Progression.recommend(heavy, exercise: bench, history: log, bodyweight: nil)
        #expect(plan.sets[0].effort.load == .kg(20))
    }
}

@MainActor
@Suite struct ProgramStoreTests {
    @Test func followingAProgramPlansStartsAndAdvancesWorkouts() throws {
        let persistence = InMemoryTrainingPersistence()
        let clock = Fixture.instant()
        let training = try TrainingStore(persistence: persistence, now: { clock })
        let programs = try ProgramStore(persistence: persistence, training: training, now: { clock })
        let program = fullBody()
        try programs.save(program)
        #expect(programs.nextWorkout(bodyweight: .kg(80)) == nil, "Nothing is active yet")
        try programs.activate(program.id)

        let plan = try #require(programs.nextWorkout(bodyweight: .kg(80)))
        #expect(plan.name == "Full body: A" && plan.program?.cycle == 0 && !plan.isDeload)
        #expect(plan.exercises.map(\.recommendation.reason) == [.firstSession, .firstSession])
        let session = try training.startSession(from: plan, bodyweight: .kg(80))
        #expect(session.program == plan.program)
        #expect(session.exercises.map { $0.sets.count } == [3, 3])
        #expect(session.exercises[0].sets.allSatisfy { !$0.isCompleted && $0.primary.reps == 7 && $0.rir == 2 })
        #expect(session.exercises[0].restOverride == 150)

        for performed in session.exercises {
            for set in performed.sets {
                var done = set
                done.primary.load = .kg(100)
                try training.updateSet(done, in: performed.id)
                try training.completeSet(set.id)
            }
        }
        try training.finishSession()
        let next = try #require(programs.nextWorkout(bodyweight: .kg(80)))
        #expect(next.name == "Full body: B")
        #expect(next.exercises.map(\.exerciseID) == ["deadlift", "pull-up"])
    }

    @Test func programsAreValidatedArchivedRestoredAndDuplicated() throws {
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let programs = try ProgramStore(persistence: persistence, training: training)
        var invalid = fullBody()
        invalid.days = [ProgramDay(name: "Rest")]
        #expect(throws: ProgramStore.StoreError.invalid(["a program needs a training day"])) { try programs.save(invalid) }
        let program = fullBody()
        try programs.save(program)
        try programs.activate(program.id)
        try programs.archive(program.id)
        #expect(programs.active == nil)
        try programs.restore(program.id)
        #expect(programs.active?.id == program.id)
        let copy = try programs.duplicate(program.id, name: "Full body II")
        #expect(copy.id != program.id && copy.days.count == 3 && copy.activatedAt == nil)
        #expect(Set(copy.days.flatMap { $0.slots.map(\.id) }).isDisjoint(with: program.days.flatMap { $0.slots.map(\.id) }))
        #expect(try ProgramStore(persistence: persistence, training: training).programs.count == 2, "Saved")
    }

    @Test func archivingOrRestoringSaysWhichProgramWillBeFollowed() throws {
        let persistence = InMemoryTrainingPersistence()
        var clock = Fixture.instant()
        let programs = try ProgramStore(persistence: persistence, training: try TrainingStore(persistence: persistence),
                                        now: { clock })
        let first = fullBody(), second = fullBody()
        try programs.save(first)
        try programs.save(second)
        try programs.activate(first.id)
        clock += 60
        try programs.activate(second.id)

        #expect(programs.activeAfterArchiving(second.id)?.id == first.id)
        #expect(programs.active?.id == second.id, "A preview changes nothing")
        try programs.archive(second.id)
        #expect(programs.active?.id == first.id)
        #expect(programs.activeAfterRestoring(second.id)?.id == second.id)
        try programs.restore(second.id)
        #expect(programs.active?.id == second.id)
        #expect(programs.activeAfterArchiving(first.id)?.id == second.id, "Archiving one not followed changes nothing")
    }

    @Test func programsSyncAndCanBeProposedByAnAgent() async throws {
        let server = FakeDocumentServer()
        let phoneStore = InMemoryTrainingPersistence()
        let phoneTraining = try TrainingStore(persistence: phoneStore)
        let phonePrograms = try ProgramStore(persistence: phoneStore, training: phoneTraining)
        let phoneAgent = try AgentStore(persistence: phoneStore, hosts: [phoneTraining, phonePrograms])
        let phone = SyncEngine(hosts: [phoneTraining, phonePrograms, phoneAgent], state: phoneStore, api: server)

        let program = fullBody()
        let proposal = Proposal(author: AgentIdentity(kind: .mcp, name: "Synthetic coach"), title: "A three-day plan",
                                summary: "Full body, three days a week.",
                                changes: [try ProposedChange(kind: "program", id: program.id.uuidString,
                                                             before: Program?.none, after: program)],
                                evidence: [], confidence: .medium, falsifier: "You can't train three days a week.")
        try phoneAgent.file(proposal)
        try phoneAgent.accept(proposal.id)
        #expect(phonePrograms.program(program.id) == program)
        try await phone.sync()

        let tabletStore = InMemoryTrainingPersistence()
        let tabletTraining = try TrainingStore(persistence: tabletStore)
        let tabletPrograms = try ProgramStore(persistence: tabletStore, training: tabletTraining)
        let tablet = SyncEngine(hosts: [tabletTraining, tabletPrograms], state: tabletStore, api: server)
        try await tablet.sync()
        #expect(tabletPrograms.programs == [program])
    }
}
