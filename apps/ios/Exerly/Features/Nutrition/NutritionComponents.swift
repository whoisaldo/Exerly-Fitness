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

struct NutritionDailySummary: View {
    let amounts: NutrientAmounts
    let targets: DailyTargets?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(amounts[.energy].map { "\(TrainingFormat.number($0)) kcal" } ?? "No energy reported")
                    .font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(Color.exPrimary)
                if let targets { Text("Target \(TrainingFormat.number(targets.energy)) kcal").font(.caption).foregroundStyle(.secondary) }
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                macro(.protein, target: targets?.protein)
                macro(.carbohydrate, target: targets?.carbohydrate)
                macro(.fat, target: targets?.fat)
            }
            if targets == nil {
                Text("Nutrition targets have not been set for this date.").font(.footnote).foregroundStyle(.secondary)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func macro(_ nutrient: Nutrient, target: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nutrient.name).font(.caption).foregroundStyle(.secondary)
            Text(amounts[nutrient].map { "\(TrainingFormat.number($0)) g" } ?? "Not reported").monospacedDigit()
            if let target { Text("Target \(TrainingFormat.number(target)) g").font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}

enum NutritionFormat {
    static func status(_ status: DayStatus) -> String {
        switch status {
        case .unlogged: "In progress"
        case .partial: "Partial log"
        case .complete: "Complete log"
        case .fasting: "Fasting"
        }
    }

    static func statusDescription(_ status: DayStatus) -> String {
        switch status {
        case .unlogged: "Keep logging. This day is not confirmed as a complete intake day."
        case .partial: "Some food is missing. This day is excluded from expenditure estimates."
        case .complete: "All food for this day is logged. It can inform expenditure estimates."
        case .fasting: "Confirm that you fasted. An empty fasting day counts as zero energy intake."
        }
    }

    static func portion(_ entry: FoodEntry) -> String {
        if let serving = entry.serving, let quantity = entry.quantity {
            return "\(TrainingFormat.number(quantity)) × \(serving.name) · \(TrainingFormat.number(entry.grams)) g"
        }
        return "\(TrainingFormat.number(entry.grams)) g"
    }

    static func day(_ date: LocalDate, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d yyyy")
        return formatter.string(from: pickerDate(date, timeZone: timeZone))
    }

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
