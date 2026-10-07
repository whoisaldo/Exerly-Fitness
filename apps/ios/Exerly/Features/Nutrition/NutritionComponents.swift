import ExerlyCore
import SwiftUI

struct NutritionNumberInput: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).foregroundStyle(.secondary)
            TextField("Unknown", text: $text).keyboardType(.decimalPad)
                .accessibilityLabel(title).monospacedDigit()
        }
    }
}

struct NutritionChoice<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).foregroundStyle(.secondary)
            Menu {
                content
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(value).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }.frame(minHeight: 44)
            }.accessibilityLabel("\(title), \(value)")
        }
    }
}

struct NutritionConfirmation: View {
    let title: String
    let message: String
    let confirm: String
    var cancelLabel = "Cancel"
    var destructive = false
    let perform: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(title).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    Text(message)
                    Button(role: destructive ? .destructive : nil, action: perform) {
                        Text(confirm).frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("nutrition.confirm")
                }.fixedSize(horizontal: false, vertical: true).padding()
            }
            .navigationTitle("Confirm").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelLabel, action: cancel).accessibilityIdentifier("nutrition.confirmCancel")
                }
            }
        }
    }
}

struct NutritionAmountsView: View {
    let amounts: NutrientAmounts
    var showAll = true

    var body: some View {
        ForEach([Nutrient.energy, .protein, .carbohydrate, .fat], id: \.self) { nutrient in
            row(nutrient)
        }
        if showAll {
            DisclosureGroup("All nutrients") {
                ForEach(Nutrient.Group.allCases.filter { $0 != .energy && $0 != .macros }, id: \.self) { group in
                    DisclosureGroup(NutritionFormat.group(group)) {
                        ForEach(Nutrient.allCases.filter { $0.group == group }, id: \.self) { row($0) }
                    }
                }
            }
        }
    }

    private func row(_ nutrient: Nutrient) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nutrient.name).foregroundStyle(.secondary)
            Text(amounts[nutrient].map { "\(TrainingFormat.number($0)) \(nutrient.unit.rawValue)" } ?? "Not reported")
                .monospacedDigit()
        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
}

enum NutritionFormat {
    static func group(_ group: Nutrient.Group) -> String {
        switch group {
        case .energy: "Energy"
        case .macros: "Macros"
        case .carbohydrates: "Carbohydrates"
        case .fats: "Fats"
        case .vitamins: "Vitamins"
        case .minerals: "Minerals"
        case .aminoAcids: "Amino acids"
        case .other: "Other nutrients"
        }
    }

    static func source(_ source: FoodSource) -> String {
        switch source {
        case .custom: "Custom food"
        case .recipe: "Recipe"
        case .usda: "USDA FoodData Central"
        case .openFoodFacts: "Open Food Facts"
        case .fatSecret: "FatSecret"
        case .imported: "Imported food"
        }
    }

    /// DatePicker needs a Date; keep its calendar day in the account's time zone.
    static func pickerDate(_ date: LocalDate, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: 12)) ?? .now
    }
}
