import ExerlyCore
import SwiftUI

enum NutritionPortionMeasure: Hashable {
    case grams, ounces, milliliters, fluidOunces, serving(Serving)

    var title: String {
        switch self {
        case .grams: "Grams"
        case .ounces: "Ounces"
        case .milliliters: "Milliliters"
        case .fluidOunces: "U.S. fluid ounces"
        case .serving(let serving): serving.name
        }
    }

    var symbol: String {
        switch self {
        case .grams: "g"
        case .ounces: "oz"
        case .milliliters: "ml"
        case .fluidOunces: "fl oz"
        case .serving: ""
        }
    }

    var identifier: String {
        switch self {
        case .grams: "grams"
        case .ounces: "ounces"
        case .milliliters: "milliliters"
        case .fluidOunces: "fluidOunces"
        case .serving(let serving): "serving.\(serving.name).\(serving.grams)"
        }
    }

    var amountTitle: String {
        if case .serving(let serving) = self, serving.name == ExerlyCore.Food.wholeRecipe { return "Share of the recipe" }
        return symbol.isEmpty ? "Number of servings" : "Amount (\(symbol))"
    }
    var step: Double { self == .grams || self == .milliliters ? 10 : 0.5 }
    var initialAmount: Double { self == .grams || self == .milliliters ? 100 : 1 }
    var presets: [Double] {
        switch self {
        case .grams: [50, 100, 150]
        case .milliliters: [30, 100, 250]
        case .ounces: [1, 2, 4]
        case .fluidOunces: [1, 4, 8]
        case .serving(let serving): serving.name == ExerlyCore.Food.wholeRecipe ? [0.25, 0.5, 1] : [0.5, 1, 2]
        }
    }

    func portion(in food: ExerlyCore.Food) -> Serving? {
        switch self {
        case .grams: nil
        case .ounces: Serving("oz", grams: USUnits.grams(ounces: 1))
        case .milliliters: food.grams(milliliters: 1).map { Serving("ml", grams: $0) }
        case .fluidOunces: food.grams(milliliters: USUnits.milliliters(fluidOunces: 1)).map { Serving("fl oz", grams: $0) }
        case .serving(let serving): serving
        }
    }

    static func saved(_ serving: Serving?, food: ExerlyCore.Food) -> Self {
        guard let serving else { return .grams }
        return [Self.ounces, .milliliters, .fluidOunces].first { $0.portion(in: food) == serving } ?? .serving(serving)
    }

    static func preferred(for food: ExerlyCore.Food, unit: MassUnit) -> Self {
        if unit == .pounds { return food.volume == nil ? .ounces : .fluidOunces }
        return food.volume == nil ? .grams : .milliliters
    }

    static func available(for food: ExerlyCore.Food, unit: MassUnit) -> [Self] {
        var choices: [Self] = unit == .pounds ? [.ounces, .grams] : [.grams, .ounces]
        if food.volume != nil { choices += unit == .pounds ? [.fluidOunces, .milliliters] : [.milliliters, .fluidOunces] }
        for serving in food.servings + food.recipePortions {
            let measure = saved(serving, food: food)
            if !choices.contains(measure) { choices.append(measure) }
        }
        return choices
    }
}

/// Grams, ounces, volumes and the food's own servings as chips. Switching
/// converts the amount and keeps its weight; the presets below it set whole
/// servings. A label serving chosen while the amount is invalid starts at one.
struct NutritionMeasureChips: View {
    @ObservedObject var draft: NutritionEntryDraft
    let unit: MassUnit
    var onChoose: () -> Void = {}

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: ExSpacing.small) {
                ForEach(draft.availableMeasures, id: \.self) { measure in
                    let selected = measure == draft.measure
                    Button {
                        onChoose()
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        guard !selected else { return }
                        if !draft.selectMeasure(measure), case .serving(let serving) = measure,
                           draft.publishedServings.contains(serving) {
                            draft.selectPortion(serving)
                        }
                    } label: {
                        Text(title(measure)).font(.exLabel.weight(selected ? .semibold : .medium))
                            .padding(.horizontal, 14).frame(minHeight: 34)
                            .foregroundStyle(selected ? Color.white : Color.exTextSecondary)
                            .background(selected ? Color.exActionFill : Color.exSurface2, in: Capsule())
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel(label(measure))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("nutrition.measure.\(measure.identifier)")
                }
            }
        }.scrollIndicators(.hidden).scrollClipDisabled()
            .sensoryFeedback(.selection, trigger: draft.measure)
    }

    private func title(_ measure: NutritionPortionMeasure) -> String {
        guard case .serving(let serving) = measure else { return measure.symbol }
        return FoodFormat.statesWeight(serving.name) ? serving.name : "\(serving.name) · \(FoodFormat.weight(serving.grams, unit: unit))"
    }

    private func label(_ measure: NutritionPortionMeasure) -> String {
        guard case .serving(let serving) = measure else { return measure.title }
        return "\(serving.name), \(FoodFormat.weight(serving.grams, unit: unit)) each"
    }
}
