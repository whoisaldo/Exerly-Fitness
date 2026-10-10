import XCTest

/// Reminder buttons run from SpringBoard, and foods found in Spotlight. The
/// app schedules reminders from saved preferences as it does for anyone; only
/// their trigger is shortened (EXERLY_TEST_REMINDER_DELAY) so they arrive
/// during the test.
final class NotificationActionsUITests: ExerlyUITestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// A breakfast habit around now (see seedWeek), the reminders given, and
    /// the app signed in with reminders arriving 30 seconds after scheduling.
    private func signedIn(reminders: [String: Any], times: [String: Any], prefix: String,
                          environment: [String: String] = [:]) async throws -> (app: XCUIApplication, token: String) {
        try await control([:])
        let person = try await createAccount(prefix: prefix, units: "imperial")
        try await seedWeek(token: person.token)
        try await deleteSetupWeight(token: person.token)
        if !reminders.isEmpty { try await setReminders(reminders, times: times, token: person.token) }
        let app = launch(resetSession: true, environment: environment.merging(["EXERLY_TEST_REMINDER_DELAY": "30"]) { $1 })
        signIn(app, email: person.email)
        return (app, person.token)
    }

    private func setReminders(_ reminders: [String: Any], times: [String: Any], token: String) async throws {
        let current = try await request("GET", "/api/preferences", token: token)
        _ = try await request("PATCH", "/api/preferences", body: [
            "base_revision": current["revision"]!, "changes": ["reminders": reminders, "reminderTimes": times],
        ], token: token)
    }

    /// Now on the clock in New York, the seeded account's zone: "08:05".
    private var now: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.newYork
        let parts = calendar.dateComponents([.hour, .minute], from: Date())
        return String(format: "%02d:%02d", parts.hour!, parts.minute!)
    }

    /// Turns on delivery in Preferences (or refreshes it), then goes Home.
    private func deliverReminders(_ app: XCUIApplication, capturing name: String? = nil) {
        if !app.navigationBars["Preferences"].exists {
            tap(app.buttons["Profile"], in: app)
            tap(app.buttons["profile.preferences"], in: app)
            XCTAssertTrue(app.navigationBars["Preferences"].waitForExistence(timeout: 10))
        }
        let enable = app.buttons["Enable reminders on this iPhone"]
        let refresh = app.buttons["Refresh reminder delivery"]
        reveal(refresh, in: app)
        if enable.waitForExistence(timeout: 3) {
            let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: enable)
            wait(for: [ready], timeout: 20)
            tap(enable, in: app)
            if springboard.alerts.firstMatch.waitForExistence(timeout: 5) { springboard.alerts.buttons["Allow"].tap() }
        } else {
            tap(refresh, in: app)
        }
        let scheduled = app.staticTexts["preferences.scheduled-reminders"]
        reveal(scheduled, in: app)
        XCTAssertTrue(app.staticTexts["1 reminder scheduled"].waitForExistence(timeout: 15), app.debugDescription)
        if let name { capture(app, name) }
        XCUIDevice.shared.press(.home)
    }

    /// A notification showing `text`, as a banner or, once that has gone, in Notification Center.
    private func notification(_ text: String, timeout: TimeInterval = 45) -> XCUIElement {
        let match = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if match.waitForExistence(timeout: timeout), match.isHittable { return match }
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.003))
            .press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7)))
        XCTAssertTrue(match.waitForExistence(timeout: 10), "No notification with \(text): \(springboard.debugDescription)")
        return match
    }

    /// Today's usual foods appear once the seeded history has synced.
    private func waitForHistory(_ app: XCUIApplication) {
        let chip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.suggestion.log.")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 30), app.debugDescription)
    }

    private func todayEntries(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "nutrition.entry."))
    }

    private func closePreferences(_ app: XCUIApplication) {
        if app.navigationBars["Preferences"].exists { tap(app.buttons["preferences.save"], in: app) }
        tap(app.tabBars.buttons["Today"], in: app)
        XCTAssertTrue(todayScreen(app).waitForExistence(timeout: 10))
    }

    func testLogUsualBreakfastFromTheMealReminder() async throws {
        let (app, _) = try await signedIn(reminders: ["meals": true], times: ["meals": [now]], prefix: "notify-meal")
        waitForHistory(app)
        XCTAssertFalse(todayEntries(app).firstMatch.exists, "Nothing logged today yet")
        capture(app, "notify-before-today")
        // Profile's reminders now include a weigh-in, with its own time.
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.preferences"], in: app)
        tap(app.buttons["Reminder preferences"], in: app)
        reveal(app.textFields["preferences.reminderTimes.weighIn"], in: app)
        XCTAssertTrue(app.switches["preferences.reminders.weighIn"].exists, app.debugDescription)
        capture(app, "notify-preferences-weigh-in")
        deliverReminders(app, capturing: "notify-preferences-delivery")

        // Two taps from the banner: hold it, then Log usual breakfast.
        let reminder = notification("Press and hold to log your usual")
        capture(springboard, "notify-meal-banner")
        reminder.press(forDuration: 1.2)
        let logUsual = springboard.buttons["Log usual breakfast"]
        XCTAssertTrue(logUsual.waitForExistence(timeout: 8), springboard.debugDescription)
        XCTAssertTrue(springboard.buttons["Repeat yesterday's breakfast"].exists)
        XCTAssertTrue(springboard.buttons["Search"].exists)
        capture(springboard, "notify-meal-actions")
        logUsual.tap()

        let confirmation = notification("to Breakfast.", timeout: 30)
        capture(springboard, "notify-meal-logged")
        let food = try XCTUnwrap(["Greek yogurt, plain", "Blueberries"].first { confirmation.label.contains("Logged \($0), ") },
                                 "Logged a usual breakfast food: \(confirmation.label)")

        app.activate()
        closePreferences(app)
        let entry = todayEntries(app).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(entry.label.hasPrefix(food), entry.label)
        XCTAssertEqual(todayEntries(app).count, 1)
        capture(app, "notify-after-today")
    }

    func testLogWeightTypedIntoTheWeighInReminder() async throws {
        // The weigh-in reminder is added to the saved preferences in the app (a debug-only hook), so this
        // runs against a fixture whose API predates it; api.preferences.test.js covers the API storing it.
        let values = #"{"reminders":{"weighIn":true},"reminderTimes":{"weighIn":"07:00"}}"#
        let (app, token) = try await signedIn(reminders: [:], times: [:], prefix: "notify-weight",
                                              environment: ["EXERLY_TEST_REMINDER_VALUES": values])
        capture(app, "notify-weight-before-today")
        deliverReminders(app, capturing: "notify-weight-preferences")

        // Two taps: hold the reminder, which opens its only button's field
        // straight away, type, then Log.
        let reminder = notification("Press and hold to type today's weight in lb.")
        capture(springboard, "notify-weight-banner")
        reminder.press(forDuration: 1.2)
        let logWeight = springboard.buttons["Log weight"]
        if logWeight.waitForExistence(timeout: 2) { logWeight.tap() }
        let field = springboard.descendants(matching: .any).matching(NSPredicate(format: "placeholderValue == %@", "Weight")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8), springboard.debugDescription)
        field.typeText("181.4")
        capture(springboard, "notify-weight-typed")
        springboard.buttons["Log"].tap()

        let confirmation = notification("Logged 181.4 lb.", timeout: 30)
        XCTAssertTrue(confirmation.exists)
        capture(springboard, "notify-weight-logged")

        app.activate()
        closePreferences(app)
        // A new weigh-in starts from the last reading: the one typed in the notification.
        tap(app.buttons["today.weighIn"], in: app)
        let value = app.buttons["weighIn.value"]
        XCTAssertTrue(value.waitForExistence(timeout: 10))
        XCTAssertEqual(value.label, "Weight, 181.4 pounds")
        capture(app, "notify-weight-after")
        tap(app.buttons["weighIn.cancel"], in: app)
        let synced = try await waitForWeighIn(token: token) { ($0["weight"] as? [String: Any])?["value"] as? Double == 181.4 }
        XCTAssertEqual((synced?["weight"] as? [String: Any])?["unit"] as? String, "lb")
    }

    /// A food logged before is offered as the Log a food shortcut, so choosing
    /// it logs the remembered portion; a saved food never logged opens its
    /// portion sheet.
    func testSpotlightLogsAUsualFoodAndOpensANewOnesPortion() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "notify-spotlight", units: "imperial")
        try await seedWeek(token: person.token)
        let cottage = SeedFood(name: "Cottage cheese, low fat", per100g: ["energy": 72, "protein": 12.4, "carbohydrate": 2.7, "fat": 1])
        _ = try await request("PUT", "/v1/documents/saved_food/\(cottage.id)", body: ["base_revision": 0, "payload": [
            "id": cottage.id, "name": cottage.name, "source": "custom", "per100g": cottage.per100g,
            "servings": [["name": "cup", "grams": 226]], "favorite": false, "createdAt": "2026-10-01T12:00:00.000Z",
        ]], token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        waitForHistory(app)
        // Indexing follows the account's foods as they sync.
        Thread.sleep(forTimeInterval: 3)
        XCUIDevice.shared.press(.home)
        // Spotlight runs in its own process: pull down on the Home Screen, or tap its Search.
        let spotlight = XCUIApplication(bundleIdentifier: "com.apple.Spotlight")
        let field = spotlight.textFields["SpotlightSearchField"]
        springboard.swipeDown()
        if !field.waitForExistence(timeout: 5) { springboard.otherElements["spotlight-pill"].firstMatch.tap() }
        XCTAssertTrue(field.waitForExistence(timeout: 8), spotlight.debugDescription)

        field.typeText("greek yogurt")
        let usual = spotlight.cells.matching(NSPredicate(format: "label CONTAINS %@", "Greek yogurt, plain")).firstMatch
        XCTAssertTrue(usual.waitForExistence(timeout: 45), spotlight.debugDescription)
        capture(spotlight, "notify-spotlight-usual")
        usual.tap()
        // Spotlight says what was logged in a panel tests can't query (Today shows
        // the entry below); its Done sits near the top of the screen.
        Thread.sleep(forTimeInterval: 3)
        capture(spotlight, "notify-spotlight-usual-logged")
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        spotlight.buttons["Clear text"].tap()
        field.typeText("cottage cheese")
        let saved = spotlight.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "Cottage cheese, low fat")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 45), spotlight.debugDescription)
        capture(spotlight, "notify-spotlight-saved")
        saved.tap()
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 15), app.debugDescription)
        capture(app, "notify-spotlight-portion")
        tap(app.buttons["nutrition.saveEntry"], in: app)

        let entries = todayEntries(app)
        let cottageEntry = entries.matching(NSPredicate(format: "label BEGINSWITH %@", "Cottage cheese, low fat")).firstMatch
        XCTAssertTrue(cottageEntry.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(entries.matching(NSPredicate(format: "label BEGINSWITH %@", "Greek yogurt, plain")).firstMatch.exists)
        capture(app, "notify-spotlight-after")
    }
}
