import XCTest

/// Drives the watch app against its paired phone, which runs Exerly signed
/// into a fixture account whose program plans Pull: deadlift, 3 sets. Run by
/// `apps/ios/scripts/watch-uitest.sh` beside WatchCompanionUITests, which
/// checks on the phone that the set logged here was recorded.
final class WatchWorkoutUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        guard ProcessInfo.processInfo.environment["EXERLY_WATCH_COMPANION"] == "1" else {
            throw XCTSkip("Needs the paired phone's half: apps/ios/scripts/watch-uitest.sh")
        }
        continueAfterFailure = false
    }

    func testStartsTodaysWorkoutLogsASetInOneTapAndRests() throws {
        let start = app.buttons["watch.start"]
        XCTAssertTrue(launchConnected(), "The phone publishes today's workout: \(app.debugDescription)")
        XCTAssertEqual(app.staticTexts["watch.plannedTitle"].label, "Pull")
        capture("01-start")

        start.tap()
        allowHealthAccess()
        let done = app.buttons["watch.done"]
        let setNumber = app.staticTexts["watch.setNumber"]
        let weight = app.descendants(matching: .any)["watch.weight"]
        let reps = app.descendants(matching: .any)["watch.reps"]
        XCTAssertTrue(done.waitForExistence(timeout: 60), "The workout started on the phone: \(app.debugDescription)")
        XCTAssertEqual(app.staticTexts["watch.exercise"].label, "Deadlift")
        XCTAssertEqual(setNumber.label, "Set 1 of 3")
        let planned = (weight: weight.value as? String, reps: reps.value as? String)
        capture("02-set")

        // One tap logs the set as prefilled, and rest begins.
        done.tap()
        let rest = app.descendants(matching: .any)["watch.rest"]
        XCTAssertTrue(rest.waitForExistence(timeout: 10), "Rest follows the set: \(app.debugDescription)")
        XCTAssertTrue(waitForPhone(), "The phone handled the set")
        capture("03-rest")
        app.buttons["watch.addRest"].tap()
        app.buttons["watch.skipRest"].tap()
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        XCTAssertEqual(setNumber.label, "Set 2 of 3")
        XCTAssertEqual(weight.value as? String, planned.weight)

        // Live heart rate from the workout session.
        let heartRate = app.descendants(matching: .any)["watch.heartRate"]
        let reading = NSPredicate(format: "value ENDSWITH %@", "beats per minute")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: reading, evaluatedWith: heartRate)], timeout: 60), .completed,
                       "No heart rate reading: \(heartRate.debugDescription)")
        capture("04-heart-rate")

        // The Digital Crown changes the reps, and the weight after a tap on it.
        XCTAssertTrue(turnCrown(changing: reps), "The Crown changes the reps first")
        XCTAssertEqual(weight.value as? String, planned.weight, "The weight waits for a tap")
        weight.tap()
        XCTAssertTrue(turnCrown(changing: weight), "After a tap, the Crown changes the weight")
        let edited = (weight: weight.value as? String, reps: reps.value as? String)
        capture("05-set-edited")
        done.tap()
        XCTAssertTrue(rest.waitForExistence(timeout: 10))
        app.buttons["watch.skipRest"].tap()
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForPhone(), "The phone handled the edited set")
        XCTAssertEqual(setNumber.label, "Set 3 of 3")
        XCTAssertEqual(weight.value as? String, edited.weight, "The phone carried the new weight to the next set")
        XCTAssertEqual(reps.value as? String, edited.reps)

        // The largest text size, relaunched mid-workout from the state the watch kept.
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(done.waitForExistence(timeout: 30), "The workout is still on screen: \(app.debugDescription)")
        XCTAssertEqual(setNumber.label, "Set 3 of 3")
        capture("06-set-largest-text")
        reveal(done)
        done.tap()
        XCTAssertTrue(rest.waitForExistence(timeout: 10))
        capture("07-rest-largest-text")

        app.buttons["watch.finish"].firstMatch.tap()
        let save = app.buttons["Save workout"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        reveal(save)
        save.tap()
        XCTAssertTrue(app.buttons["watch.summaryDone"].waitForExistence(timeout: 10))
        capture("08-saved")
        reveal(app.buttons["watch.summaryDone"])
        app.buttons["watch.summaryDone"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 30), "Back to the program's next workout")
    }

    /// Turns the Crown a little at a time until the value changes, and
    /// checks it went up.
    private func turnCrown(changing element: XCUIElement) -> Bool {
        let before = element.value as? String ?? ""
        // A turn under about a sixth of a rotation moves less than one step.
        for _ in 0..<4 where element.value as? String == before {
            XCUIDevice.shared.rotateDigitalCrown(delta: 0.25)
        }
        let number = { (value: String) in Double(value.split(separator: " ").first ?? "") ?? -1 }
        return number(element.value as? String ?? "") > number(before)
    }

    /// Launches until the phone's state arrives, for up to ten minutes while
    /// the phone's half signs in. On the simulator, the first launch after an
    /// install can come before WatchConnectivity knows the app, and that
    /// launch's session never activates; the next one does.
    private func launchConnected() -> Bool {
        app.launchArguments = ["--ui-testing"]
        for _ in 0..<12 {
            app.launch()
            if app.buttons["watch.start"].waitForExistence(timeout: 50) { return true }
            app.terminate()
        }
        return false
    }

    /// Health asks once, in the system's sheet, to save workouts and read
    /// heart rate: Review, turn everything on, Next, then Done.
    private func allowHealthAccess() {
        let sheet = XCUIApplication(bundleIdentifier: "com.apple.Carousel")
        let review = sheet.buttons["UIA.Health.WatchAuthSheet.ReviewButton"]
        guard review.waitForExistence(timeout: 10) else { return }
        review.tap()
        let next = sheet.cells["UIA.Health.WatchAuthSheet.ConfigureCell.Button"]
        for _ in 0..<3 {
            let all = sheet.switches["UIA.Health.WatchAuthSheet.SwitchOutlet"].firstMatch
            if all.waitForExistence(timeout: 5), all.value as? String == "0" { all.tap() }
            for _ in 0..<8 where !next.exists || !next.isHittable { sheet.swipeUp() }
            guard next.exists else { return }
            let last = next.label == "Done"
            next.tap()
            if last { return }
        }
    }

    /// Scrolls until the element can be tapped, as the largest text pushes it down.
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<6 where element.exists && !element.isHittable { app.swipeUp() }
    }

    /// Waits until the phone has handled every command, so the watch shows the phone's own state.
    private func waitForPhone() -> Bool {
        let pending = app.descendants(matching: .any)["debug.pending"]
        let handled = NSPredicate(format: "value == %@", "0")
        return XCTWaiter.wait(for: [expectation(for: handled, evaluatedWith: pending)], timeout: 30) == .completed
    }

    /// Asks watch-uitest.sh for a simctl screenshot and waits for it.
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        guard let directory = ProcessInfo.processInfo.environment["EXERLY_SCREEN_DIR"], !directory.isEmpty else { return }
        let request = URL(fileURLWithPath: directory).appendingPathComponent("watch-\(name).request")
        FileManager.default.createFile(atPath: request.path, contents: nil)
        let deadline = Date().addingTimeInterval(20)
        while FileManager.default.fileExists(atPath: request.path), Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
    }
}
