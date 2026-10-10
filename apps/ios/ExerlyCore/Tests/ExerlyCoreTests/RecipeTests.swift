import Foundation
import Testing
@testable import ExerlyCore

@MainActor
@Suite struct RecipeTests {
    let monday = LocalDate("2026-10-05")!

    func store() throws -> NutritionStore {
        try NutritionStore(persistence: InMemoryTrainingPersistence(), now: { Fixture.instant() })
    }

    func porridge(yield: Double? = nil, servings: Double? = 2) -> Food {
        Food.recipe(name: "Porridge", ingredients: [RecipeIngredient(food: Foods.oats.snapshot, grams: 80),
                                                    RecipeIngredient(food: Foods.milk.snapshot, grams: 300)],
                    yieldGrams: yield, servingCount: servings)
    }

    @Test func aServingSplitsTheWholeRecipeAndPer100gFollowsTheCookedWeight() throws {
        let total = 380 * 0.8 + 60 * 3.0
        let raw = porridge()
        #expect(close(raw.recipeTotal?.energy, total) && raw.recipeGrams == 380)
        #expect(close(raw.per100g.energy, total / 3.8))
        #expect(raw.recipeServing?.grams == 190 && close(raw.perRecipeServing?.energy, total / 2))

        // Watered down to 500 g: 100 g holds less, a serving holds the same.
        let cooked = porridge(yield: 500)
        #expect(close(cooked.recipeTotal?.energy, total) && cooked.recipeGrams == 500)
        #expect(close(cooked.per100g.energy, total / 5))
        #expect(cooked.recipeServing?.grams == 250 && close(cooked.perRecipeServing?.energy, total / 2))
        #expect(porridge(servings: nil).perRecipeServing == nil)
    }

    @Test func aShareOfThePotLogsAsAFractionOfTheWholeRecipe() throws {
        let pot = porridge(yield: 1200, servings: 4)
        let whole = try #require(pot.recipeWhole)
        #expect(whole == Serving(Food.wholeRecipe, grams: 1200))
        #expect(pot.recipePortions == [Serving("1 serving", grams: 300), whole])
        #expect(porridge(servings: nil).recipePortions.map(\.name) == [Food.wholeRecipe])
        #expect(Foods.oats.recipePortions.isEmpty)

        let quarter = try NutritionStore.preview(pot, serving: whole, quantity: 0.25)
        #expect(quarter.grams == 300 && quarter.quantity == 0.25)
        #expect(close(quarter.nutrients.energy, (380 * 0.8 + 60 * 3) / 4))
        let entry = try store().log(pot, serving: whole, quantity: 0.25, on: monday, meal: "Dinner")
        #expect(entry.grams == 300 && entry.serving == whole)
    }

    @Test func nutrientsNoIngredientReportsStayUnknownAndPartlyReportedOnesAreNamed() throws {
        let sauce = Food(name: "Homemade sauce", per100g: NutrientAmounts([.energy: 80]))
        let bowl = Food.recipe(name: "Chicken and sauce", ingredients: [RecipeIngredient(food: Foods.chicken.snapshot, grams: 200),
                                                                        RecipeIngredient(food: sauce.snapshot, grams: 100)],
                               servingCount: 2)
        // Nothing reports carbohydrate or vitamin C: unknown, not zero.
        #expect(bowl.per100g[.carbohydrate] == nil && bowl.per100g[.vitaminC] == nil)
        #expect(bowl.perRecipeServing?[.carbohydrate] == nil)
        #expect(bowl.recipeGaps[.carbohydrate] == nil && bowl.recipeGaps[.energy] == nil)
        // Protein counts the chicken alone, and says the sauce left it out.
        #expect(close(bowl.recipeTotal?[.protein], 62))
        #expect(bowl.recipeGaps[.protein] == ["Homemade sauce"] && bowl.recipeGaps[.iron] == ["Homemade sauce"])
        #expect(close(bowl.recipeTotal?.energy, 330 + 80))
    }

    @Test func expandingAPortionScalesEachIngredientWithItsServing() throws {
        let nutrition = try store()
        let breakfast = Food.recipe(name: "Oats and milk", ingredients: [
            RecipeIngredient(food: Foods.oats.snapshot, grams: 80, serving: Foods.oats.servings[0], quantity: 2),
            RecipeIngredient(food: Foods.milk.snapshot, grams: 244, serving: Foods.milk.servings[0], quantity: 1)
        ], servingCount: 2)
        let half = breakfast.ingredients(inPortion: 162)
        #expect(half.map(\.grams) == [40, 122] && half.map(\.quantity) == [1, 0.5])

        let parts = try nutrition.logIngredients(of: breakfast, serving: breakfast.recipeServing, on: monday, meal: "Breakfast")
        #expect(parts.map(\.serving) == [Foods.oats.servings[0], Foods.milk.servings[0]] && parts.map(\.quantity) == [1, 0.5])
        let serving = try NutritionStore.preview(breakfast, serving: breakfast.recipeServing).nutrients
        #expect(close(parts.reduce(0) { $0 + $1.nutrients.energy }, serving.energy))
        #expect(close(nutrition.summary(on: monday).totals[.calcium], serving[.calcium] ?? 0))
    }

    @Test func aMealBecomesOneServingOfItsWeighedEntries() throws {
        let nutrition = try store()
        try nutrition.log(Foods.oats, serving: Foods.oats.servings[0], quantity: 2, on: monday, meal: "Breakfast")
        let chicken = try nutrition.log(Foods.chicken, grams: 150, on: monday, meal: "Breakfast")
        try nutrition.saveEntry(chicken.editingNutrients(NutrientAmounts([.energy: 240, .protein: 45])))
        try nutrition.quickAdd(NutrientAmounts([.energy: 120]), on: monday, meal: "Breakfast")
        let meal = nutrition.entries(on: monday)

        let recipe = Food.recipe(from: meal, name: "Big breakfast")
        #expect(recipe.servingCount == 1 && recipe.ingredients?.count == 2, "the quick add has no weight to add")
        let oats = try #require(recipe.ingredients?.first { $0.food.foodID == Foods.oats.id })
        #expect(oats.serving == Foods.oats.servings[0] && oats.quantity == 2 && oats.grams == 80)
        #expect(recipe.ingredients?.first { $0.food.foodID == Foods.chicken.id }?.food.edited == true)
        #expect(close(recipe.perRecipeServing?.energy, 304 + 240))
        try nutrition.saveFood(recipe)
        #expect(nutrition.entries(on: monday) == meal, "the meal itself is left as it was")
    }

    @Test func editingOrDuplicatingARecipeLeavesWhatWasLoggedAlone() throws {
        let nutrition = try store()
        var original = porridge()
        original.favorite = true
        try nutrition.saveFood(original)
        let bowl = try nutrition.log(original, serving: original.recipeServing, on: monday, meal: "Breakfast")

        let copy = original.duplicated(now: Fixture.instant(days: 1))
        #expect(copy.id != original.id && copy.name == "Porridge copy" && !copy.favorite)
        #expect(copy.ingredients == original.ingredients && copy.per100g == original.per100g && copy.createdAt == Fixture.instant(days: 1))
        try nutrition.saveFood(copy.withIngredients([RecipeIngredient(food: Foods.oats.snapshot, grams: 100)], yieldGrams: nil))

        var edited = original.withIngredients([RecipeIngredient(food: Foods.milk.snapshot, grams: 500)], yieldGrams: 450)
        edited.servingCount = 3
        try nutrition.saveFood(edited)
        #expect(nutrition.entries.first == bowl, "the entry keeps the nutrients it was logged with")
        #expect(nutrition.food(original.id)?.ingredients?.count == 1 && nutrition.food(copy.id)?.ingredients?.first?.grams == 100)
    }

    @Test func ingredientsSavedBeforeServingsDecodeAndInvalidServingsAreRefused() throws {
        let old = #"{"food":{"foodID":"F1","name":"Oats","source":"custom","per100g":{"energy":380}},"grams":80}"#
        let ingredient = try ExerlyJSON.decoder.decode(RecipeIngredient.self, from: Data(old.utf8))
        #expect(ingredient.serving == nil && ingredient.quantity == nil)
        #expect(String(decoding: try ExerlyJSON.canonical(ingredient), as: UTF8.self).contains("serving") == false)

        var counted = ingredient
        counted.serving = Serving("1/2 cup", grams: 40)
        counted.quantity = 0
        #expect(throws: NutritionStore.StoreError.invalid(["each ingredient needs a positive weight"])) {
            try store().saveFood(Food.recipe(name: "Oats", ingredients: [counted]))
        }
    }
}
