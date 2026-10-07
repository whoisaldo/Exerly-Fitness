import XCTest

@MainActor
final class ProductionUITests: XCTestCase {
    private var fixtureURL = ProcessInfo.processInfo.environment["EXERLY_UI_FIXTURE_URL"] ?? "http://127.0.0.1:39001"

    // Let async test bodies finish or throw before XCTest starts the next test.
    // Aborting at an assertion can leave their fixture requests running.
    override func setUpWithError() throws {
        continueAfterFailure = true
        addUIInterruptionMonitor(withDescription: "Password saving") { alert in
            guard alert.label.contains("Save Password"), alert.buttons["Not Now"].exists else { return false }
            alert.buttons["Not Now"].tap()
            return true
        }
    }

    func testDesignPrimaryScreenCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in visual review of primary screens")
        }
        try await control([:])
        let person = try await createAccount(prefix: "design-primary", units: "imperial")
        _ = try await seedNutritionEntry(token: person.token, nutrients: ["energy": 57, "protein": 0.4, "carbohydrate": 15.2, "fat": 0.1, "sodium": 0])
        _ = try await seedProgram(name: "Strength foundations", activated: "2026-10-01T12:00:00.000Z", token: person.token)
        _ = try await seedTrainingWorkout(name: "Full body", loads: [60, 65, 65], daysAgo: 2,
                                           exercises: ["deadlift", "barbell-bench-press"], token: person.token)
        let app = launch(resetSession: true)
        capture(app, "design-01-welcome")
        signIn(app, email: person.email)
        XCTAssertTrue(app.staticTexts["nutrition.targetEnergy"].waitForExistence(timeout: 10))
        capture(app, "design-02-diary")
        tap(app.buttons["nutrition.addFood"], in: app)
        capture(app, "design-03-food-picker")
        tap(app.buttons["Cancel"].firstMatch, in: app)
        tap(app.buttons["Train"], in: app)
        capture(app, "design-04-training")
        tap(app.buttons["Library"], in: app)
        capture(app, "design-05-library")
        tap(app.buttons["Progress"], in: app)
        capture(app, "design-06-progress")
        tap(app.buttons["Profile"], in: app)
        capture(app, "design-07-profile")
        tap(app.buttons["profile.account"], in: app)
        capture(app, "design-08-account")
        tap(app.navigationBars.buttons.element(boundBy: 0), in: app)
        tap(app.buttons["profile.sync"], in: app)
        capture(app, "design-09-sync")
        tap(app.navigationBars.buttons.element(boundBy: 0), in: app)
        tap(app.buttons["profile.agents"], in: app)
        capture(app, "design-10-connections")
    }

    func testDesignAccessibilityAudit() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_ACCESSIBILITY_AUDIT"] == "1" else {
            throw XCTSkip("Opt-in native accessibility audit")
        }
        try await control([:])
        let person = try await createAccount(prefix: "design-audit", units: "imperial")
        _ = try await seedNutritionEntry(token: person.token, nutrients: ["energy": 57, "protein": 0.4, "carbohydrate": 15.2, "fat": 0.1])
        _ = try await seedProgram(name: "Strength foundations", activated: "2026-10-01T12:00:00.000Z", token: person.token)
        let app = launch(resetSession: true)
        var findings: [String] = []
        var rechecked: [String] = []
        func audit(_ screen: String) throws {
            capture(app, "accessibility-\(screen)")
            let tabBar = app.tabBars.firstMatch
            let bottom = tabBar.exists ? tabBar.frame.minY : app.frame.maxY
            var covered: [(XCUIElement, String)] = []
            try app.performAccessibilityAudit { issue in
                let detail = "\(screen): \(issue.compactDescription) | \(issue.element?.label ?? "No element") | \(String(describing: issue.element?.frame)) | \(issue.detailedDescription)"
                // XCTest also audits scroll content beneath the native tab bar
                // and its edge effect. Move that content into view and retest
                // it below. No contrast finding is dismissed by label alone.
                if tabBar.exists, issue.auditType == .contrast, let element = issue.element,
                   element.frame.minY >= bottom - 64 {
                    covered.append((element, detail))
                } else { findings.append(detail) }
                return true
            }
            for (snapshotElement, detail) in covered {
                let label = snapshotElement.label
                let element = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
                for _ in 0..<4 where element.exists && element.frame.maxY >= bottom - 72 { app.swipeUp() }
                let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : 0
                guard element.exists, element.frame.minY > top, element.frame.maxY < bottom - 8 else {
                    findings.append("Could not expose for contrast recheck: \(detail)")
                    continue
                }
                try app.performAccessibilityAudit(for: .contrast) { issue in
                    if issue.element?.label == label { findings.append("Visible recheck: \(detail)") }
                    return true
                }
                rechecked.append("Scrolled clear of system chrome and re-audited: \(detail)")
            }
            if !covered.isEmpty { capture(app, "accessibility-\(screen)-uncovered") }
        }
        try audit("welcome")
        signIn(app, email: person.email)
        XCTAssertTrue(app.staticTexts["nutrition.targetEnergy"].waitForExistence(timeout: 10))
        try audit("diary")
        for tab in ["Train", "Library", "Progress", "Profile"] {
            tap(app.buttons[tab], in: app)
            try audit(tab.lowercased())
        }
        // Audit every screen before reporting all findings as one failed test.
        let report = (findings.isEmpty ? "No native accessibility findings." : findings.joined(separator: "\n\n")) + "\n\n" + rechecked.joined(separator: "\n\n")
        let attachment = XCTAttachment(string: report)
        attachment.name = "Native accessibility findings"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(findings.isEmpty, report)
    }

    func testDesignEmptyScreenCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in visual review of empty screens")
        }
        try await control([:])
        let person = try await createAccount(prefix: "design-empty", units: "imperial")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        capture(app, "design-empty-diary")
        tap(app.buttons["Train"], in: app)
        capture(app, "design-empty-training")
        tap(app.buttons["training.start"], in: app)
        capture(app, "design-new-workout")
        tap(app.buttons["Cancel"].firstMatch, in: app)
        tap(app.buttons["Library"], in: app)
        capture(app, "design-empty-library")
        tap(app.buttons["nutrition.libraryCreate"], in: app)
        capture(app, "design-food-editor")
        tap(app.buttons["Cancel"].firstMatch, in: app)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.preferences"], in: app)
        capture(app, "design-preferences")
    }

    func testDesignSecondaryScreenCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in visual review of secondary screens")
        }
        try await control([:])
        let person = try await createAccount(prefix: "design-secondary", units: "imperial")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["nutrition.dailyHealth"], in: app)
        XCTAssertTrue(app.staticTexts["diary.selected-day"].waitForExistence(timeout: 10))
        capture(app, "design-11-daily-health")
        tap(app.buttons["Log activity"], in: app)
        capture(app, "design-12-activity-editor")
        tap(app.buttons["Cancel"].firstMatch, in: app)
        tap(app.buttons["Log sleep"], in: app)
        capture(app, "design-13-sleep-editor")
        tap(app.buttons["Cancel"].firstMatch, in: app)
        tap(app.buttons["Add a custom water amount"], in: app)
        capture(app, "design-14-water-editor")
        tap(app.buttons["Cancel"].firstMatch, in: app)
        tap(app.buttons["Progress"], in: app)
        tap(app.buttons["Log weight"], in: app)
        capture(app, "design-15-weight-editor")
        tap(app.buttons["Cancel"].firstMatch, in: app)
        tap(app.buttons["Add measurement"], in: app)
        capture(app, "design-16-measurement-editor")
        tap(app.buttons["Cancel"].firstMatch, in: app)
        selectProgress("Photos", in: app)
        capture(app, "design-17-photos")
        selectProgress("Milestones", in: app)
        capture(app, "design-18-milestones")
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["Nutrition Program"], in: app)
        XCTAssertTrue(app.staticTexts["Daily targets"].waitForExistence(timeout: 10))
        capture(app, "design-19-nutrition-program")
        tap(app.navigationBars.buttons.firstMatch, in: app)
        tap(app.buttons["Change Password"], in: app)
        capture(app, "design-20-password")
        tap(app.buttons["Cancel"].firstMatch, in: app)
        tap(app.buttons["Apple Health"], in: app)
        capture(app, "design-21-health-permissions")
    }

    func testDesignAdminScreenCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else {
            throw XCTSkip("Opt-in visual review of admin screens")
        }
        try await control([:])
        let person = try await createAccount(prefix: "design-admin", units: "imperial")
        try await control(["designAdminEmail": person.email])
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["Admin Panel"], in: app)
        XCTAssertTrue(app.staticTexts["Recorded entries"].waitForExistence(timeout: 15))
        capture(app, "design-admin-overview")
        tap(app.buttons["Users"], in: app)
        XCTAssertTrue(app.staticTexts[person.email].waitForExistence(timeout: 10))
        capture(app, "design-admin-accounts")
    }

    func testDesignProgressPhotosCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_PHOTOS"] == "1" else {
            throw XCTSkip("Opt-in photo import review on a simulator with synthetic media")
        }
        try await control([:])
        let person = try await createAccount(prefix: "design-photos", units: "imperial")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Progress"], in: app)
        selectProgress("Photos", in: app)
        tap(app.buttons["Add photo"], in: app)
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 10))
        dismissPhotoPickerIntroduction(in: app)
        // The opt-in simulator has two freshly imported geometric PNGs first.
        let libraryPhotos = app.images.matching(identifier: "PXGGridLayout-Info")
        XCTAssertTrue(libraryPhotos.element(boundBy: 0).waitForExistence(timeout: 10))
        libraryPhotos.element(boundBy: 0).tap()
        let photos = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "progress.photo."))
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 10))
        tap(app.buttons["progress.addPhoto"], in: app)
        dismissPhotoPickerIntroduction(in: app)
        XCTAssertTrue(libraryPhotos.element(boundBy: 1).waitForExistence(timeout: 10))
        libraryPhotos.element(boundBy: 1).tap()
        XCTAssertTrue(photos.element(boundBy: 1).waitForExistence(timeout: 10))
        XCTAssertEqual(photos.count, 2)
        capture(app, "design-photos-populated")
        tap(app.buttons["Compare"], in: app)
        tap(photos.element(boundBy: 0), in: app)
        tap(photos.element(boundBy: 1), in: app)
        revealAbove(app.staticTexts["Side by side"], in: app)
        XCTAssertTrue(app.staticTexts["Side by side"].exists)
        capture(app, "design-photos-comparison")
        tap(app.buttons["Done"], in: app)
        tap(photos.firstMatch, in: app)
        XCTAssertTrue(app.navigationBars["Progress photo"].waitForExistence(timeout: 5))
        capture(app, "design-photo-detail")
        tap(app.buttons["Close"], in: app)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--ui-testing" }
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Progress"], in: app)
        selectProgress("Photos", in: app)
        reveal(photos.element(boundBy: 1), in: app)
        XCTAssertTrue(photos.element(boundBy: 1).waitForExistence(timeout: 10))
        XCTAssertEqual(photos.count, 2)
        capture(app, "design-photos-relaunched")
    }

    func testNutritionManualFoodKeepsUnknownsAndSurvivesOfflineEditing() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "nutrition-manual")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["nutrition.addFood"], in: app)
        tap(app.buttons["nutrition.createFood"], in: app)
        replace(app.textFields["nutrition.foodName"], with: "Synthetic oats", in: app)
        replace(app.textFields["Energy (kcal)"], with: "380", in: app)
        replace(app.textFields["Protein (g)"], with: "13.2", in: app)
        replace(app.textFields["Carbohydrate (g)"], with: "62.5", in: app)
        replace(app.textFields["Fat (g)"], with: "0", in: app)
        dismissKeyboard(app)
        capture(app, "nutrition-manual-label")
        tap(app.buttons["nutrition.saveFood"], in: app)
        XCTAssertTrue(app.navigationBars["Log food"].waitForExistence(timeout: 10))
        replace(app.textFields["Amount (g)"], with: "37.2", in: app)
        tap(app.buttons["exerly.keypad.5"], in: app)
        XCTAssertEqual(app.textFields["Amount (g)"].value as? String, "37.25")
        dismissKeyboard(app)
        tap(app.buttons["Dinner"], in: app)
        capture(app, "nutrition-manual-portion")
        try await control(["offline": true])
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "nutrition.entry.")).firstMatch
        reveal(entry, in: app)
        XCTAssertTrue(entry.exists)
        capture(app, "nutrition-manual-offline-diary")
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        tap(entry, in: app)
        XCTAssertEqual(app.textFields["Amount (g)"].value as? String, "37.25")
        replace(app.textFields["Amount (g)"], with: "40.5", in: app)
        dismissKeyboard(app)
        tap(app.buttons["nutrition.saveEntry"], in: app)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        tap(entry, in: app)
        XCTAssertEqual(app.textFields["Amount (g)"].value as? String, "40.5")
        capture(app, "nutrition-manual-relaunched-entry")
        tap(app.buttons["Cancel"], in: app)
        try await control([:])
        tap(app.buttons["Retry"].firstMatch, in: app)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        tap(app.buttons["account.syncNow"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let entries = documents.filter { $0["kind"] as? String == "food_entry" }
            .compactMap { $0["payload"] as? [String: Any] }
        XCTAssertEqual(entries.count, 1)
        let saved = try XCTUnwrap(entries.first)
        XCTAssertEqual(saved["grams"] as? Double, 40.5)
        XCTAssertEqual(saved["meal"] as? String, "Dinner")
        let food = try XCTUnwrap(saved["food"] as? [String: Any])
        XCTAssertEqual(food["name"] as? String, "Synthetic oats")
        let nutrients = try XCTUnwrap(food["per100g"] as? [String: Any])
        XCTAssertEqual(nutrients["energy"] as? Double, 380)
        XCTAssertEqual(nutrients["fat"] as? Double, 0)
        XCTAssertNil(nutrients["iron"])
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertEqual(saved["date"] as? String, formatter.string(from: yesterday))
    }

    func testNutritionSubmittedSearchBarcodeAndThreeTapRepeat() async throws {
        try await control(["resetFoodDatabaseRequests": true])
        let person = try await createAccount(prefix: "nutrition-search")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["nutrition.addFood"], in: app)
        let searchField = app.searchFields.firstMatch
        replace(searchField, with: "oat", in: app)
        let before = try await request("GET", "/__test/food-database-requests")
        XCTAssertEqual((before["requests"] as? [[String: Any]])?.count, 0, "Typing must not query the food database")
        XCTAssertTrue(app.keyboards.buttons["Search"].waitForExistence(timeout: 5))
        app.keyboards.buttons["Search"].tap()
        let food = app.buttons["nutrition.food.off:0012345678905"]
        XCTAssertTrue(food.waitForExistence(timeout: 10))
        capture(app, "nutrition-search-results")
        tap(food, in: app)
        replace(app.textFields["Amount (g)"], with: "35.5", in: app)
        dismissKeyboard(app)
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))
        // Exactly three taps from the diary. No typing or portion changes.
        tap(app.buttons["nutrition.addFood"], in: app)
        tap(food, in: app)
        XCTAssertEqual(app.textFields["Amount (g)"].value as? String, "35.5")
        capture(app, "nutrition-repeat-previous-portion")
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))
        tap(app.buttons["nutrition.addFood"], in: app)
        tap(app.buttons["nutrition.barcode"], in: app)
        replace(app.textFields["nutrition.barcodeDigits"], with: "0000000000000", in: app)
        dismissKeyboard(app)
        tap(app.buttons["nutrition.lookupBarcode"], in: app)
        XCTAssertTrue(app.staticTexts["nutrition.barcodeNotFound"].waitForExistence(timeout: 10))
        capture(app, "nutrition-barcode-not-found")
        replace(app.textFields["nutrition.barcodeDigits"], with: "0012345678905", in: app)
        dismissKeyboard(app)
        tap(app.buttons["nutrition.lookupBarcode"], in: app)
        XCTAssertTrue(app.buttons["nutrition.barcodeFood"].waitForExistence(timeout: 10))
        capture(app, "nutrition-barcode-found")
        tap(app.buttons["nutrition.barcodeFood"], in: app)
        replace(app.textFields["Amount (g)"], with: "20", in: app)
        dismissKeyboard(app)
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        tap(app.buttons["account.syncNow"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let entries = documents.filter { $0["kind"] as? String == "food_entry" }.compactMap { $0["payload"] as? [String: Any] }
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.compactMap { $0["grams"] as? Double }.sorted(), [20, 35.5, 35.5])
        XCTAssertTrue(entries.allSatisfy { ($0["food"] as? [String: Any])?["foodID"] as? String == "off:0012345678905" })
        XCTAssertFalse(documents.contains { $0["kind"] as? String == "saved_food" }, "Database food logging must not require saving a library food")
        let requests = try await request("GET", "/__test/food-database-requests")
        let calls = try XCTUnwrap(requests["requests"] as? [[String: Any]])
        XCTAssertEqual(calls.filter { $0["type"] as? String == "search" }.count, 1)
        XCTAssertEqual(calls.filter { $0["type"] as? String == "barcode" }.count, 2)
    }

    func testNutritionDayNoteCopyAndDeletionUndoStayOfflineUntilReconnection() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "nutrition-day")
        let seeded = try await seedNutritionEntry(token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        let original = app.buttons["nutrition.entry.\(seeded.id)"]
        reveal(original, in: app)
        XCTAssertTrue(original.waitForExistence(timeout: 15))
        try await control(["offline": true])
        revealAbove(app.buttons["nutrition.dayStatus"], in: app)
        tap(app.buttons["nutrition.dayStatus"], in: app)
        let partial = app.buttons["nutrition.status.partial"]
        guard partial.waitForExistence(timeout: 5) else {
            XCTFail("Logging status menu did not open: \(app.debugDescription)")
            return
        }
        partial.tap()
        capture(app, "nutrition-partial-review")
        tap(app.buttons["nutrition.confirm"], in: app)
        tap(app.buttons["nutrition.dayActions"], in: app)
        tap(app.buttons["nutrition.editNote"], in: app)
        replace(app.textFields["nutrition.dayNote"], with: "Dinner after training", in: app)
        dismissKeyboard(app)
        capture(app, "nutrition-day-note")
        tap(app.buttons["nutrition.saveNote"], in: app)
        revealAbove(app.buttons["Dinner actions"], in: app)
        tap(app.buttons["Dinner actions"], in: app)
        tap(app.buttons["Copy Dinner"], in: app)
        capture(app, "nutrition-copy-review")
        tap(app.buttons["nutrition.copyConfirm"], in: app)
        revealAbove(app.buttons["Next day"], in: app)
        tap(app.buttons["Next day"], in: app)
        let copied = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "nutrition.entry.")).firstMatch
        reveal(copied, in: app)
        let copiedID = copied.identifier
        XCTAssertNotEqual(copiedID, "nutrition.entry.\(seeded.id)")
        capture(app, "nutrition-copied-day")
        tap(copied, in: app)
        tap(app.buttons["Delete entry"], in: app)
        capture(app, "nutrition-delete-review")
        tap(app.buttons["nutrition.confirm"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))
        revealAbove(app.buttons["nutrition.undoDelete"], in: app)
        capture(app, "nutrition-deleted-entry")
        tap(app.buttons["nutrition.undoDelete"], in: app)
        reveal(app.buttons[copiedID], in: app)
        XCTAssertTrue(app.buttons[copiedID].exists)
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        reveal(app.buttons["nutrition.dayStatus"], in: app)
        XCTAssertTrue(app.buttons["nutrition.dayStatus"].label.contains("Partial log"))
        reveal(app.staticTexts["Dinner after training"], in: app)
        XCTAssertTrue(app.staticTexts["Dinner after training"].exists)
        capture(app, "nutrition-note-after-relaunch")
        try await control([:])
        tap(app.buttons["Retry"].firstMatch, in: app)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        tap(app.buttons["account.syncNow"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let entries = documents.filter { $0["kind"] as? String == "food_entry" }.compactMap { $0["payload"] as? [String: Any] }
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.allSatisfy { $0["grams"] as? Double == 123.25 })
        XCTAssertEqual(Set(entries.compactMap { $0["id"] as? String }).count, 2)
        let day = try XCTUnwrap(documents.first { $0["kind"] as? String == "nutrition_day" }?["payload"] as? [String: Any])
        XCTAssertEqual(day["date"] as? String, seeded.date)
        XCTAssertEqual(day["status"] as? String, "partial")
        XCTAssertEqual(day["notes"] as? String, "Dinner after training")
    }

    func testNutritionLibraryEditingFavoritesAndArchiveKeepHistoricalEntries() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "nutrition-library")
        let seeded = try await seedNutritionEntry(token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        try await control(["offline": true])
        tap(app.buttons["Library"], in: app)
        let food = app.buttons["nutrition.libraryFood.\(seeded.foodID)"]
        let search = app.textFields["nutrition.librarySearch"]
        replace(search, with: "missing label", in: app)
        XCTAssertFalse(food.exists)
        tap(app.buttons["Clear search"], in: app)
        replace(search, with: "pear", in: app)
        dismissKeyboard(app)
        XCTAssertTrue(food.exists)
        tap(app.buttons["Clear search"], in: app)
        tap(food, in: app)
        tap(app.buttons["nutrition.libraryFavorite"], in: app)
        XCTAssertTrue(app.buttons["Remove from favorites"].exists)
        tap(app.buttons["nutrition.libraryActions"], in: app)
        tap(app.buttons["nutrition.libraryEdit"], in: app)
        replace(app.textFields["nutrition.foodName"], with: "Synthetic ripe pear", in: app)
        replace(app.textFields["Energy (kcal)"], with: "60", in: app)
        dismissKeyboard(app)
        capture(app, "nutrition-library-label-edit")
        tap(app.buttons["nutrition.saveFood"], in: app)
        XCTAssertTrue(app.staticTexts["Synthetic ripe pear"].waitForExistence(timeout: 10))
        tap(app.buttons["nutrition.libraryLog"], in: app)
        XCTAssertEqual(app.textFields["Amount (g)"].value as? String, "123.25")
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(app.staticTexts["nutrition.libraryLogged"].waitForExistence(timeout: 10))
        capture(app, "nutrition-library-new-entry")
        tap(app.buttons["nutrition.libraryActions"], in: app)
        tap(app.buttons["nutrition.libraryArchive"], in: app)
        capture(app, "nutrition-library-archive-review")
        tap(app.buttons["nutrition.confirmCancel"], in: app)
        XCTAssertTrue(app.buttons["nutrition.libraryLog"].exists)
        tap(app.buttons["nutrition.libraryActions"], in: app)
        tap(app.buttons["nutrition.libraryArchive"], in: app)
        tap(app.buttons["nutrition.confirm"], in: app)
        XCTAssertTrue(app.staticTexts["Archived"].waitForExistence(timeout: 10))
        tap(app.navigationBars.buttons["Food library"], in: app)
        XCTAssertFalse(food.exists)
        tap(app.buttons["Archived"], in: app)
        tap(food, in: app)
        capture(app, "nutrition-library-archived-food")
        tap(app.buttons["nutrition.libraryArchive"], in: app)
        capture(app, "nutrition-library-restore-review")
        tap(app.buttons["nutrition.confirm"], in: app)
        XCTAssertTrue(app.buttons["nutrition.libraryLog"].waitForExistence(timeout: 10))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Library"], in: app)
        tap(food, in: app)
        XCTAssertTrue(app.staticTexts["Synthetic ripe pear"].exists)
        XCTAssertTrue(app.buttons["Remove from favorites"].exists)
        capture(app, "nutrition-library-restored-after-relaunch")
        try await control([:])
        tap(app.buttons["Retry"].firstMatch, in: app)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        tap(app.buttons["account.syncNow"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let saved = try XCTUnwrap(documents.first { $0["kind"] as? String == "saved_food" }?["payload"] as? [String: Any])
        XCTAssertEqual(saved["name"] as? String, "Synthetic ripe pear")
        XCTAssertEqual(saved["favorite"] as? Bool, true)
        XCTAssertTrue(saved["archivedAt"] == nil || saved["archivedAt"] is NSNull)
        let entries = documents.filter { $0["kind"] as? String == "food_entry" }.compactMap { $0["payload"] as? [String: Any] }
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.allSatisfy { $0["grams"] as? Double == 123.25 })
        let old = try XCTUnwrap(entries.first { $0["id"] as? String == seeded.id })
        XCTAssertEqual((old["food"] as? [String: Any])?["name"] as? String, "Synthetic pear")
        XCTAssertEqual(((old["food"] as? [String: Any])?["per100g"] as? [String: Any])?["energy"] as? Double, 57)
        let new = try XCTUnwrap(entries.first { $0["id"] as? String != seeded.id })
        XCTAssertEqual((new["food"] as? [String: Any])?["name"] as? String, "Synthetic ripe pear")
        XCTAssertEqual(((new["food"] as? [String: Any])?["per100g"] as? [String: Any])?["energy"] as? Double, 60)
    }

    private func seedNutritionEntry(token: String, name: String = "Synthetic pear", nutrients: [String: Double] = ["energy": 57, "sodium": 0], grams: Double = 123.25) async throws -> (id: String, date: String, foodID: String) {
        let foodID = UUID().uuidString
        let entryID = UUID().uuidString
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: Date())
        let food: [String: Any] = ["id": foodID, "name": name, "source": "custom", "per100g": nutrients,
                                    "servings": [], "favorite": false, "createdAt": "2026-10-06T12:00:00.000Z"]
        _ = try await request("PUT", "/v1/documents/saved_food/\(foodID)", body: ["base_revision": 0, "payload": food], token: token)
        let snapshot: [String: Any] = ["foodID": foodID, "name": name, "source": "custom", "per100g": nutrients]
        let entry: [String: Any] = ["id": entryID, "date": date, "meal": "Dinner", "loggedAt": "2026-10-06T18:30:00.000Z",
                                     "food": snapshot, "grams": grams]
        _ = try await request("PUT", "/v1/documents/food_entry/\(entryID)", body: ["base_revision": 0, "payload": entry], token: token)
        return (entryID, date, foodID)
    }

    func testAccountDeletionRequiresConfirmationAndFailureKeepsTheAccount() throws {
        let app = launch(resetSession: true, accountControls: "delete-error")
        XCTAssertTrue(app.staticTexts["morgan@example.test"].waitForExistence(timeout: 10))
        tap(app.buttons["account.delete"], in: app)
        tap(app.buttons["account.confirmDelete"], in: app)
        capture(app, "account-delete-confirmation")
        tap(app.alerts.buttons["Cancel"], in: app)
        XCTAssertTrue(app.buttons["account.confirmDelete"].exists)
        XCTAssertFalse(app.staticTexts["Account deleted"].exists)
        tap(app.buttons["account.confirmDelete"], in: app)
        tap(app.alerts.buttons["Delete account"], in: app)
        let failure = app.staticTexts["Could not reach Exerly. Check your connection and try again."]
        reveal(failure, in: app)
        XCTAssertTrue(failure.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Account deleted"].exists)
        capture(app, "account-delete-error")
        for _ in 0..<6 where !app.buttons["account.confirmDelete"].exists { app.swipeDown() }
        XCTAssertTrue(app.buttons["account.confirmDelete"].isEnabled)
    }

    func testAppleOnlyAccountCannotDisconnectItsOnlySignInMethod() throws {
        let app = launch(resetSession: true, accountControls: "apple-only")
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 10))
        let disconnect = app.buttons["account.disconnectApple"]
        for _ in 0..<10 where !disconnect.exists { app.swipeUp() }
        XCTAssertTrue(disconnect.exists)
        XCTAssertFalse(disconnect.isEnabled)
        let explanation = app.staticTexts["Keep Apple connected so you can sign in to this account."]
        for _ in 0..<6 where !explanation.exists { app.swipeUp() }
        XCTAssertTrue(explanation.exists)
        capture(app, "account-apple-only")
    }

    func testWelcomeCanOpenSignIn() throws {
        let app = launch(resetSession: true)
        capture(app, "auth-welcome")
        reveal(app.buttons["I already have an account"], in: app)
        capture(app, "auth-welcome-actions")
        tap(app.buttons["I already have an account"], in: app)
        XCTAssertTrue(app.secureTextFields["Password"].waitForExistence(timeout: 5))
        reveal(app.buttons["account.appleAuthorization"], in: app)
        XCTAssertTrue(app.buttons["account.appleAuthorization"].isEnabled)
        capture(app, "auth-apple-sign-in")
    }

    func testAccountSyncExportAndDeletionAgainstTheServer() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "account-actions")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["training.start"], in: app)
        replace(app.textFields["training.name"], with: "Account sync test", in: app)
        dismissKeyboard(app)
        tap(app.buttons["training.confirmStart"], in: app)
        tap(app.buttons["Profile"], in: app)
        capture(app, "account-live-profile")
        tap(app.buttons["profile.sync"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        capture(app, "account-live-sync")
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        XCTAssertTrue(documents.contains { ($0["payload"] as? [String: Any])?["name"] as? String == "Account sync test" })
        tap(app.navigationBars.buttons["Profile"], in: app)
        tap(app.buttons["profile.account"], in: app)
        XCTAssertTrue(app.staticTexts["Email and password"].waitForExistence(timeout: 10))
        capture(app, "account-live-settings")
        tap(app.buttons["account.export"], in: app)
        XCTAssertTrue(app.buttons["Close"].firstMatch.waitForExistence(timeout: 15))
        capture(app, "account-live-export")
        if app.buttons["Close"].firstMatch.exists { tap(app.buttons["Close"].firstMatch, in: app) }
        else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        }
        reveal(app.buttons["account.exportDevice"], in: app)
        capture(app, "account-live-export-options")
        tap(app.buttons["account.delete"], in: app)
        tap(app.buttons["account.confirmDelete"], in: app)
        try await control(["dropAccountDeleteAcknowledgement": true])
        tap(app.alerts.buttons["Delete account"], in: app)
        XCTAssertTrue(app.buttons["I already have an account"].waitForExistence(timeout: 20))
        capture(app, "account-live-deleted")
        var check = URLRequest(url: URL(string: fixtureURL + "/api/export")!)
        check.setValue("Bearer \(person.token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: check)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 401)
    }

    func testSwitchingAccountsKeepsEachWorkoutSeparate() async throws {
        try await control([:])
        let first = try await createAccount(prefix: "switch-first")
        let second = try await createAccount(prefix: "switch-second")
        let app = launch(resetSession: true)
        signIn(app, email: first.email)
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["training.start"], in: app)
        replace(app.textFields["training.name"], with: "First account workout", in: app)
        dismissKeyboard(app)
        tap(app.buttons["training.confirmStart"], in: app)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.logout"], in: app)
        signIn(app, email: second.email)
        tap(app.buttons["Train"], in: app)
        XCTAssertTrue(app.buttons["training.start"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["First account workout"].exists)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.logout"], in: app)
        signIn(app, email: first.email)
        tap(app.buttons["Train"], in: app)
        XCTAssertTrue(app.navigationBars["First account workout"].waitForExistence(timeout: 10))
        capture(app, "account-switch-restored")
    }

    func testOfflineWorkoutSurvivesRelaunchAndSyncsWhenReconnected() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "offline-training")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        try await control(["offline": true, "disconnect": true])
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["training.start"], in: app)
        replace(app.textFields["training.name"], with: "Offline saved workout", in: app)
        dismissKeyboard(app)
        tap(app.buttons["training.confirmStart"], in: app)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        XCTAssertTrue(app.staticTexts["Offline. Your changes are saved on this device."].waitForExistence(timeout: 20))
        capture(app, "account-sync-offline")
        tap(app.navigationBars.buttons["Profile"], in: app)
        tap(app.buttons["profile.account"], in: app)
        tap(app.buttons["account.exportDevice"], in: app)
        XCTAssertTrue(app.buttons["Close"].firstMatch.waitForExistence(timeout: 10))
        capture(app, "account-offline-export")
        tap(app.buttons["Close"].firstMatch, in: app)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--ui-testing" }
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Train"], in: app)
        XCTAssertTrue(app.navigationBars["Offline saved workout"].waitForExistence(timeout: 10))
        try await control([:])
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        XCTAssertTrue(documents.contains { ($0["payload"] as? [String: Any])?["name"] as? String == "Offline saved workout" })
        capture(app, "account-sync-reconnected")
        tap(app.navigationBars.buttons["Profile"], in: app)
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        tap(app.buttons["profile.account"], in: app)
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
        capture(app, "account-reconnected-navigation")
    }

    func testProgramBuilderPersistsOfflineAndFinishedWorkoutsAdvanceThePlan() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "program-builder")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["programs.open"], in: app)
        tap(app.buttons["program.create"], in: app)
        replace(app.descendants(matching: .any).matching(identifier: "program.name").firstMatch, with: "Two-day strength", in: app)
        replace(app.textFields["Cycles"], with: "2", in: app)
        dismissKeyboard(app)
        capture(app, "program-builder-start")
        tap(app.buttons["program.deload"], in: app)
        XCTAssertTrue(app.buttons["No deload cycle"].waitForExistence(timeout: 5))
        capture(app, "program-deload-choices")
        tap(app.buttons["No deload cycle"], in: app)
        tap(app.buttons["program.save"], in: app)
        XCTAssertTrue(app.staticTexts["a program needs a training day"].waitForExistence(timeout: 10))
        capture(app, "program-builder-invalid")
        revealAbove(app.buttons["program.addDay"], in: app)
        tap(app.buttons["program.addDay"], in: app)
        tap(app.staticTexts["Day 1"], in: app)
        try configureProgramDay(app, name: "Pull", exercise: "Deadlift", override: true)
        tap(app.navigationBars.buttons.firstMatch, in: app)
        tap(app.buttons["program.addRest"], in: app)
        tap(app.buttons["program.addDay"], in: app)
        tap(app.staticTexts["Day 3"], in: app)
        try configureProgramDay(app, name: "Push", exercise: "Barbell Bench Press", override: false)
        tap(app.navigationBars.buttons.firstMatch, in: app)
        revealAbove(app.staticTexts["Pull"], in: app)
        capture(app, "program-builder-days")
        try await control(["offline": true, "disconnect": true])
        tap(app.buttons["program.save"], in: app)
        XCTAssertTrue(app.navigationBars["Programs"].waitForExistence(timeout: 10))
        app.terminate()
        app.launchArguments.removeAll { $0 == "--ui-testing" }
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["programs.open"], in: app)
        tap(app.staticTexts["Two-day strength"], in: app)
        capture(app, "program-offline-restored")
        tap(app.buttons["program.activate"], in: app)
        capture(app, "program-follow-confirmation")
        tap(app.buttons["program.confirm"], in: app)
        revealAbove(app.staticTexts["Following this program"], in: app)
        XCTAssertTrue(app.staticTexts["Following this program"].exists)
        tap(app.navigationBars.buttons.firstMatch, in: app)
        tap(app.navigationBars.buttons.firstMatch, in: app)
        revealAbove(app.buttons["program.nextWorkout"], in: app)
        tap(app.buttons["program.nextWorkout"], in: app)
        XCTAssertTrue(app.navigationBars["Next workout"].waitForExistence(timeout: 10))
        reveal(app.staticTexts["Two-day strength: Pull"], in: app)
        let previewOpened = app.staticTexts["Two-day strength: Pull"].waitForExistence(timeout: 10)
        _ = try XCTUnwrap(previewOpened ? true : nil, app.debugDescription)
        capture(app, "program-next-preview")
        reveal(app.staticTexts["Target 3 RIR"], in: app)
        XCTAssertTrue(app.staticTexts["Target 3 RIR"].exists)
        capture(app, "program-next-targets")
        tap(app.buttons["program.startPlanned"], in: app)
        let incomplete = app.buttons["Complete set 1, Deadlift"]
        reveal(incomplete, in: app)
        XCTAssertTrue(incomplete.exists)
        XCTAssertFalse(app.buttons["Reopen set 1, Deadlift"].exists)
        capture(app, "program-starts-incomplete")
        tap(app.buttons["Edit set 1, Deadlift"], in: app)
        replace(app.textFields["training.load.0"], with: "60", in: app)
        replace(app.textFields["training.reps.0"], with: "5", in: app)
        dismissKeyboard(app)
        tap(app.buttons["training.saveSet"], in: app)
        tap(incomplete, in: app)
        tap(app.buttons["training.finish"], in: app)
        tap(app.buttons["Save workout"], in: app)
        XCTAssertTrue(app.navigationBars["Training"].waitForExistence(timeout: 10))
        tap(app.buttons["program.nextWorkout"], in: app)
        XCTAssertTrue(app.navigationBars["Next workout"].waitForExistence(timeout: 10))
        reveal(app.staticTexts["Two-day strength: Push"], in: app)
        XCTAssertTrue(app.staticTexts["Two-day strength: Push"].waitForExistence(timeout: 10))
        capture(app, "program-next-skips-rest")
        tap(app.buttons["Close"], in: app)
        try await control([:])
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let program = try XCTUnwrap(documents.first { $0["kind"] as? String == "program" }?["payload"] as? [String: Any])
        XCTAssertEqual(program["name"] as? String, "Two-day strength")
        XCTAssertEqual(program["cycles"] as? Int, 2)
        XCTAssertNotNil(program["activatedAt"])
        let days = try XCTUnwrap(program["days"] as? [[String: Any]])
        XCTAssertEqual(days.compactMap { $0["name"] as? String }, ["Pull", "Rest", "Push"])
        let slots = try XCTUnwrap(days.first?["slots"] as? [[String: Any]])
        let targets = try XCTUnwrap(slots.first?["cycleTargets"] as? [String: Any])
        XCTAssertEqual((targets["0"] as? [String: Any])?["rir"] as? Double, 3)
        let workout = try XCTUnwrap(documents.first { $0["kind"] as? String == "workout_session" }?["payload"] as? [String: Any])
        XCTAssertEqual((workout["program"] as? [String: Any])?["programID"] as? String, program["id"] as? String)
        XCTAssertNotNil(workout["endedAt"])
    }

    func testProgramLifecyclePreviewsSelectionAndKeepsCancelledDraft() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "program-lifecycle")
        _ = try await seedProgram(name: "Earlier strength", activated: "2026-10-01T12:00:00.000Z", token: person.token)
        let latest = try await seedProgram(name: "Current strength", activated: "2026-10-02T12:00:00.000Z", token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["programs.open"], in: app)
        tap(app.buttons["program.open.\(latest.id)"], in: app)
        try await control(["offline": true, "disconnect": true])
        tap(app.buttons["program.archive"], in: app)
        let priorPreview = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "You will be following Earlier strength.")).firstMatch
        XCTAssertTrue(priorPreview.waitForExistence(timeout: 5))
        capture(app, "program-archive-preview")
        tap(app.buttons["program.confirmCancel"], in: app)
        revealAbove(app.staticTexts["Following this program"], in: app)
        XCTAssertTrue(app.staticTexts["Following this program"].exists)
        tap(app.buttons["program.archive"], in: app)
        tap(app.buttons["program.confirm"], in: app)
        tap(app.buttons["program.restore"], in: app)
        let restorePreview = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "You will be following Current strength.")).firstMatch
        XCTAssertTrue(restorePreview.waitForExistence(timeout: 5))
        capture(app, "program-restore-preview")
        tap(app.buttons["program.confirm"], in: app)
        tap(app.buttons["program.duplicate"], in: app)
        reveal(app.staticTexts["program.duplicateResult"], in: app)
        XCTAssertTrue(app.staticTexts["program.duplicateResult"].exists)
        capture(app, "program-duplicated")
        revealAbove(app.buttons["program.edit"], in: app)
        tap(app.buttons["program.edit"], in: app)
        let name = app.descendants(matching: .any).matching(identifier: "program.name").firstMatch
        tap(name, in: app)
        // At large text sizes a tap can put the caret in the middle of a
        // horizontally scrolling name. Select the whole paragraph first.
        name.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        name.typeText("Unsaved name")
        XCTAssertEqual(name.value as? String, "Unsaved name")
        dismissKeyboard(app)
        tap(app.buttons["Cancel"], in: app)
        capture(app, "program-discard-confirmation")
        tap(app.buttons["program.confirmCancel"], in: app)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "program.name").firstMatch.value as? String, "Unsaved name")
        tap(app.buttons["Cancel"], in: app)
        tap(app.buttons["program.confirm"], in: app)
        revealAbove(app.staticTexts["Current strength"], in: app)
        XCTAssertTrue(app.staticTexts["Current strength"].exists)
        capture(app, "program-cancel-keeps-saved")
        tap(app.navigationBars.buttons.firstMatch, in: app)
        reveal(app.staticTexts["Current strength copy"], in: app)
        XCTAssertTrue(app.staticTexts["Current strength copy"].exists)
        capture(app, "program-list-with-copy")
        app.terminate()
        app.launchArguments.removeAll { $0 == "--ui-testing" }
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Train"], in: app)
        XCTAssertTrue(app.staticTexts["Current strength"].waitForExistence(timeout: 10))
        capture(app, "program-selection-after-relaunch")
        try await control([:])
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let programs = documents.filter { $0["kind"] as? String == "program" }.compactMap { $0["payload"] as? [String: Any] }
        XCTAssertEqual(programs.count, 3)
        let original = try XCTUnwrap(programs.first { $0["id"] as? String == latest.id })
        XCTAssertEqual(original["name"] as? String, "Current strength")
        XCTAssertNil(original["archivedAt"])
        let copy = try XCTUnwrap(programs.first { $0["name"] as? String == "Current strength copy" })
        XCTAssertNil(copy["activatedAt"])
        XCTAssertNotEqual(copy["id"] as? String, latest.id)
    }

    func testProgramSuggestionShowsReadableTargetsAndCanBeAcceptedAndUndoneOffline() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "program-suggestion")
        let seeded = try await seedProgram(name: "Suggested strength", token: person.token)
        let suggestion = try await seedProgramProposal(program: seeded.payload, token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["suggestions.open"], in: app)
        tap(app.buttons["suggestions.proposal.\(suggestion)"], in: app)
        tap(app.buttons["suggestions.program.after"], in: app)
        reveal(app.staticTexts["3 sets · 5–8 reps · 3 RIR"], in: app)
        XCTAssertTrue(app.staticTexts["3 sets · 5–8 reps · 3 RIR"].exists)
        capture(app, "program-proposed-targets")
        tap(app.navigationBars.buttons.firstMatch, in: app)
        let context = app.staticTexts["Day 1 · Pull · Deadlift · Base targets · Reps in reserve"]
        reveal(context, in: app)
        XCTAssertTrue(context.exists)
        XCTAssertTrue(app.staticTexts["Before: 2"].exists)
        XCTAssertTrue(app.staticTexts["After: 3"].exists)
        capture(app, "program-proposed-diff")
        reveal(app.staticTexts["After: 3"], in: app)
        capture(app, "program-proposed-values")
        tap(app.buttons["evidence.program.\(seeded.id)"], in: app)
        reveal(app.staticTexts["3 sets · 5–8 reps · 2 RIR"], in: app)
        XCTAssertTrue(app.staticTexts["3 sets · 5–8 reps · 2 RIR"].exists)
        capture(app, "program-proposal-source")
        tap(app.navigationBars.buttons.firstMatch, in: app)
        try await control(["offline": true, "disconnect": true])
        tap(app.buttons["suggestions.accept"], in: app)
        revealAbove(app.staticTexts["suggestions.status"], in: app)
        XCTAssertTrue(app.staticTexts["Accepted"].exists)
        capture(app, "program-proposal-accepted")
        app.terminate()
        app.launchArguments.removeAll { $0 == "--ui-testing" }
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["programs.open"], in: app)
        tap(app.buttons["program.open.\(seeded.id)"], in: app)
        reveal(app.staticTexts["3 sets · 5–8 reps · 3 RIR"], in: app)
        XCTAssertTrue(app.staticTexts["3 sets · 5–8 reps · 3 RIR"].exists)
        capture(app, "program-accepted-after-relaunch")
        tap(app.navigationBars.buttons.firstMatch, in: app)
        tap(app.navigationBars.buttons.firstMatch, in: app)
        tap(app.buttons["suggestions.open"], in: app)
        tap(app.buttons["suggestions.proposal.\(suggestion)"], in: app)
        tap(app.buttons["suggestions.undo"], in: app)
        revealAbove(app.staticTexts["suggestions.status"], in: app)
        XCTAssertTrue(app.staticTexts["Undone"].exists)
        capture(app, "program-proposal-undone")
        try await control([:])
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let row = try await request("GET", "/v1/documents/program/\(seeded.id)", token: person.token)
        let payload = try XCTUnwrap(row["payload"] as? [String: Any])
        let days = try XCTUnwrap(payload["days"] as? [[String: Any]])
        let slots = try XCTUnwrap(days[0]["slots"] as? [[String: Any]])
        XCTAssertEqual((slots[0]["target"] as? [String: Any])?["rir"] as? Double, 2)
        let proposal = try await request("GET", "/v1/documents/proposal/\(suggestion)", token: person.token)
        XCTAssertEqual((proposal["payload"] as? [String: Any])?["status"] as? String, "undone")
    }

    func testPlannedWorkoutExplainsItsEstimateAndOpensTheSourceWorkout() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "program-evidence")
        _ = try await seedTrainingWorkout(name: "Earlier program evidence", loads: [60], daysAgo: 5, token: person.token)
        _ = try await seedTrainingWorkout(name: "Latest program evidence", loads: [65], daysAgo: 2, token: person.token)
        _ = try await seedProgram(name: "Evidence strength", activated: "2026-10-06T12:00:00.000Z", token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["program.nextWorkout"], in: app)
        XCTAssertTrue(app.navigationBars["Next workout"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Evidence strength: Pull"].waitForExistence(timeout: 10))
        capture(app, "program-estimate-summary")
        let estimate = app.staticTexts["Estimated 1RM used"]
        reveal(estimate, in: app)
        XCTAssertTrue(estimate.exists)
        capture(app, "program-estimate")
        let caveat = app.staticTexts["RIR was not recorded for this set. The estimate assumes your target of 2 RIR."]
        reveal(caveat, in: app)
        XCTAssertTrue(caveat.exists)
        capture(app, "program-estimate-caveat")
        reveal(app.buttons["program.source.deadlift"], in: app)
        capture(app, "program-estimate-assumption")
        tap(app.buttons["program.source.deadlift"], in: app)
        XCTAssertTrue(app.navigationBars["Latest program evidence"].waitForExistence(timeout: 10))
        capture(app, "program-estimate-source")
        tap(app.navigationBars.buttons.firstMatch, in: app)
        tap(app.buttons["Close"], in: app)
        revealAbove(app.buttons["training.start"], in: app)
        XCTAssertTrue(app.buttons["training.start"].exists)
    }

    private func seedProgram(name: String, activated: String? = nil, token: String) async throws -> (id: String, payload: [String: Any]) {
        let id = UUID().uuidString
        var payload: [String: Any] = ["id": id, "name": name, "cycles": 2, "deload": "none", "createdAt": "2026-10-01T12:00:00.000Z",
            "days": [["id": UUID().uuidString, "name": "Pull", "slots": [["id": UUID().uuidString, "exerciseID": "deadlift", "notes": "",
                "target": ["sets": 3, "minReps": 5, "maxReps": 8, "rir": 2, "kind": "standard"],
                "cycleTargets": [String: Any](), "expandRepRange": false, "weightMatch": true]]]]]
        if let activated { payload["activatedAt"] = activated }
        _ = try await request("PUT", "/v1/documents/program/\(id)", body: ["base_revision": 0, "payload": payload], token: token)
        return (id, payload)
    }

    private func seedProgramProposal(program: [String: Any], token: String) async throws -> String {
        let id = try XCTUnwrap(program["id"] as? String)
        var after = program
        var days = try XCTUnwrap(after["days"] as? [[String: Any]])
        var slots = try XCTUnwrap(days[0]["slots"] as? [[String: Any]])
        var target = try XCTUnwrap(slots[0]["target"] as? [String: Any])
        target["rir"] = 3
        slots[0]["target"] = target
        days[0]["slots"] = slots
        after["days"] = days
        let created = try await request("POST", "/v1/tokens", body: ["name": "Synthetic program coach", "scopes": ["propose"], "expires_in_days": 7], token: token)
        let secret = try XCTUnwrap(created["token"] as? String)
        let envelope = try await request("POST", "/mcp", body: ["jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": ["name": "propose", "arguments": [
            "title": "Leave more reps in reserve", "summary": "Review a change to future workout targets.", "confidence": "low",
            "falsifier": "The current effort target already matches your preference.",
            "evidence": [["claim": "A preference to review, without a performance diagnosis.", "level": "anecdote", "dataRefs": [["kind": "program", "id": id]]]],
            "changes": [["kind": "program", "id": id, "after": after]]]]], token: secret)
        let result = try XCTUnwrap(envelope["result"] as? [String: Any])
        XCTAssertNotEqual(result["isError"] as? Bool, true)
        let content = try XCTUnwrap((result["content"] as? [[String: Any]])?.first?["text"] as? String)
        let proposal = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any])
        let proposalID = try XCTUnwrap(proposal["proposal_id"] as? String)
        return try XCTUnwrap(UUID(uuidString: proposalID)).uuidString
    }

    private func configureProgramDay(_ app: XCUIApplication, name: String, exercise: String, override: Bool) throws {
        replace(app.descendants(matching: .any).matching(identifier: "program.dayName").firstMatch, with: name, in: app)
        dismissKeyboard(app)
        tap(app.buttons["program.addExercise"], in: app)
        tap(app.searchFields.firstMatch, in: app)
        app.searchFields.firstMatch.typeText(exercise + "\n")
        tap(app.buttons["Add \(exercise)"], in: app)
        tap(app.staticTexts[exercise], in: app)
        tap(app.buttons["program.editTargets"], in: app)
        replace(app.textFields["Sets"], with: "1", in: app)
        dismissKeyboard(app)
        replace(app.textFields["Minimum reps"], with: "5", in: app)
        dismissKeyboard(app)
        replace(app.textFields["Maximum reps"], with: "5", in: app)
        dismissKeyboard(app)
        capture(app, "program-targets-\(name)")
        tap(app.buttons["program.applyTargets"], in: app)
        if override {
            tap(app.buttons["program.addOverride"], in: app)
            tap(app.buttons["program.override.0"], in: app)
            replace(app.textFields["Reps in reserve"], with: "3", in: app)
            dismissKeyboard(app)
            capture(app, "program-cycle-override")
            tap(app.buttons["program.applyTargets"], in: app)
        }
        tap(app.navigationBars.buttons.firstMatch, in: app)
    }

    func testEntryCheckAfterManualFinishCanBeRejectedOfflineWithoutReturning() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "entry-check")
        let session = try await seedTrainingWorkout(name: "Entry check workout", loads: [100, 100, 100],
                                                   finished: false, token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Train"], in: app)
        XCTAssertTrue(app.navigationBars["Entry check workout"].waitForExistence(timeout: 20))
        try await control(["offline": true])
        tap(app.buttons["Edit set 3, Deadlift"], in: app)
        replace(app.textFields["training.load.0"], with: "1000", in: app)
        dismissKeyboard(app)
        tap(app.buttons["training.saveSet"], in: app)
        tap(app.buttons["training.finish"], in: app)
        tap(app.buttons["Save workout"], in: app)
        tap(app.buttons["suggestions.open"], in: app)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "suggestions.proposal.")).firstMatch
        reveal(row, in: app)
        guard row.waitForExistence(timeout: 15) else { return XCTFail("Finished workout should offer its entry check") }
        let rowID = row.identifier
        capture(app, "entry-check-inbox")
        tap(row, in: app)
        reveal(app.staticTexts["Before: 1000 kg"], in: app)
        XCTAssertTrue(app.staticTexts["Before: 1000 kg"].exists)
        reveal(app.staticTexts["After: 100 kg"], in: app)
        XCTAssertTrue(app.staticTexts["After: 100 kg"].exists)
        capture(app, "entry-check-diff")
        let basis = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "other working sets of Deadlift in this workout")).firstMatch
        reveal(basis, in: app)
        XCTAssertTrue(basis.exists)
        capture(app, "entry-check-evidence")
        tap(app.buttons["evidence.workout.\(session)"], in: app)
        reveal(app.staticTexts["1000 kg × 5 reps"], in: app)
        XCTAssertTrue(app.staticTexts["1000 kg × 5 reps"].exists)
        capture(app, "entry-check-original-workout")
        tap(app.navigationBars.buttons.firstMatch, in: app)
        tap(app.buttons["suggestions.reject"], in: app)
        XCTAssertFalse(app.buttons["suggestions.accept"].exists)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--ui-testing" }
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["suggestions.open"], in: app)
        let empty = app.staticTexts["suggestions.pendingSummary"]
        reveal(empty, in: app)
        XCTAssertEqual(empty.label, "You're up to date")
        tap(app.buttons[rowID], in: app)
        let status = app.staticTexts["suggestions.status"]
        reveal(status, in: app)
        XCTAssertTrue(status.label.contains("Rejected"))
        capture(app, "entry-check-rejected-relaunch")
        try await control([:])
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let saved = try await request("GET", "/v1/documents/workout_session/\(session)", token: person.token)
        let exercises = try XCTUnwrap((saved["payload"] as? [String: Any])?["exercises"] as? [[String: Any]])
        let sets = try XCTUnwrap(exercises.first?["sets"] as? [[String: Any]])
        let efforts = try XCTUnwrap(sets.last?["efforts"] as? [[String: Any]])
        XCTAssertEqual((efforts.first?["load"] as? [String: Any])?["value"] as? Double, 1000)
    }

    func testEntryChecksOffKeepsManualFinishAndPersistsAcrossRelaunch() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "checks-off")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["observations.open"], in: app)
        reveal(app.staticTexts["observations.empty"], in: app)
        XCTAssertTrue(app.staticTexts["observations.empty"].exists)
        capture(app, "observations-sparse")
        let toggle = app.switches["observations.entryChecks"]
        reveal(toggle, in: app)
        // iOS 18 exposes the label and switch as one wide accessibility row.
        // Tap the actual switch at its trailing edge.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
        capture(app, "entry-checks-off")
        _ = try await seedTrainingWorkout(name: "Manual with checks off", loads: [100, 100, 1000],
                                          finished: false, token: person.token)
        tap(app.navigationBars.buttons.firstMatch, in: app)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        tap(app.buttons["account.syncNow"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        tap(app.buttons["Train"], in: app)
        XCTAssertTrue(app.navigationBars["Manual with checks off"].waitForExistence(timeout: 20))
        try await control(["offline": true])
        tap(app.buttons["training.finish"], in: app)
        tap(app.buttons["Save workout"], in: app)
        tap(app.buttons["observations.open"], in: app)
        tap(app.buttons["observations.suggestions"], in: app)
        reveal(app.staticTexts["suggestions.pendingSummary"], in: app)
        XCTAssertEqual(app.staticTexts["suggestions.pendingSummary"].label, "You're up to date")
        capture(app, "entry-checks-off-manual-saved")
        app.terminate()
        app.launchArguments.removeAll { $0 == "--ui-testing" }
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["observations.open"], in: app)
        reveal(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
        capture(app, "entry-checks-off-relaunch")
        try await control([:])
    }

    func testTrainingObservationsLinkToLogsAndShowMissingSourceData() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "observations")
        var sessions: [String] = []
        for days in [30, 24, 18, 13, 6, 2] {
            sessions.append(try await seedTrainingWorkout(name: "Evidence workout \(days)", loads: [days < 10 ? 85 : 100],
                                                          daysAgo: days, exercises: ["deadlift", "barbell-bench-press"], token: person.token))
        }
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["observations.open"], in: app)
        let stall = app.buttons["observations.stall.deadlift"]
        reveal(stall, in: app)
        XCTAssertTrue(stall.waitForExistence(timeout: 20))
        capture(app, "observations-findings")
        let deload = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "observations.deload.")).firstMatch
        tap(deload, in: app)
        capture(app, "observations-deload")
        tap(app.navigationBars.buttons.firstMatch, in: app)
        revealAbove(stall, in: app)
        tap(stall, in: app)
        let caveat = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "RIR not recorded")).firstMatch
        reveal(caveat, in: app)
        XCTAssertTrue(caveat.exists)
        capture(app, "observations-stall-evidence")
        tap(app.buttons["evidence.exercise.deadlift"], in: app)
        reveal(app.staticTexts["Best estimated 1RM"], in: app)
        capture(app, "observations-exercise-summary")
        reveal(app.staticTexts["RIR not recorded"].firstMatch, in: app)
        XCTAssertTrue(app.staticTexts["Bodyweight not recorded"].firstMatch.exists)
        capture(app, "observations-exercise-log")
        tap(app.buttons["exerciseLog.workout.\(sessions.last!)"], in: app)
        XCTAssertTrue(app.navigationBars["Evidence workout 2"].waitForExistence(timeout: 10))
        capture(app, "observations-source-workout")
        tap(app.navigationBars.buttons.firstMatch, in: app)
        for id in sessions {
            _ = try await request("DELETE", "/v1/documents/workout_session/\(id)", body: ["base_revision": 1], token: person.token)
        }
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        tap(app.buttons["account.syncNow"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        tap(app.buttons["Train"], in: app)
        XCTAssertTrue(app.staticTexts["No working sets saved"].waitForExistence(timeout: 10))
        capture(app, "observations-missing-logs")
        tap(app.navigationBars.buttons.firstMatch, in: app)
        let unavailable = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Cannot verify from saved data")).firstMatch
        reveal(unavailable, in: app)
        XCTAssertTrue(unavailable.exists)
        capture(app, "observations-unverifiable-evidence")
    }

    private func seedTrainingWorkout(name: String, loads: [Double], finished: Bool = true, daysAgo: Int = 0,
                                     exercises: [String] = ["deadlift"], token: String) async throws -> String {
        let id = UUID().uuidString
        let date = Date().addingTimeInterval(Double(-daysAgo * 86400) - 3600)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var payload: [String: Any] = [
            "id": id, "name": name, "notes": "", "startedAt": formatter.string(from: date), "timeZoneID": "America/New_York",
            "exercises": exercises.map { exercise -> [String: Any] in
                ["id": UUID().uuidString, "exerciseID": exercise, "notes": "", "sets": loads.enumerated().map { index, load -> [String: Any] in
                    ["id": UUID().uuidString, "kind": "standard", "completedAt": formatter.string(from: date.addingTimeInterval(Double(60 + index * 120))),
                     "efforts": [["reps": 5, "load": ["unit": "kg", "value": load]]]]
                }]
            }
        ]
        if finished { payload["endedAt"] = formatter.string(from: date.addingTimeInterval(1800)) }
        _ = try await request("PUT", "/v1/documents/workout_session/\(id)", body: ["base_revision": 0, "payload": payload], token: token)
        return id
    }

    func testAgentSuggestionReviewOfflineAcceptanceUndoRejectionAndAudit() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "agent-review")
        let correction = try await seedAgentProposal(title: "Check the deadlift load", token: person.token)
        let rejected = try await seedAgentProposal(title: "Another load suggestion", token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Train"], in: app)
        reveal(app.buttons["training.start"], in: app)
        capture(app, "agents-training-entry")
        tap(app.buttons["suggestions.open"], in: app)
        let correctionRow = app.buttons["suggestions.proposal.\(correction.proposalID)"]
        reveal(correctionRow, in: app)
        XCTAssertTrue(correctionRow.waitForExistence(timeout: 20))
        capture(app, "suggestions-inbox")
        tap(correctionRow, in: app)
        capture(app, "suggestions-review-title")
        reveal(app.staticTexts["Before: 1500 kg"], in: app)
        XCTAssertTrue(app.staticTexts["Before: 1500 kg"].exists)
        reveal(app.staticTexts["After: 150 kg"], in: app)
        XCTAssertTrue(app.staticTexts["After: 150 kg"].exists)
        capture(app, "suggestions-before-after")
        let mismatch = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Does not match saved data")).firstMatch
        reveal(mismatch, in: app)
        XCTAssertTrue(mismatch.exists)
        capture(app, "suggestions-evidence-mismatch")
        reveal(app.staticTexts["You confirm that the original load is correct."], in: app)
        capture(app, "suggestions-falsifier")
        try await control(["offline": true])
        tap(app.buttons["suggestions.accept"], in: app)
        XCTAssertTrue(app.buttons["suggestions.undo"].waitForExistence(timeout: 5))
        capture(app, "suggestions-accepted-offline")

        app.terminate()
        app.launchArguments.removeAll { $0 == "--ui-testing" }
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["suggestions.open"], in: app)
        tap(correctionRow, in: app)
        reveal(app.buttons["suggestions.undo"], in: app)
        XCTAssertTrue(app.buttons["suggestions.undo"].exists)
        try await control([:])
        tap(app.navigationBars.buttons["Suggestions"], in: app)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        try await assertWorkoutLoad(150, id: correction.sessionID, token: person.token)
        tap(app.buttons["Train"], in: app)
        tap(correctionRow, in: app)
        tap(app.buttons["suggestions.undo"], in: app)
        XCTAssertFalse(app.buttons["suggestions.accept"].exists)
        XCTAssertFalse(app.buttons["suggestions.undo"].exists)
        try await assertWorkoutLoad(1500, id: correction.sessionID, token: person.token)
        tap(app.navigationBars.buttons["Suggestions"], in: app)
        revealAbove(app.buttons["suggestions.proposal.\(rejected.proposalID)"], in: app)
        tap(app.buttons["suggestions.proposal.\(rejected.proposalID)"], in: app)
        tap(app.buttons["suggestions.reject"], in: app)
        XCTAssertFalse(app.buttons["suggestions.accept"].exists)
        try await assertWorkoutLoad(1500, id: rejected.sessionID, token: person.token)
        tap(app.navigationBars.buttons["Suggestions"], in: app)
        revealAbove(app.buttons["suggestions.audit"], in: app)
        tap(app.buttons["suggestions.audit"], in: app)
        XCTAssertTrue(app.staticTexts["Suggestion rejected"].waitForExistence(timeout: 10))
        capture(app, "suggestions-audit")
        reveal(app.staticTexts["Suggestion undone"], in: app)
        XCTAssertTrue(app.staticTexts["Suggestion undone"].exists)
        reveal(app.staticTexts["Suggestion accepted"], in: app)
        XCTAssertTrue(app.staticTexts["Suggestion accepted"].exists)
    }

    func testStaleAgentSuggestionPreservesLaterWorkoutEdits() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "agent-stale")
        let suggestion = try await seedAgentProposal(title: "An outdated load suggestion", token: person.token)
        let path = "/v1/documents/workout_session/\(suggestion.sessionID)"
        let stored = try await request("GET", path, token: person.token)
        var payload = try XCTUnwrap(stored["payload"] as? [String: Any])
        payload["notes"] = "Later manual note to preserve"
        _ = try await request("PUT", path, body: ["base_revision": try XCTUnwrap(stored["revision"]), "payload": payload], token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Train"], in: app)
        tap(app.buttons["suggestions.open"], in: app)
        tap(app.buttons["suggestions.proposal.\(suggestion.proposalID)"], in: app)
        tap(app.buttons["suggestions.accept"], in: app)
        XCTAssertTrue(app.staticTexts["suggestions.error"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["suggestions.error"], in: app)
        XCTAssertFalse(app.buttons["suggestions.accept"].exists)
        capture(app, "suggestions-stale")
        let unchanged = try await request("GET", path, token: person.token)
        XCTAssertEqual((unchanged["payload"] as? [String: Any])?["notes"] as? String, "Later manual note to preserve")
        try await assertWorkoutLoad(1500, id: suggestion.sessionID, token: person.token)
    }

    func testAgentConnectionDefaultsToProposalsAndCanBeRevoked() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "agent-access")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.agents"], in: app)
        capture(app, "agents-empty")
        tap(app.buttons["agents.create"], in: app)
        replace(app.textFields["agents.name"], with: "Morgan's agent", in: app)
        dismissKeyboard(app)
        reveal(app.buttons["agents.permission"], in: app)
        XCTAssertTrue(app.buttons["agents.permission"].label.contains("Read and propose"))
        capture(app, "agents-propose-form")
        tap(app.buttons["agents.confirmCreate"], in: app)
        XCTAssertTrue(app.navigationBars["Save your token"].waitForExistence(timeout: 15))
        reveal(app.staticTexts["Token hidden"], in: app)
        XCTAssertTrue(app.staticTexts["Token hidden"].exists)
        reveal(app.buttons["agents.copyToken"], in: app)
        XCTAssertTrue(app.buttons["agents.copyToken"].exists)
        // Never reveal or capture a token in a UI attachment or test log.
        tap(app.buttons["agents.tokenDone"], in: app)
        let tokens = try await requestArray("GET", "/v1/tokens", token: person.token)
        let token = try XCTUnwrap(tokens.first)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(Set(token["scopes"] as? [String] ?? []), Set(["read", "propose"]))
        XCTAssertNil(token["token"])
        let id = try XCTUnwrap(token["id"] as? String)
        let revoke = app.buttons["agents.revoke.\(id)"]
        reveal(revoke, in: app)
        capture(app, "agents-connected")
        tap(revoke, in: app)
        capture(app, "agents-revoke-confirmation")
        tap(app.alerts.buttons["Cancel"], in: app)
        XCTAssertTrue(revoke.exists)
        tap(revoke, in: app)
        tap(app.alerts.buttons["Revoke access"], in: app)
        XCTAssertTrue(app.staticTexts["No connected agents"].waitForExistence(timeout: 15))
        let remaining = try await requestArray("GET", "/v1/tokens", token: person.token)
        XCTAssertTrue(remaining.isEmpty)

        revealAbove(app.buttons["agents.create"], in: app)
        tap(app.buttons["agents.create"], in: app)
        replace(app.textFields["agents.name"], with: "Direct access check", in: app)
        dismissKeyboard(app)
        tap(app.buttons["agents.permission"], in: app)
        tap(app.buttons["Direct write"], in: app)
        tap(app.buttons["agents.confirmCreate"], in: app)
        XCTAssertTrue(app.alerts["Allow direct changes?"].waitForExistence(timeout: 5))
        capture(app, "agents-direct-write-confirmation")
        tap(app.alerts.buttons["Cancel"], in: app)
        let afterCancel = try await requestArray("GET", "/v1/tokens", token: person.token)
        XCTAssertTrue(afterCancel.isEmpty)
    }

    private func seedAgentProposal(title: String, token: String) async throws -> (sessionID: String, proposalID: String) {
        let sessionID = UUID().uuidString
        func workout(load: Double) -> [String: Any] {
            ["id": sessionID, "name": title, "notes": "", "startedAt": "2026-10-06T14:00:00.000Z",
             "endedAt": "2026-10-06T15:00:00.000Z", "timeZoneID": "America/New_York",
             "bodyweight": ["unit": "kg", "value": 80], "exercises": [[
                "id": UUID().uuidString, "exerciseID": "deadlift", "notes": "", "sets": [[
                    "id": UUID().uuidString, "kind": "standard", "rir": 2,
                    "completedAt": "2026-10-06T14:15:00.000Z", "efforts": [["reps": 3, "load": ["unit": "kg", "value": load]]]
                ]]
             ]]]
        }
        let before = workout(load: 1500)
        _ = try await request("PUT", "/v1/documents/workout_session/\(sessionID)", body: ["base_revision": 0, "payload": before], token: token)
        var after = before
        var exercises = try XCTUnwrap(after["exercises"] as? [[String: Any]])
        var sets = try XCTUnwrap(exercises[0]["sets"] as? [[String: Any]])
        sets[0]["efforts"] = [["reps": 3, "load": ["unit": "kg", "value": 150]]]
        exercises[0]["sets"] = sets
        after["exercises"] = exercises
        let created = try await request("POST", "/v1/tokens", body: ["name": "Synthetic coach", "scopes": ["propose"], "expires_in_days": 7], token: token)
        let secret = try XCTUnwrap(created["token"] as? String)
        let envelope = try await request("POST", "/mcp", body: [
            "jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": ["name": "propose", "arguments": [
                "title": title, "summary": "Review a possible extra zero in the recorded load.", "confidence": "medium",
                "falsifier": "You confirm that the original load is correct.",
                "evidence": [["claim": "This claim deliberately differs from the saved workout.", "level": "personalData",
                              "caveats": ["A single session cannot establish a trend."], "dataRefs": [["kind": "workout_session", "id": sessionID]],
                              "metric": ["name": "exercise.e1rm.best", "parameters": ["exercise": "deadlift", "from": "2026-10-01", "through": "2026-10-31"], "claimed": 1]]],
                "changes": [["kind": "workout_session", "id": sessionID, "after": after]]
            ]]
        ], token: secret)
        let result = try XCTUnwrap(envelope["result"] as? [String: Any])
        XCTAssertNotEqual(result["isError"] as? Bool, true)
        let text = try XCTUnwrap((result["content"] as? [[String: Any]])?.first?["text"] as? String)
        let proposal = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let id = try XCTUnwrap(proposal["proposal_id"] as? String)
        return (sessionID, try XCTUnwrap(UUID(uuidString: id)).uuidString)
    }

    private func assertWorkoutLoad(_ expected: Double, id: String, token: String) async throws {
        var load: Double?
        for _ in 0..<30 {
            let result = try await request("GET", "/v1/documents/workout_session/\(id)", token: token)
            let exercises = (result["payload"] as? [String: Any])?["exercises"] as? [[String: Any]]
            let sets = exercises?.first?["sets"] as? [[String: Any]]
            let efforts = sets?.first?["efforts"] as? [[String: Any]]
            load = (efforts?.first?["load"] as? [String: Any])?["value"] as? Double
            if load == expected { break }
            try await Task.sleep(for: .milliseconds(300))
        }
        XCTAssertEqual(load, expected)
    }

    private func createAccount(prefix: String, units: String = "metric") async throws -> (email: String, token: String) {
        let email = "\(prefix)-\(UUID().uuidString.prefix(8).lowercased())@exerly.test"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": "Simulator-Test-123!", "name": "Morgan"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Morgan", "age": 34, "gender": "female", "sex": "female", "height": 167.5, "weight": 72.25,
            "goal": "maintain", "activityLevel": "light", "unitSystem": units, "timezone": "America/New_York"
        ], token: token)
        return (email, token)
    }

    private func signIn(_ app: XCUIApplication, email: String) {
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        dismissPasswordPrompt(in: app)
    }

    func testTrainingSessionSurvivesRelaunchAndPrefillsTheNextWorkout() async throws {
        try await control([:])
        let email = "training-\(UUID().uuidString.lowercased())@exerly.test"
        let signup = try await request("POST", "/signup", body: ["email": email, "password": "Simulator-Test-123!", "name": "Morgan"])
        let token = try XCTUnwrap(signup["token"] as? String)
        _ = try await request("POST", "/api/onboarding/complete", body: [
            "name": "Morgan", "age": 34, "gender": "female", "sex": "female", "height": 167.5, "weight": 72.25,
            "goal": "maintain", "activityLevel": "light", "unitSystem": "metric", "timezone": "America/New_York"
        ], token: token)
        let app = launch(resetSession: true)
        tap(app.buttons["I already have an account"], in: app)
        replace(app.textFields["Email"], with: email, in: app)
        replace(app.secureTextFields["Password"], with: "Simulator-Test-123!", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Log In"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        capture(app, "training-home")
        tap(app.buttons["Train"], in: app)
        capture(app, "training-empty")
        tap(app.buttons["training.start"], in: app)
        tap(app.buttons["training.confirmStart"], in: app)
        tap(app.buttons["training.addExercise"], in: app)
        let search = app.searchFields.firstMatch
        tap(search, in: app)
        search.typeText("barbell bench press")
        tap(app.buttons["Add Barbell Bench Press"], in: app)
        tap(app.buttons["Edit set 1, Barbell Bench Press"], in: app)
        replace(app.textFields["training.load.0"], with: "40.5", in: app)
        capture(app, "design-training-keypad")
        tap(app.buttons["exerly.keypadDone"], in: app)
        replace(app.textFields["training.reps.0"], with: "8", in: app)
        dismissKeyboard(app)
        tap(app.buttons["training.saveSet"], in: app)
        tap(app.buttons["Complete set 1, Barbell Bench Press"], in: app)
        XCTAssertTrue(app.buttons["Reopen set 1, Barbell Bench Press"].exists)
        capture(app, "training-completed-set")

        app.terminate(); app.launchArguments.removeAll { $0 == "--ui-testing" }; app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 20))
        tap(app.buttons["Train"], in: app)
        XCTAssertTrue(app.buttons["Reopen set 1, Barbell Bench Press"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["40.5 kg × 8 reps"].exists)
        tap(app.buttons["training.finish"], in: app)
        tap(app.buttons["Save workout"], in: app)
        XCTAssertTrue(app.navigationBars["Training"].waitForExistence(timeout: 10))
        tap(app.buttons["training.start"], in: app)
        tap(app.buttons["training.confirmStart"], in: app)
        tap(app.buttons["training.addExercise"], in: app)
        tap(app.searchFields.firstMatch, in: app)
        app.searchFields.firstMatch.typeText("barbell bench press")
        tap(app.buttons["Add Barbell Bench Press"], in: app)
        XCTAssertTrue(app.staticTexts["Previous: 40.5 kg × 8 reps"].exists)
        tap(app.buttons["Complete set 1, Barbell Bench Press"], in: app)
        XCTAssertTrue(app.buttons["Reopen set 1, Barbell Bench Press"].exists)
        capture(app, "training-prefilled-one-tap")
    }

    func testFractionalFoodSnapshotSurvivesNativePortionAndNutritionEdits() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "food-precision")
        let seeded = try await seedNutritionEntry(token: person.token, name: "Precise oats",
            nutrients: ["energy": 99.5, "protein": 3.3333, "sodium": 123.4567], grams: 150)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["nutrition.entry.\(seeded.id)"], in: app)
        replace(app.textFields["Amount (g)"], with: "75", in: app)
        dismissKeyboard(app)
        capture(app, "food-native-three-quarter-portion")
        tap(app.buttons["nutrition.saveEntry"], in: app)
        tap(app.buttons["Library"], in: app)
        tap(app.buttons["nutrition.libraryFood.\(seeded.foodID)"], in: app)
        tap(app.buttons["nutrition.libraryActions"], in: app)
        tap(app.buttons["nutrition.libraryEdit"], in: app)
        replace(app.textFields["Energy (kcal)"], with: "200.5", in: app)
        dismissKeyboard(app)
        tap(app.buttons["nutrition.saveFood"], in: app)
        tap(app.buttons["nutrition.libraryLog"], in: app)
        XCTAssertEqual(app.textFields["Amount (g)"].value as? String, "75")
        tap(app.buttons["nutrition.saveEntry"], in: app)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        tap(app.buttons["account.syncNow"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let entries = documents.filter { $0["kind"] as? String == "food_entry" }.compactMap { $0["payload"] as? [String: Any] }
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.allSatisfy { $0["grams"] as? Double == 75 })
        let old = try XCTUnwrap(entries.first { $0["id"] as? String == seeded.id })
        let oldNutrients = try XCTUnwrap((old["food"] as? [String: Any])?["per100g"] as? [String: Any])
        XCTAssertEqual(oldNutrients["energy"] as? Double, 99.5, "Label corrections must not rewrite a logged snapshot")
        XCTAssertEqual(oldNutrients["protein"] as? Double, 3.3333)
        XCTAssertEqual(oldNutrients["sodium"] as? Double, 123.4567)
        let new = try XCTUnwrap(entries.first { $0["id"] as? String != seeded.id })
        let newNutrients = try XCTUnwrap((new["food"] as? [String: Any])?["per100g"] as? [String: Any])
        XCTAssertEqual(newNutrients["energy"] as? Double, 200.5)
        XCTAssertEqual(newNutrients["protein"] as? Double, 3.3333)
        XCTAssertEqual(newNutrients["sodium"] as? Double, 123.4567)
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
        XCTAssertTrue(app.buttons["diary.selected-day"].waitForExistence(timeout: 15))
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
        let selected = app.buttons["diary.selected-day"]
        XCTAssertTrue(selected.waitForExistence(timeout: 10))
        XCTAssertEqual(selected.value as? String, expectedDay)
        capture(app, "calendar-account-today")
        tap(app.buttons["nutrition.dailyHealth"], in: app)
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
        XCTAssertEqual(app.buttons["diary.selected-day"].value as? String, expectedDay)
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
        tap(app.buttons["nutrition.dailyHealth"], in: app)
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
        tap(app.buttons["nutrition.dailyHealth"], in: app)
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
        tap(app.buttons["nutrition.dailyHealth"], in: app)
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
        tap(app.buttons["nutrition.dailyHealth"], in: app)
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
        tap(app.buttons["nutrition.dailyHealth"], in: app)
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
        tap(app.buttons["Progress"], in: app)
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
        tap(app.buttons["Progress"], in: app)
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
        tap(app.buttons["Progress"], in: app)
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
        tap(app.buttons["Progress"], in: app)
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
        tap(app.buttons["Progress"], in: app)
        tap(app.buttons["Log weight"], in: app)
        XCTAssertTrue(app.textFields["weight.value"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["weight.value"].value as? String, "72.8")
        capture(app, "weight-browser-return")
        tap(app.buttons["Cancel"], in: app)
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["Progress"], in: app)
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
        tap(app.buttons["nutrition.dailyHealth"], in: app)
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
        tap(app.buttons["nutrition.dailyHealth"], in: app)
        reveal(total, in: app)
        XCTAssertEqual(total.label, "850 ml")
        app.terminate()
        try await control([:])
        _ = try await request("POST", "/api/water", body: ["entry_date": yesterday, "deltaMl": 300], token: token)
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["nutrition.dailyHealth"], in: app)
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
        let person = try await createAccount(prefix: "day-status")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["Previous day"], in: app)
        let yesterday = try XCTUnwrap(app.buttons["diary.selected-day"].value as? String)
        try await control(["offline": true])
        tap(app.buttons["nutrition.dayStatus"], in: app)
        tap(app.buttons["nutrition.status.complete"], in: app)
        tap(app.buttons["nutrition.confirm"], in: app)
        tap(app.buttons["nutrition.dayActions"], in: app)
        tap(app.buttons["nutrition.editNote"], in: app)
        let note = app.descendants(matching: .any).matching(identifier: "nutrition.dayNote").firstMatch
        replace(note, with: "All meals recorded", in: app)
        dismissKeyboard(app)
        tap(app.buttons["nutrition.saveNote"], in: app)
        reveal(app.staticTexts["All meals recorded"], in: app)
        XCTAssertTrue(app.staticTexts["All meals recorded"].exists)
        capture(app, "diary-status-offline")
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        reveal(app.buttons["nutrition.dayStatus"], in: app)
        XCTAssertTrue(app.buttons["nutrition.dayStatus"].label.contains("Complete log"))
        tap(app.buttons["nutrition.dayActions"], in: app)
        tap(app.buttons["nutrition.editNote"], in: app)
        XCTAssertEqual(note.value as? String, "All meals recorded")
        tap(app.buttons["Cancel"], in: app)
        try await control([:])
        tap(app.buttons["Retry"].firstMatch, in: app)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        tap(app.buttons["account.syncNow"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let days = documents.filter { $0["kind"] as? String == "nutrition_day" }
        XCTAssertEqual(days.count, 1, "The current day must remain untouched")
        let saved = try XCTUnwrap(days.first?["payload"] as? [String: Any])
        XCTAssertEqual(saved["date"] as? String, yesterday)
        XCTAssertEqual(saved["status"] as? String, "complete")
        XCTAssertEqual(saved["notes"] as? String, "All meals recorded")
        app.terminate(); app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        reveal(app.staticTexts["All meals recorded"], in: app)
        XCTAssertTrue(app.staticTexts["All meals recorded"].exists)
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

    func testMealChoiceSurvivesScrollingAndCanBeChangedExplicitly() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "meal-choice")
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tap(app.buttons["nutrition.addFood"], in: app)
        tap(app.buttons["nutrition.barcode"], in: app)
        replace(app.textFields["nutrition.barcodeDigits"], with: "0012345678905", in: app)
        dismissKeyboard(app)
        tap(app.buttons["nutrition.lookupBarcode"], in: app)
        tap(app.buttons["nutrition.barcodeFood"], in: app)
        tap(app.buttons["Dinner"], in: app)
        XCTAssertTrue(app.buttons["Dinner"].isSelected)
        capture(app, "meal-choice-initial-dinner")
        tap(app.buttons["Lunch"], in: app)
        XCTAssertTrue(app.buttons["Lunch"].isSelected)
        capture(app, "meal-choice-lunch")
        tap(app.buttons["Dinner"], in: app)
        reveal(app.buttons["About this food"], in: app)
        revealAbove(app.buttons["Dinner"], in: app)
        XCTAssertTrue(app.buttons["Dinner"].isSelected, "Scrolling must preserve the chosen meal")
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        reveal(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic oat bar")).firstMatch, in: app)
        capture(app, "meal-choice-saved-dinner")
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: person.token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let entries = documents.filter { $0["kind"] as? String == "food_entry" }.compactMap { $0["payload"] as? [String: Any] }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?["meal"] as? String, "Dinner")
        XCTAssertFalse(entries.contains { $0["meal"] as? String == "Lunch" })
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
        XCTAssertTrue(app.buttons["U.S."].isSelected)
        capture(app, "design-setup-us-default")
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
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons["nutrition.addFood"], in: app)
        tap(app.buttons["nutrition.barcode"], in: app)
        replace(app.textFields["nutrition.barcodeDigits"], with: "0012345678905", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Look up barcode"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic oat bar")).firstMatch, in: app)
        replace(app.textFields["Amount (g)"], with: "60", in: app)
        dismissKeyboard(app)
        tap(app.buttons["Dinner"], in: app)
        XCTAssertTrue(app.buttons["Dinner"].isSelected)
        capture(app, "yesterday-dinner-60g")
        reveal(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(app.buttons["Dinner"].isSelected, "Scrolling must not change the meal")
        capture(app, "yesterday-meal-before-save")
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        reveal(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic oat bar")).firstMatch, in: app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic oat bar")).firstMatch.exists)
        capture(app, "yesterday-dinner-logged")

        let login = try await request("POST", "/login", body: ["email": email, "password": password])
        let token = try XCTUnwrap(login["token"] as? String)
        let bootstrap = try await request("GET", "/api/bootstrap", token: token)
        let status = try XCTUnwrap(bootstrap["onboarding"] as? [String: Any])
        XCTAssertEqual(status["complete"] as? Bool, true)
        let program = try await request("GET", "/api/program", token: token)
        XCTAssertEqual(program["goal_type"] as? String, "lose")
        let targetSummary = try await request("GET", "/api/summary", token: token)
        let targets = try XCTUnwrap(targetSummary["targets"] as? [String: Any])
        let expectedEnergy = try XCTUnwrap(targets["calories"] as? Double)
        revealAbove(app.buttons["Back to today"], in: app)
        tap(app.buttons["Back to today"], in: app)
        XCTAssertTrue(app.staticTexts["nutrition.targetEnergy"].waitForExistence(timeout: 15))
        XCTAssertEqual(Double(app.staticTexts["nutrition.targetEnergy"].value as? String ?? ""), expectedEnergy)
        tap(app.buttons["Previous day"], in: app)
        XCTAssertTrue(app.staticTexts["No targets set for this day"].waitForExistence(timeout: 15))

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: yesterday)
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let exported = try await request("GET", "/api/export", token: token)
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let entries = documents.filter { $0["kind"] as? String == "food_entry" }.compactMap { $0["payload"] as? [String: Any] }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?["date"] as? String, day)
        XCTAssertEqual(entries.first?["meal"] as? String, "Dinner")
        XCTAssertEqual(entries.first?["grams"] as? Double, 60)
        let nutrients = try XCTUnwrap((entries.first?["food"] as? [String: Any])?["per100g"] as? [String: Any])
        XCTAssertEqual(nutrients["energy"] as? Double, 412)
        XCTAssertEqual(nutrients["sodium"] as? Double, 240)
        tap(app.buttons["Home"], in: app)

        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic oat bar")).firstMatch, in: app)
        replace(app.textFields["Amount (g)"], with: "30", in: app)
        dismissKeyboard(app)
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))

        try await control(["offline": true])
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Offline. Showing saved account details."].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Get Started"].exists)
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic oat bar")).firstMatch, in: app)
        XCTAssertEqual(app.textFields["Amount (g)"].value as? String, "30")
        replace(app.textFields["Amount (g)"], with: "20", in: app)
        dismissKeyboard(app)
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic oat bar")).firstMatch, in: app)
        XCTAssertEqual(app.textFields["Amount (g)"].value as? String, "20")
        tap(app.buttons["Cancel"], in: app)
        capture(app, "offline-session-preserved")
        try await control([:])
        tap(app.buttons["Retry"].firstMatch, in: app)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 15))
        tap(app.buttons["Previous day"], in: app)
        reveal(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic oat bar")).firstMatch, in: app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic oat bar")).firstMatch.exists)
        capture(app, "reconnected-diary")
        tap(app.buttons["Profile"], in: app)
        tap(app.buttons["profile.sync"], in: app)
        tap(app.buttons["account.syncNow"], in: app)
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout: 20))
        let synced = try await request("GET", "/api/export", token: token)
        let syncedDocs = try XCTUnwrap(synced["documents"] as? [[String: Any]])
        let syncedEntries = syncedDocs.filter { $0["kind"] as? String == "food_entry" }.compactMap { $0["payload"] as? [String: Any] }
        XCTAssertEqual(syncedEntries.count, 1)
        XCTAssertEqual(syncedEntries.first?["id"] as? String, entries.first?["id"] as? String)
        XCTAssertEqual(syncedEntries.first?["grams"] as? Double, 20)
        XCTAssertEqual(syncedEntries.first?["date"] as? String, day)
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
        XCTAssertTrue(app.staticTexts["Offline. Showing saved account details."].waitForExistence(timeout: 15))
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
            tap(app.buttons["U.S., lb and inches"], in: app)
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

    private func launch(resetSession: Bool, legacyToken: String? = nil, accountControls: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = resetSession ? ["--ui-testing"] : []
        if let appearance = ProcessInfo.processInfo.environment["EXERLY_TEST_APPEARANCE"],
           ["light", "dark", "system"].contains(appearance) {
            app.launchArguments += ["-exerlyAppearance", appearance]
        }
        if ProcessInfo.processInfo.environment["EXERLY_TEST_LARGEST_TYPE"] == "1" {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment["EXERLY_API_BASE_URL"] = fixtureURL
        app.launchEnvironment["EXERLY_TEST_STORE_ID"] = UUID().uuidString
        app.launchEnvironment["EXERLY_TEST_LEGACY_TOKEN"] = legacyToken
        app.launchEnvironment["EXERLY_TEST_ACCOUNT_CONTROLS"] = accountControls
        app.launch()
        return app
    }
    @discardableResult
    private func dismissPasswordPrompt(in app: XCUIApplication) -> Bool {
        // Fresh iOS 26 simulators offer to save the synthetic account password.
        // The app's elements still exist behind that system sheet, but none are
        // hittable. Handle only this prompt, leaving permission dialogs testable.
        let passwordSheet = app.sheets["Save Password?"]
        if passwordSheet.exists && passwordSheet.buttons["Not Now"].exists {
            passwordSheet.buttons["Not Now"].tap()
            return true
        } else {
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let passwordPrompt = springboard.alerts.matching(NSPredicate(format: "label CONTAINS %@", "Save Password")).firstMatch
            if passwordPrompt.exists && passwordPrompt.buttons["Not Now"].exists {
                passwordPrompt.buttons["Not Now"].tap()
                return true
            }
        }
        return false
    }
    private func revealAbove(_ element: XCUIElement, in app: XCUIApplication) {
        // A full-app swipe starts inside the saved-account banner at large
        // text sizes on SE. Keep upward-list navigation in the visible list too.
        for _ in 0..<24 where !element.exists {
            let bar = app.navigationBars.allElementsBoundByAccessibilityElement.last ?? app.navigationBars.firstMatch
            let home = app.buttons["Home"]
            let top = max(bar.exists ? bar.frame.maxY + 16 : 48, scrollViewport(in: app)?.minY ?? 0)
            let bottom = home.exists && home.isHittable ? home.frame.minY - 18 : app.frame.height - 38
            let height = max(80, bottom - top)
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (top + height * 0.16) / app.frame.height))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (top + height * 0.84) / app.frame.height))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        reveal(element, in: app)
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        dismissPasswordPrompt(in: app)
        if !element.exists { _ = element.waitForExistence(timeout: 5) }
        func visibleFrame(_ item: XCUIElement) -> Bool {
            guard item.exists else { return false }
            let frame = item.frame
            return !frame.isEmpty && !frame.isNull && !frame.isInfinite && app.frame.intersects(frame)
        }
        // Virtualized rows and dismissing sheets can expose an accessibility
        // element before it has a usable frame. Asking isHittable then causes
        // XCTest to abort all subsequent event delivery for this test.
        if (app.keyboards.firstMatch.exists || app.buttons["exerly.keypadDone"].exists) &&
            (!visibleFrame(element) || !element.isHittable) && app.buttons["Done"].firstMatch.exists {
            app.buttons["Done"].firstMatch.tap()
        }
        for _ in 0..<48 {
            // The system can present the sheet after the diary first appears.
            dismissPasswordPrompt(in: app)
            let home = app.buttons["Home"]
            // Identify native tab controls by their container. iOS can expose
            // the tab's symbol as its element label, which made the old label
            // allowlist drag the content 48 times before tapping a visible tab.
            if visibleFrame(element) && element.isHittable,
               app.tabBars.buttons.allElementsBoundByAccessibilityElement.contains(where: { $0.exists && $0.frame == element.frame }) { return }
            // Stacked sheets expose the diary's navigation bar as well as
            // their own. Find the control in any bar instead of assuming
            // the last accessibility node is the frontmost navigation bar.
            if visibleFrame(element) && element.isHittable,
               app.navigationBars.buttons.allElementsBoundByAccessibilityElement.contains(where: { $0.exists && $0.frame == element.frame }) { return }
            let lowerEdge = visibleFrame(home) && home.isHittable ? home.frame.minY - 10 : app.frame.height - 30
            let bar = app.navigationBars.allElementsBoundByAccessibilityElement.last ?? app.navigationBars.firstMatch
            // The saved-account notice is outside the navigation stack. Its
            // Retry button is already visible above the bar; scrolling the
            // diary cannot move it into the list's bounds.
            if visibleFrame(element), element.isHittable, element.label == "Retry", bar.exists,
               element.frame.maxY < bar.frame.minY { return }
            if visibleFrame(element) && element.isHittable && bar.exists,
               element.frame.minY >= bar.frame.minY, element.frame.maxY <= bar.frame.maxY { return }
            // The compact date controls sit just below the navigation bar.
            // A 56-point exclusion zone made the helper scroll a fully visible
            // control repeatedly. Check its center below the actual bar.
            let upperEdge = bar.exists ? bar.frame.maxY + 12 : 40
            if visibleFrame(element) && element.frame.midY > upperEdge && element.frame.midY < lowerEdge && element.isHittable { return }
            // A full-screen swipe can jump from below the SE's tab bar to
            // above its navigation bar. Short drags avoid that oscillation.
            // Keep the gesture inside the scrolling area. A large-type account
            // notice or the fixed Progress choices can occupy its upper half.
            let viewport = scrollViewport(in: app)
            let top = max(upperEdge, viewport?.minY ?? upperEdge) + 8
            let bottom = min(lowerEdge, viewport?.maxY ?? lowerEdge) - 8
            let down = element.exists && element.frame.height > 0 && element.frame.midY < top
            let height = max(80, bottom - top)
            let distance = element.exists ? 0.16 : 0.34
            let low = top + height * (0.5 - distance)
            let high = top + height * (0.5 + distance)
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (down ? low : high) / app.frame.height))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (down ? high : low) / app.frame.height))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
    }
    private func scrollViewport(in app: XCUIApplication) -> CGRect? {
        app.scrollViews.allElementsBoundByAccessibilityElement.compactMap { scroll in
            guard scroll.exists, !scroll.frame.isEmpty, !scroll.frame.isNull,
                  app.frame.intersects(scroll.frame), scroll.isHittable else { return nil }
            return scroll.frame.intersection(app.frame)
        }.max { $0.width * $0.height < $1.width * $1.height }
    }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(element.isHittable, app.debugDescription)
        element.tap()
        // A fresh simulator may show the password sheet between the hittability
        // check and event delivery, swallowing a tab tap. Retry only that known
        // interruption, and only if the original control is still available.
        if dismissPasswordPrompt(in: app), element.exists, element.isHittable {
            element.tap()
        }
    }
    private func replace(_ field: XCUIElement, with text: String, in app: XCUIApplication) {
        // XCTest can call a partly obscured SwiftUI field hittable while its
        // tap point falls in the keyboard toolbar. Reveal the whole field
        // before switching focus, as a person scrolling the editor would.
        if field.exists, app.keyboards.firstMatch.exists,
           field.frame.maxY > app.keyboards.firstMatch.frame.minY - 50 {
            dismissKeyboard(app)
        }
        tap(field, in: app)
        let existing = field.value as? String ?? ""
        // Tapping a populated field can put the caret at its start, including
        // UIKit numeric fields. Select the paragraph before deleting so a
        // replacement cannot silently prepend digits to the old value.
        if !existing.isEmpty && existing != field.placeholderValue {
            field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        }
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count + 3) + text)
        if field.elementType == .textField {
            // Busy CI simulators can drop keystrokes or miss the selection.
            // Retry through the real editing menu and verify the final value.
            for _ in 0..<2 where field.value as? String != text {
                field.press(forDuration: 1.1)
                let selectAll = app.menuItems["Select All"].firstMatch
                let selectAllButton = app.buttons["Select All"].firstMatch
                if selectAll.exists { selectAll.tap() }
                else if selectAllButton.exists { selectAllButton.tap() }
                else { field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap() }
                let count = (field.value as? String ?? "").count
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count + 3))
                for character in text { field.typeText(String(character)) }
            }
            XCTAssertEqual(field.value as? String, text)
        }
    }
    private func dismissKeyboard(_ app: XCUIApplication) {
        if app.buttons["Hide keyboard"].firstMatch.exists { app.buttons["Hide keyboard"].firstMatch.tap() }
        else if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
        else { app.swipeUp() }
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        if name.hasPrefix("design") { Thread.sleep(forTimeInterval: 0.5) }
        if dismissPasswordPrompt(in: app) { Thread.sleep(forTimeInterval: 0.8) }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func selectProgress(_ title: String, in app: XCUIApplication) {
        if app.buttons["progress.section"].exists { tap(app.buttons["progress.section"], in: app) }
        tap(app.buttons[title], in: app)
    }
    private func dismissPhotoPickerIntroduction(in app: XCUIApplication) {
        let introduction = app.otherElements["PXGSingleViewContainerView_AX"]
        if introduction.exists, introduction.label.hasPrefix("Private Access to Photos") {
            let close = introduction.buttons["Close"]
            if close.exists { close.tap() }
        }
    }
    private func control(_ body: [String: Any]) async throws {
        _ = try await request("POST", "/__test/control", body: body)
    }
    private func request(_ method: String, _ path: String, body: [String: Any]? = nil, token: String? = nil) async throws -> [String: Any] {
        let result = try await responseJSON(method, path, body: body, token: token)
        return try XCTUnwrap(result as? [String: Any])
    }
    private func requestArray(_ method: String, _ path: String, token: String) async throws -> [[String: Any]] {
        let result = try await responseJSON(method, path, token: token)
        return try XCTUnwrap(result as? [[String: Any]])
    }
    private func responseJSON(_ method: String, _ path: String, body: [String: Any]? = nil, token: String? = nil) async throws -> Any {
        var request = URLRequest(url: URL(string: fixtureURL + path)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if path == "/mcp" { request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept") }
        request.setValue("isolated-simulator", forHTTPHeaderField: "X-Test-Fixture")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Timezone")
        if method != "GET" { request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertTrue((200..<300).contains((response as! HTTPURLResponse).statusCode), String(data: data, encoding: .utf8) ?? "")
        return try JSONSerialization.jsonObject(with: data)
    }
}
