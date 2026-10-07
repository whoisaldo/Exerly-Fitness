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

    var amountTitle: String { symbol.isEmpty ? "Number of servings" : "Amount (\(symbol))" }
    var step: Double { self == .grams || self == .milliliters ? 10 : 0.5 }
    var initialAmount: Double { self == .grams || self == .milliliters ? 100 : 1 }
    var presets: [Double] {
        switch self {
        case .grams: [50, 100, 150]
        case .milliliters: [30, 100, 250]
        case .ounces: [1, 2, 4]
        case .fluidOunces: [1, 4, 8]
        case .serving: [0.5, 1, 2]
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
        for serving in food.servings + (food.recipeServing.map { [$0] } ?? []) {
            let measure = saved(serving, food: food)
            if !choices.contains(measure) { choices.append(measure) }
        }
        return choices
    }
}

struct NutritionMeasureSelection: View {
    @ObservedObject var draft: NutritionEntryDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ExScreen {
                Text("Switch measures without changing the portion's nutrition.")
                    .font(.exBody).foregroundStyle(Color.exTextSecondary)
                ExCard {
                    ForEach(draft.availableMeasures, id: \.self) { measure in
                        Button {
                            draft.selectMeasure(measure)
                            dismiss()
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: ExSpacing.item) {
                                VStack(alignment: .leading, spacing: ExSpacing.small) {
                                    Text(measure.title).font(.exBodyMedium)
                                    if case .serving(let serving) = measure {
                                        Text("\(TrainingFormat.number(serving.grams)) g each").font(.exCaption)
                                            .foregroundStyle(Color.exTextSecondary)
                                    }
                                }.fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                if measure == draft.measure { Image(systemName: "checkmark").accessibilityHidden(true) }
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).foregroundStyle(Color.exPrimaryText)
                            .accessibilityIdentifier("nutrition.measure.\(measure.identifier)")
                            .accessibilityAddTraits(measure == draft.measure ? .isSelected : [])
                        if measure != draft.availableMeasures.last { Divider().overlay(Color.exBorder.opacity(0.3)) }
                    }
                }
            }
            .navigationTitle("Portion measure").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
