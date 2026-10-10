import ExerlyCore
import XCTest
@testable import Exerly

/// The watch's link to the phone: the payloads both ends exchange, the state
/// the phone publishes, its commands run through the store, and the watch's
/// prediction of them. Synthetic data only.
@MainActor
final class WatchLinkTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite: String!
    private var workspace: TrainingWorkspace!
    private let newYork = TimeZone(identifier: "America/New_York")!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        suite = "exerly.watch.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        workspace = try TrainingWorkspace(accountID: "watch-account", root: root)
    }

    override func tearDown() async throws {
        await workspace.close()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }

    /// Bench press with three sets of 160 lb × 7, then a pull-up without reps.
    private func startBench() throws -> (session: UUID, bench: [UUID], pullUp: UUID) {
        let store = workspace.store
        let session = try store.startSession(name: "Upper A", bodyweight: .kg(80), timeZone: newYork)
        let bench = try store.addExercise("barbell-bench-press")
        try store.addSet(to: bench)
        try store.addSet(to: bench)
        for var set in try XCTUnwrap(store.activeSession?.exercises.first?.sets) {
            set.primary = Effort(reps: 7, load: .lb(160))
            try store.updateSet(set, in: bench)
        }
        try store.addExercise("pull-up")
        let sets = try XCTUnwrap(store.activeSession?.exercises.first?.sets.map(\.id))
        return (session.id, sets, try XCTUnwrap(store.activeSession?.exercises.last?.sets.first?.id))
    }

    private func state(_ unit: MassUnit = .pounds) -> WatchState {
        WatchState(workspace: workspace, unit: unit, savesToHealth: true, handled: nil)
    }

    @discardableResult
    private func run(_ action: WatchCommand.Action, _ workoutID: UUID?) -> Bool {
        WatchCoordinator.apply(WatchCommand(workoutID: workoutID, action: action), to: workspace, unit: .pounds,
                               timeZone: newYork, defaults: defaults)
    }

    // MARK: Payloads

    func testPayloadsRoundTripUnderTheirVersionAndAreIgnoredOtherwise() throws {
        _ = try startBench()
        var sent = state()
        sent.revision = 1_791_000_000_123
        sent.handled = UUID()
        let payload = WatchLink.payload(sent)
        XCTAssertTrue(PropertyListSerialization.propertyList(payload, isValidFor: .binary), "WatchConnectivity carries plist types only")
        XCTAssertEqual(WatchLink.state(from: payload), sent)

        let workout = UUID()
        for action: WatchCommand.Action in [.start, .completeSet(UUID(), weight: 62.5, reps: 8, unit: "kg"),
                                            .completeSet(UUID(), weight: nil, reps: nil, unit: "lb"),
                                            .extendRest(seconds: 30), .skipRest, .finish, .recording] {
            let command = WatchCommand(workoutID: workout, action: action)
            XCTAssertEqual(WatchLink.command(from: WatchLink.payload(command)), command)
        }

        var newer = payload
        newer["v"] = WatchLink.version + 1
        XCTAssertNil(WatchLink.state(from: newer), "A payload from another version is ignored, not misread")
        XCTAssertNil(WatchLink.state(from: ["v": WatchLink.version, "state": Data("{}".utf8)]))
        XCTAssertNil(WatchLink.command(from: payload), "A state isn't a command")
        XCTAssertNil(WatchLink.state(from: [:]))
    }

    // MARK: What the phone publishes

    func testTheWatchGetsEverySetLeftInThePersonsUnitWithItsRestAndWeights() throws {
        let workout = try startBench()
        let active = try XCTUnwrap(state().active)
        XCTAssertEqual(active.id, workout.session)
        XCTAssertEqual(active.title, "Upper A")
        XCTAssertEqual(active.unit, "lb")
        XCTAssertEqual(active.completedSets, 0)
        XCTAssertEqual(active.totalSets, 4)
        XCTAssertNil(active.rest)
        XCTAssertEqual(active.upcoming.map(\.id), workout.bench + [workout.pullUp])

        let first = active.upcoming[0]
        XCTAssertEqual(first.exercise, "Barbell Bench Press")
        XCTAssertEqual([first.number, first.count], [1, 3])
        XCTAssertEqual(first.weight, 160)
        XCTAssertEqual(first.reps, 7)
        XCTAssertEqual(first.values, "160 lb × 7")
        XCTAssertTrue(first.isLoggable)
        XCTAssertEqual(first.rest, RestPolicy().compoundUpper)
        XCTAssertEqual(active.upcoming[2].rest, RestPolicy().betweenExercises, "The last set rests before the next exercise")

        let loads = try XCTUnwrap(active.loads[first.exerciseID.uuidString])
        XCTAssertEqual(loads, loads.sorted())
        XCTAssertEqual(loads.first, 45, "Barbell loads start at the empty bar")
        XCTAssertTrue(loads.contains(160) && loads.contains(165) && loads.contains(155), "Steps by the plates around the plan")
        XCTAssertGreaterThanOrEqual(loads.last ?? 0, 240)

        let pullUp = active.upcoming[3]
        XCTAssertNil(pullUp.weight)
        XCTAssertEqual(pullUp.reps, 0, "Reps the person still has to fill in")
        XCTAssertFalse(pullUp.isLoggable)
        XCTAssertNil(active.loads[pullUp.exerciseID.uuidString], "Bodyweight sets have no weights to step through")

        XCTAssertEqual(state(.kilograms).active?.upcoming.first?.weight, 72.6, "The same set in kilograms, to 0.1")
    }

    func testWithNoWorkoutInProgressTheWatchGetsTheProgramsNext() throws {
        XCTAssertNil(state().planned, "No program, nothing planned")
        let program = Program(name: "Strength foundations", days: [ProgramDay(name: "Upper A", slots: [
            ProgramSlot(exerciseID: "barbell-bench-press", target: SlotTarget(sets: 3, minReps: 5, maxReps: 8, rir: 2)),
            ProgramSlot(exerciseID: "barbell-row", target: SlotTarget(sets: 2, minReps: 8, maxReps: 10, rir: 2)),
        ])], cycles: 1)
        try workspace.programs.save(program)
        try workspace.programs.activate(program.id)
        let planned = try XCTUnwrap(state().planned)
        XCTAssertEqual(planned, .init(title: "Upper A", program: "Strength foundations", exercises: 2, sets: 5))
        XCTAssertNil(state().active)
        XCTAssertTrue(state().signedIn)
    }

    // MARK: Commands

    func testCommandsChangeTheWorkoutWithTheStoreCallsTheScreensUse() throws {
        let program = Program(name: "Strength foundations", days: [ProgramDay(name: "Pull", slots: [
            ProgramSlot(exerciseID: "deadlift", target: SlotTarget(sets: 3, minReps: 5, maxReps: 8, rir: 2)),
        ])], cycles: 1)
        try workspace.programs.save(program)
        try workspace.programs.activate(program.id)
        let store = workspace.store

        XCTAssertFalse(run(.skipRest, UUID()), "Nothing to change without a workout")
        XCTAssertTrue(run(.start, nil))
        let session = try XCTUnwrap(store.activeSession)
        XCTAssertEqual(session.name, "Strength foundations: Pull")
        XCTAssertFalse(run(.start, nil), "Start doesn't replace the workout in progress")
        let sets = try XCTUnwrap(session.exercises.first?.sets.map(\.id))

        XCTAssertFalse(run(.completeSet(sets[0], weight: 225, reps: 5, unit: "lb"), UUID()), "A command for another workout does nothing")
        XCTAssertTrue(run(.completeSet(sets[0], weight: 225, reps: 5, unit: "lb"), session.id))
        var done = try XCTUnwrap(store.activeSession?.set(sets[0])?.set)
        XCTAssertTrue(done.isCompleted)
        XCTAssertEqual(done.primary.load, .lb(225))
        XCTAssertEqual(done.primary.reps, 5)
        XCTAssertEqual(store.activeSession?.set(sets[1])?.set.primary.load, .lb(225), "Later sets follow the weight chosen on the watch")
        XCTAssertFalse(run(.completeSet(sets[0], weight: nil, reps: nil, unit: "lb"), session.id), "A set already done isn't logged twice")

        let rest = try XCTUnwrap(store.restTimer)
        XCTAssertTrue(run(.extendRest(seconds: 30), session.id))
        XCTAssertEqual(store.restTimer?.endsAt, rest.endsAt.addingTimeInterval(30))
        XCTAssertTrue(run(.skipRest, session.id))
        XCTAssertNil(store.restTimer)
        XCTAssertFalse(run(.extendRest(seconds: 30), session.id), "+30 s after rest is over doesn't start a new rest")

        // Unchanged values log as prefilled.
        XCTAssertTrue(run(.completeSet(sets[1], weight: nil, reps: nil, unit: "lb"), session.id))
        done = try XCTUnwrap(store.activeSession?.set(sets[1])?.set)
        XCTAssertEqual(done.primary.load, .lb(225))
        XCTAssertTrue(done.isCompleted)

        XCTAssertFalse(WatchHealthWorkouts.contains(session.id, defaults: defaults))
        XCTAssertTrue(run(.recording, session.id))
        XCTAssertTrue(WatchHealthWorkouts.contains(session.id, defaults: defaults))

        XCTAssertTrue(run(.finish, session.id))
        XCTAssertNil(store.activeSession)
        let saved = try XCTUnwrap(store.history.sessions.first { $0.id == session.id })
        XCTAssertEqual(saved.exercises.first?.sets.count, 2, "The set never done is removed, as on the phone")
        XCTAssertEqual(state().finished, session.id)
    }

    func testFinishingWithNothingDoneDiscardsTheWorkout() throws {
        let workout = try startBench()
        XCTAssertTrue(run(.finish, workout.session))
        // A recording notice that arrives after the workout ended still counts.
        XCTAssertTrue(run(.recording, workout.session))
        XCTAssertTrue(WatchHealthWorkouts.contains(workout.session, defaults: defaults))
        XCTAssertNil(workspace.store.activeSession)
        XCTAssertTrue(workspace.store.history.sessions.isEmpty)
        XCTAssertNil(state().finished)
    }

    // MARK: The watch's prediction

    /// What the watch shows before the phone answers matches what the phone does.
    func testThePredictionMatchesWhatThePhoneDoes() throws {
        let workout = try startBench()
        func check(_ action: WatchCommand.Action, _ message: String, line: UInt = #line) throws {
            let before = state()
            let now = Date()
            let predicted = before.applying(WatchCommand(workoutID: workout.session, action: action), at: now)
            XCTAssertTrue(run(action, workout.session), message, line: line)
            let actual = state()
            XCTAssertEqual(predicted.active?.upcoming.map(\.id), actual.active?.upcoming.map(\.id), message, line: line)
            XCTAssertEqual(predicted.active?.upcoming.map(\.weight), actual.active?.upcoming.map(\.weight), message, line: line)
            XCTAssertEqual(predicted.active?.upcoming.map(\.reps), actual.active?.upcoming.map(\.reps), message, line: line)
            XCTAssertEqual(predicted.active?.completedSets, actual.active?.completedSets, message, line: line)
            XCTAssertEqual(predicted.finished, actual.finished, message, line: line)
            let restLeft = { (state: WatchState) in state.active?.rest.map { $0.endsAt.timeIntervalSince(now) } }
            XCTAssertEqual(restLeft(predicted) ?? -1, restLeft(actual) ?? -1, accuracy: 2, message, line: line)
        }
        try check(.completeSet(workout.bench[0], weight: 165, reps: 6, unit: "lb"), "A set with a new weight and reps")
        try check(.extendRest(seconds: 30), "Thirty more seconds")
        try check(.skipRest, "Rest skipped")
        try check(.completeSet(workout.bench[1], weight: nil, reps: nil, unit: "lb"), "A set as prefilled")
        try check(.finish, "Finished")

        // A command for another workout predicts nothing.
        let other = WatchCommand(workoutID: UUID(), action: .skipRest)
        XCTAssertEqual(state().applying(other, at: .now), state())
    }
}
