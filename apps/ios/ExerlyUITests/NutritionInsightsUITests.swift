import XCTest

/// Progress → Nutrition: averages over counted days, every nutrient against
/// its goal, the foods behind each one, and when calories were eaten.
@MainActor
final class NutritionInsightsUITests: ExerlyUITestCase {
    private var designCapture: Bool { ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" }

    /// Only complete, unmarked-with-food and fasting days count; a partial day
    /// doesn't. A nutrient no label reported says so, and a nutrient's foods
    /// add up over the range.
    func testInsightsCountKnownDaysAndNameEachNutrientsFoods() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "nutrition-insights", units: "metric")
        try await seedPlan(token: person.token, startOffset: -30)
        let oats = SeedFood(name: "Rolled oats", per100g: ["energy": 380, "protein": 13, "carbohydrate": 67, "fat": 7, "iron": 4.3])
        let spinach = SeedFood(name: "Spinach", per100g: ["energy": 23, "protein": 2.9, "carbohydrate": 3.6, "fat": 0.4, "iron": 2.7])
        let bar = SeedFood(name: "Protein bar", per100g: ["energy": 350, "protein": 30, "carbohydrate": 40, "fat": 9])
        for food in [oats, spinach, bar] { try await saveFood(food, token: person.token) }
        // Yesterday: complete, 1,016 kcal and 14 mg of iron, 8.6 of it from oats.
        let yesterday = Self.day(-1)
        try await logEntry(oats, grams: 200, on: yesterday, minutes: 30, meal: "Breakfast", token: person.token)   // 760 kcal, 8.6 mg
        try await logEntry(spinach, grams: 200, on: yesterday, minutes: 330, meal: "Lunch", token: person.token)  // 46 kcal, 5.4 mg
        try await logEntry(bar, grams: 60, on: yesterday, minutes: 540, meal: "Snacks", token: person.token)      // 210 kcal, no iron
        try await setStatus("complete", on: yesterday.date, token: person.token)
        // Two days ago: partial, so it stays out.
        let partial = Self.day(-2)
        try await logEntry(bar, grams: 500, on: partial, minutes: 60, meal: "Snacks", token: person.token)
        try await setStatus("partial", on: partial.date, token: person.token)
        // Three days ago: a fast, a real zero.
        try await setStatus("fasting", on: Self.day(-3).date, token: person.token)

        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        openNutrition(in: app)
        selectRange("1W", in: app)

        let coverage = app.descendants(matching: .any)["nutrition.coverage"]
        XCTAssertTrue(coverage.waitForExistence(timeout: 30))
        XCTAssertTrue(waitForLabel(coverage, containing: "2 of 7 days counted"), coverage.label)
        XCTAssertTrue(coverage.label.contains("1 partial"), coverage.label)

        // (760 + 46 + 210) over two counted days, one of them a fast.
        let energy = app.descendants(matching: .any)["nutrition.metric.energy"]
        XCTAssertTrue(energy.waitForExistence(timeout: 10))
        XCTAssertTrue((energy.value as? String ?? "").contains("508 kilocalories"), energy.value as? String ?? "")

        // A tap on the chart's last day picks it, and the page still scrolls afterwards.
        let chart = app.descendants(matching: .any)["nutrition.chart"]
        XCTAssertTrue(chart.exists)
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.6)).tap()
        let readout = app.descendants(matching: .any)["nutrition.readout"]
        XCTAssertTrue(waitForLabel(readout, containing: "Yesterday · Complete"), readout.label)
        XCTAssertTrue(readout.label.contains("1,016 kilocalories"), readout.label)
        tap(app.buttons["nutrition.clearSelection"], in: app)
        XCTAssertTrue(waitForLabel(readout, containing: "Average"), readout.label)

        // Vitamin D has a goal but nothing reported it.
        let vitaminD = app.buttons["nutrition.nutrient.vitaminD"]
        reveal(vitaminD, in: app)
        XCTAssertTrue(vitaminD.label.contains("not reported"), vitaminD.label)

        let iron = app.buttons["nutrition.nutrient.iron"]
        reveal(iron, in: app)
        XCTAssertTrue(iron.label.contains("Iron"), iron.label)
        tap(iron, in: app)
        let first = app.descendants(matching: .any)["nutrition.contributor.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(first.label.hasPrefix("Rolled oats"), first.label)
        XCTAssertTrue(first.label.contains("61 percent"), first.label)
        let second = app.descendants(matching: .any)["nutrition.contributor.1"]
        XCTAssertTrue(second.label.hasPrefix("Spinach"), second.label)
        XCTAssertFalse(app.descendants(matching: .any)["nutrition.contributor.2"].exists, "The bar reports no iron")
        let unreported = app.descendants(matching: .any)["nutrition.detail.unreported"]
        XCTAssertTrue(unreported.exists)
        XCTAssertTrue(unreported.label.contains("1 of 3 entries"), unreported.label)
    }

    func testNutritionInsightsCapture() async throws {
        guard designCapture else { throw XCTSkip("Opt-in visual review") }
        try await control([:])
        let person = try await createAccount(prefix: "nutrition-design", units: "imperial")
        try await seedPlan(token: person.token, startOffset: -70)
        try await seedWeeks(token: person.token, days: 42)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        openNutrition(in: app)
        try await Task.sleep(for: .seconds(2))
        selectRange("1M", in: app)
        _ = app.descendants(matching: .any)["nutrition.chart"].waitForExistence(timeout: 30)
        try await Task.sleep(for: .seconds(1))
        capture(app, "nutrition-01-overview")

        let chart = app.descendants(matching: .any)["nutrition.chart"]
        if chart.exists {
            chart.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.5)).tap()
            try await Task.sleep(for: .seconds(0.6))
            capture(app, "nutrition-02-selected-day")
        }
        app.swipeUp(velocity: .slow)
        try await Task.sleep(for: .seconds(0.5))
        capture(app, "nutrition-03-scrolled")
        app.swipeUp(velocity: .slow)
        try await Task.sleep(for: .seconds(0.5))
        capture(app, "nutrition-04-nutrients")
        app.swipeUp(velocity: .slow)
        try await Task.sleep(for: .seconds(0.5))
        capture(app, "nutrition-05-nutrients")
        app.swipeUp(velocity: .slow)
        try await Task.sleep(for: .seconds(0.5))
        capture(app, "nutrition-06-nutrients")
        app.swipeUp(velocity: .slow)
        try await Task.sleep(for: .seconds(0.5))
        capture(app, "nutrition-07-end")

        let fiber = app.buttons["nutrition.nutrient.fiber"]
        if fiber.exists || fiber.waitForExistence(timeout: 2) {
            reveal(fiber, in: app)
            tap(fiber, in: app)
            try await Task.sleep(for: .seconds(1))
            capture(app, "nutrition-08-fiber")
            app.swipeUp(velocity: .slow)
            try await Task.sleep(for: .seconds(0.5))
            capture(app, "nutrition-09-fiber-foods")
            app.navigationBars.buttons.firstMatch.tap()
            try await Task.sleep(for: .seconds(0.8))
        }
        for _ in 0..<8 { app.swipeDown(velocity: .fast) }
        selectRange("1Y", in: app)
        try await Task.sleep(for: .seconds(1))
        capture(app, "nutrition-10-year")
        selectRange("Yesterday", in: app)
        try await Task.sleep(for: .seconds(1))
        capture(app, "nutrition-11-yesterday")
        selectRange("1W", in: app)
        try await Task.sleep(for: .seconds(1))
        capture(app, "nutrition-12-week")
    }

    // MARK: Navigation

    private func openNutrition(in app: XCUIApplication) {
        for _ in 0..<12 {
            if dismissPasswordPrompt(in: app) { break }
            Thread.sleep(forTimeInterval: 0.25)
        }
        tap(app.buttons["Progress"], in: app)
        if app.buttons["progress.section"].waitForExistence(timeout: 3) {
            tap(app.buttons["progress.section"], in: app)
        }
        tap(app.buttons["Nutrition"].firstMatch, in: app)
    }

    /// Chooses a span from the buttons, or from the menu at accessibility sizes.
    private func selectRange(_ title: String, in app: XCUIApplication) {
        let button = app.buttons["nutrition.range.\(title)"]
        if button.waitForExistence(timeout: 5) {
            tap(button, in: app)
            return
        }
        let menu = app.buttons["nutrition.range"]
        guard menu.exists else { return }
        tap(menu, in: app)
        let spoken = ["1W": "1 week", "1M": "1 month", "3M": "3 months", "1Y": "1 year", "Yesterday": "Yesterday"][title] ?? title
        let choice = app.buttons[spoken].firstMatch
        if choice.waitForExistence(timeout: 3) { choice.tap() }
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.label.contains(text) { return true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }

    // MARK: Seeding

    private func saveFood(_ food: SeedFood, token: String) async throws {
        let payload: [String: Any] = ["id": food.id, "name": food.name, "source": "custom", "per100g": food.per100g,
                                      "servings": [], "favorite": false, "createdAt": "2026-08-01T12:00:00.000Z"]
        _ = try await request("PUT", "/v1/documents/saved_food/\(food.id)", body: ["base_revision": 0, "payload": payload], token: token)
    }

    /// Logs an entry on a New York day, `minutes` after 07:10 that morning.
    private func logEntry(_ food: SeedFood, grams: Double, on day: (date: String, at: Date), minutes: Int, meal: String,
                          token: String) async throws {
        let id = UUID().uuidString
        let at = day.at.addingTimeInterval(Double(minutes * 60))
        let entry: [String: Any] = ["id": id, "date": day.date, "meal": meal, "loggedAt": Self.iso(at),
                                    "food": ["foodID": food.id, "name": food.name, "source": "custom", "per100g": food.per100g],
                                    "grams": grams]
        _ = try await request("PUT", "/v1/documents/food_entry/\(id)", body: ["base_revision": 0, "payload": entry], token: token)
    }

    private func setStatus(_ status: String, on date: String, token: String) async throws {
        let payload: [String: Any] = ["id": date, "date": date, "status": status, "notes": "", "tags": [String]()]
        _ = try await request("PUT", "/v1/documents/nutrition_day/\(date)", body: ["base_revision": 0, "payload": payload], token: token)
    }

    /// A coached cut in force from `startOffset` days ago: more on weekends,
    /// and a custom fiber floor and target.
    private func seedPlan(token: String, startOffset: Int) async throws {
        let id = UUID().uuidString
        func day(_ energy: Double) -> [String: Any] {
            ["energy": energy, "protein": 165, "fat": 70, "carbohydrate": ((energy - 165 * 4 - 70 * 9) / 4).rounded(.down)]
        }
        let payload: [String: Any] = [
            "id": id, "startDate": Self.day(startOffset).date, "createdAt": "2026-08-01T12:00:00.000Z",
            "goal": ["direction": "lose", "weeklyRate": 0.005], "mode": "coached", "diet": "balanced", "protein": "high",
            "weekdayWeights": [1, 1, 1, 1, 1, 1, 1], "checkInDay": 2, "allowBelowFloor": false,
            "targets": [day(2400), day(2150), day(2150), day(2150), day(2150), day(2150), day(2400)],
            "nutrientGoals": ["fiber": ["floor": 25, "target": 35]],
        ]
        _ = try await request("PUT", "/v1/documents/nutrition_plan/\(id)", body: ["base_revision": 0, "payload": payload], token: token)
    }

    /// Several weeks of varied, synthetic eating with micronutrients from
    /// whole foods and macros only from packaged labels. Most days are
    /// complete; some are partial, one is a fast and a few weren't logged.
    private func seedWeeks(token: String, days: Int) async throws {
        let yogurt = SeedFood(name: "Greek yogurt, plain", per100g: [
            "energy": 73, "protein": 10, "carbohydrate": 3.9, "fat": 1.9, "sugars": 3.6, "saturatedFat": 1.2, "calcium": 110,
            "potassium": 141, "sodium": 36, "vitaminB12": 0.75, "riboflavin": 0.23, "phosphorus": 135, "zinc": 0.5, "cholesterol": 5])
        let berries = SeedFood(name: "Blueberries", per100g: [
            "energy": 57, "protein": 0.7, "carbohydrate": 14.5, "fat": 0.3, "fiber": 2.4, "sugars": 10, "vitaminC": 9.7,
            "vitaminK": 19.3, "potassium": 77, "manganese": 0.34])
        let oats = SeedFood(name: "Rolled oats", per100g: [
            "energy": 380, "protein": 13, "carbohydrate": 67, "fat": 7, "fiber": 10, "sugars": 1, "iron": 4.3, "magnesium": 138,
            "zinc": 3.6, "phosphorus": 410, "thiamin": 0.46, "potassium": 362, "manganese": 3.6, "saturatedFat": 1.2])
        let eggs = SeedFood(name: "Eggs, scrambled", per100g: [
            "energy": 148, "protein": 10, "carbohydrate": 1.6, "fat": 11, "cholesterol": 277, "vitaminD": 2, "vitaminB12": 0.8,
            "selenium": 22, "choline": 210, "riboflavin": 0.38, "sodium": 145, "saturatedFat": 3.3, "vitaminA": 150])
        let toast = SeedFood(name: "Whole wheat toast", per100g: [
            "energy": 247, "protein": 13, "carbohydrate": 41, "fat": 3.4, "fiber": 7, "sugars": 6, "sodium": 450, "saturatedFat": 0.7])
        let chicken = SeedFood(name: "Chicken breast, grilled", per100g: [
            "energy": 165, "protein": 31, "carbohydrate": 0, "fat": 3.6, "sodium": 74, "potassium": 256, "niacin": 13.7,
            "vitaminB6": 0.6, "selenium": 27.6, "phosphorus": 228, "cholesterol": 85, "saturatedFat": 1])
        let rice = SeedFood(name: "Jasmine rice, cooked", per100g: [
            "energy": 130, "protein": 2.7, "carbohydrate": 28, "fat": 0.3, "fiber": 0.4, "manganese": 0.47, "selenium": 7.5])
        let salmon = SeedFood(name: "Salmon fillet", per100g: [
            "energy": 208, "protein": 20, "carbohydrate": 0, "fat": 13, "omega3": 2.2, "vitaminD": 11, "vitaminB12": 3.2,
            "selenium": 36, "potassium": 363, "saturatedFat": 3.1, "cholesterol": 55, "sodium": 59])
        let potato = SeedFood(name: "Roasted potatoes", per100g: [
            "energy": 149, "protein": 2.5, "carbohydrate": 24, "fat": 4.8, "fiber": 2.2, "potassium": 535, "vitaminC": 11,
            "vitaminB6": 0.3, "sodium": 210])
        let spinach = SeedFood(name: "Spinach salad", per100g: [
            "energy": 23, "protein": 2.9, "carbohydrate": 3.6, "fat": 0.4, "fiber": 2.2, "iron": 2.7, "vitaminK": 483,
            "vitaminA": 469, "folate": 194, "magnesium": 79, "calcium": 99, "potassium": 558, "vitaminC": 28])
        let oil = SeedFood(name: "Olive oil", per100g: [
            "energy": 884, "protein": 0, "carbohydrate": 0, "fat": 100, "saturatedFat": 14, "monounsaturatedFat": 73,
            "polyunsaturatedFat": 10.5, "vitaminE": 14, "vitaminK": 60])
        let banana = SeedFood(name: "Banana", per100g: [
            "energy": 89, "protein": 1.1, "carbohydrate": 22.8, "fat": 0.3, "fiber": 2.6, "sugars": 12.2, "potassium": 358,
            "vitaminB6": 0.37, "vitaminC": 8.7, "magnesium": 27])
        let bar = SeedFood(name: "Protein bar", per100g: [
            "energy": 350, "protein": 33, "carbohydrate": 38, "fat": 10, "sugars": 5, "addedSugars": 3, "fiber": 12, "sodium": 380])
        let almonds = SeedFood(name: "Almonds", per100g: [
            "energy": 579, "protein": 21, "carbohydrate": 22, "fat": 50, "fiber": 12.5, "vitaminE": 25.6, "magnesium": 270,
            "calcium": 269, "iron": 3.7, "monounsaturatedFat": 31.6, "polyunsaturatedFat": 12.3, "saturatedFat": 3.8])
        let coffee = SeedFood(name: "Coffee, brewed", per100g: ["energy": 1, "protein": 0.1, "caffeine": 40, "potassium": 49, "water": 99])
        let foods = [yogurt, berries, oats, eggs, toast, chicken, rice, salmon, potato, spinach, oil, banana, bar, almonds, coffee]
        for food in foods { try await saveFood(food, token: token) }

        for back in 1...days {
            let day = Self.day(-back)
            let wave = sin(Double(back) * 1.9)
            if back % 11 == 5 { try await setStatus("fasting", on: day.date, token: token); continue }
            if back % 13 == 9 || back == days - 1 { continue }
            try await logEntry(coffee, grams: 240, on: day, minutes: 0, meal: "Breakfast", token: token)
            if back % 2 == 0 {
                try await logEntry(yogurt, grams: 200 + 30 * wave, on: day, minutes: 25, meal: "Breakfast", token: token)
                try await logEntry(berries, grams: 90, on: day, minutes: 25, meal: "Breakfast", token: token)
                try await logEntry(oats, grams: 45, on: day, minutes: 25, meal: "Breakfast", token: token)
            } else {
                try await logEntry(eggs, grams: 150, on: day, minutes: 40, meal: "Breakfast", token: token)
                try await logEntry(toast, grams: 70, on: day, minutes: 40, meal: "Breakfast", token: token)
            }
            if back % 9 == 2 {
                try await setStatus("partial", on: day.date, token: token)
                continue
            }
            try await logEntry(chicken, grams: 180 + 25 * wave, on: day, minutes: 320, meal: "Lunch", token: token)
            try await logEntry(rice, grams: 210, on: day, minutes: 320, meal: "Lunch", token: token)
            try await logEntry(spinach, grams: back % 3 == 0 ? 120 : 60, on: day, minutes: 320, meal: "Lunch", token: token)
            try await logEntry(back % 4 == 1 ? banana : bar, grams: back % 4 == 1 ? 120 : 60, on: day, minutes: 520,
                               meal: "Snacks", token: token)
            try await logEntry(salmon, grams: 160 + 20 * wave, on: day, minutes: 720, meal: "Dinner", token: token)
            try await logEntry(potato, grams: 230 - 40 * wave, on: day, minutes: 720, meal: "Dinner", token: token)
            try await logEntry(oil, grams: 12, on: day, minutes: 720, meal: "Dinner", token: token)
            if back % 5 == 0 {
                try await logEntry(almonds, grams: 30, on: day, minutes: 860, meal: "Snacks", token: token)
            }
            if back % 3 != 1 { try await setStatus("complete", on: day.date, token: token) }
        }
    }
}
