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

/// Opt-in: Exerly in the Shortcuts app and Control Center, driven like a
/// person would, with a screenshot of each step.
final class AppIntentsCaptureUITests: ExerlyUITestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")

    func testShortcutsAndControlsCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in visual review of Exerly in Shortcuts and Control Center")
        }
        let app = try await signedInWithWeek(prefix: "intent-capture")
        let chip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.suggestion.log.")).firstMatch
        if chip.waitForExistence(timeout: 20) { tap(chip, in: app) }
        pause(2)
        XCUIDevice.shared.press(.home)
        pause(1.5)

        // Exerly's actions in Shortcuts, then two run from there in the app's process.
        // An answer left from an earlier run stays up until closed.
        while springboard.buttons["Done"].firstMatch.exists {
            springboard.buttons["Done"].firstMatch.tap()
            pause(1)
        }
        shortcuts.activate()
        pause(4)
        // Shortcuts reopens where it was left; start from its library.
        for _ in 0..<3 where !shortcuts.buttons["Exerly"].exists && shortcuts.buttons["BackButton"].exists {
            shortcuts.buttons["BackButton"].firstMatch.tap()
            pause(2)
        }
        save("intents-01-shortcuts-library")
        shortcuts.buttons["Exerly"].firstMatch.tap()
        pause(3)
        save("intents-02-shortcuts-exerly")
        shortcuts.buttons["flame.fill"].firstMatch.tap()
        XCTAssertTrue(dialog("You've eaten ", name: "intents-03-calories-left"), "Calories left answers")
        let repeatDinner = shortcuts.otherElements.matching(NSPredicate(format: "label == %@", "Dinner"))
            .containing(.button, identifier: "arrow.counterclockwise").firstMatch
        for _ in 0..<5 where !(repeatDinner.exists && repeatDinner.isHittable) {
            shortcuts.swipeUp(velocity: .slow)
            pause(1)
        }
        XCTAssertTrue(repeatDinner.waitForExistence(timeout: 5))
        repeatDinner.tap()
        XCTAssertTrue(dialog("Repeated ", name: "intents-04-repeat-dinner"), "Repeat a meal logs the last dinner")
        app.activate()
        let salmon = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Salmon fillet")).firstMatch
        reveal(salmon, in: app)
        XCTAssertTrue(salmon.waitForExistence(timeout: 10), "The repeated dinner is on Today")
        save("intents-05-today-after-repeat")

        // Exerly's controls in Control Center's gallery; Weigh in added once, then tapped.
        XCUIDevice.shared.press(.home)
        pause(1.5)
        openControlCenter()
        let control = springboard.buttons.matching(NSPredicate(format: "label == %@", "Weigh in")).firstMatch
        let added = control.exists
        springboard.buttons["Add Controls"].firstMatch.tap()
        let add = springboard.buttons["Add a Control"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), springboard.debugDescription)
        add.tap()
        let search = springboard.searchFields["Search Controls"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        pause(2)
        search.tap()
        pause(1)
        search.typeText("Exerly")
        pause(2)
        save("intents-06-control-gallery")
        if added {
            // Already there from an earlier run: end the search and put the gallery away.
            springboard.buttons["Close"].firstMatch.tap()
            pause(1)
            springboard.buttons["Sheet Grabber"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        } else {
            springboard.buttons["com.exerly.fitness.control.weighIn"].firstMatch.tap()
            pause(2.5)
            save("intents-07-control-added")
        }
        pause(1.5)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        pause(2)
        save("intents-08-control-center")
        XCTAssertTrue(control.waitForExistence(timeout: 5), "The Weigh in control is in Control Center")
        control.tap()
        XCTAssertTrue(app.buttons["weighIn.save"].waitForExistence(timeout: 15), "The control opens the weigh-in sheet")
        pause(1)
        save("intents-09-control-opened-weigh-in")
    }

    /// Waits for an intent's answer, which the system shows over every app, then closes it.
    private func dialog(_ prefix: String, name: String) -> Bool {
        let text = springboard.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        guard text.waitForExistence(timeout: 30) else {
            dump(springboard, name + "-missing")
            return false
        }
        pause(1.5)
        save(name)
        add(XCTAttachment(string: text.label))
        springboard.buttons["Done"].firstMatch.tap()
        pause(1.5)
        return true
    }

    private func openControlCenter() {
        for _ in 0..<3 where !springboard.buttons["Add Controls"].exists {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.005))
                .press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.7)))
            pause(2)
        }
    }

    private func pause(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

    private func save(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let directory = ProcessInfo.processInfo.environment["EXERLY_SCREEN_DIR"], !directory.isEmpty else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: url.appendingPathComponent(name + ".png"))
    }

    /// The screen and an app's elements, for working out the next step.
    private func dump(_ target: XCUIApplication, _ name: String) {
        save(name)
        guard let directory = ProcessInfo.processInfo.environment["EXERLY_SCREEN_DIR"], !directory.isEmpty else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try? target.debugDescription.write(to: url.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
    }
}
