import ExerlyCore
import SwiftUI

struct NutritionRecipeDetails: View {
    let food: ExerlyCore.Food
    let unit: MassUnit

    var body: some View {
        ExCard {
            ExSectionHeading("Portions")
            if let count = food.servingCount {
                Text("Makes \(TrainingFormat.number(count)) equal servings").font(.exBodyMedium)
            }
            if let weight = food.yieldGrams {
                Text("Finished weight · \(weightText(weight))").font(.exBody)
            } else {
                Text("Finished weight not entered").font(.exBodyMedium)
                Text("Use equal servings, or edit the recipe after weighing the finished dish. Weight-based entries currently use the ingredient weights.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            Text("Totals include the nutrients reported by your ingredients.")
                .font(.exCaption).foregroundStyle(Color.exTextSecondary)
        }
        ExCard {
            ExSectionHeading("Ingredients", detail: "\((food.ingredients ?? []).count)")
            ForEach(Array((food.ingredients ?? []).enumerated()), id: \.offset) { _, ingredient in
                VStack(alignment: .leading, spacing: ExSpacing.tight) {
                    Text(ingredient.food.name).font(.exBodyMedium)
                    Text("\(weightText(ingredient.grams)) · \(NutritionFormat.source(ingredient.food.source))")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }.accessibilityElement(children: .combine)
            }
        }
        if let preparation = food.preparation, !preparation.isEmpty {
            ExCard {
                ExSectionHeading("Preparation")
                Text(preparation).font(.exBody)
            }
        }
    }

    private func weightText(_ grams: Double) -> String {
        let amount = unit == .pounds ? USUnits.ounces(grams: grams) : grams
        return "\(amount.formatted(.number.precision(.fractionLength(0...1)))) \(unit == .pounds ? "oz" : "g")"
    }
}
