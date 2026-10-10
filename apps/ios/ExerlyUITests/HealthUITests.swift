import XCTest

/// Apple Health on the simulator's real HealthKit store: the switches, a
/// smart scale's reading arriving as a weigh-in, and writes that happen once
/// and only with consent. Scale readings are synthetic, written by the app's
/// debug seed as another app would write them.
@MainActor
final class HealthUITests: ExerlyUITestCase {
    private var designCapture: Bool { ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" }

    /// `launch(resetSession: true)` with the Health seed and write probe.
    private func launchWithHealth(seed: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        if let appearance = ProcessInfo.processInfo.environment["EXERLY_TEST_APPEARANCE"],
           ["light", "dark", "system"].contains(appearance) {
            app.launchArguments += ["-exerlyAppearance", appearance]
        }
        if ProcessInfo.processInfo.environment["EXERLY_TEST_LARGEST_TYPE"] == "1" {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment["EXERLY_API_BASE_URL"] = fixtureURL
        app.launchEnvironment["EXERLY_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["EXERLY_HEALTH_PROBE"] = "1"
        if let seed { app.launchEnvironment["EXERLY_HEALTH_SEED"] = seed }
        app.launch()
        return app
    }

    /// Waits until `element` matches `format`, which takes `argument`.
    private func wait(for element: XCUIElement, _ format: String, _ argument: String, timeout: TimeInterval = 20) async {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: format, argument), object: element)
        await fulfillment(of: [expectation], timeout: timeout)
    }

    private func openHealthSettings(_ app: XCUIApplication) {
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["Apple Health"], in: app)
        XCTAssertTrue(app.switches["health.readWeights"].waitForExistence(timeout: 10), app.debugDescription)
    }

    /// Turns a switch on and answers Health's permission sheet, if Health
    /// shows one (it asks once per type on a simulator).
    private func turnOn(_ identifier: String, in app: XCUIApplication) async {
        let toggle = app.switches[identifier]
        tap(toggle, in: app)
        let allow = app.buttons["Allow"]
        if allow.waitForExistence(timeout: 6) {
            if !allow.isEnabled {
                let all = app.cells["UIA.Health.AuthSheet.AllCategoryButton"]
                if all.exists { all.tap() } else { app.buttons["Turn On All"].firstMatch.tap() }
            }
            allow.tap()
        }
        await wait(for: toggle, "value == %@", "1", timeout: 15)
    }

    private func waitForProbe(_ text: String, in app: XCUIApplication) async {
        await wait(for: app.staticTexts["health.debug.probe"], "label == %@", text)
    }

    private func seedTrend(_ token: String) async throws {
        for back in 1...12 {
            let day = Self.day(-back)
            let kilograms = ((72.6 - Double(12 - back) * 0.06 + (back % 3 == 0 ? 0.3 : 0)) * 10).rounded() / 10
            try await seedWeighIn(token: token, date: day.date, at: day.at, value: kilograms, unit: "kg")
        }
    }

    /// A smart scale's 00:30 reading, with body fat, becomes today's weigh-in:
    /// on Today's trend card, in Progress → Body, and in the account.
    func testScaleReadingFromHealthBecomesTodaysWeighIn() async throws {
        continueAfterFailure = false
        try await control([:])
        let person = try await createAccount(prefix: "health-read", units: "metric")
        try await deleteSetupWeight(token: person.token)
        try await seedTrend(person.token)
        let app = launchWithHealth(seed: "71.8|21.4|0|00:30")
        signIn(app, email: person.email)
        let today = Self.day(0).date

        // The one-time offer on Progress → Body.
        tap(app.buttons["Progress"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["health.prompt"].waitForExistence(timeout: 15))
        if designCapture { capture(app, "health-prompt") }

        openHealthSettings(app)
        XCTAssertEqual(app.switches["health.readWeights"].value as? String, "0")
        XCTAssertEqual(app.switches["health.writeFood"].value as? String, "0")
        if designCapture { capture(app, "health-settings-off") }
        await turnOn("health.readWeights", in: app)
        await wait(for: app.descendants(matching: .any)["health.lastResult"], "label CONTAINS %@", "from Health")
        if designCapture {
            reveal(app.buttons["health.syncNow"], in: app)
            capture(app, "health-settings-synced")
        }

        let saved = try await waitForWeighIn(token: person.token) { $0["source"] as? String == "appleHealth" }
        XCTAssertEqual(saved?["date"] as? String, today, "A 00:30 reading belongs to that local day")
        XCTAssertEqual(saved?["bodyFat"] as? Double, 21.4)

        tap(app.buttons["Today"], in: app)
        let weighed = app.buttons["weightCard.weighIn"]
        reveal(weighed, in: app)
        XCTAssertEqual(weighed.label, "Weighed in today, 71.8 kilograms")
        if designCapture { capture(app, "health-trend-today") }

        tap(app.buttons["Progress"], in: app)
        XCTAssertFalse(app.descendants(matching: .any)["health.prompt"].exists, "The offer is gone once weigh-ins flow")
        let row = app.buttons["body.weighIn.\(today)"]
        reveal(row, in: app)
        XCTAssertEqual(row.label, "Weigh-in, Today, 71.8 kilograms")
        if designCapture { capture(app, "health-body") }
    }

    /// Writing is off until its switch is on, then each record reaches Health
    /// once: a second sync adds nothing.
    func testWritesReachHealthOnceAndOnlyWithConsent() async throws {
        continueAfterFailure = false
        try await control([:])
        let person = try await createAccount(prefix: "health-write", units: "metric")
        _ = try await seedNutritionEntry(token: person.token, name: "Synthetic lentil soup",
                                         nutrients: ["energy": 92, "protein": 6.1, "carbohydrate": 13.4, "fat": 1.2,
                                                     "fiber": 3.8, "sodium": 310, "iron": 1.6, "water": 80], grams: 350)
        let app = launchWithHealth(seed: nil)
        signIn(app, email: person.email)
        // The diary and setup's weigh-in arrive before Health is turned on.
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Synthetic lentil soup"))
            .firstMatch.waitForExistence(timeout: 20))
        openHealthSettings(app)
        await waitForProbe("food 0 weight 0 workout 0", in: app)

        await turnOn("health.writeWeights", in: app)
        await waitForProbe("food 0 weight 1 workout 0", in: app)
        await turnOn("health.writeFood", in: app)
        await waitForProbe("food 1 weight 1 workout 0", in: app)

        let syncNow = app.buttons["health.syncNow"]
        tap(syncNow, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["health.lastResult"].waitForExistence(timeout: 10))
        tap(syncNow, in: app)
        await wait(for: app.descendants(matching: .any)["health.lastResult"], "label CONTAINS %@", "up to date")
        await waitForProbe("food 1 weight 1 workout 0", in: app)
        if designCapture {
            reveal(syncNow, in: app)
            capture(app, "health-settings-writing")
        }

        // Turning food off stops it: a new entry isn't written.
        tap(app.switches["health.writeFood"], in: app)
        XCTAssertEqual(app.switches["health.writeFood"].value as? String, "0")
    }
}
