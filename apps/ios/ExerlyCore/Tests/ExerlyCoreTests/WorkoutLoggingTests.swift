import Foundation
import Testing
@testable import ExerlyCore

@Suite struct WorkoutLoggingTests {
    let library = Fixture.library

    @Test func barbellStepsSnapOntoTheGridAndStopAtTheBar() {
        let barbell = LoadIncrements(kilograms: 2.5, pounds: 5, minimum: .kg(20))
        #expect(barbell.stepped(60, up: true, in: .kilograms) == 62.5)
        #expect(barbell.stepped(60, up: false, in: .kilograms) == 57.5)
        #expect(barbell.stepped(61, up: true, in: .kilograms) == 62.5, "off-grid loads snap up")
        #expect(barbell.stepped(61, up: false, in: .kilograms) == 60, "and down")
        #expect(barbell.stepped(0, up: true, in: .kilograms) == 20, "an empty field starts at the bar")
        #expect(barbell.stepped(20, up: false, in: .kilograms) == 20, "never below the bar")
        #expect(barbell.stepped(22.5, up: false, in: .kilograms) == 20)
        #expect(barbell.stepped(135, up: true, in: .pounds) == 140)
        #expect(barbell.stepped(0, up: true, in: .pounds) == 45, "a 20 kg bar reads 45 lb, not 44.09")
        #expect(barbell.stepped(45, up: false, in: .pounds) == 45)
    }

    @Test func plainStepsNeverGoBelowZeroAndKeepFractions() {
        let cable = LoadIncrements(kilograms: 1.25, pounds: 2.5)
        #expect(cable.stepped(0, up: false, in: .kilograms) == 0)
        #expect(cable.stepped(1.25, up: false, in: .kilograms) == 0)
        #expect(cable.stepped(3.75, up: true, in: .kilograms) == 5)
        #expect(cable.stepped(.nan, up: true, in: .kilograms) == 1.25)
        #expect(cable.stepped(-4, up: true, in: .pounds) == 2.5)
        let none = LoadIncrements(kilograms: 0, pounds: 0)
        #expect(none.stepped(12, up: true, in: .kilograms) == 12)
    }

    @Test func listedWeightsStepThroughWhatTheGymHas() {
        let dumbbells = LoadIncrements(kilograms: 2, pounds: 5, available: [.kg(10), .kg(12.5), .lb(35), .kg(20), .kg(12.5)])
        #expect(dumbbells.stepped(12.5, up: true, in: .kilograms) == 15.875733, "35 lb, in kilograms")
        #expect(dumbbells.stepped(13, up: false, in: .kilograms) == 12.5)
        #expect(dumbbells.stepped(0, up: true, in: .kilograms) == 10)
        #expect(dumbbells.stepped(20, up: true, in: .kilograms) == 20, "the heaviest stays")
        #expect(dumbbells.stepped(10, up: false, in: .kilograms) == 10, "the lightest stays")
        #expect(dumbbells.stepped(30, up: true, in: .pounds) == 35)
    }

    @Test func gymIncrementsComeFromItsSmallestPlates() throws {
        let gym = GymProfile(name: "Synthetic garage", bars: [.lb(45)], plates: [PlateStock(.lb(45), pairs: 2), PlateStock(.lb(5), pairs: 2)])
        let squat = try #require(library.exercise("back-squat"))
        let increments = gym.increments(for: squat)
        #expect(increments.stepped(135, up: true, in: .pounds) == 145)
        #expect(increments.stepped(0, up: true, in: .pounds) == 45)
    }

    @Test func estimatedDurationAddsWorkAndRestInTheOrderSetsAreDone() throws {
        let bench = SlotTarget(sets: 3, minReps: 5, maxReps: 8, rir: 2)
        let program = Program(name: "Synthetic", days: [ProgramDay(name: "Upper", slots: [
            ProgramSlot(exerciseID: "barbell-bench-press", target: bench)
        ])], cycles: 1)
        let history = TrainingHistory(sessions: [], library: library)
        let position = try #require(ProgramSchedule.next(for: program, in: history))
        let plan = ProgramSchedule.plan(program, at: position, history: history, bodyweight: nil)
        // Three sets of work and two rests for an upper-body compound lift.
        #expect(plan.estimatedDuration(library: library) == 3 * 45 + 2 * 150)
        #expect(plan.estimatedDuration(library: library, secondsPerSet: 30) == 3 * 30 + 2 * 150)

        var timed = program
        timed.days[0].slots[0].target.rest = 60
        let override = ProgramSchedule.plan(timed, at: try #require(ProgramSchedule.next(for: timed, in: history)),
                                            history: history, bodyweight: nil)
        #expect(override.estimatedDuration(library: library) == 3 * 45 + 2 * 60)
    }

    @Test func supersetsRestOnlyBetweenRounds() throws {
        let group = UUID()
        let target = SlotTarget(sets: 2, minReps: 8, maxReps: 12, rir: 2)
        let program = Program(name: "Synthetic", days: [ProgramDay(name: "Upper", slots: [
            ProgramSlot(exerciseID: "barbell-bench-press", supersetID: group, target: target),
            ProgramSlot(exerciseID: "dumbbell-lateral-raise", supersetID: group, target: target),
            ProgramSlot(exerciseID: "plank", target: SlotTarget(sets: 1, minReps: 1, maxReps: 1, rir: 0))
        ])], cycles: 1)
        let history = TrainingHistory(sessions: [], library: library)
        var plan = ProgramSchedule.plan(program, at: try #require(ProgramSchedule.next(for: program, in: history)),
                                        history: history, bodyweight: nil)
        plan.exercises[2].recommendation.sets[0].effort.duration = 60
        // bench, raise (no rest), bench (150 before the round), raise, then 120 before the plank.
        let expected: Double = 4 * 45 + 150 + 120 + 60
        #expect(plan.estimatedDuration(library: library) == expected)
        #expect(WorkoutPlan(name: "Empty", program: nil, isDeload: false, exercises: []).estimatedDuration(library: library) == 0)
    }

    @Test func nearestLoadRoundsOntoWhatTheEquipmentAllows() {
        let bodyweight = LoadIncrements(kilograms: 1.25, pounds: 2.5)
        #expect(bodyweight.nearest(11.023, in: .pounds) == 10)
        #expect(bodyweight.nearest(11.3, in: .pounds) == 12.5)
        #expect(bodyweight.nearest(11.25, in: .pounds) == 10, "halfway rounds down")
        #expect(bodyweight.nearest(10, in: .pounds) == 10)
        let barbell = LoadIncrements(kilograms: 2.5, pounds: 5, minimum: .kg(20))
        #expect(barbell.nearest(30, in: .pounds) == 45, "never below the bar")
        #expect(barbell.nearest(100, in: .kilograms) == 100)
        let dumbbells = LoadIncrements(kilograms: 2, pounds: 5, available: [.lb(20), .lb(25), .lb(30)])
        #expect(dumbbells.nearest(23.5, in: .pounds) == 25)
        #expect(dumbbells.nearest(50, in: .pounds) == 30)
    }

    @Test func plansSpeakThePersonsUnitWithoutTouchingTheirOwnLoads() throws {
        let pullUp = try #require(library.exercise("pull-up"))
        let bench = try #require(library.exercise("barbell-bench-press"))
        let target = SlotTarget(sets: 2, minReps: 6, maxReps: 10, rir: 1)
        func planned(_ exercise: ExerlyCore.Exercise, _ load: Mass) -> PlannedExercise {
            PlannedExercise(slotID: nil, exerciseID: exercise.id, notes: "", supersetID: nil, target: target,
                            recommendation: Recommendation(sets: Array(repeating: PlannedSet(kind: .standard, effort: Effort(reps: 8, load: load), rir: 1), count: 2),
                                                           reason: .progress, oneRepMax: nil, basisSetID: nil, outsideRange: false))
        }
        let plan = WorkoutPlan(name: "Upper", program: nil, isDeload: false,
                               exercises: [planned(pullUp, .kg(5)), planned(bench, .lb(162.5))])
        let pounds = plan.expressed(in: .pounds, library: library)
        #expect(pounds.exercises[0].recommendation.sets.map(\.effort.load) == [.lb(10), .lb(10)])
        #expect(pounds.exercises[1].recommendation.sets[0].effort.load == .lb(162.5), "loads already in pounds stay exact")
        let kilograms = plan.expressed(in: .kilograms, library: library)
        #expect(kilograms.exercises[0].recommendation.sets[0].effort.load == .kg(5))
        #expect(kilograms.exercises[1].recommendation.sets[0].effort.load == .kg(72.5), "73.7 kg on a 2.5 kg grid from the bar")
    }
}
