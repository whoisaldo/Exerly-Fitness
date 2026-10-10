import XCTest

/// Starting today's workout and logging sets, measured in taps from the home screen.
@MainActor
final class TrainingFlowUITests: ExerlyUITestCase {

    /// Train, then Start: today's planned workout in two taps, with no
    /// questions. A set prefilled from the plan and the last session takes
    /// one tap, and routine edits stay on the workout screen.
    func testTodaysWorkoutStartsInTwoTapsAndAPrefilledSetLogsInOne() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "train-taps", units: "imperial")
        try await seedStrengthPlan(token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        settleAfterSignIn(app)

        tapCount = 0
        tap(app.buttons["Train"], in: app)
        let start = app.buttons["training.startToday"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["training.todayName"].label, "Upper A")
        tap(start, in: app)
        XCTAssertTrue(app.buttons["training.finish"].waitForExistence(timeout: 10))
        XCTAssertLessThanOrEqual(tapCount, 2, "Starting today's workout from the home screen")
        XCTAssertTrue(app.navigationBars["Strength foundations: Upper A"].exists)
        // Last session's 155 lb × 8, 7, 6 at 2 RIR progresses to 160 lb.
        let load = app.textFields["set.barbell-bench-press.1.load"]
        XCTAssertEqual(load.value as? String, "160")
        XCTAssertEqual(app.textFields["set.barbell-bench-press.1.rir"].value as? String, "2")
        XCTAssertTrue(app.buttons["Previous: 155 lb × 8 reps"].exists)

        tapCount = 0
        tap(app.buttons["Complete set 1, Barbell Bench Press"], in: app)
        XCTAssertTrue(app.buttons["Reopen set 1, Barbell Bench Press"].waitForExistence(timeout: 5))
        XCTAssertEqual(tapCount, 1, "Completing a prefilled set")
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["training.setProgress"].label, "1 of 15 sets done")

        // A weight change in place: the keypad steps by the plates and Next
        // moves to reps. Later sets that held the old weight follow.
        tap(app.textFields["set.barbell-bench-press.2.load"], in: app)
        XCTAssertTrue(app.buttons["exerly.keypadDone"].waitForExistence(timeout: 5))
        tap(app.buttons["training.keypadPlus"], in: app)
        tap(app.buttons["training.keypadNext"], in: app)
        tap(app.buttons["exerly.keypad.8"], in: app)
        tap(app.buttons["exerly.keypadDone"], in: app)
        XCTAssertFalse(app.buttons["training.saveSet"].exists, "Routine edits never open a sheet")
        XCTAssertEqual(app.textFields["set.barbell-bench-press.2.load"].value as? String, "165")
        XCTAssertEqual(app.textFields["set.barbell-bench-press.2.reps"].value as? String, "8")
        XCTAssertEqual(app.textFields["set.barbell-bench-press.3.load"].value as? String, "165")
        XCTAssertEqual(app.textFields["set.barbell-bench-press.1.load"].value as? String, "160", "A completed set keeps its values")

        tap(app.buttons["Add 15 seconds of rest"], in: app)
        tap(app.buttons["Skip rest"], in: app)
        XCTAssertFalse(app.buttons["Skip rest"].exists)
        tap(app.buttons["Complete set 2, Barbell Bench Press"], in: app)
        XCTAssertTrue(app.buttons["Reopen set 2, Barbell Bench Press"].waitForExistence(timeout: 5))

        // Two of fifteen sets: the prompt says the day stays next, and can be cancelled.
        tap(app.buttons["training.finish"], in: app)
        let staysNext = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Upper A stays your next workout")).firstMatch
        XCTAssertTrue(staysNext.waitForExistence(timeout: 5), app.debugDescription)
        tap(app.buttons["Cancel"].firstMatch, in: app)
        XCTAssertTrue(app.buttons["Save workout"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["training.finish"].isHittable, "Still in the workout")
        tap(app.buttons["training.finish"], in: app)
        tap(app.buttons["Save workout"], in: app)
        XCTAssertTrue(app.buttons["training.summaryDone"].waitForExistence(timeout: 10))
        tap(app.buttons["training.summaryDone"], in: app)
        // Train says the workout is done; cut short, its day is still the one to do.
        XCTAssertTrue(app.staticTexts["training.doneName"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["training.startToday"].exists)
        XCTAssertEqual(app.buttons["training.startNext"].label, "Start next: Upper A", "Under half the sets leaves the day next")
    }

    /// Only done sets read as selected. The workout's last set starts no
    /// rest, and with every set done Finish saves without asking.
    func testTheLastSetStartsNoRestAndFinishSavesWithoutAsking() async throws {
        let app = try await signedInWithWeek(prefix: "train-last-set")
        tap(app.buttons["today.startWorkout"], in: app)
        XCTAssertTrue(app.buttons["training.finish"].waitForExistence(timeout: 10))
        let second = app.buttons["Complete set 2, Deadlift"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertFalse(second.isSelected, "A set not yet done isn't selected")
        XCTAssertFalse(second.images["Selected"].exists, "Nor does its checkmark read as Selected")

        tap(app.buttons["Complete set 1, Deadlift"], in: app)
        XCTAssertTrue(app.buttons["Reopen set 1, Deadlift"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Reopen set 1, Deadlift"].isSelected, "A done set is selected")
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 5), "Sets still to do get a rest")
        tap(app.buttons["Complete set 2, Deadlift"], in: app)
        tap(app.buttons["Complete set 3, Deadlift"], in: app)
        XCTAssertTrue(app.buttons["Reopen set 3, Deadlift"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Skip rest"].exists, "The workout's last set leaves nothing to rest for")

        tap(app.buttons["training.finish"], in: app)
        XCTAssertTrue(app.buttons["training.summaryDone"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Save workout"].exists)
    }

    func testDesignTrainingCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in visual review of the training flow")
        }
        try await control([:])
        let person = try await createAccount(prefix: "train-design", units: "imperial")
        try await seedStrengthPlan(token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        settleAfterSignIn(app)
        tap(app.buttons["Train"], in: app)
        XCTAssertTrue(app.buttons["training.startToday"].waitForExistence(timeout: 20))
        capture(app, "after-01-train-home")
        reveal(app.buttons["suggestions.open"], in: app)
        capture(app, "after-02-train-home-scrolled")
        revealAbove(app.buttons["program.nextWorkout"], in: app)
        tap(app.buttons["program.nextWorkout"], in: app)
        XCTAssertTrue(app.navigationBars["Next workout"].waitForExistence(timeout: 10))
        capture(app, "after-03-preview")
        tap(app.buttons["Close"], in: app)
        tap(app.buttons["training.startToday"], in: app)
        XCTAssertTrue(app.buttons["training.finish"].waitForExistence(timeout: 10))
        capture(app, "after-04-active-workout")
        tap(app.buttons["Complete set 1, Barbell Bench Press"], in: app)
        XCTAssertTrue(app.buttons["Skip rest"].waitForExistence(timeout: 5))
        capture(app, "after-05-set-completed-rest")
        tap(app.textFields["set.barbell-bench-press.2.load"], in: app)
        XCTAssertTrue(app.buttons["exerly.keypadDone"].waitForExistence(timeout: 5))
        capture(app, "after-06-inline-keypad")
        tap(app.buttons["exerly.keypadDone"], in: app)
        tap(app.buttons["Complete set 2, Barbell Bench Press"], in: app)
        tap(app.buttons["Complete set 3, Barbell Bench Press"], in: app)
        reveal(app.buttons["Complete set 1, Pull-Up"], in: app)
        capture(app, "after-07-workout-progress")
        tap(app.buttons["training.exerciseMenu.pull-up"], in: app)
        capture(app, "after-08-exercise-menu")
        // Close the menu the way a person would, by tapping outside it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        tap(app.buttons["training.menu"], in: app)
        capture(app, "after-09-workout-menu")
        tap(app.buttons["Workout details"], in: app)
        tap(app.buttons["Cancel"], in: app)
        tap(app.buttons["training.finish"], in: app)
        tap(app.buttons["Save workout"], in: app)
        XCTAssertTrue(app.buttons["training.summaryDone"].waitForExistence(timeout: 10))
        capture(app, "after-10-finish-summary")
        tap(app.buttons["training.summaryDone"], in: app)
        XCTAssertTrue(app.buttons["training.startNext"].waitForExistence(timeout: 10))
        capture(app, "after-11-train-home-next")
    }

    /// The workout as the tab bar's accessory shows it from another tab,
    /// resting and between sets. The tab view mounts the accessory.
    func testDesignWorkoutAccessoryCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in visual review of the workout accessory")
        }
        try await control([:])
        let person = try await createAccount(prefix: "train-accessory", units: "imperial")
        try await seedStrengthPlan(token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        settleAfterSignIn(app)
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["training.startToday"], in: app)
        tap(app.buttons["Complete set 1, Barbell Bench Press"], in: app)
        capture(app, "accessory-01-train-resting")
        tap(app.tabBars.buttons.element(boundBy: 0), in: app)
        capture(app, "accessory-02-home-resting")
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["Skip rest"], in: app)
        tap(app.tabBars.buttons.element(boundBy: 0), in: app)
        capture(app, "accessory-03-home-elapsed")
        app.swipeUp()
        capture(app, "accessory-04-home-scrolled")
    }

    func testDesignTrainingEmptyCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in visual review of the training flow without a plan")
        }
        try await control([:])
        let person = try await createAccount(prefix: "train-empty", units: "metric")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        settleAfterSignIn(app)
        tap(app.buttons["Train"], in: app)
        XCTAssertTrue(app.buttons["planSetup.open"].waitForExistence(timeout: 20))
        capture(app, "after-20-train-no-plan")
        tap(app.buttons["training.start"], in: app)
        XCTAssertTrue(app.buttons["training.finish"].waitForExistence(timeout: 10))
        tap(app.buttons["training.addExercise"], in: app)
        tap(app.searchFields.firstMatch, in: app)
        app.searchFields.firstMatch.typeText("plank\n")
        tap(app.buttons["Add Plank"], in: app)
        tap(app.buttons["training.addExercise"], in: app)
        tap(app.searchFields.firstMatch, in: app)
        app.searchFields.firstMatch.typeText("one-arm dumbbell row\n")
        tap(app.buttons["Add One-Arm Dumbbell Row"], in: app)
        capture(app, "after-21-empty-workout-exercises")
        tap(app.buttons["Complete set 1, Plank"], in: app)
        XCTAssertTrue(app.buttons["exerly.keypadDone"].waitForExistence(timeout: 5), "A set without values opens its first missing value")
        capture(app, "after-22-missing-value")
    }

    // MARK: Synthetic data

    /// An activated two-day program and an earlier upper-body session, in pounds,
    /// with a recent weigh-in.
    func seedStrengthPlan(token: String, history: Bool = true) async throws {
        let upper: [(String, Int, Int, Int, Double)] = [
            ("barbell-bench-press", 3, 5, 8, 2), ("barbell-row", 3, 6, 10, 2), ("overhead-press", 3, 6, 10, 2),
            ("pull-up", 3, 6, 10, 1), ("dumbbell-lateral-raise", 3, 10, 15, 1)
        ]
        let lower: [(String, Int, Int, Int, Double)] = [
            ("back-squat", 3, 5, 8, 2), ("romanian-deadlift", 3, 6, 10, 2), ("leg-press", 3, 10, 12, 2)
        ]
        func day(_ name: String, _ slots: [(String, Int, Int, Int, Double)]) -> [String: Any] {
            ["id": UUID().uuidString, "name": name, "slots": slots.map { slot -> [String: Any] in
                ["id": UUID().uuidString, "exerciseID": slot.0, "notes": "",
                 "target": ["sets": slot.1, "minReps": slot.2, "maxReps": slot.3, "rir": slot.4, "kind": "standard"],
                 "cycleTargets": [String: Any](), "expandRepRange": false, "weightMatch": true]
            }]
        }
        let programID = UUID().uuidString
        let program: [String: Any] = ["id": programID, "name": "Strength foundations", "cycles": 4, "deload": "none",
                                      "createdAt": "2026-10-01T12:00:00.000Z", "activatedAt": "2026-10-01T12:00:00.000Z",
                                      "days": [day("Upper A", upper), day("Lower A", lower)]]
        _ = try await request("PUT", "/v1/documents/program/\(programID)", body: ["base_revision": 0, "payload": program], token: token)
        try await seedWeighIn(pounds: 181.4, token: token)
        guard history else { return }
        let sets: [(String, Double?, [Int])] = [
            ("barbell-bench-press", 155, [8, 7, 6]), ("barbell-row", 135, [10, 9, 8]), ("overhead-press", 95, [8, 7, 7]),
            ("pull-up", nil, [9, 8, 7]), ("dumbbell-lateral-raise", 20, [14, 12, 12])
        ]
        try await seedSession(name: "Upper A", daysAgo: 3, exercises: sets, token: token)
    }

    func seedSession(name: String, daysAgo: Int, exercises: [(String, Double?, [Int])], token: String) async throws {
        let id = UUID().uuidString
        let start = Date().addingTimeInterval(Double(-daysAgo * 86400) - 5400)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var minute = 0.0
        let payload: [String: Any] = [
            "id": id, "name": name, "notes": "", "startedAt": formatter.string(from: start),
            "endedAt": formatter.string(from: start.addingTimeInterval(3900)), "timeZoneID": "America/New_York",
            "bodyweight": ["unit": "lb", "value": 182],
            "exercises": exercises.map { exercise -> [String: Any] in
                ["id": UUID().uuidString, "exerciseID": exercise.0, "notes": "", "sets": exercise.2.map { reps -> [String: Any] in
                    minute += 3
                    var effort: [String: Any] = ["reps": reps]
                    if let load = exercise.1 { effort["load"] = ["unit": "lb", "value": load] }
                    return ["id": UUID().uuidString, "kind": "standard", "rir": 2,
                            "completedAt": formatter.string(from: start.addingTimeInterval(minute * 60)), "efforts": [effort]]
                }]
            }
        ]
        _ = try await request("PUT", "/v1/documents/workout_session/\(id)", body: ["base_revision": 0, "payload": payload], token: token)
    }

    func seedWeighIn(pounds: Double, token: String) async throws {
        let id = UUID().uuidString
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        let at = Date().addingTimeInterval(-86400)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let payload: [String: Any] = ["id": id, "at": iso.string(from: at), "date": formatter.string(from: at),
                                      "weight": ["unit": "lb", "value": pounds]]
        _ = try await request("PUT", "/v1/documents/weight_entry/\(id)", body: ["base_revision": 0, "payload": payload], token: token)
    }
}

extension ExerlyUITestCase {
    /// A fresh iOS 26 simulator offers to save the password a few seconds
    /// after sign-in, sometimes as a sheet that is never drawn but still
    /// blocks hit testing. Wait for it and dismiss it before counting taps.

    /// Starts an empty workout from the Train tab and names it in its details.
    func startNamedWorkout(_ name: String, in app: XCUIApplication) {
        tap(app.buttons["training.start"], in: app)
        XCTAssertTrue(app.buttons["training.menu"].waitForExistence(timeout: 10))
        tap(app.buttons["training.menu"], in: app)
        tap(app.buttons["Workout details"], in: app)
        replace(app.textFields["training.name"], with: name, in: app)
        tap(app.buttons["training.saveDetails"], in: app)
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 10))
    }
}
