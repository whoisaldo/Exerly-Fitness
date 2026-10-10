import XCTest

/// Recipes: built from food search, saved from a meal, logged like any food,
/// and edited without touching what was logged before.
@MainActor
final class RecipeUITests: ExerlyUITestCase {
    private struct Kitchen {
        let oats = SeedFood(name: "Rolled oats", per100g: ["energy": 380, "protein": 13, "carbohydrate": 67, "fat": 7])
        let milk = SeedFood(name: "Whole milk", per100g: ["energy": 61, "protein": 3.2, "carbohydrate": 4.8, "fat": 3.3])
        let banana = SeedFood(name: "Banana", per100g: ["energy": 89, "protein": 1.1, "carbohydrate": 22.8, "fat": 0.3])
        let recipeID = UUID().uuidString
    }

    /// Three foods logged at yesterday's breakfast and today's, and a recipe
    /// made of them: 80 g oats, 300 g milk and 120 g banana cooked to 450 g,
    /// two servings of 297 kcal.
    private func seedKitchen(token: String) async throws -> Kitchen {
        let kitchen = Kitchen()
        for food in [kitchen.oats, kitchen.milk, kitchen.banana] {
            let payload: [String: Any] = ["id": food.id, "name": food.name, "source": "custom", "per100g": food.per100g,
                                          "servings": [], "favorite": false, "createdAt": "2026-10-01T12:00:00.000Z"]
            _ = try await request("PUT", "/v1/documents/saved_food/\(food.id)", body: ["base_revision": 0, "payload": payload], token: token)
        }
        for days in [1, 0] {
            try await seedEntry(kitchen.oats, grams: 80, daysAgo: days, meal: "Breakfast", token: token)
            try await seedEntry(kitchen.milk, grams: 250, daysAgo: days, meal: "Breakfast", token: token)
            try await seedEntry(kitchen.banana, grams: 120, daysAgo: days, meal: "Breakfast", token: token)
        }
        func ingredient(_ food: SeedFood, _ grams: Double) -> [String: Any] {
            ["food": ["foodID": food.id, "name": food.name, "source": "custom", "per100g": food.per100g], "grams": grams]
        }
        // The ingredients' totals over the 450 g cooked weight.
        let per100g: [String: Double] = ["energy": 131.96, "protein": 4.7378, "carbohydrate": 21.191, "fat": 3.5244]
        let ingredients: [[String: Any]] = [ingredient(kitchen.oats, 80), ingredient(kitchen.milk, 300), ingredient(kitchen.banana, 120)]
        let recipe: [String: Any] = [
            "id": kitchen.recipeID, "name": "Banana oat porridge", "source": "recipe", "servings": [String](), "favorite": false,
            "createdAt": "2026-10-02T12:00:00.000Z", "yieldGrams": 450.0, "servingCount": 2.0,
            "preparation": "Simmer the oats in the milk for five minutes, then stir in the sliced banana.",
            "ingredients": ingredients, "per100g": per100g
        ]
        _ = try await request("PUT", "/v1/documents/saved_food/\(kitchen.recipeID)", body: ["base_revision": 0, "payload": recipe], token: token)
        return kitchen
    }

    /// Today's date where the fixture account lives, and an instant an hour ago.
    private func today() -> (date: String, at: String) {
        let day = DateFormatter()
        day.calendar = Calendar(identifier: .gregorian)
        day.timeZone = TimeZone(identifier: "America/New_York")!
        day.dateFormat = "yyyy-MM-dd"
        let instant = ISO8601DateFormatter()
        instant.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let at = Date().addingTimeInterval(-3600)
        return (day.string(from: at), instant.string(from: at))
    }

    private func entries(_ name: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "nutrition.entry.", name + ","))
    }

    /// Food search's saved foods: a segment, or a menu at the largest text sizes.
    private func showMyFoods(_ app: XCUIApplication) {
        if !app.buttons["My foods"].waitForExistence(timeout: 3) { tap(app.buttons["nutrition.listScope"], in: app) }
        tap(app.buttons["My foods"], in: app)
    }

    private func energy(_ app: XCUIApplication) -> String? {
        let hero = app.descendants(matching: .any)["nutrition.portionEnergy"]
        return hero.waitForExistence(timeout: 5) ? hero.label : nil
    }

    func testARecipeFromThreeIngredientsLogsOneServingWithItsTotals() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "recipe-create")
        let kitchen = try await seedKitchen(token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tapCount = 0
        tap(app.buttons["nutrition.addFood"], in: app)
        showMyFoods(app)
        tap(app.buttons["nutrition.createRecipeRow"], in: app)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "The name is ready to type")
        app.descendants(matching: .any)["recipe.name"].typeText("Banana oat bowl")
        tap(app.buttons["recipe.addIngredients"], in: app)
        for food in [kitchen.oats, kitchen.milk, kitchen.banana] { tap(app.buttons["nutrition.plateAdd.\(food.id)"], in: app) }
        XCTAssertEqual(app.buttons["nutrition.reviewPlate"].label, "Review recipe · 3 foods")
        tap(app.buttons["nutrition.reviewPlate"], in: app)
        XCTAssertEqual(energy(app), "563 kilocalories", "One serving is the whole bowl: 304 + 152.5 + 106.8 kcal")
        tap(app.buttons["2"], in: app)
        XCTAssertEqual(energy(app), "282 kilocalories", "Two servings split it")
        XCTAssertTrue(app.descendants(matching: .any)["recipe.per100g"].label.hasPrefix("Per 100 g, 125 kilocalories"),
                      "563.3 kcal over the ingredients' 450 g")
        tap(app.buttons["recipe.save"], in: app)
        XCTAssertEqual(tapCount, 10, "Search, My foods, Create a recipe, Add ingredients, three +, Review, 2 servings, Save")

        // Saving from search goes straight to its portion: one serving.
        XCTAssertTrue(app.buttons["nutrition.saveEntry"].waitForExistence(timeout: 10))
        XCTAssertEqual(energy(app), "282 kilocalories")
        XCTAssertTrue(app.buttons["nutrition.measure.serving.1 serving.225.0"].isSelected)
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertEqual(tapCount, 11, "and Log")
        XCTAssertTrue(todayScreen(app).waitForExistence(timeout: 10))
        let bowl = entries("Banana oat bowl", in: app).firstMatch
        XCTAssertTrue(bowl.waitForExistence(timeout: 5))
        XCTAssertTrue(bowl.label.hasSuffix("1 serving · 225 g, 282 calories"), bowl.label)
    }

    func testSavingAMealAsARecipeTakesThreeTaps() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "recipe-meal")
        _ = try await seedKitchen(token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tapCount = 0
        openMealActions("Breakfast", in: app)
        tap(app.buttons["Save as recipe"], in: app)
        XCTAssertTrue(app.navigationBars["New recipe"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe.ingredient.")).count, 3)
        XCTAssertEqual(energy(app), "563 kilocalories", "The meal as one serving")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Only the name is left to type")
        app.descendants(matching: .any)["recipe.name"].typeText("Usual breakfast")
        tap(app.buttons["recipe.save"], in: app)
        XCTAssertEqual(tapCount, 3, "Hold the meal, Save as recipe, Save")
        XCTAssertTrue(app.staticTexts["Saved Usual breakfast to your recipes"].waitForExistence(timeout: 5))
        XCTAssertEqual(entries("Rolled oats", in: app).count, 1, "The meal itself stays as it was")

        tap(app.buttons["nutrition.addFood"], in: app)
        let field = app.searchFields.firstMatch
        tap(field, in: app)
        field.typeText("Usual")
        let recipe = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "nutrition.food.", "Usual breakfast"))
        XCTAssertTrue(recipe.firstMatch.waitForExistence(timeout: 5), "The recipe is found like any saved food")
    }

    func testEditingARecipeLeavesTheEarlierEntryAlone() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "recipe-edit")
        let kitchen = try await seedKitchen(token: person.token)
        let (date, at) = today()
        let entryID = UUID().uuidString
        let entry: [String: Any] = [
            "id": entryID, "date": date, "meal": "Dinner", "loggedAt": at, "grams": 225.0, "quantity": 1.0,
            "serving": ["name": "1 serving", "grams": 225.0],
            "food": ["foodID": kitchen.recipeID, "name": "Banana oat porridge", "source": "recipe",
                     "per100g": ["energy": 131.96, "protein": 4.7378, "carbohydrate": 21.191, "fat": 3.5244]]
        ]
        _ = try await request("PUT", "/v1/documents/food_entry/\(entryID)", body: ["base_revision": 0, "payload": entry], token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        let logged = app.buttons["nutrition.entry.\(entryID)"]
        reveal(logged, in: app)
        XCTAssertTrue(logged.label.hasSuffix("297 calories"), logged.label)

        tapCount = 0
        openFoodLibrary(app)
        tap(app.buttons["nutrition.libraryFood.\(kitchen.recipeID)"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["recipe.details"].waitForExistence(timeout: 5))
        tap(app.buttons["nutrition.libraryActions"], in: app)
        tap(app.buttons["recipe.edit"], in: app)
        XCTAssertTrue(app.navigationBars["Edit recipe"].waitForExistence(timeout: 5))
        XCTAssertEqual(energy(app), "297 kilocalories")
        tap(app.buttons["recipe.ingredient.\(kitchen.oats.id)"], in: app)
        replace(app.textFields["recipe.ingredientAmount"], with: "160", in: app)
        tap(app.buttons["recipe.applyIngredient"], in: app)
        XCTAssertEqual(energy(app), "449 kilocalories", "Twice the oats: 897.8 kcal over 450 g, 225 g a serving")
        tap(app.buttons["recipe.save"], in: app)
        XCTAssertEqual(tapCount, 9, "Profile, Foods & recipes, the recipe, actions, Edit, the oats, their amount, Done, Save")
        XCTAssertTrue(app.navigationBars["Saved food"].waitForExistence(timeout: 5))

        // A copy to vary starts as a new recipe with the same ingredients.
        tap(app.buttons["nutrition.libraryActions"], in: app)
        tap(app.buttons["recipe.duplicate"], in: app)
        XCTAssertTrue(app.navigationBars["New recipe"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["recipe.name"].value as? String, "Banana oat porridge copy")
        XCTAssertEqual(energy(app), "449 kilocalories")
        tap(app.buttons["recipe.save"], in: app)

        tap(app.tabBars.buttons["Today"], in: app)
        reveal(logged, in: app)
        XCTAssertTrue(logged.label.hasSuffix("1 serving · 225 g, 297 calories"), "Logged before the edit, so unchanged: \(logged.label)")
    }

    func testARecipeLogsAsAShareOfThePotOrAsItsIngredients() async throws {
        try await control([:])
        let person = try await createAccount(prefix: "recipe-share")
        let kitchen = try await seedKitchen(token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        tapCount = 0
        tap(app.buttons["nutrition.addFood"], in: app)
        showMyFoods(app)
        tap(app.buttons["nutrition.food.\(kitchen.recipeID)"], in: app)
        XCTAssertEqual(energy(app), "297 kilocalories", "One of two servings")
        tap(app.buttons["nutrition.measure.serving.whole recipe.450.0"], in: app)
        XCTAssertEqual(app.textFields["Share of the recipe"].value as? String, "0.5", "The same 225 g, as a share of the pot")
        tap(app.buttons["0.25"], in: app)
        XCTAssertEqual(energy(app), "148 kilocalories", "A quarter of 593.8 kcal")
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertEqual(tapCount, 6, "Search, My foods, the recipe, whole recipe, ¼, Log")
        let share = entries("Banana oat porridge", in: app).firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        XCTAssertTrue(share.label.contains("0.25 × whole recipe") && share.label.hasSuffix("148 calories"), share.label)

        // The same quarter as its ingredients, each a quarter of its amount.
        tap(app.buttons["nutrition.addFood"], in: app)
        showMyFoods(app)
        tap(app.buttons["nutrition.food.\(kitchen.recipeID)"], in: app)
        // The switch itself sits at the row's trailing edge; its label doesn't toggle it.
        let expand = app.switches["nutrition.logIngredients"]
        reveal(expand, in: app)
        expand.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertEqual(expand.value as? String, "1")
        tap(app.buttons["nutrition.saveEntry"], in: app)
        XCTAssertTrue(todayScreen(app).waitForExistence(timeout: 10))
        let oats = entries("Rolled oats", in: app)
        XCTAssertTrue(oats.element(boundBy: 1).waitForExistence(timeout: 5))
        XCTAssertEqual(oats.count, 2, "Breakfast's oats and the recipe's")
        XCTAssertTrue(oats.allElementsBoundByIndex.contains { $0.label == "Rolled oats, 20 g, 76 calories" },
                      oats.allElementsBoundByIndex.map(\.label).joined(separator: "; "))
        XCTAssertEqual(entries("Banana oat porridge", in: app).count, 1)
    }

    /// Screens for review, in light and dark, at the default and largest text.
    func testRecipesCapture() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_DESIGN_CAPTURE"] == "1" else { throw XCTSkip("Opt-in visual review") }
        try await control([:])
        let person = try await createAccount(prefix: "recipe-capture")
        let kitchen = try await seedKitchen(token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        openMealActions("Breakfast", in: app)
        capture(app, "after-01-meal-menu")
        tap(app.buttons["Save as recipe"], in: app)
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 5)
        app.descendants(matching: .any)["recipe.name"].typeText("Usual breakfast")
        capture(app, "after-02-meal-recipe")
        tap(app.buttons["recipe.save"], in: app)
        capture(app, "after-03-saved")

        tap(app.buttons["nutrition.addFood"], in: app)
        showMyFoods(app)
        capture(app, "after-04-picker-my-foods")
        tap(app.buttons["nutrition.createRecipeRow"], in: app)
        capture(app, "after-05-new-recipe")
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 5)
        app.descendants(matching: .any)["recipe.name"].typeText("Banana oat bowl")
        tap(app.buttons["recipe.addIngredients"], in: app)
        for food in [kitchen.oats, kitchen.milk, kitchen.banana] { tap(app.buttons["nutrition.plateAdd.\(food.id)"], in: app) }
        capture(app, "after-06-picking")
        tap(app.buttons["nutrition.reviewPlate"], in: app)
        tap(app.buttons["2"], in: app)
        dismissKeyboard(app)
        app.swipeDown()
        capture(app, "after-07-recipe")
        app.swipeUp()
        capture(app, "after-08-recipe-yield")
        let milk = app.buttons["recipe.ingredient.\(kitchen.milk.id)"]
        revealAbove(milk, in: app)
        tap(milk, in: app)
        capture(app, "after-09-ingredient")
        tap(app.buttons["recipe.applyIngredient"], in: app)
        tap(app.buttons["recipe.save"], in: app)
        XCTAssertTrue(app.buttons["nutrition.saveEntry"].waitForExistence(timeout: 10))
        capture(app, "after-10-recipe-portion")
        // At the largest text sizes the measures scroll sideways, past the screen's edge.
        let pot = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "nutrition.measure.serving.whole recipe")).firstMatch
        if !pot.isHittable { app.buttons["nutrition.measure.grams"].swipeLeft() }
        tap(pot, in: app)
        capture(app, "after-11-share-of-pot")
        tap(app.buttons["nutrition.saveEntry"], in: app)

        openFoodLibrary(app)
        capture(app, "after-12-library")
        tap(app.buttons["nutrition.libraryFood.\(kitchen.recipeID)"], in: app)
        capture(app, "after-13-library-recipe")
        app.swipeUp()
        capture(app, "after-14-library-recipe-details")
        tap(app.buttons["nutrition.libraryActions"], in: app)
        capture(app, "after-15-library-actions")
    }
}
