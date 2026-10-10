import XCTest
import ExerlyCore
@testable import Exerly

@MainActor
final class TrainingLoggingPresentationTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func program() -> Program {
        Program(name: "Synthetic strength", days: [ProgramDay(name: "Upper", slots: [
            ProgramSlot(exerciseID: "barbell-bench-press", target: SlotTarget(sets: 3, minReps: 5, maxReps: 8, rir: 2)),
            ProgramSlot(exerciseID: "pull-up", target: SlotTarget(sets: 2, minReps: 6, maxReps: 10, rir: 1),
                        cycleTargets: [1: SlotTarget(sets: 3, minReps: 6, maxReps: 10, rir: 0)])
        ])], cycles: 2)
    }

    func testStartingTodaysWorkoutUsesTheLatestWeighInWithoutAsking() throws {
        let workspace = try TrainingWorkspace(accountID: "logger-start", root: root)
        XCTAssertFalse(try workspace.startNextWorkout(timeZone: .gmt), "No program, nothing to start")
        let plan = program()
        try workspace.programs.save(plan)
        try workspace.programs.activate(plan.id)
        _ = try workspace.nutrition.logWeight(.lb(180), at: Date(timeIntervalSince1970: 1_791_000_000), timeZone: .gmt)
        _ = try workspace.nutrition.logWeight(.lb(182.5), at: Date(timeIntervalSince1970: 1_791_100_000), timeZone: .gmt)
        XCTAssertEqual(workspace.latestBodyweight, .lb(182.5))

        XCTAssertTrue(try workspace.startNextWorkout(timeZone: .gmt, unit: .pounds))
        let session = try XCTUnwrap(workspace.store.activeSession)
        XCTAssertEqual(session.bodyweight, .lb(182.5))
        XCTAssertEqual(session.name, "Synthetic strength: Upper")
        XCTAssertEqual(session.program?.programID, plan.id)
        XCTAssertEqual(session.exercises.map(\.sets.count), [3, 2])
        XCTAssertFalse(session.exercises.flatMap(\.sets).contains(where: \.isCompleted), "Planned sets start incomplete")
        XCTAssertThrowsError(try workspace.startNextWorkout(timeZone: .gmt), "One workout at a time")
    }

    func testExerciseTargetsComeFromTheSessionsCycle() throws {
        let workspace = try TrainingWorkspace(accountID: "logger-targets", root: root)
        let plan = program()
        try workspace.programs.save(plan)
        let slots = plan.days[0].slots
        let session = WorkoutSession(name: "Upper", program: ProgramRef(programID: plan.id, dayID: plan.days[0].id, cycle: 1))
        let targets = workspace.slotTargets(for: session)
        XCTAssertEqual(targets[slots[0].id]?.sets, 3)
        XCTAssertEqual(targets[slots[1].id]?.rir, 0, "The cycle's own target")
        XCTAssertTrue(workspace.slotTargets(for: WorkoutSession(name: "Ad hoc")).isEmpty)
        let library = ExerlyCore.ExerciseLibrary.bundled
        XCTAssertEqual(TrainingFormat.compactTarget(slots[0].target, exercise: library.exercise("barbell-bench-press")), "3 × 5–8 · 2 RIR")
        XCTAssertEqual(TrainingFormat.compactTarget(SlotTarget(sets: 1, minReps: 5, maxReps: 5, rir: 1), exercise: library.exercise("deadlift")),
                       "1 × 5 · 1 RIR")
        XCTAssertEqual(TrainingFormat.compactTarget(SlotTarget(sets: 2, minReps: 1, maxReps: 1, rir: 0), exercise: library.exercise("plank")), "2 sets")
    }

    func testPreviousColumnIsShortAndKeepsTheEnteredUnit() {
        let pounds = PerformedSet(efforts: [Effort(reps: 8, load: .lb(155))])
        XCTAssertEqual(TrainingFormat.compact(pounds, metric: .weightReps, unit: .pounds), "155 × 8")
        XCTAssertEqual(TrainingFormat.compact(PerformedSet(efforts: [Effort(reps: 9)]), metric: .bodyweightReps, unit: .pounds), "BW × 9")
        XCTAssertEqual(TrainingFormat.compact(PerformedSet(efforts: [Effort(reps: 8, load: .kg(10))]), metric: .bodyweightReps, unit: .kilograms), "+10 × 8")
        XCTAssertEqual(TrainingFormat.compact(PerformedSet(efforts: [Effort(reps: 6, load: .kg(20))]), metric: .assistedReps, unit: .kilograms), "−20 × 6")
        XCTAssertEqual(TrainingFormat.compact(PerformedSet(efforts: [Effort(duration: 45)]), metric: .duration, unit: .kilograms), "45 s")
        let drop = PerformedSet(kind: .drop, efforts: [Effort(reps: 8, load: .kg(40)), Effort(reps: 6, load: .kg(30))])
        XCTAssertEqual(TrainingFormat.compact(drop, metric: .weightReps, unit: .kilograms), "40 × 8 +1")
        let converted = PerformedSet(efforts: [Effort(reps: 5, load: .kg(60))])
        XCTAssertEqual(TrainingFormat.compact(converted, metric: .weightReps, unit: .pounds), "132.3 × 5")
    }

    func testLoadsShowToATenthWithoutTrailingZeros() {
        XCTAssertEqual(TrainingFormat.load(140), "140")
        XCTAssertEqual(TrainingFormat.load(132.277), "132.3")
        XCTAssertEqual(TrainingFormat.load(62.25), "62.3")
        XCTAssertEqual(TrainingFormat.load(1250.04), "1250")
        XCTAssertEqual(TrainingFormat.mass(.kg(60), unit: .pounds), "132.3 lb")
        XCTAssertEqual(TrainingFormat.mass(.lb(140), unit: .pounds), "140 lb")
        XCTAssertEqual(TrainingFormat.set(PerformedSet(efforts: [Effort(reps: 5, load: .kg(60))]), unit: .pounds), "132.3 lb × 5 reps")
        XCTAssertEqual(InsightFormat.set(PerformedSet(efforts: [Effort(reps: 5, load: .kg(60))]), unit: .pounds), "132.3 lb × 5")
    }

    func testWorkoutDatesReadAsDaysAndNameOnlyAnotherZone() throws {
        let today = try XCTUnwrap(LocalDate("2026-10-09"))
        XCTAssertEqual(TrainingFormat.through(today, today: today), "Through today")
        XCTAssertEqual(TrainingFormat.through(today.adding(days: -1), today: today), "Through yesterday")
        XCTAssertEqual(TrainingFormat.through(today.adding(days: -3), today: today), "Through Tue, Oct 6")
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let losAngeles = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertNil(TrainingFormat.zoneNote(newYork, account: newYork))
        XCTAssertNil(TrainingFormat.zoneNote(try XCTUnwrap(TimeZone(identifier: "America/Detroit")), account: newYork),
                     "Another city in the same zone isn't worth a line")
        let note = try XCTUnwrap(TrainingFormat.zoneNote(losAngeles, account: newYork))
        XCTAssertTrue(note.hasPrefix("Logged in "), note)
        XCTAssertFalse(note.contains("/"), note)
        XCTAssertEqual(TrainingFormat.minutes(1800), "30 min")
    }

    func testGridCellsShowWhatTheSetHoldsAndPointAtWhatIsMissing() throws {
        let library = ExerlyCore.ExerciseLibrary.bundled
        let bench = try XCTUnwrap(library.exercise("barbell-bench-press"))
        let set = PerformedSet(efforts: [Effort(reps: 8, load: .kg(60))], rir: 6)
        XCTAssertEqual(SetGrid.text(.load, of: set, unit: .kilograms), "60")
        XCTAssertEqual(SetGrid.text(.rir, of: set, unit: .kilograms), "6+")
        XCTAssertEqual(SetGrid.text(.load, of: set, unit: .pounds), "132.3", "Shown in the person's unit to 0.1, saved as entered")
        XCTAssertEqual(SetGrid.fields(.weightReps), [.load, .reps, .rir])
        XCTAssertEqual(SetGrid.fields(.distanceDuration), [.distance, .duration])
        XCTAssertEqual(SetGrid.shortTitle(.load, metric: .bodyweightReps, unit: .pounds), "+LB")
        XCTAssertEqual(SetGrid.missing(PerformedSet(efforts: [Effort(reps: 8)]), exercise: bench), .load)
        XCTAssertEqual(SetGrid.missing(PerformedSet(efforts: [Effort(load: .kg(60))]), exercise: bench), .reps)
        let plank = try XCTUnwrap(library.exercise("plank"))
        XCTAssertEqual(SetGrid.missing(PerformedSet(), exercise: plank), .duration)
    }

    func testEmptyWorkoutNamesFollowTheLocalTimeOfDay() {
        let newYork = TimeZone(identifier: "America/New_York")!
        // 2026-10-05 13:00 UTC is 09:00 in New York.
        let morning = Date(timeIntervalSince1970: 1_791_205_200)
        XCTAssertEqual(TrainingFormat.emptyWorkoutName(at: morning, timeZone: newYork), "Morning workout")
        XCTAssertEqual(TrainingFormat.emptyWorkoutName(at: morning.addingTimeInterval(5 * 3600), timeZone: newYork), "Afternoon workout")
        XCTAssertEqual(TrainingFormat.emptyWorkoutName(at: morning.addingTimeInterval(10 * 3600), timeZone: newYork), "Evening workout")
        XCTAssertEqual(TrainingFormat.minutes(42 * 60 + 20), "42 min")
        XCTAssertEqual(TrainingFormat.minutes(65 * 60), "1 h 5 min")
        XCTAssertEqual(TrainingFormat.minutes(120 * 60), "2 h")
    }

    func testPlannedWorkoutTitlesPutTheDayFirst() {
        let reference = ProgramRef(programID: UUID(), dayID: UUID(), cycle: 0)
        let planned = TrainingFormat.title(of: WorkoutSession(name: "Strength foundations: Upper A", program: reference))
        XCTAssertEqual(planned.name, "Upper A")
        XCTAssertEqual(planned.program, "Strength foundations")
        let adHoc = TrainingFormat.title(of: WorkoutSession(name: "Legs: heavy"))
        XCTAssertEqual(adHoc.name, "Legs: heavy", "Only planned sessions are split")
        XCTAssertNil(adHoc.program)
    }
}
