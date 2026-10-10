import XCTest

/// Where Exerly's controls and open-the-app intents lead. Each hands the app
/// the same link these tests open, so each link must land on its screen.
final class AppIntentsUITests: ExerlyUITestCase {
    func testEachOpenTheAppActionLandsOnItsScreen() async throws {
        let app = try await signedInWithWeek(prefix: "intent-links")
        XCTAssertTrue(app.scrollViews["today.screen"].waitForExistence(timeout: 10))

        open("exerly://search")
        XCTAssertTrue(app.navigationBars["Add food"].waitForExistence(timeout: 10), "Log food opens the search tab")
        XCTAssertTrue(app.searchFields.firstMatch.exists)
        XCTAssertFalse(app.buttons["nutrition.closePicker"].exists, "The tab, not Today's search sheet")

        open("exerly://scan")
        XCTAssertTrue(app.navigationBars["Scan barcode"].waitForExistence(timeout: 10), "Scan barcode opens the scanner")
        XCTAssertTrue(app.textFields["nutrition.barcodeDigits"].waitForExistence(timeout: 5), "Without a camera the digits are ready to type")
        app.navigationBars["Scan barcode"].buttons.firstMatch.tap()
        tap(app.buttons["nutrition.closePicker"], in: app)
        XCTAssertTrue(app.buttons["nutrition.closePicker"].waitForNonExistence(timeout: 5))

        open("exerly://weigh-in")
        XCTAssertTrue(app.buttons["weighIn.save"].waitForExistence(timeout: 10), "Weigh in opens the weigh-in sheet")
        XCTAssertTrue(app.staticTexts["Weigh-in"].exists)
        tap(app.buttons["weighIn.cancel"], in: app)
        XCTAssertTrue(app.buttons["weighIn.save"].waitForNonExistence(timeout: 5))

        let activity = app.descendants(matching: .any)["debug.liveActivity"]
        XCTAssertEqual(activity.value as? String, "none")
        open("exerly://start-workout")
        XCTAssertTrue(app.buttons["training.finish"].waitForExistence(timeout: 10), "Start workout starts today's workout")
        XCTAssertTrue(wait(activity, for: "active Pull 0/3"), "The program's next workout: \(activity.value ?? "")")

        // Again with it in progress, from another tab: back to the same workout.
        tap(app.buttons["Today"], in: app)
        XCTAssertTrue(app.buttons["today.resumeWorkout"].waitForExistence(timeout: 10))
        open("exerly://start-workout")
        XCTAssertTrue(app.buttons["training.finish"].waitForExistence(timeout: 10))
        XCTAssertEqual(activity.value as? String, "active Pull 0/3", "No second workout was started")
    }

    private func open(_ link: String) {
        XCUIDevice.shared.system.open(URL(string: link)!)
    }

    private func wait(_ element: XCUIElement, for value: String, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

