import XCTest

/// Opt-in: Exerly's widgets in the Home Screen widget gallery, on the Home
/// Screen and on the Lock Screen, with the snapshot the app writes for a
/// signed-in week.
final class WidgetUITests: ExerlyUITestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    func testWidgetCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in visual review of the widgets")
        }
        let app = try await signedInWithWeek(prefix: "widget-capture")
        // The usual foods on screen, so today has something eaten.
        let suggestions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.suggestion.log."))
        XCTAssertTrue(suggestions.firstMatch.waitForExistence(timeout: 20))
        for index in 0..<min(3, suggestions.count) {
            let chip = suggestions.element(boundBy: index)
            if chip.frame.maxX < app.frame.maxX { tap(chip, in: app) }
        }
        captureGallery()
        addToHomeScreen()
        addToLockScreen()
    }

    /// Each page of Exerly's gallery: Today and Next workout, small and medium.
    private func captureGallery() {
        openExerlyGallery()
        let names = ["widget-01-today-small", "widget-02-today-medium", "widget-03-next-small", "widget-04-next-medium"]
        for (index, name) in names.enumerated() {
            if index > 0 { swipeGallery() }
            save(name)
        }
        springboard.buttons["close"].firstMatch.tap()
        pause(1)
        springboard.buttons["Done"].firstMatch.tap()
        pause(1)
    }

    /// Today, medium, and Next workout, small, on the Home Screen.
    private func addToHomeScreen() {
        for (page, name) in [(1, "widget-05-home-today-medium"), (2, "widget-06-home-next-small")] {
            openExerlyGallery()
            for _ in 0..<page { swipeGallery() }
            springboard.buttons[" Add Widget"].firstMatch.tap()
            pause(2)
            save(name)
            springboard.buttons["Done"].firstMatch.tap()
            pause(1.5)
        }
    }

    /// Today inline above the clock, and Exerly's accessory widgets below it.
    private func addToLockScreen() {
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        pause(1.5)
        XCUIDevice.shared.press(.home)
        pause(2)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.5)
        pause(1.5)
        springboard.buttons["posterboard-customize-button"].firstMatch.tap()
        pause(2)
        let inline = springboard.buttons["inline-widget-reticle-view"].firstMatch
        if inline.waitForExistence(timeout: 3) {
            inline.tap()
            pause(1.5)
            let today = springboard.cells["Exerly, Today, Top Widget"].firstMatch
            if today.waitForExistence(timeout: 3) { today.tap() }
            pause(1)
            save("widget-07-lock-inline")
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
            pause(1.5)
        }
        let grouped = springboard.buttons["grouped-widgets-reticle-view"].firstMatch
        if grouped.waitForExistence(timeout: 3) {
            grouped.tap()
            pause(2)
            let exerly = springboard.cells["Exerly"].firstMatch
            if exerly.waitForExistence(timeout: 3) { exerly.tap() }
            pause(2)
            save("widget-08-lock-gallery")
            accessory("Exerly, Today", "Rectangular").tap()
            pause(1.5)
            let sheet = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.7))
            sheet.press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.7)))
            pause(1.5)
            accessory("Exerly, Next workout", "Circular").tap()
            pause(1.5)
            springboard.buttons["close"].firstMatch.tap()
            pause(1)
            // The list of apps stays open; drag it away.
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.455))
                .press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99)))
            pause(1.5)
        }
        let done = springboard.buttons["editing-done"].firstMatch
        if done.waitForExistence(timeout: 3) { done.tap() } else { dump("l-08-no-done") }
        pause(2)
        // Editing ends in the wallpaper switcher; the current one returns to the Lock Screen.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        pause(2)
        save("widget-09-lock-screen")
    }

    private func accessory(_ label: String, _ family: String) -> XCUIElement {
        springboard.buttons.matching(NSPredicate(format: "label == %@ AND value == %@", label, "Widget, \(family)")).firstMatch
    }

    private func openExerlyGallery() {
        XCUIDevice.shared.press(.home)
        pause(1.5)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).press(forDuration: 1.5)
        pause(1)
        springboard.buttons["Edit"].firstMatch.tap()
        pause(1)
        springboard.buttons["Add Widget"].firstMatch.tap()
        pause(1.5)
        let search = springboard.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), springboard.debugDescription)
        search.tap()
        search.typeText("Exerly")
        pause(1.5)
        let exerly = springboard.cells.containing(.staticText, identifier: "Exerly").firstMatch
        if exerly.waitForExistence(timeout: 3) { exerly.tap() } else { springboard.staticTexts["Exerly"].firstMatch.tap() }
        pause(1.5)
    }

    private func swipeGallery() {
        let from = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.58))
        from.press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.58)))
        pause(1.2)
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

    /// The screen and SpringBoard's elements, for working out the next step.
    private func dump(_ name: String) {
        save(name)
        guard let directory = ProcessInfo.processInfo.environment["EXERLY_SCREEN_DIR"], !directory.isEmpty else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try? springboard.debugDescription.write(to: url.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
    }
}
