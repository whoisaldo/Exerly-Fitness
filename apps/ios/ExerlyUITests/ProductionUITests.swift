import XCTest

@MainActor
final class ProductionUITests: XCTestCase {
    private var fixtureURL = "http://127.0.0.1:39001"

    // Let async test bodies finish or throw before XCTest starts the next test.
    // Aborting at an assertion can leave their fixture requests running.
    override func setUpWithError() throws { continueAfterFailure = true }

    func testWelcomeCanOpenSignIn() throws {
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        XCTAssertTrue(app.secureTextFields["Password"].waitForExistence(timeout: 5))
    }

    func testFractionalFoodSnapshotSurvivesNativePortionAndNutritionEdits() async throws {
        try await control([:])
        let email = "food-precision-\(UUID().uuidString.lowercased())@exerly.test"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": "Simulator-Test-123!", "name": "Food Taylor"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Food Taylor", "age": 34, "gender": "female", "sex": "female", "height": 167.5, "weight": 72.25,
            "goal": "maintain", "activityLevel": "light", "unitSystem": "metric", "timezone": "America/New_York"
        ], token: token)
        let created = try await request("POST", "/api/food", body: [
            "name": "Precise oats", "calories": 99.5, "protein": 3.3333, "sodium": 123.4567,
            "servings": 1.5, "meal_type": "breakfast", "nutrition_basis": ["amount": 100, "unit": "g"],
            "client_id": UUID().uuidString.lowercased(), "base_revision": 0
        ], token: token)
        let identifier = try XCTUnwrap(created["id"] as? String)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Edit Precise oats"], in: app)
        replace(app.textFields["Number of servings"], with: "0.75", in: app)
        dismissKeyboard(app)
        reveal(app.staticTexts["75 kcal"].firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["75 kcal"].firstMatch.exists)
        capture(app, "food-native-three-quarter-portion")
        tap(app.buttons["Save changes"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))
        var saved = try await request("GET", "/api/food/\(identifier)", token: token)
        for _ in 0..<20 where saved["revision"] as? Int != 2 {
            try await Task.sleep(for: .milliseconds(250))
            saved = try await request("GET", "/api/food/\(identifier)", token: token)
        }
        XCTAssertEqual(saved["calories"] as? Int, 75)
        XCTAssertEqual(saved["protein"] as? Double, 2.5)
        XCTAssertEqual(saved["sodium"] as? Double, 92.59)
        XCTAssertEqual((saved["nutrition_snapshot"] as? [String: Any])?["calories"] as? Double, 99.5)
        tap(app.buttons["Edit Precise oats"], in: app)
        tap(app.buttons["Correct nutrition per serving"], in: app)
        replace(app.textFields["Calories"], with: "200.5", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Save changes"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))
        saved = try await request("GET", "/api/food/\(identifier)", token: token)
        for _ in 0..<20 where saved["revision"] as? Int != 3 {
            try await Task.sleep(for: .milliseconds(250))
            saved = try await request("GET", "/api/food/\(identifier)", token: token)
        }
        XCTAssertEqual(saved["calories"] as? Int, 150)
        XCTAssertEqual((saved["nutrition_snapshot"] as? [String: Any])?["calories"] as? Double, 200.5)
        let exported = try await request("GET", "/api/export", token: token)
        let food = try XCTUnwrap((exported["food"] as? [[String: Any]])?.first)
        XCTAssertEqual(food["calories"] as? Int, 150)
        XCTAssertEqual(food["servings"] as? Double, 0.75)
    }

    func testLandingPagePhoneLoggingCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_BRAG_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in phone footage capture; run brag-output/record-phone.py")
        }
        fixtureURL = "http://127.0.0.1:39003"
        let email = "phone-film-\(UUID().uuidString.lowercased())@exerly.test"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": "Simulator-Test-123!", "name": "Morgan"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Morgan", "age": 34, "gender": "female", "sex": "female", "height": 167.5, "weight": 72.25,
            "goal": "maintain", "activityLevel": "light", "unitSystem": "metric", "timezone": "America/New_York"
        ], token: token)
        let initialSummary = try await request("GET", "/api/summary", token: token)
        let today = try XCTUnwrap(initialSummary["date"] as? String)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let yesterday = formatter.string(from: try XCTUnwrap(formatter.date(from: today)).addingTimeInterval(-86400))
        _ = try await request("POST", "/api/food", body: ["name": "Chicken & avocado bowl", "calories": 520,
            "protein": 38, "carbs": 48, "fat": 19, "fiber": 8, "sugar": 4, "mealType": "lunch",
            "servingSize": "1 bowl", "servings": 1, "source": "manual", "entry_date": yesterday], token: token)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        func mark(_ phase: String) {
            print("EXERLY_BRAG \(phase) \(Date().timeIntervalSince1970)")
            fflush(stdout)
        }
        mark("ready")
        try await Task.sleep(for: .seconds(4))
        mark("diary"); capture(app, "brag-phone-diary")
        try await Task.sleep(for: .seconds(3))
        tap(app.buttons["diary.add.lunch"], in: app)
        let meal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Chicken & avocado bowl")).firstMatch
        XCTAssertTrue(meal.waitForExistence(timeout: 10))
        mark("recents"); capture(app, "brag-phone-recents")
        try await Task.sleep(for: .seconds(3))
        tap(meal, in: app)
        mark("serving"); capture(app, "brag-phone-serving")
        try await Task.sleep(for: .seconds(3))
        replace(app.textFields["Number of servings"], with: "1.5", in: app)
        dismissKeyboard(app)
        mark("quantity"); capture(app, "brag-phone-quantity")
        try await Task.sleep(for: .seconds(3))
        reveal(app.buttons["Log Food"], in: app)
        mark("save")
        tap(app.buttons["Log Food"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        reveal(app.buttons["Edit Chicken & avocado bowl"], in: app)
        mark("logged"); capture(app, "brag-phone-logged")
        try await Task.sleep(for: .seconds(3))
        reveal(app.buttons["Add 250 ml of water"], in: app)
        mark("water")
        tap(app.buttons["Add 250 ml of water"], in: app)
        try await Task.sleep(for: .seconds(3))
        for _ in 0..<3 { app.swipeDown(velocity: .fast) }
        XCTAssertTrue(app.staticTexts["diary.selected-day"].waitForExistence(timeout: 15))
        try await Task.sleep(for: .seconds(2))
        mark("summary"); capture(app, "brag-phone-summary")
        try await Task.sleep(for: .seconds(4))
        let result = try await request("GET", "/api/summary", token: token)
        XCTAssertEqual(result["water_ml"] as? Int, 250)
        XCTAssertEqual(result["entry_count"] as? Int, 1)
        mark("end")
    }

    func testAccountCalendarTodayAgreesWithAPIWhenDeviceIsOnAnotherDay() async throws {
        try await control([:])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let deviceDay = formatter.string(from: Date())
        let zone = try XCTUnwrap(["Pacific/Kiritimati", "Etc/GMT+12"].first { identifier in
            formatter.timeZone = TimeZone(identifier: identifier)
            return formatter.string(from: Date()) != deviceDay
        })
        let email = "calendar-\(UUID().uuidString.lowercased())@exerly.test"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": "Simulator-Test-123!", "name": "Calendar Taylor", "timezone": zone])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Calendar Taylor", "age": 34, "gender": "female", "sex": "female", "height": 167.75, "weight": 72.25,
            "goal": "maintain", "activityLevel": "light", "unitSystem": "metric", "timezone": zone
        ], token: token)
        let summary = try await request("GET", "/api/summary", token: token)
        let expectedDay = try XCTUnwrap(summary["date"] as? String)
        XCTAssertNotEqual(expectedDay, deviceDay)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        let selected = app.staticTexts["diary.selected-day"]
        XCTAssertTrue(selected.waitForExistence(timeout: 10))
        XCTAssertEqual(selected.value as? String, expectedDay)
        capture(app, "calendar-account-today")
        tap(app.buttons["Add 250 ml of water"], in: app)
        var water: [String: Any] = [:]
        for _ in 0..<30 {
            water = (try await request("GET", "/api/summary", token: token))["water"] as? [String: Any] ?? [:]
            if water["ml"] as? Int == 250 { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(water["entry_date"] as? String, expectedDay)
        XCTAssertEqual(water["ml"] as? Int, 250)
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["diary.selected-day"].value as? String, expectedDay)
    }

    func testBrowserSetupDraftContinuesOnNative() async throws {
        let fixture = try await request("GET", "/__test/setup-roundtrip")
        guard fixture["phase"] as? String == "browser-draft" else { throw XCTSkip("Requires the shared browser setup fixture") }
        try await control([:])
        let email = try XCTUnwrap(fixture["email"] as? String)
        let login = try await request("POST", "/login", body: ["email": email, "password": "Simulator-Test-123!"])
        let token = try XCTUnwrap(login["token"] as? String)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.buttons["Finish setup"].waitForExistence(timeout: 15))
        capture(app, "setup-browser-draft-native-review")
        tap(app.buttons["Previous setup step"], in: app)
        tap(app.buttons["Previous setup step"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "General Health")).firstMatch, in: app)
        tap(app.buttons["setup.nutritionGoal"], in: app)
        tap(app.buttons["Gain weight"], in: app)
        replace(app.textFields["Target weight"], with: "75.25", in: app)
        dismissKeyboard(app)
        capture(app, "setup-independent-nutrition-goal")
        tap(app.buttons["Continue"], in: app)
        tap(app.buttons["Continue"], in: app)
        XCTAssertTrue(app.buttons["Finish setup"].waitForExistence(timeout: 10))
        var draft: [String: Any] = [:]
        for _ in 0..<30 {
            draft = (try await request("GET", "/api/onboarding/draft", token: token))["draft"] as? [String: Any] ?? [:]
            if draft["last_valid_step"] as? Int == 4,
               (draft["answers"] as? [String: Any])?["nutritionGoal"] as? String == "gain" { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        let answers = try XCTUnwrap(draft["answers"] as? [String: Any])
        XCTAssertEqual(answers["name"] as? String, "Browser to Native Taylor")
        XCTAssertEqual(answers["goal"] as? String, "general_health")
        XCTAssertEqual(answers["nutritionGoal"] as? String, "gain")
        XCTAssertEqual(answers["targetWeight"] as? Double, 75.25)
        XCTAssertEqual(answers["allergies"] as? [String], ["sesame", "nuts"])
        XCTAssertEqual(answers["equipment"] as? [String], ["bodyweight", "rings"])
        XCTAssertEqual(answers["bedtime"] as? String, "22:45")
        XCTAssertEqual(answers["wakeTime"] as? String, "06:15")
        XCTAssertEqual((answers["manualTargets"] as? [String: Any])?["calories"] as? Double, 2310)
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["Finish setup"].waitForExistence(timeout: 15))
        capture(app, "setup-native-draft-reopened")
        _ = try await request("POST", "/__test/setup-roundtrip", body: ["email": email, "phase": "native-draft"])
    }

    func testBrowserSetupCompletionReturnsToNative() async throws {
        let fixture = try await request("GET", "/__test/setup-roundtrip")
        guard fixture["phase"] as? String == "browser-complete" else { throw XCTSkip("Requires browser completion in the shared setup fixture") }
        try await control([:])
        let email = try XCTUnwrap(fixture["email"] as? String)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Finish setup"].exists)
        XCTAssertFalse(app.staticTexts["NO TARGET"].exists)
        capture(app, "setup-browser-completion-native-diary")
        let login = try await request("POST", "/login", body: ["email": email, "password": "Simulator-Test-123!"])
        let token = try XCTUnwrap(login["token"] as? String)
        let bootstrap = try await request("GET", "/api/bootstrap", token: token)
        XCTAssertEqual((bootstrap["onboarding"] as? [String: Any])?["complete"] as? Bool, true)
        XCTAssertEqual((bootstrap["targets"] as? [String: Any])?["calories"] as? Double, 2310)
        let exported = try await request("GET", "/api/export", token: token)
        XCTAssertEqual((exported["weights"] as? [[String: Any]])?.count, 1)
        let profile = (exported["account"] as? [String: Any])?["profile"] as? [String: Any]
        XCTAssertEqual(profile?["nutritionGoal"] as? String, "gain")
        XCTAssertEqual(profile?["allergies"] as? [String], ["sesame", "nuts"])
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
    }

    func testActivityAndSleepOfflineRecoveryConflictDeletionAndUndo() async throws {
        try await control([:])
        let email = "daily-logs-\(UUID().uuidString.lowercased())@exerly.test"
        let password = "Simulator-Test-123!"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": password, "name": "Daily Taylor"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Daily Taylor", "age": 34, "gender": "female", "sex": "female",
            "height": 167.5, "weight": 72.25, "goal": "maintain", "activityLevel": "light",
            "unitSystem": "metric", "timezone": TimeZone.current.identifier,
        ], token: token)
        let date = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: date)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: password, in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        try await control(["offline": true])
        for _ in 0..<3 { tap(app.buttons["Previous day"], in: app) }
        XCTAssertEqual(app.staticTexts["diary.selected-day"].value as? String, day)
        tap(app.buttons["Log activity"], in: app)
        replace(app.textFields["activity.name"], with: "Walk", in: app)
        replace(app.textFields["activity.minutes"], with: "30.25", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Save activity"], in: app)
        for hours in ["7.25", "0.5"] {
            tap(app.buttons["Log sleep"], in: app)
            replace(app.textFields["sleep.hours"], with: hours, in: app)
            if hours == "7.25" {
                replace(app.textFields["sleep.bedtime"], with: "23:00", in: app)
                replace(app.textFields["sleep.wake-time"], with: "06:15", in: app)
            }
            dismissKeyboard(app)
            tap(app.buttons["Save sleep"], in: app)
        }
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        for _ in 0..<3 { tap(app.buttons["Previous day"], in: app) }
        tap(app.buttons["Edit activity Walk"], in: app)
        XCTAssertEqual(app.textFields["activity.minutes"].value as? String, "30.25")
        capture(app, "activity-offline-reopened")
        tap(app.buttons["Cancel"], in: app)
        tap(app.buttons["Edit sleep entry, 7.25 hours"], in: app)
        XCTAssertEqual(app.textFields["sleep.hours"].value as? String, "7.25")
        XCTAssertEqual(app.textFields["sleep.bedtime"].value as? String, "23:00")
        capture(app, "sleep-offline-reopened")
        tap(app.buttons["Cancel"], in: app)
        app.terminate()
        try await control([:])
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        var summary: [String: Any] = [:]
        for _ in 0..<20 {
            summary = try await request("GET", "/api/summary?entry_date=\(day)", token: token)
            if summary["entry_count"] as? Int == 3 { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(summary["entry_count"] as? Int, 3)
        XCTAssertEqual(summary["sleep_hours"] as? Double, 7.75)
        let activity = try XCTUnwrap((summary["activities"] as? [[String: Any]])?.first)
        let activityID = try XCTUnwrap(activity["id"] as? String)
        XCTAssertEqual(activity["duration_min"] as? Double, 30.25)
        XCTAssertTrue(activity["calories"] is NSNull)
        for _ in 0..<3 { tap(app.buttons["Previous day"], in: app) }
        tap(app.buttons["Edit activity Walk"], in: app)
        replace(app.textFields["activity.minutes"], with: "45..5", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Save activity"], in: app)
        let validation = app.staticTexts["Enter the activity duration in minutes."]
        reveal(validation, in: app)
        XCTAssertTrue(validation.exists)
        replace(app.textFields["activity.minutes"], with: "45.5", in: app)
        replace(app.textFields["activity.calories"], with: "0", in: app)
        dismissKeyboard(app)
        _ = try await request("PUT", "/api/activities/\(activityID)", body: ["activity": "Walk", "duration_min": 40, "base_revision": 1], token: token)
        tap(app.buttons["Save activity"], in: app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Review changes"], in: app)
        tap(app.buttons["Walk"], in: app)
        capture(app, "activity-conflict-review")
        tap(app.buttons["Save my changes"], in: app)
        var saved: [String: Any] = [:]
        for _ in 0..<20 {
            saved = try await request("GET", "/api/activities/\(activityID)", token: token)
            if saved["revision"] as? Int == 3 { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(saved["duration_min"] as? Double, 45.5)
        XCTAssertEqual(saved["calories"] as? Double, 0)
        app.terminate(); app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        for _ in 0..<3 { tap(app.buttons["Previous day"], in: app) }
        tap(app.buttons["Edit activity Walk"], in: app)
        tap(app.buttons["Delete activity"], in: app)
        XCTAssertTrue(app.alerts["Delete this activity?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete activity"].tap()
        for _ in 0..<20 {
            saved = try await request("GET", "/api/activities/\(activityID)?include_deleted=true", token: token)
            if saved["deleted_at"] is String { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(saved["revision"] as? Int, 4)
        tap(app.buttons["Undo activity deletion"], in: app)
        for _ in 0..<20 {
            saved = try await request("GET", "/api/activities/\(activityID)?include_deleted=true", token: token)
            if saved["revision"] as? Int == 5 { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(saved["revision"] as? Int, 5)
        XCTAssertFalse(saved["deleted_at"] is String)
        tap(app.buttons["Edit sleep entry, 7.25 hours"], in: app)
        replace(app.textFields["sleep.hours"], with: "8.25", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Save sleep"], in: app)
        tap(app.buttons["Edit sleep entry, 8.25 hours"], in: app)
        tap(app.buttons["Delete sleep entry"], in: app)
        XCTAssertTrue(app.alerts["Delete this sleep entry?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete sleep entry"].tap()
        for _ in 0..<20 {
            summary = try await request("GET", "/api/summary?entry_date=\(day)", token: token)
            if summary["sleep_hours"] as? Double == 0.5 { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(summary["sleep_hours"] as? Double, 0.5)
        tap(app.buttons["Undo sleep deletion"], in: app)
        for _ in 0..<20 {
            summary = try await request("GET", "/api/summary?entry_date=\(day)", token: token)
            if summary["sleep_hours"] as? Double == 8.75 { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(summary["sleep_hours"] as? Double, 8.75)
        let exported = try await request("GET", "/api/export", token: token)
        let activities = try XCTUnwrap(exported["activities"] as? [[String: Any]])
        let sleep = try XCTUnwrap(exported["sleep"] as? [[String: Any]])
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities.first?["id"] as? String, activityID)
        XCTAssertEqual(activities.first?["revision"] as? Int, 5)
        XCTAssertEqual(sleep.count, 2)
        XCTAssertEqual(sleep.first { $0["hours"] as? Double == 8.25 }?["revision"] as? Int, 4)
        let today = try await request("GET", "/api/summary", token: token)
        XCTAssertEqual(today["entry_count"] as? Int, 0)
        reveal(app.buttons["Edit sleep entry, 8.25 hours"], in: app)
        capture(app, "activity-sleep-synchronized-undo")
    }

    func testActivityAndSleepWebChangesReturnToNative() async throws {
        let proof = try await request("GET", "/__test/daily-logs-roundtrip")
        try XCTSkipUnless(proof["ready"] as? Bool == true, "Run scripts/test-cross-client.sh to exercise the shared native/browser account")
        let email = try XCTUnwrap(proof["email"] as? String)
        let activityID = try XCTUnwrap(proof["activityID"] as? String)
        let sleepID = try XCTUnwrap(proof["sleepID"] as? String)
        let day = try XCTUnwrap(proof["day"] as? String)
        let login = try await request("POST", "/login", body: ["email": email, "password": "Simulator-Test-123!"])
        let token = try XCTUnwrap(login["token"] as? String)
        let activity = try await request("GET", "/api/activities/\(activityID)", token: token)
        let sleep = try await request("GET", "/api/sleep/\(sleepID)", token: token)
        XCTAssertEqual(activity["duration_min"] as? Double, 63.25)
        XCTAssertEqual(activity["revision"] as? Int, 6)
        XCTAssertTrue(activity["calories"] is NSNull)
        XCTAssertEqual(sleep["hours"] as? Double, 8.75)
        XCTAssertEqual(sleep["quality"] as? String, "good")
        XCTAssertEqual(sleep["revision"] as? Int, 5)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let date = try XCTUnwrap(formatter.date(from: day))
        let days = Calendar.current.dateComponents([.day], from: date, to: Calendar.current.startOfDay(for: Date())).day ?? 0
        for _ in 0..<days { tap(app.buttons["Previous day"], in: app) }
        tap(app.buttons["Edit activity Walk"], in: app)
        XCTAssertEqual(app.textFields["activity.minutes"].value as? String, "63.25")
        capture(app, "activity-browser-return")
        tap(app.buttons["Cancel"], in: app)
        tap(app.buttons["Edit sleep entry, 8.75 hours"], in: app)
        XCTAssertEqual(app.textFields["sleep.hours"].value as? String, "8.75")
        XCTAssertEqual(app.textFields["sleep.bedtime"].value as? String, "23:00")
        capture(app, "sleep-browser-return")
        tap(app.buttons["Cancel"], in: app)
        reveal(app.buttons["Edit sleep entry, 0.5 hours"], in: app)
        XCTAssertTrue(app.buttons["Edit sleep entry, 0.5 hours"].exists)
        let summary = try await request("GET", "/api/summary?entry_date=\(day)", token: token)
        XCTAssertEqual(summary["sleep_hours"] as? Double, 9.25)
    }

    func testBodyMeasurementOfflineRecoveryAndSynchronizedUndo() async throws {
        try await control([:])
        let email = "measurement-\(UUID().uuidString.lowercased())@exerly.test"
        let password = "Simulator-Test-123!"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": password, "name": "Measurement Taylor"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Measurement Taylor", "age": 34, "gender": "female", "sex": "female",
            "height": 167.5, "weight": 72.25, "goal": "maintain", "activityLevel": "light",
            "unitSystem": "metric", "timezone": TimeZone.current.identifier,
        ], token: token)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: password, in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Progress"], in: app)
        tap(app.buttons["Add measurement"], in: app)
        tap(app.buttons["measurement.type"], in: app)
        tap(app.buttons["Waist"], in: app)
        replace(app.textFields["Value (cm)"], with: "82.55", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Save"], in: app)
        tap(app.buttons["Edit waist measurement"], in: app)
        XCTAssertEqual(app.textFields["Value (cm)"].value as? String, "82.55")
        try await control(["offline": true])
        replace(app.textFields["Value (cm)"], with: "81.25", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Save"], in: app)
        capture(app, "measurement-offline-edit")
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Progress"], in: app)
        tap(app.buttons["Edit waist measurement"], in: app)
        XCTAssertEqual(app.textFields["Value (cm)"].value as? String, "81.25")
        tap(app.buttons["Cancel"], in: app)
        try await control([:])
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Progress"], in: app)
        tap(app.buttons["Edit waist measurement"], in: app)
        XCTAssertEqual(app.textFields["Value (cm)"].value as? String, "81.25")
        let synced = try await request("GET", "/api/measurements", token: token)
        let records = try XCTUnwrap(synced["entries"] as? [[String: Any]])
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?["value"] as? Double, 81.25)
        let id = try XCTUnwrap(records.first?["id"] as? String)
        tap(app.buttons["Delete measurement"], in: app)
        var removed = false
        for _ in 0..<15 {
            let result = try await request("GET", "/api/measurements", token: token)
            if result["total"] as? Int == 0 { removed = true; break }
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTAssertTrue(removed, "The deletion must reach the API before exercising undo")
        tap(app.buttons["Undo"], in: app)
        tap(app.buttons["Edit waist measurement"], in: app)
        XCTAssertEqual(app.textFields["Value (cm)"].value as? String, "81.25")
        tap(app.buttons["Cancel"], in: app)
        capture(app, "measurement-synchronized-undo")
        let exported = try await request("GET", "/api/export", token: token)
        let exportedMeasurements = try XCTUnwrap(exported["measurements"] as? [[String: Any]])
        XCTAssertEqual(exportedMeasurements.count, 1)
        XCTAssertEqual(exportedMeasurements.first?["id"] as? String, id)
        XCTAssertEqual(exportedMeasurements.first?["value"] as? Double, 81.25)
    }

    func testBodyMeasurementWebChangesReturnToNative() async throws {
        let proof = try await request("GET", "/__test/measurement-roundtrip")
        try XCTSkipUnless(proof["ready"] as? Bool == true, "Run scripts/test-cross-client.sh to exercise the shared native/browser account")
        let email = try XCTUnwrap(proof["email"] as? String)
        let id = try XCTUnwrap(proof["id"] as? String)
        let login = try await request("POST", "/login", body: ["email": email, "password": "Simulator-Test-123!"])
        let token = try XCTUnwrap(login["token"] as? String)
        let result = try await request("GET", "/api/measurements", token: token)
        let rows = try XCTUnwrap(result["entries"] as? [[String: Any]])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first { $0["id"] as? String == id }?["value"] as? Double, 80.5)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Progress"], in: app)
        tap(app.buttons["Edit waist measurement"], in: app)
        XCTAssertEqual(app.textFields["Value (cm)"].value as? String, "80.5")
        tap(app.buttons["Cancel"], in: app)
        tap(app.buttons["Edit arms measurement"], in: app)
        XCTAssertEqual(app.textFields["Value (cm)"].value as? String, "31.75")
        tap(app.buttons["Cancel"], in: app)
        capture(app, "measurement-browser-return")
    }

    func testWeightOfflineRecoveryConflictReviewDeletionAndUndo() async throws {
        try await control([:])
        let email = "weight-\(UUID().uuidString.lowercased())@exerly.test"
        let password = "Simulator-Test-123!"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": password, "name": "Weight Taylor"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Weight Taylor", "age": 34, "gender": "female", "sex": "female",
            "height": 167.5, "weight": 72.25, "goal": "maintain", "activityLevel": "light",
            "unitSystem": "metric", "timezone": TimeZone.current.identifier,
        ], token: token)
        let original = try await request("GET", "/api/weight/day", token: token)
        let id = try XCTUnwrap(original["id"] as? String)
        let day = try XCTUnwrap(original["entry_date"] as? String)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: password, in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Log weight"], in: app)
        let field = app.textFields["weight.value"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "72.25")
        try await control(["offline": true])
        replace(field, with: "73.25", in: app)
        replace(app.descendants(matching: .any).matching(identifier: "weight.note").firstMatch, with: "Morning reading", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Save weight"], in: app)
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Log weight"], in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "73.25")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "weight.note").firstMatch.value as? String, "Morning reading")
        capture(app, "weight-offline-reopened")
        app.terminate()
        try await control([:])
        _ = try await request("PUT", "/api/weight/day", body: ["weight_kg": 75, "base_revision": 1, "note": "Other device"], token: token)
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Review changes"], in: app)
        tap(app.buttons["Weight · \(day)"], in: app)
        XCTAssertTrue(app.staticTexts["Other device"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Morning reading"].exists)
        capture(app, "weight-conflict-review")
        tap(app.buttons["Save my changes"], in: app)
        var saved: [String: Any] = [:]
        for _ in 0..<20 {
            saved = try await request("GET", "/api/weight/day", token: token)
            if saved["revision"] as? Int == 3 { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(saved["weight_kg"] as? Double, 73.25)
        XCTAssertEqual(saved["revision"] as? Int, 3)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Log weight"], in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "73.25")
        tap(app.buttons["Delete weight reading"], in: app)
        XCTAssertTrue(app.alerts["Delete this weight reading?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete reading"].tap()
        var deleted: [String: Any] = [:]
        for _ in 0..<20 {
            deleted = try await request("GET", "/api/weight/day", token: token)
            if deleted["deleted_at"] is String { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertTrue(deleted["deleted_at"] is String)
        XCTAssertEqual(deleted["revision"] as? Int, 4)
        tap(app.buttons["Log weight"], in: app)
        XCTAssertTrue(app.buttons["Restore weight reading"].waitForExistence(timeout: 10))
        capture(app, "weight-deleted-reading")
        tap(app.buttons["Cancel"], in: app)
        tap(app.buttons["Undo weight deletion"], in: app)
        var restored: [String: Any] = [:]
        for _ in 0..<20 {
            restored = try await request("GET", "/api/weight/day", token: token)
            if restored["revision"] as? Int == 5 { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(restored["id"] as? String, id)
        XCTAssertEqual(restored["revision"] as? Int, 5)
        XCTAssertFalse(restored["deleted_at"] is String)
        let exported = try await request("GET", "/api/export", token: token)
        let weights = try XCTUnwrap(exported["weights"] as? [[String: Any]])
        XCTAssertEqual(weights.count, 1)
        XCTAssertEqual(weights.first?["weight_kg"] as? Double, 73.25)
        tap(app.buttons["Progress"], in: app)
        tap(app.buttons["Edit weight for \(day)"], in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "73.25")
        capture(app, "weight-synchronized-undo")
    }

    func testWeightWebChangesReturnToNative() async throws {
        let proof = try await request("GET", "/__test/weight-roundtrip")
        try XCTSkipUnless(proof["ready"] as? Bool == true, "Run scripts/test-cross-client.sh to exercise the shared native/browser account")
        let email = try XCTUnwrap(proof["email"] as? String)
        let day = try XCTUnwrap(proof["day"] as? String)
        let login = try await request("POST", "/login", body: ["email": email, "password": "Simulator-Test-123!"])
        let token = try XCTUnwrap(login["token"] as? String)
        let reading = try await request("GET", "/api/weight/day?entry_date=\(day)", token: token)
        XCTAssertEqual(reading["id"] as? String, proof["id"] as? String)
        XCTAssertEqual(reading["revision"] as? Int, 11)
        XCTAssertEqual(reading["weight_kg"] as? Double, 72.8)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Log weight"], in: app)
        XCTAssertTrue(app.textFields["weight.value"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["weight.value"].value as? String, "72.8")
        capture(app, "weight-browser-return")
        tap(app.buttons["Cancel"], in: app)
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["Log weight"], in: app)
        XCTAssertTrue(app.textFields["weight.value"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["weight.value"].value as? String, "74.25")
    }

    func testWaterAdditionsSurviveOfflineRelaunchAndMergeWithAnotherDevice() async throws {
        try await control([:])
        let email = "water-\(UUID().uuidString.lowercased())@exerly.test"
        let password = "Simulator-Test-123!"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": password, "name": "Water Taylor"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Water Taylor", "age": 34, "gender": "female", "sex": "female",
            "height": 167.5, "weight": 72.25, "goal": "maintain", "activityLevel": "light",
            "unitSystem": "metric", "timezone": TimeZone.current.identifier,
        ], token: token)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        _ = try await request("POST", "/api/water", body: ["entry_date": yesterday, "ml": 100], token: token)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: password, in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        let total = app.staticTexts["water.total"]
        reveal(total, in: app)
        XCTAssertEqual(total.label, "100 ml")
        try await control(["offline": true])
        tap(app.buttons["Add 250 ml of water"], in: app)
        tap(app.buttons["Add a custom water amount"], in: app)
        replace(app.textFields["water.amount"], with: "5001", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Save water"], in: app)
        XCTAssertTrue(app.staticTexts["Enter a whole number from 1 to 5,000 ml."].exists)
        replace(app.textFields["water.amount"], with: "500", in: app)
        dismissKeyboard(app)
        XCTAssertFalse(app.staticTexts["Enter a whole number from 1 to 5,000 ml."].exists)
        capture(app, "water-custom-amount")
        tap(app.buttons["Save water"], in: app)
        reveal(total, in: app)
        XCTAssertEqual(total.label, "850 ml")
        reveal(app.buttons["Add a custom water amount"], in: app)
        capture(app, "water-offline-additions")
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        reveal(total, in: app)
        XCTAssertEqual(total.label, "850 ml")
        app.terminate()
        try await control([:])
        _ = try await request("POST", "/api/water", body: ["entry_date": yesterday, "deltaMl": 300], token: token)
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        reveal(total, in: app)
        for _ in 0..<20 {
            if total.label == "1,150 ml" { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTAssertEqual(total.label, "1,150 ml")
        let saved = try await request("GET", "/api/water?entry_date=\(yesterday)", token: token)
        XCTAssertEqual(saved["ml"] as? Int, 1150)
        XCTAssertEqual(saved["revision"] as? Int, 4)
        let today = try await request("GET", "/api/water", token: token)
        XCTAssertEqual(today["ml"] as? Int, 0)
        let exported = try await request("GET", "/api/export", token: token)
        let water = try XCTUnwrap(exported["water"] as? [[String: Any]])
        XCTAssertEqual(water.count, 1)
        XCTAssertEqual(water.first?["ml"] as? Int, 1150)
        reveal(app.buttons["Add a custom water amount"], in: app)
        capture(app, "water-synchronized-additions")
    }

    func testDiaryLoggingStatusSurvivesOfflineRelaunchAndReconnection() async throws {
        try await control([:])
        let email = "diary-\(UUID().uuidString.lowercased())@exerly.test"
        let password = "Simulator-Test-123!"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": password, "name": "Diary Taylor"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Diary Taylor", "age": 34, "gender": "female", "sex": "female",
            "height": 167.5, "weight": 72.25, "goal": "maintain", "activityLevel": "light",
            "unitSystem": "metric", "timezone": TimeZone.current.identifier,
        ], token: token)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: password, in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["Edit logging status"], in: app)
        tap(app.buttons["diary.status-picker"], in: app)
        tap(app.buttons["Complete"], in: app)
        let note = app.descendants(matching: .any).matching(identifier: "diary.note").firstMatch
        replace(note, with: "All meals recorded", in: app)
        dismissKeyboard(app)
        try await control(["offline": true])
        tap(app.buttons["Save status"], in: app)
        reveal(app.staticTexts["All meals recorded"], in: app)
        XCTAssertTrue(app.staticTexts["All meals recorded"].waitForExistence(timeout: 5))
        capture(app, "diary-status-offline")
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["Edit logging status"], in: app)
        XCTAssertEqual(note.value as? String, "All meals recorded")
        tap(app.buttons["Cancel"], in: app)
        try await control([:])
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["Edit logging status"], in: app)
        XCTAssertEqual(note.value as? String, "All meals recorded")
        tap(app.buttons["Cancel"], in: app)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        let saved = try await request("GET", "/api/diary/day?entry_date=\(yesterday)", token: token)
        XCTAssertEqual(saved["status"] as? String, "complete")
        XCTAssertEqual(saved["revision"] as? Int, 1)
        let today = try await request("GET", "/api/diary/day", token: token)
        XCTAssertEqual(today["status"] as? String, "in_progress")
        capture(app, "diary-status-synchronized")
    }

    func testLegacyAccountRepairKeepsKnownAnswersAndDoesNotCreateAWeighIn() async throws {
        try await control([:])
        let email = "repair-\(UUID().uuidString.lowercased())@exerly.test"
        let password = "Simulator-Test-123!"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": password, "name": "Repair Taylor"])
        let token = try XCTUnwrap(signup["token"] as? String)
        try await control(["repairLegacyEmail": email])
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: password, in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.staticTexts["Repair 1 of 2"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Activity Level"].exists)
        XCTAssertFalse(app.textFields["Your name"].exists)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Lightly Active")).firstMatch, in: app)
        capture(app, "legacy-repair-missing-activity")
        tap(app.buttons["Continue"], in: app)
        XCTAssertTrue(app.buttons["Finish setup"].waitForExistence(timeout: 10))
        capture(app, "legacy-repair-target-review")
        tap(app.buttons["Finish setup"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        let bootstrap = try await request("GET", "/api/bootstrap", token: token)
        let account = try XCTUnwrap(bootstrap["account"] as? [String: Any])
        XCTAssertEqual(account["weight"] as? Double, 72.25)
        XCTAssertEqual(account["height"] as? Double, 167.5)
        XCTAssertEqual(account["age"] as? Int, 34)
        XCTAssertEqual((bootstrap["onboarding"] as? [String: Any])?["complete"] as? Bool, true)
        let trend = try await request("GET", "/api/weight/trend", token: token)
        XCTAssertTrue((trend["series"] as? [[String: Any]] ?? []).allSatisfy { $0["weight"] == nil || $0["weight"] is NSNull })
    }

    func testSignupInterruptedSetupBarcodeAndOfflineRelaunch() async throws {
        try await control([:])
        let app = launch(resetSession: true)
        let email = "simulator-\(UUID().uuidString.lowercased())@exerly.test"
        let password = "Simulator-Test-123!"
        tap(app.buttons["Get Started"], in: app)
        replace(app.textFields["Full Name"], with: "Simulator Taylor", in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: password, in: app)
        dismissKeyboard(app)
        tap(app.buttons["I agree to the Terms of Service & Privacy Policy"], in: app)
        tap(app.buttons["Create Account"], in: app)
        XCTAssertTrue(app.textFields["Your name"].waitForExistence(timeout: 15))
        tap(app.buttons["Metric"], in: app)
        tap(app.buttons["Continue"], in: app)
        replace(app.textFields["Height, cm"], with: "178.5", in: app)
        replace(app.textFields["Weight, kg"], with: "82.5", in: app)
        dismissKeyboard(app)
        let formula = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Formula parameter")).firstMatch
        tap(formula, in: app)
        tap(app.buttons["Male parameter"], in: app)
        capture(app, "setup-answers-before-relaunch")
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.textFields["Height, cm"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.textFields["Height, cm"].value as? String, "178.5")
        XCTAssertEqual(app.textFields["Weight, kg"].value as? String, "82.5")
        tap(app.buttons["Continue"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Lose Weight")).firstMatch, in: app)
        replace(app.textFields["Target weight"], with: "78", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Continue"], in: app)
        tap(app.buttons["Continue"], in: app)
        XCTAssertTrue(app.staticTexts["Review your targets"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Finish setup"].waitForExistence(timeout: 10))
        capture(app, "setup-target-review")
        try await control(["dropSetupAcknowledgement": true])
        tap(app.buttons["Finish setup"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["NO TARGET"].exists)
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["diary.add.dinner"], in: app)
        tap(app.buttons["Scan food barcode"], in: app)
        replace(app.textFields["barcode.digits"], with: "0036000291452", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Look up barcode"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Simulator oat drink")).firstMatch, in: app)
        replace(app.textFields["Number of servings"], with: "1.5", in: app)
        dismissKeyboard(app)
        XCTAssertTrue(app.staticTexts["Total: 150 ml"].exists)
        capture(app, "yesterday-dinner-150ml")
        tap(app.buttons["Log Food"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        reveal(app.buttons["Edit Simulator oat drink"], in: app)
        XCTAssertTrue(app.buttons["Edit Simulator oat drink"].exists)
        capture(app, "yesterday-dinner-logged")

        let login = try await request("POST", "/login", body: ["email": email, "password": password])
        let token = try XCTUnwrap(login["token"] as? String)
        let bootstrap = try await request("GET", "/api/bootstrap", token: token)
        let status = try XCTUnwrap(bootstrap["onboarding"] as? [String: Any])
        XCTAssertEqual(status["complete"] as? Bool, true)
        let program = try await request("GET", "/api/program", token: token)
        XCTAssertEqual(program["goal_type"] as? String, "lose")
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: yesterday)
        let summary = try await request("GET", "/api/summary?entry_date=\(day)", token: token)
        let meals = try XCTUnwrap(summary["meals"] as? [String: Any])
        let dinner = try XCTUnwrap(meals["dinner"] as? [String: Any])
        let entries = try XCTUnwrap(dinner["entries"] as? [[String: Any]])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?["servings"] as? Double, 1.5)
        XCTAssertEqual(entries.first?["calories"] as? Double, 90)
        XCTAssertEqual(entries.first?["sodium"] as? Double, 60)
        XCTAssertEqual((entries.first?["nutrition_basis"] as? [String: Any])?["unit"] as? String, "ml")

        tap(app.buttons["Edit Simulator oat drink"], in: app)
        replace(app.textFields["Number of servings"], with: "0.75", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Save changes"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))

        try await control(["offline": true])
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Offline. Showing saved account data."].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Get Started"].exists)
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["Edit Simulator oat drink"], in: app)
        XCTAssertEqual(app.textFields["Number of servings"].value as? String, "0.75")
        replace(app.textFields["Number of servings"], with: "0.5", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Save changes"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["Edit Simulator oat drink"], in: app)
        XCTAssertEqual(app.textFields["Number of servings"].value as? String, "0.5")
        tap(app.buttons["Cancel"], in: app)
        capture(app, "offline-session-preserved")
        try await control([:])
        tap(app.buttons["Retry"].firstMatch, in: app)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        reveal(app.buttons["Edit Simulator oat drink"], in: app)
        XCTAssertTrue(app.buttons["Edit Simulator oat drink"].exists)
        capture(app, "reconnected-diary")
        let synced = try await request("GET", "/api/summary?entry_date=\(day)", token: token)
        let syncedDinner = ((synced["meals"] as? [String: Any])?["dinner"] as? [String: Any])?["entries"] as? [[String: Any]]
        XCTAssertEqual(syncedDinner?.count, 1)
        XCTAssertEqual(syncedDinner?.first?["id"] as? String, entries.first?["id"] as? String)
        XCTAssertEqual(syncedDinner?.first?["calories"] as? Int, 30)
    }

    func testLegacySessionUpgradeRecoversALostResponseAndKeepsOfflineAccount() async throws {
        try await control([:])
        let email = "legacy-session-\(UUID().uuidString.lowercased())@exerly.test"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": "Simulator-Test-123!", "name": "Legacy Taylor"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Legacy Taylor", "age": 34, "gender": "female", "sex": "female", "height": 167.75, "weight": 72.25,
            "goal": "maintain", "activityLevel": "light", "unitSystem": "metric", "timezone": "America/New_York"
        ], token: token)
        let legacy = try await request("POST", "/__test/legacy-session", body: ["email": email])
        try await control(["dropSessionUpgradeAcknowledgement": true])
        let app = launch(resetSession: true, legacyToken: try XCTUnwrap(legacy["token"] as? String))
        XCTAssertTrue(app.staticTexts["Connection unavailable"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Try again"].exists)
        capture(app, "legacy-session-upgrade-response-lost")
        app.terminate()
        app.launchArguments = []
        app.launchEnvironment.removeValue(forKey: "EXERLY_TEST_LEGACY_TOKEN")
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20), app.debugDescription)
        openPreferences(app)
        XCTAssertEqual(app.textFields["preferences.name"].value as? String, "Legacy Taylor")
        replace(app.textFields["preferences.name"], with: "Upgraded Taylor", in: app)
        dismissKeyboard(app)
        tap(app.buttons["preferences.save"], in: app)
        XCTAssertTrue(app.staticTexts["Preferences saved."].waitForExistence(timeout: 15), app.debugDescription)
        let saved = try await request("GET", "/api/preferences", token: token)
        XCTAssertEqual((saved["values"] as? [String: Any])?["name"] as? String, "Upgraded Taylor")
        capture(app, "legacy-session-upgrade-saved-preferences")
        try await control(["offline": true])
        app.terminate(); app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Offline. Showing saved account data."].waitForExistence(timeout: 15))
        capture(app, "legacy-session-upgrade-offline-relaunch")
        try await control([:])
        app.terminate(); app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        let stats = try await request("GET", "/__test/session-upgrades?email=\(email)")
        let attempts = try XCTUnwrap(stats["attempts"] as? [[String: Any]])
        XCTAssertEqual(attempts.count, 2)
        XCTAssertEqual(attempts.first?["operation"] as? String, attempts.last?["operation"] as? String)
        XCTAssertNotNil(attempts.first?["operation"] as? String)
        XCTAssertEqual(stats["count"] as? Int, 2, "The signup and the single recovered upgrade are the only server sessions")
    }

    func testPreferencesDraftRecoveryLostResponseAndReviewedConflict() async throws {
        try await control([:])
        let email = "preferences-cross-\(UUID().uuidString.lowercased())@exerly.test"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": "Simulator-Test-123!", "name": "Preference Taylor"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Preference Taylor", "age": 34, "gender": "nonbinary", "sex": "female", "height": 167.75, "weight": 72.25,
            "goal": "gain_muscle", "nutritionGoal": "maintain", "activityLevel": "light", "unitSystem": "metric", "timezone": "America/New_York",
            "allergies": ["sesame", "nuts"], "equipment": ["rings"], "bedtime": "22:45", "wakeTime": "06:15", "sleepGoalHours": 7.25
        ], token: token)
        let before = try await request("GET", "/api/export", token: token)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        openPreferences(app)
        replace(app.textFields["preferences.name"], with: "Native Preference Taylor", in: app)
        dismissKeyboard(app)
        for _ in 0..<2 {
            tap(app.buttons["preferences.unitSystem"], in: app)
            tap(app.buttons["Imperial, lb and inches"], in: app)
            tap(app.buttons["preferences.unitSystem"], in: app)
            tap(app.buttons["Metric, kg and cm"], in: app)
        }
        XCTAssertEqual(app.textFields["preferences.height"].value as? String, "167.75")
        tap(app.buttons["Food preferences"], in: app)
        replace(app.textFields["preferences.dietaryStyle"], with: "Mediterranean", in: app)
        dismissKeyboard(app)
        let allergies = app.descendants(matching: .any).matching(identifier: "preferences.allergies").firstMatch
        reveal(allergies, in: app)
        XCTAssertEqual(allergies.value as? String, "sesame\nnuts")
        capture(app, "preferences-native-food-draft")
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        openPreferences(app)
        XCTAssertEqual(app.textFields["preferences.name"].value as? String, "Native Preference Taylor")
        capture(app, "preferences-native-draft-reopened")
        try await control(["dropPreferencesAcknowledgement": true])
        tap(app.buttons["preferences.save"], in: app)
        XCTAssertTrue(app.buttons["Retry save"].waitForExistence(timeout: 15))
        let committed = try await request("GET", "/api/preferences", token: token)
        XCTAssertEqual((committed["values"] as? [String: Any])?["name"] as? String, "Native Preference Taylor")
        _ = try await request("PATCH", "/api/preferences", body: ["base_revision": committed["revision"]!, "changes": ["dietaryStyle": "Pescatarian", "experienceLevel": "advanced"]], token: token)
        app.terminate(); app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        openPreferences(app)
        XCTAssertTrue(app.buttons["Save preferences"].waitForExistence(timeout: 15))
        replace(app.textFields["preferences.name"], with: "Native Reviewed Taylor", in: app)
        dismissKeyboard(app)
        let remote = try await request("GET", "/api/preferences", token: token)
        _ = try await request("PATCH", "/api/preferences", body: ["base_revision": remote["revision"]!, "changes": ["name": "Other Device Taylor", "sleepGoalHours": 8.25]], token: token)
        tap(app.buttons["preferences.save"], in: app)
        XCTAssertTrue(app.buttons["Save my edits"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Your edit: Native Reviewed Taylor"].exists)
        XCTAssertTrue(app.staticTexts["Saved on account: Other Device Taylor"].exists)
        capture(app, "preferences-native-conflict")
        tap(app.buttons["Save my edits"], in: app)
        tap(app.buttons["Save reviewed edits"], in: app)
        XCTAssertTrue(app.staticTexts["Preferences saved."].waitForExistence(timeout: 15))
        tap(app.buttons["Sleep preferences"], in: app)
        reveal(app.textFields["preferences.sleepGoalHours"], in: app)
        XCTAssertEqual(app.textFields["preferences.sleepGoalHours"].value as? String, "8.25")
        XCTAssertEqual(app.textFields["preferences.bedtime"].value as? String, "22:45")
        capture(app, "preferences-native-saved-sleep")
        let final = try await request("GET", "/api/preferences", token: token)
        let values = try XCTUnwrap(final["values"] as? [String: Any])
        XCTAssertEqual(values["name"] as? String, "Native Reviewed Taylor")
        XCTAssertEqual(values["dietaryStyle"] as? String, "Pescatarian")
        XCTAssertEqual(values["height"] as? Double, 167.75)
        XCTAssertEqual(values["experienceLevel"] as? String, "advanced")
        XCTAssertEqual(values["allergies"] as? [String], ["sesame", "nuts"])
        let after = try await request("GET", "/api/export", token: token)
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: before["weights"]!, options: .sortedKeys), try JSONSerialization.data(withJSONObject: after["weights"]!, options: .sortedKeys))
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: before["program"]!, options: .sortedKeys), try JSONSerialization.data(withJSONObject: after["program"]!, options: .sortedKeys))
        _ = try await request("POST", "/__test/preferences-roundtrip", body: ["email": email, "phase": "native-saved"])
    }

    func testBrowserPreferencesReturnToNative() async throws {
        let fixture = try await request("GET", "/__test/preferences-roundtrip")
        guard fixture["phase"] as? String == "browser-saved" else { throw XCTSkip("Requires the shared browser preferences fixture") }
        try await control([:])
        let email = try XCTUnwrap(fixture["email"] as? String)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        openPreferences(app)
        XCTAssertEqual(app.textFields["preferences.name"].value as? String, "Browser Preference Taylor")
        tap(app.buttons["Sleep preferences"], in: app)
        reveal(app.textFields["preferences.sleepGoalHours"], in: app)
        XCTAssertEqual(app.textFields["preferences.sleepGoalHours"].value as? String, "7.75")
        XCTAssertEqual(app.textFields["preferences.bedtime"].value as? String, "22:15")
        capture(app, "preferences-browser-to-native")
        tap(app.buttons["Reminder preferences"], in: app)
        reveal(app.textFields["preferences.reminderTimes.sleep"], in: app)
        XCTAssertEqual(app.textFields["preferences.reminderTimes.sleep"].value as? String, "22:00")
        capture(app, "preferences-shared-reminder-intent")
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        openPreferences(app)
        XCTAssertEqual(app.textFields["preferences.name"].value as? String, "Browser Preference Taylor")
    }

    func testReminderDeviceDeliverySchedulesCancelsAndSurvivesRelaunch() async throws {
        try await control([:])
        let email = "reminder-device-\(UUID().uuidString.lowercased())@exerly.test"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": "Simulator-Test-123!", "name": "Reminder Taylor"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Reminder Taylor", "age": 34, "gender": "female", "height": 167.75, "weight": 72.25,
            "goal": "maintain", "activityLevel": "light", "timezone": "America/New_York", "unitSystem": "metric"
        ], token: token)
        let initial = try await request("GET", "/api/preferences", token: token)
        _ = try await request("PATCH", "/api/preferences", body: [
            "base_revision": initial["revision"]!, "changes": ["reminders": ["sleep": true], "reminderTimes": ["sleep": "22:00"]]
        ], token: token)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        openPreferences(app)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "Loading saved reminder intent must not request OS permission")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let due = calendar.dateComponents([.hour, .minute], from: Date().addingTimeInterval(130))
        let dueTime = String(format: "%02d:%02d", due.hour!, due.minute!)
        let current = try await request("GET", "/api/preferences", token: token)
        _ = try await request("PATCH", "/api/preferences", body: [
            "base_revision": current["revision"]!, "changes": ["timezone": "UTC", "reminderTimes": ["sleep": dueTime]]
        ], token: token)
        tap(app.buttons["Refresh reminder delivery"], in: app)
        let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["Enable reminders on this iPhone"])
        await fulfillment(of: [ready], timeout: 15)
        tap(app.buttons["Enable reminders on this iPhone"], in: app)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 5) {
            springboard.alerts.buttons["Allow"].tap()
        }
        reveal(app.staticTexts["preferences.scheduled-reminders"], in: app)
        XCTAssertTrue(app.staticTexts["1 reminder scheduled"].waitForExistence(timeout: 15))
        capture(app, "reminder-device-scheduled")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(springboard.staticTexts["Sleep reminder"].firstMatch.waitForExistence(timeout: 150), springboard.debugDescription)
        capture(springboard, "reminder-delivered-by-ios")
        app.activate()
        let retained = try await request("GET", "/api/preferences", token: token)
        let values = try XCTUnwrap(retained["values"] as? [String: Any])
        XCTAssertEqual((values["reminders"] as? [String: Bool])?["sleep"], true)
        XCTAssertEqual((values["reminderTimes"] as? [String: String])?["sleep"], dueTime)
        tap(app.buttons["Turn off delivery on this iPhone"], in: app)
        XCTAssertTrue(app.staticTexts["Delivery off on this iPhone"].waitForExistence(timeout: 10))
        capture(app, "reminder-device-disabled")
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        openPreferences(app)
        reveal(app.staticTexts["Delivery off on this iPhone"], in: app)
        XCTAssertTrue(app.staticTexts["Delivery off on this iPhone"].exists)
    }

    private func openPreferences(_ app: XCUIApplication) {
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.preferences"], in: app)
        XCTAssertTrue(app.navigationBars["Preferences"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["preferences.name"].waitForExistence(timeout: 15))
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: app.buttons["Refresh preferences"])
        waitForExpectations(timeout: 15)
    }

    private func launch(resetSession: Bool, legacyToken: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = resetSession ? ["--ui-testing"] : []
        app.launchEnvironment["EXERLY_API_BASE_URL"] = fixtureURL
        app.launchEnvironment["EXERLY_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["EXERLY_TEST_LEGACY_TOKEN"] = legacyToken
        app.launch()
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        if !element.exists { _ = element.waitForExistence(timeout: 5) }
        func visibleFrame(_ item: XCUIElement) -> Bool {
            guard item.exists else { return false }
            let frame = item.frame
            return !frame.isEmpty && !frame.isNull && !frame.isInfinite && app.frame.intersects(frame)
        }
        // Virtualized rows and dismissing sheets can expose an accessibility
        // element before it has a usable frame. Asking isHittable then causes
        // XCTest to abort all subsequent event delivery for this test.
        if app.keyboards.firstMatch.exists && (!visibleFrame(element) || !element.isHittable) && app.buttons["Done"].firstMatch.exists {
            app.buttons["Done"].firstMatch.tap()
        }
        for _ in 0..<16 {
            let home = app.buttons["Home"]
            if visibleFrame(element) && element.isHittable && home.exists,
               ["Home", "Library", "Progress", "Profile"].contains(element.label),
               abs(element.frame.midY - home.frame.midY) < 2 { return }
            let lowerEdge = visibleFrame(home) && home.isHittable ? home.frame.minY - 10 : app.frame.height - 30
            let bar = app.navigationBars.allElementsBoundByIndex.last ?? app.navigationBars.firstMatch
            if visibleFrame(element) && element.isHittable && bar.exists,
               app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", element.label)).firstMatch.exists { return }
            let upperEdge = bar.exists ? bar.frame.maxY + 8 : 40
            if visibleFrame(element) && element.frame.midY > upperEdge && element.frame.midY < lowerEdge && element.isHittable { return }
            // A full-screen swipe can jump from below the SE's tab bar to
            // above its navigation bar. Short drags avoid that oscillation.
            let down = element.exists && element.frame.height > 0 && element.frame.midY < upperEdge
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.4 : 0.6))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.6 : 0.4))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
    }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(element.isHittable, app.debugDescription)
        element.tap()
    }
    private func replace(_ field: XCUIElement, with text: String, in app: XCUIApplication) {
        tap(field, in: app)
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count + 3) + text)
        if field.elementType == .textField { XCTAssertEqual(field.value as? String, text) }
    }
    private func dismissKeyboard(_ app: XCUIApplication) {
        if app.buttons["Hide keyboard"].firstMatch.exists { app.buttons["Hide keyboard"].firstMatch.tap() }
        else if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
        else { app.swipeUp() }
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func control(_ body: [String: Any]) async throws {
        _ = try await request("POST", "/__test/control", body: body)
    }
    private func request(_ method: String, _ path: String, body: [String: Any]? = nil, token: String? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: fixtureURL + path)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("isolated-simulator", forHTTPHeaderField: "X-Test-Fixture")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Timezone")
        if method != "GET" { request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertTrue((200..<300).contains((response as! HTTPURLResponse).statusCode), String(data: data, encoding: .utf8) ?? "")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
