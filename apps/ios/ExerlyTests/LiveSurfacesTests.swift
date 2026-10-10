import ExerlyCore
import XCTest
@testable import Exerly

/// The workout's Live Activity content, its buttons, and the widgets' snapshot.
@MainActor
final class LiveSurfacesTests: XCTestCase {
    private var clock = Date(timeIntervalSince1970: 1_791_000_000)

    private func makeStore() throws -> TrainingStore {
        try TrainingStore(persistence: InMemoryTrainingPersistence(), now: { [unowned self] in clock })
    }

    /// An ad hoc workout: bench press with three sets of 160 lb × 7, and a
    /// pull-up whose reps aren't filled in.
    private func startBench(_ store: TrainingStore) throws -> (session: UUID, bench: [UUID], pullUp: UUID) {
        let session = try store.startSession(name: "Upper A", bodyweight: .kg(80))
        let bench = try store.addExercise("barbell-bench-press")
        try store.addSet(to: bench)
        try store.addSet(to: bench)
        for var set in try XCTUnwrap(store.activeSession?.exercises.first?.sets) {
            set.primary = Effort(reps: 7, load: .lb(160))
            try store.updateSet(set, in: bench)
        }
        try store.addExercise("pull-up")
        let sets = try XCTUnwrap(store.activeSession?.exercises.first?.sets.map(\.id))
        let pullUpSet = try XCTUnwrap(store.activeSession?.exercises.last?.sets.first?.id)
        return (session.id, sets, pullUpSet)
    }

    // MARK: Live Activity content

    func testContentFollowsSetsRestAndTheNextSetInThePersonsUnit() throws {
        let store = try makeStore()
        let workout = try startBench(store)
        let start = clock

        var content = try XCTUnwrap(WorkoutActivityContent(store: store, unit: .pounds, now: clock))
        XCTAssertEqual(content.workoutID, workout.session)
        XCTAssertEqual(content.state.title, "Upper A")
        XCTAssertNil(content.state.program)
        XCTAssertEqual(content.state.startedAt, start)
        XCTAssertEqual(content.state.setsLabel, "0/4")
        XCTAssertNil(content.state.rest)
        var next = try XCTUnwrap(content.state.next)
        XCTAssertEqual(next.setID, workout.bench[0])
        XCTAssertEqual(next.line, "Barbell Bench Press · Set 1 · 160 lb × 7")
        XCTAssertEqual(next.spokenLine, "Next, Barbell Bench Press, set 1, 160 pounds, 7 reps")
        XCTAssertTrue(next.isLoggable)
        // The same set in kilograms, to the nearest 0.1.
        XCTAssertEqual(WorkoutActivityContent(store: store, unit: .kilograms, now: clock)?.state.next?.values, "72.6 kg × 7")

        clock += 60
        try store.completeSet(workout.bench[0])
        content = try XCTUnwrap(WorkoutActivityContent(store: store, unit: .pounds, now: clock))
        let timer = try XCTUnwrap(store.restTimer)
        XCTAssertEqual(content.state.rest, .init(startedAt: timer.startedAt, endsAt: timer.endsAt))
        XCTAssertEqual(content.state.spokenSets, "1 of 4 sets done")
        next = try XCTUnwrap(content.state.next)
        XCTAssertEqual(next.setID, workout.bench[1])
        XCTAssertEqual(next.number, 2)
        XCTAssertEqual(content.state.activeRest(isStale: false), content.state.rest)
        XCTAssertNil(content.state.activeRest(isStale: true), "Rest ends on the Lock Screen when the content goes stale")

        // Once rest is over, the next change shows no countdown.
        XCTAssertNil(WorkoutActivityContent(store: store, unit: .pounds, now: timer.endsAt)?.state.rest)

        try store.completeSet(workout.bench[1])
        try store.completeSet(workout.bench[2])
        next = try XCTUnwrap(WorkoutActivityContent(store: store, unit: .pounds, now: clock)?.state.next)
        XCTAssertEqual(next.line, "Pull-Up · Set 1 · BW × –")
        XCTAssertFalse(next.isLoggable, "A set missing its reps can't be logged from the Lock Screen")

        try store.discardSession()
        XCTAssertNil(WorkoutActivityContent(store: store, unit: .pounds, now: clock))
    }

    func testAPlannedWorkoutShowsItsDayWithTheProgramBeside() throws {
        let persistence = InMemoryTrainingPersistence()
        let store = try TrainingStore(persistence: persistence)
        let programs = try ProgramStore(persistence: persistence, training: store)
        let program = Program(name: "Strength foundations", days: [ProgramDay(name: "Upper A", slots: [
            ProgramSlot(exerciseID: "barbell-bench-press", target: SlotTarget(sets: 3, minReps: 5, maxReps: 8, rir: 2)),
        ])], cycles: 1)
        try programs.save(program)
        try programs.activate(program.id)
        try store.startSession(from: XCTUnwrap(programs.nextWorkout(bodyweight: nil)), bodyweight: nil)
        let state = try XCTUnwrap(WorkoutActivityContent(store: store, unit: .kilograms)?.state)
        XCTAssertEqual(state.title, "Upper A")
        XCTAssertEqual(state.program, "Strength foundations")
        XCTAssertEqual(state.setsLabel, "0/3")
        XCTAssertEqual(state.next?.values, "– × 6", "A first workout has no load yet")
    }

    func testValuesKeepTheirUnitForEveryKindOfSet() {
        func values(_ efforts: [Effort], _ metric: TrackingMetric, _ unit: MassUnit = .pounds) -> String {
            let result = WorkoutActivityContent.values(PerformedSet(kind: efforts.count > 1 ? .drop : .standard, efforts: efforts),
                                                       metric: metric, unit: unit)
            return "\(result.text) | \(result.spoken)"
        }
        XCTAssertEqual(values([Effort(reps: 9)], .bodyweightReps), "BW × 9 | bodyweight, 9 reps")
        XCTAssertEqual(values([Effort(reps: 8, load: .kg(10))], .bodyweightReps, .kilograms),
                       "+10 kg × 8 | bodyweight plus 10 kilograms, 8 reps")
        XCTAssertEqual(values([Effort(reps: 6, load: .lb(40))], .assistedReps), "−40 lb × 6 | 40 pounds assistance, 6 reps")
        XCTAssertEqual(values([Effort(duration: 45)], .duration), "45 s | 45 seconds")
        XCTAssertEqual(values([Effort(load: .kg(20), duration: 30)], .weightDuration, .kilograms),
                       "20 kg · 30 s | 20 kilograms, 30 seconds")
        XCTAssertEqual(values([Effort(duration: 300, distance: 1000)], .distanceDuration), "1000 m · 300 s | 1000 metres, 300 seconds")
        XCTAssertEqual(values([Effort(load: .lb(90), distance: 40)], .weightDistance), "90 lb · 40 m | 90 pounds, 40 metres")
        XCTAssertEqual(values([Effort(reps: 1, load: .lb(100)), Effort(reps: 4, load: .lb(80))], .weightReps),
                       "100 lb × 1 +1 | 100 pounds, 1 rep, then 1 more")
        XCTAssertEqual(values([Effort()], .weightReps), "– × – | weight not set, reps not set")
    }

    // MARK: Live Activity buttons

    func testButtonsOnlyChangeTheWorkoutAndSetTheyWereDrawnFor() throws {
        let store = try makeStore()
        let workout = try startBench(store)

        XCTAssertFalse(WorkoutActivityActions.apply(.completeSet(workout.bench[0]), to: UUID(), in: store),
                       "A button left from another workout does nothing")
        XCTAssertFalse(try XCTUnwrap(store.activeSession?.set(workout.bench[0])?.set.isCompleted))

        XCTAssertTrue(WorkoutActivityActions.apply(.completeSet(workout.bench[0]), to: workout.session, in: store))
        XCTAssertTrue(try XCTUnwrap(store.activeSession?.set(workout.bench[0])?.set.isCompleted))
        let rest = try XCTUnwrap(store.restTimer)
        XCTAssertFalse(WorkoutActivityActions.apply(.completeSet(workout.bench[0]), to: workout.session, in: store),
                       "A second tap on the same button doesn't log another set")
        XCTAssertEqual(store.summary(of: try XCTUnwrap(store.activeSession)).completedSets, 1)

        XCTAssertTrue(WorkoutActivityActions.apply(.extendRest(seconds: 30), to: workout.session, in: store))
        XCTAssertEqual(store.restTimer?.endsAt, rest.endsAt.addingTimeInterval(30))
        XCTAssertTrue(WorkoutActivityActions.apply(.skipRest, to: workout.session, in: store))
        XCTAssertNil(store.restTimer)
        XCTAssertFalse(WorkoutActivityActions.apply(.skipRest, to: workout.session, in: store))
        XCTAssertFalse(WorkoutActivityActions.apply(.extendRest(seconds: 30), to: workout.session, in: store),
                       "+30 s after rest is over doesn't start a new rest")

        XCTAssertFalse(WorkoutActivityActions.apply(.completeSet(workout.pullUp), to: workout.session, in: store),
                       "A set without its values isn't logged")
        XCTAssertFalse(try XCTUnwrap(store.activeSession?.set(workout.pullUp)?.set.isCompleted))
    }

    // MARK: Widget snapshot

    func testSnapshotCoversTodayTomorrowAndTheWorkoutToShow() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let zone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let workspace = try TrainingWorkspace(accountID: "widgets", root: root)
        let now = Date()
        let today = LocalDate(now, in: zone)
        try workspace.nutrition.savePlan(NutritionPlan(startDate: today, goal: NutritionGoal(.maintain), mode: .manual,
                                                       targets: Array(repeating: DailyTargets(energy: 2300, protein: 160, fat: 70, carbohydrate: 250), count: 7)),
                                         timeZone: zone)
        let oats = ExerlyCore.Food(name: "Synthetic oats", per100g: NutrientAmounts([.energy: 380, .protein: 13, .fat: 7, .carbohydrate: 60]))
        try workspace.nutrition.log(oats, grams: 100, on: today, meal: "Breakfast")
        let program = Program(name: "Strength foundations", days: [
            ProgramDay(name: "Upper A", slots: [
                ProgramSlot(exerciseID: "barbell-bench-press", target: SlotTarget(sets: 3, minReps: 5, maxReps: 8, rir: 2)),
                ProgramSlot(exerciseID: "pull-up", target: SlotTarget(sets: 2, minReps: 6, maxReps: 10, rir: 2)),
            ]),
            ProgramDay(name: "Lower A", slots: [
                ProgramSlot(exerciseID: "deadlift", target: SlotTarget(sets: 3, minReps: 5, maxReps: 8, rir: 2)),
            ]),
        ], cycles: 2)
        try workspace.programs.save(program)
        try workspace.programs.activate(program.id)
        let writer = WidgetSnapshotWriter(workspace: workspace, unit: .pounds, timeZone: zone, url: nil)

        var snapshot = writer.snapshot(at: now)
        XCTAssertEqual(snapshot.days.count, 2)
        let day = try XCTUnwrap(snapshot.day(at: now))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        XCTAssertEqual(day.start, calendar.startOfDay(for: now), "Days turn over at the account's midnight")
        XCTAssertEqual(snapshot.days[1].start, day.end)
        XCTAssertEqual(day.energy, .init(consumed: 380, target: 2300))
        XCTAssertEqual(day.energy.remaining, 1920)
        XCTAssertEqual(day.protein, .init(consumed: 13, target: 160))
        XCTAssertEqual(snapshot.days[1].energy, .init(consumed: 0, target: 2300))
        XCTAssertEqual(snapshot.workout(at: now), .planned(.init(name: "Upper A", program: "Strength foundations", isDeload: false,
                                                                    exercises: [.init(name: "Barbell Bench Press", sets: 3),
                                                                                .init(name: "Pull-Up", sets: 2)])))
        XCTAssertEqual(snapshot.changes(after: now), [day.end, snapshot.days[1].end])

        try workspace.startNextWorkout(timeZone: zone, unit: .pounds)
        snapshot = writer.snapshot(at: now)
        guard case .active(let active) = snapshot.workout(at: now) else { return XCTFail("Expected the workout in progress") }
        XCTAssertEqual(active.name, "Upper A")
        XCTAssertEqual(active.totalSets, 5)

        var set = try XCTUnwrap(workspace.store.activeSession?.exercises.first?.sets.first)
        set.primary = Effort(reps: 8, load: .lb(135))
        try workspace.store.updateSet(set, in: XCTUnwrap(workspace.store.activeSession?.exercises.first?.id))
        try workspace.store.completeSet(set.id)
        try workspace.store.finishSession()
        snapshot = writer.snapshot(at: now)
        let next = WidgetSnapshot.PlannedWorkout(name: "Lower A", program: "Strength foundations", isDeload: false,
                                                 exercises: [.init(name: "Deadlift", sets: 3)])
        XCTAssertEqual(snapshot.workout(at: now), .done(.init(name: "Upper A", workingSets: 1, until: day.end), next: next))
        XCTAssertEqual(snapshot.workout(at: day.end), .planned(next), "Tomorrow shows the next workout")
        XCTAssertNil(snapshot.day(at: snapshot.days[1].end), "Past tomorrow the widget asks for the app")
    }

    func testSnapshotWritesOnlyWhenItChangesAndIsRemovedAtSignOut() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let start = Date(timeIntervalSince1970: 1_791_000_000)
        var snapshot = WidgetSnapshot(days: [.init(start: start, end: start + 86_400, energy: .init(consumed: 900, target: nil),
                                                   protein: .init(consumed: 50, target: nil), carbohydrate: .init(consumed: 90, target: nil),
                                                   fat: .init(consumed: 30, target: nil))],
                                      active: .init(name: "Upper A", startedAt: start, completedSets: 2, totalSets: 15),
                                      done: nil, planned: nil)
        XCTAssertNil(WidgetSnapshot.read(from: url))
        XCTAssertTrue(try snapshot.write(to: url))
        XCTAssertFalse(try snapshot.write(to: url), "An unchanged snapshot doesn't redraw the widgets")
        XCTAssertEqual(WidgetSnapshot.read(from: url), snapshot)
        snapshot.active?.completedSets = 3
        XCTAssertTrue(try snapshot.write(to: url))
        XCTAssertEqual(WidgetSnapshot.read(from: url)?.active?.completedSets, 3)
        XCTAssertFalse(try snapshot.write(to: nil), "Without the App Group nothing is written")
        XCTAssertTrue(WidgetSnapshot.remove(at: url))
        XCTAssertNil(WidgetSnapshot.read(from: url))
        XCTAssertFalse(WidgetSnapshot.remove(at: url))
        XCTAssertNil(snapshot.day(at: start - 1))
        XCTAssertEqual(snapshot.day(at: start)?.energy.consumed, 900)
        XCTAssertNil(snapshot.day(at: start)?.energy.remaining, "No target, nothing left to count down")
    }
}
