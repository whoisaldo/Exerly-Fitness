import XCTest

/// Weigh-ins, trend weight and expenditure.
@MainActor
final class BodyUITests: ExerlyUITestCase {
    private var designCapture: Bool { ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" }

    /// From the button that opens the sheet: open, drag once, Save.
    func testWeighInTakesThreeTapsFromItsButton() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "body-taps", units: "imperial")
        try await deleteSetupWeight(token: person.token)
        let yesterday = Self.day(-1)
        try await seedWeighIn(token: person.token, date: yesterday.date, at: yesterday.at, value: 184.6, unit: "lb")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        settle(app)
        tap(app.buttons["Progress"], in: app)
        let open = app.buttons["body.weighIn"]
        XCTAssertTrue(open.waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["body.weighIn.\(yesterday.date)"].waitForExistence(timeout: 20))

        tapCount = 0
        tap(open, in: app)
        let value = app.buttons["weighIn.value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertEqual(value.label, "Weight, 184.6 pounds", "The sheet starts on the last reading")
        let ruler = app.descendants(matching: .any)["weighIn.ruler"]
        XCTAssertTrue(ruler.exists)
        // One drag to the left moves the scale up about four ticks of 0.2 lb.
        let start = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -41, dy: 0)), withVelocity: .slow,
                    thenHoldForDuration: 0.1)
        tapCount += 1
        let entered = try XCTUnwrap(Double(value.label.replacingOccurrences(of: "Weight, ", with: "")
            .replacingOccurrences(of: " pounds", with: "")))
        XCTAssertGreaterThan(entered, 184.6)
        XCTAssertLessThan(entered, 186)
        tap(app.buttons["weighIn.save"], in: app)
        XCTAssertLessThanOrEqual(tapCount, 3, "A weigh-in takes at most three taps from its button")
        XCTAssertTrue(app.buttons["Progress"].waitForExistence(timeout: 5))
        let today = Self.day(0).date
        XCTAssertTrue(app.descendants(matching: .any)["body.weighIn.\(today)"].waitForExistence(timeout: 10))
        let saved = try await waitForWeighIn(token: person.token) { $0["date"] as? String == today }
        let weight = try XCTUnwrap(saved?["weight"] as? [String: Any])
        XCTAssertEqual(weight["unit"] as? String, "lb")
        XCTAssertEqual(try XCTUnwrap(weight["value"] as? Double), entered, accuracy: 0.001)
        capture(app, "body-taps-saved")
    }

    /// A weigh-in saved offline survives a relaunch and syncs; edits keep its
    /// identity, and a deletion can be undone. Setup's weight arrives as one.
    func testWeighInOfflineRelaunchSyncEditDeleteAndUndo() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "body-offline", units: "metric")
        let today = Self.day(0).date
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        settle(app)
        tap(app.buttons["Progress"], in: app)
        // Setup's 72.25 kg becomes an ExerlyCore weigh-in.
        XCTAssertTrue(app.buttons["Weigh-in, Today, 72.25 kilograms"].waitForExistence(timeout: 30), app.debugDescription)
        let setup = try await waitForWeighIn(token: person.token) { ($0["weight"] as? [String: Any])?["value"] as? Double == 72.25 }
        XCTAssertEqual(setup?["date"] as? String, today)

        try await control(["offline": true])
        tap(app.buttons["body.weighIn"], in: app)
        XCTAssertEqual(app.buttons["weighIn.value"].label, "Weight, 72.3 kilograms")
        tap(app.buttons["weighIn.increase"], in: app)
        tap(app.buttons["weighIn.increase"], in: app)
        XCTAssertEqual(app.buttons["weighIn.value"].label, "Weight, 72.5 kilograms")
        tap(app.buttons["weighIn.save"], in: app)
        let offlineRow = app.buttons["Weigh-in, Today, 72.5 kilograms"]
        XCTAssertTrue(offlineRow.waitForExistence(timeout: 10))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Progress"], in: app)
        XCTAssertTrue(offlineRow.waitForExistence(timeout: 15), "The offline weigh-in is still on the device")
        capture(app, "body-offline-relaunched")

        try await control([:])
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        let found = try await waitForWeighIn(token: person.token) { ($0["weight"] as? [String: Any])?["value"] as? Double == 72.5 }
        let synced = try XCTUnwrap(found)
        let id = try XCTUnwrap(synced["id"] as? String)

        tap(app.buttons["Progress"], in: app)
        tap(offlineRow, in: app)
        XCTAssertTrue(app.staticTexts["Edit weigh-in"].waitForExistence(timeout: 5))
        tap(app.buttons["weighIn.value"], in: app)
        for key in ["7", "1", Locale.current.decimalSeparator ?? ".", "8"] { tap(app.buttons["exerly.keypad.\(key)"], in: app) }
        tap(app.buttons["weighIn.save"], in: app)
        let edited = try await waitForWeighIn(token: person.token) { ($0["weight"] as? [String: Any])?["value"] as? Double == 71.8 }
        XCTAssertEqual(edited?["id"] as? String, id, "An edit keeps the weigh-in's identity")

        tap(app.buttons["Weigh-in, Today, 71.8 kilograms"], in: app)
        tap(app.buttons["weighIn.delete"], in: app)
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        var gone = false
        for _ in 0..<40 where !gone {
            gone = try await weighIns(token: person.token)[id] == nil
            if !gone { try await Task.sleep(for: .milliseconds(250)) }
        }
        XCTAssertTrue(gone, "The deletion reaches the server")
        capture(app, "body-deleted-undo")
        tap(app.buttons["Undo"], in: app)
        XCTAssertTrue(app.buttons["Weigh-in, Today, 71.8 kilograms"].waitForExistence(timeout: 10))
        let restored = try await waitForWeighIn(token: person.token) { ($0["weight"] as? [String: Any])?["value"] as? Double == 71.8 }
        XCTAssertNotNil(restored)
    }

    func testBodyCapture() async throws {
        guard designCapture else { throw XCTSkip("Opt-in visual review") }
        try await control([:])
        let person = try await createAccount(prefix: "body-design", units: "imperial")
        try await deleteSetupWeight(token: person.token)
        try await seedHistory(token: person.token)
        let app = launch(resetSession: true, showWeightCard: true)
        signIn(app, email: person.email)
        settle(app)
        tap(app.buttons["Progress"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["body.chart"].waitForExistence(timeout: 30))
        if app.buttons["body.range.3M"].exists { tap(app.buttons["body.range.3M"], in: app) }
        try await Task.sleep(for: .seconds(1))
        capture(app, "body-01-progress")
        app.swipeUp(velocity: .slow)
        capture(app, "body-02-expenditure")
        app.swipeUp(velocity: .slow)
        capture(app, "body-03-history")
        for _ in 0..<4 { app.swipeDown() }
        tap(app.buttons["body.weighIn"], in: app)
        XCTAssertTrue(app.buttons["weighIn.value"].waitForExistence(timeout: 5))
        try await Task.sleep(for: .seconds(0.6))
        capture(app, "body-04-weigh-in")
        app.buttons["weighIn.value"].tap()
        app.buttons["exerly.keypad.1"].tap()
        app.buttons["exerly.keypad.8"].tap()
        try await Task.sleep(for: .seconds(0.6))
        capture(app, "body-05-typing")
        app.buttons["exerly.keypadDone"].tap()
        app.buttons["weighIn.cancel"].tap()
        tap(app.buttons["body.weighIn"], in: app)
        let ruler = app.descendants(matching: .any)["weighIn.ruler"]
        let start = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 31, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.1)
        app.buttons["weighIn.save"].tap()
        try await Task.sleep(for: .seconds(1))
        capture(app, "body-06-after-save")
        if app.buttons["body.range.1M"].exists {
            tap(app.buttons["body.range.1M"], in: app)
            capture(app, "body-07-one-month")
        } else {
            app.swipeUp(velocity: .slow)
            capture(app, "body-07-chart-largest-type")
        }
        for _ in 0..<6 { app.swipeUp() }
        capture(app, "body-08-card")
    }

    // MARK: Fixture data

    func launch(resetSession: Bool, showWeightCard: Bool) -> XCUIApplication {
        guard showWeightCard else { return launch(resetSession: resetSession) }
        let app = XCUIApplication()
        app.launchArguments = resetSession ? ["--ui-testing"] : []
        if let appearance = ProcessInfo.processInfo.environment["EXERLY_TEST_APPEARANCE"] {
            app.launchArguments += ["-exerlyAppearance", appearance]
        }
        if ProcessInfo.processInfo.environment["EXERLY_TEST_LARGEST_TYPE"] == "1" {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment["EXERLY_API_BASE_URL"] = fixtureURL
        app.launchEnvironment["EXERLY_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["EXERLY_SHOW_WEIGHT_CARD"] = "1"
        app.launch()
        return app
    }

    /// The system offers to save the synthetic password a moment after sign-in.
    func settle(_ app: XCUIApplication) {
        for _ in 0..<12 {
            if dismissPasswordPrompt(in: app) { break }
            Thread.sleep(forTimeInterval: 0.25)
        }
    }

    /// Setup records its weight for today through the older API; captures want a clean history.
    func deleteSetupWeight(token: String) async throws {
        let row = try await request("GET", "/api/weight/day", token: token)
        guard let id = row["id"] as? String, let revision = row["revision"] as? Int else { return }
        _ = try await request("DELETE", "/api/weight/\(id)?base_revision=\(revision)", token: token)
    }

    func seedWeighIn(token: String, date: String, at: Date, value: Double, unit: String) async throws {
        let id = UUID().uuidString
        let payload: [String: Any] = ["id": id, "at": Self.iso(at), "date": date, "weight": ["unit": unit, "value": value]]
        _ = try await request("PUT", "/v1/documents/weight_entry/\(id)", body: ["base_revision": 0, "payload": payload], token: token)
    }

    /// Eight weeks of a steady cut, weighed most mornings, with food fully logged on most days.
    func seedHistory(token: String) async throws {
        for reading in syntheticReadings(days: 56) {
            let pounds = (reading.kilograms / 0.453_592_37 * 10).rounded() / 10
            try await seedWeighIn(token: token, date: reading.date, at: reading.at, value: pounds, unit: "lb")
        }
        for back in 1...56 where back % 7 != 3 {
            let day = Self.day(-back)
            let id = UUID().uuidString
            let energy = 2150 + 180 * sin(Double(back) * 2.3)
            let food: [String: Any] = ["foodID": "quick:\(id)", "name": "Logged day", "source": "custom", "unweighed": true,
                                       "per100g": ["energy": energy, "protein": 165, "carbohydrate": 210, "fat": 70]]
            let entry: [String: Any] = ["id": id, "date": day.date, "meal": "Dinner", "loggedAt": Self.iso(day.at), "food": food, "grams": 100]
            _ = try await request("PUT", "/v1/documents/food_entry/\(id)", body: ["base_revision": 0, "payload": entry], token: token)
            let status: [String: Any] = ["id": day.date, "date": day.date, "status": "complete", "notes": "", "tags": [String]()]
            _ = try await request("PUT", "/v1/documents/nutrition_day/\(day.date)", body: ["base_revision": 0, "payload": status], token: token)
        }
    }

    /// The account's live weigh-in documents by ID, from the change feed.
    func weighIns(token: String) async throws -> [String: [String: Any]] {
        var latest: [String: [String: Any]?] = [:]
        var cursor = 0
        while true {
            let page = try await request("GET", "/v1/changes?after=\(cursor)&limit=1000", token: token)
            for change in page["changes"] as? [[String: Any]] ?? [] where change["kind"] as? String == "weight_entry" {
                guard let id = change["id"] as? String else { continue }
                latest[id] = change["payload"] as? [String: Any]
            }
            cursor = page["cursor"] as? Int ?? cursor
            guard page["has_more"] as? Bool == true else { break }
        }
        return latest.compactMapValues { $0 }
    }

    func waitForWeighIn(token: String, timeout: Int = 40, _ matches: @escaping ([String: Any]) -> Bool) async throws -> [String: Any]? {
        for _ in 0..<timeout {
            if let found = try await weighIns(token: token).values.first(where: matches) { return found }
            try await Task.sleep(for: .milliseconds(500))
        }
        XCTFail("No matching weigh-in reached the server")
        return nil
    }

    struct Reading {
        let date: String
        let kilograms: Double
        let at: Date
    }

    static let newYork = TimeZone(identifier: "America/New_York")!

    static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// A local date in New York `offset` days from today, and 07:10 that morning.
    static func day(_ offset: Int) -> (date: String, at: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = newYork
        formatter.dateFormat = "yyyy-MM-dd"
        let at = offset == 0 ? min(Date(), calendar.date(bySettingHour: 7, minute: 10, second: 0, of: date)!)
            : calendar.date(bySettingHour: 7, minute: 10, second: 0, of: date)!
        return (formatter.string(from: date), at)
    }

    /// A steady cut of about 0.45 kg a week with water swings, weighed on most mornings.
    func syntheticReadings(days: Int) -> [Reading] {
        (1...days).reversed().compactMap { back -> Reading? in
            guard back % 9 != 4, back % 13 != 6 else { return nil }
            let day = Double(days - back)
            let water = 0.42 * sin(day * 1.7) + 0.22 * sin(day * 0.53 + 1) + 0.12 * cos(day * 3.1)
            let kilograms = ((84.2 - 0.064 * day + water) * 10).rounded() / 10
            let local = Self.day(-back)
            return Reading(date: local.date, kilograms: kilograms, at: local.at.addingTimeInterval(Double(back % 20) * 60))
        }
    }
}
