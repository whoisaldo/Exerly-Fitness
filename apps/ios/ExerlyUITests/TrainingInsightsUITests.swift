import XCTest

/// Progress → Training: volume per muscle, strength per lift, records,
/// consistency and stall signals, from synthetic workouts.
@MainActor
final class TrainingInsightsUITests: ExerlyUITestCase {
    private var designCapture: Bool { ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" }

    /// A few seeded workouts show up as a lift with an estimate, the muscle
    /// list and records, and the lift opens its detail in the account's unit.
    func testTrainingInsightsSummarizeSeededWorkoutsAndOpenALift() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "insights", units: "imperial")
        for (index, days) in [20, 13, 6].enumerated() {
            let load = 185 + Double(index) * 10
            try await seedSession(name: "Synthetic upper", daysAgo: days, exercises: [
                ("barbell-bench-press", [(5, load, 2), (5, load, 2), (5, load, 1)]),
                ("barbell-row", [(8, 135, 2), (8, 135, 2)]),
            ], token: person.token)
        }
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        openTraining(in: app)

        let lift = app.buttons["training.lift.barbell-bench-press"]
        XCTAssertTrue(lift.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(lift.label.contains("Bench"), lift.label)
        XCTAssertTrue(lift.label.contains("pounds"), "Estimates are in the account's unit: \(lift.label)")
        XCTAssertTrue(app.descendants(matching: .any)["training.muscle.chest"].exists)
        tap(lift, in: app)
        let estimate = app.descendants(matching: .any)["liftDetail.estimate"]
        XCTAssertTrue(estimate.waitForExistence(timeout: 10), app.debugDescription)
        // 205 lb × 5 at 1 RIR is about 239 lb.
        XCTAssertTrue(estimate.label.contains("239"), estimate.label)
        XCTAssertTrue(app.descendants(matching: .any)["liftDetail.stats"].exists)
    }

    /// An account with no workouts says what will appear, not empty charts.
    func testTrainingInsightsExplainAnEmptyHistory() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "insights-empty", units: "metric")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        openTraining(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["training.empty"].waitForExistence(timeout: 30), app.debugDescription)
    }

    /// Ten weeks of a synthetic three-day split, for design captures.
    func testTrainingInsightsCapture() async throws {
        try XCTSkipUnless(designCapture, "Set EXERLY_DESIGN_CAPTURE=1 to capture")
        try await control([:])
        let person = try await createAccount(prefix: "insights-capture", units: "imperial")
        try await seedTrainingBlock(token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        openTraining(in: app)
        try await Task.sleep(for: .seconds(2))
        capture(app, "training-1-top")
        let muscles = app.descendants(matching: .any)["training.muscles"]
        guard muscles.waitForExistence(timeout: 30) else { return XCTFail(app.debugDescription) }
        reveal(muscles, in: app)
        capture(app, "training-2-muscles")
        let lifts = app.descendants(matching: .any)["training.lifts"]
        reveal(lifts, in: app)
        capture(app, "training-3-lifts")
        let records = app.descendants(matching: .any)["training.records"]
        reveal(records, in: app)
        capture(app, "training-4-records")
        let consistency = app.descendants(matching: .any)["training.consistency"]
        reveal(consistency, in: app)
        capture(app, "training-5-consistency")
        app.swipeUp()
        capture(app, "training-6-end")
        tap(app.buttons["training.lift.back-squat"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["liftDetail.estimate"].waitForExistence(timeout: 10))
        try await Task.sleep(for: .seconds(1))
        capture(app, "training-7-lift")
        app.swipeUp()
        capture(app, "training-8-lift-stats")
        app.swipeUp()
        capture(app, "training-9-lift-sets")
    }

    // MARK: Helpers

    private func openTraining(in app: XCUIApplication) {
        tap(app.buttons["Progress"], in: app)
        if app.buttons["progress.section"].waitForExistence(timeout: 3) {
            tap(app.buttons["progress.section"], in: app)
        }
        tap(app.buttons["Training"], in: app)
    }

    typealias SeedSet = (reps: Int, pounds: Double, rir: Double)

    /// One finished workout, `daysAgo` days back at about 6 pm New York time.
    private func seedSession(name: String, daysAgo: Int, bodyweight: Double = 181,
                             exercises: [(id: String, sets: [SeedSet])], token: String) async throws {
        let id = UUID().uuidString
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
        let start = day.addingTimeInterval(17.5 * 3600)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var minute = 4.0
        let performed = exercises.map { exercise -> [String: Any] in
            let sets = exercise.sets.map { set -> [String: Any] in
                minute += 2.5
                return ["id": UUID().uuidString, "kind": "standard", "rir": set.rir,
                        "completedAt": formatter.string(from: start.addingTimeInterval(minute * 60)),
                        "efforts": [set.pounds > 0 ? ["reps": set.reps, "load": ["unit": "lb", "value": set.pounds]] : ["reps": set.reps]]]
            }
            return ["id": UUID().uuidString, "exerciseID": exercise.id, "notes": "", "sets": sets]
        }
        let payload: [String: Any] = [
            "id": id, "name": name, "notes": "", "startedAt": formatter.string(from: start),
            "endedAt": formatter.string(from: start.addingTimeInterval((minute + 6) * 60)), "timeZoneID": "America/New_York",
            "bodyweight": ["unit": "lb", "value": bodyweight], "exercises": performed,
        ]
        _ = try await request("PUT", "/v1/documents/workout_session/\(id)", body: ["base_revision": 0, "payload": payload], token: token)
    }

    /// Ten weeks, three days a week: squat, bench, row and deadlift climb;
    /// the overhead press stays put, so it reads as a stall. Calves and
    /// rear delts get little direct work.
    private func seedTrainingBlock(token: String) async throws {
        for week in 0..<10 {
            let base = 70 - week * 7
            let w = Double(week)
            let squat = 205 + w * 5, bench = 165 + w * 2.5, row = 135 + w * 2.5, dead = 255 + w * 10
            try await seedSession(name: "Upper and squat", daysAgo: base, exercises: [
                ("back-squat", [(5, squat, 2), (5, squat, 2), (5, squat, 1)]),
                ("barbell-bench-press", [(5, bench, 2), (5, bench, 2), (5, bench, 1)]),
                ("barbell-row", [(8, row, 2), (8, row, 2), (8, row, 2)]),
                ("dumbbell-lateral-raise", [(12, 20, 2), (12, 20, 1)]),
                ("triceps-pushdown", [(12, 50 + w * 2.5, 2), (12, 50 + w * 2.5, 1)]),
            ], token: token)
            try await seedSession(name: "Pull and press", daysAgo: base - 2, exercises: [
                ("deadlift", [(5, dead, 2), (5, dead - 30, 3)]),
                ("overhead-press", [(5, 115, 1), (5, 115, 1), (4, 115, 0)]),
                ("pull-up", [(8, 0, 2), (8, 0, 2), (7, 0, 1)]),
                ("dumbbell-curl", [(10, 30, 2), (10, 30, 1)]),
            ], token: token)
            guard base - 4 > 0 else { continue }
            try await seedSession(name: "Squat and bench", daysAgo: base - 4, exercises: [
                ("back-squat", [(8, squat - 40, 3), (8, squat - 40, 2)]),
                ("barbell-bench-press", [(8, bench - 25, 2), (8, bench - 25, 2), (8, bench - 25, 1)]),
                ("lat-pulldown", [(10, 140 + w * 5, 2), (10, 140 + w * 5, 2)]),
                ("lying-leg-curl", [(10, 90 + w * 2.5, 2), (10, 90 + w * 2.5, 1)]),
                ("standing-calf-raise", [(12, 180, 2), (12, 180, 2)]),
            ], token: token)
        }
    }
}
