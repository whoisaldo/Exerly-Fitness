import Foundation
import Testing
@testable import ExerlyCore

/// Synthetic label text, as the camera's text recognition returns it.
@Suite struct NutritionLabelTests {
    @Test func aUSPanelReadsPerServingWithTheUsualMisreads() throws {
        let lines = ["Nutrition Facts", "8 servings per container", "Serving size 2/3 cup (55g)", "Amount per serving",
                     "Calories", "230", "% Daily Value*", "Total Fat 8g 10%", "Saturated Fat 1g 5%", "Trans Fat Og",
                     "Cholesterol Omg 0%", "Sodium 160mg 7%", "Total Carbohydrate 37g 13%", "Dietary Fiber 4g 14%",
                     "Total Sugars 12g", "Includes 10g Added Sugars 20%", "Protein 3g", "Vitamin D 2mcg 10%",
                     "Calcium 260mg 20%", "Iron 8mg 45%", "Potassium 240mg 6%"]
        let label = try #require(NutritionLabel.read(lines))
        #expect(label.basis == .serving && label.servingGrams == 55 && label.servingText == "2/3 cup (55g)")
        let expected: [Nutrient: Double] = [.energy: 230, .fat: 8, .saturatedFat: 1, .transFat: 0, .cholesterol: 0,
                                            .sodium: 160, .carbohydrate: 37, .fiber: 4, .sugars: 12, .addedSugars: 10,
                                            .protein: 3, .vitaminD: 2, .calcium: 260, .iron: 8, .potassium: 240]
        for (nutrient, value) in expected { #expect(label.amounts[nutrient] == value, "\(nutrient)") }
        #expect(label.unread.isEmpty && label.approximated.isEmpty)
        let per100g = try #require(label.per100g)
        #expect(abs((per100g[.energy] ?? 0) - 230 * 100 / 55) < 1e-9)
    }

    @Test func anEUDeclarationReadsPer100gWithSaltAsSodium() throws {
        let lines = ["NUTRITION", "Typical values per 100g per 30g serving", "Energy 1580kJ / 375kcal 474kJ / 113kcal",
                     "Fat 6,5 g 2,0 g", "of which saturates 1,2 g 0,4 g", "Carbohydrate 66 g 20 g", "of which sugars 22 g 6,6 g",
                     "Fibre 7,8 g 2,3 g", "Protein 9,4 g 2,8 g", "Salt <0,1 g <0,1 g"]
        let label = try #require(NutritionLabel.read(lines))
        #expect(label.basis == .per100g)
        let expected: [Nutrient: Double] = [.energy: 375, .fat: 6.5, .saturatedFat: 1.2, .carbohydrate: 66, .sugars: 22,
                                            .fiber: 7.8, .protein: 9.4, .sodium: 40]
        for (nutrient, value) in expected { #expect(label.amounts[nutrient] == value, "\(nutrient)") }
        #expect(label.approximated == [.sodium] && label.per100g == label.amounts)

        // kJ alone is converted, and a drink per 100 ml needs a density for grams.
        let drinkLines = ["Per 100 ml", "Energy 180 kJ", "Carbohydrate 10.6 g", "of which sugars 10.6 g", "Protein 0 g"]
        let drink = try #require(NutritionLabel.read(drinkLines))
        #expect(drink.basis == .per100ml && drink.amounts[.energy] == 43 && drink.per100g == nil)
    }

    @Test func otherTextIsNotALabelAndUnreadableLinesAreListed() throws {
        #expect(NutritionLabel.read(["Best before 12/2026", "Store in a cool, dry place"]) == nil)
        let label = try #require(NutritionLabel.read(["Calories 120", "Protein 4g", "Total Fat --"]))
        #expect(label.unread == ["total fat --"] && label.amounts[.fat] == nil)
    }
}
