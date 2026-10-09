import XCTest

/// The Today screen: what it shows for a realistic week, and the taps its
/// shortcuts take.
final class TodayUITests: ExerlyUITestCase {
    func testTodayCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in visual review of the Today screen")
        }
        let app = try await signedInWithWeek(prefix: "today-capture")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.suggestion.log.")).firstMatch.waitForExistence(timeout: 20))
        capture(app, "today-01-top")
        app.swipeUp()
        capture(app, "today-02-meals")
        app.swipeUp()
        capture(app, "today-03-footer")
        app.swipeDown(); app.swipeDown()
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.suggestion.log.")).firstMatch, in: app)
        capture(app, "today-04-logged")
        tap(app.buttons["Train"], in: app)
        capture(app, "today-05-train-tab")
        tap(app.buttons["Log food"], in: app)
        capture(app, "today-06-search-tab")
    }

    func testLoggingAUsualFoodFromTodayTakesOneTap() async throws {
        let app = try await signedInWithWeek(prefix: "today-suggestion")
        let suggestion = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.suggestion.log.")).firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 20))
        tapCount = 0
        tap(suggestion, in: app)
        XCTAssertEqual(tapCount, 1)
        XCTAssertTrue(app.buttons["today.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Logged ")).firstMatch.exists)
        // Undo, tapped where it appears, removes the entry again.
        let undo = app.buttons["today.undo"]
        XCTAssertTrue(undo.isHittable)
        undo.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "nutrition.entry.")).firstMatch.exists)
    }

    func testRepeatingYesterdaysMealTakesOneTap() async throws {
        let app = try await signedInWithWeek(prefix: "today-repeat")
        let repeatDinner = app.buttons["today.repeat.dinner"]
        reveal(repeatDinner, in: app)
        XCTAssertTrue(repeatDinner.waitForExistence(timeout: 20))
        tapCount = 0
        tap(repeatDinner, in: app)
        XCTAssertEqual(tapCount, 1)
        let salmon = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Salmon fillet")).firstMatch
        XCTAssertTrue(salmon.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["today.repeat.dinner"].exists)
    }

    func testTheWeekStripMovesBetweenDaysAndShowsTheTarget() async throws {
        let app = try await signedInWithWeek(prefix: "today-days")
        XCTAssertTrue(todayScreen(app).waitForExistence(timeout: 10))
        let today = try XCTUnwrap(shownDay(app))
        XCTAssertNotNil(targetEnergy(app))
        shiftDay(-1, in: app)
        XCTAssertTrue(app.navigationBars["Yesterday"].waitForExistence(timeout: 5))
        shiftDay(-8, in: app)
        XCTAssertTrue(todayScreen(app).exists)
        showToday(in: app)
        XCTAssertEqual(shownDay(app), today)
        XCTAssertTrue(app.navigationBars["Today"].exists)
    }

    func testTheWeekStripReachesFutureDaysForPlanning() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "today-future", units: "imperial")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        let today = try XCTUnwrap(shownDay(app))
        shiftDay(1, in: app)
        XCTAssertNotEqual(shownDay(app), today)
        XCTAssertTrue(app.navigationBars.matching(NSPredicate(format: "identifier != %@", "Today")).firstMatch.exists)
        showToday(in: app)
        XCTAssertEqual(shownDay(app), today)
    }

    func testStartingTodaysWorkoutTakesOneTapFromToday() async throws {
        let app = try await signedInWithWeek(prefix: "today-start")
        let start = app.buttons["today.startWorkout"]
        reveal(start, in: app)
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        tapCount = 0
        tap(start, in: app)
        XCTAssertEqual(tapCount, 1)
        XCTAssertTrue(app.buttons["training.finish"].waitForExistence(timeout: 10))
    }
}
