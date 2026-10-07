import ExerlyCore
import SwiftUI

struct NutritionNumberInput: View {
    let title: String
    @Binding var text: String
    var identifier = ""
    var integer = false
    var placeholder = "Unknown"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.exLabel).foregroundStyle(Color.exTextSecondary)
            ExNumericTextField(title: title, text: $text, placeholder: placeholder, integer: integer, identifier: identifier)
                .padding(ExSpacing.item).background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
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
        ExConfirmation(title: title, message: message, confirm: confirm, cancelLabel: cancelLabel,
                       destructive: destructive, identifier: "nutrition", perform: perform, cancel: cancel)
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
                .font(.exStatSmall)
        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
}

struct NutritionDailySummary: View {
    let amounts: NutrientAmounts
    let targets: DailyTargets?
    var progress: DayProgress?
    var showHeading = true
    var showTargetNote = true
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var energySize: CGFloat = 46

    private func amount(_ nutrient: Nutrient) -> Double? {
        NutritionFormat.summaryAmount(nutrient, amounts: amounts, progress: progress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            if showHeading { ExEyebrow("Daily nutrition", color: .exPrimaryText) }
            let energyLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.small))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: ExSpacing.small))
            energyLayout {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(amount(.energy).map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "–")
                    .font(.system(size: energySize, weight: .bold, design: .rounded))
                    .foregroundStyle(amount(.energy) == nil ? Color.exTextSecondary : Color.exTextPrimary)
                    .contentTransition(.numericText())
                Text("kcal").font(.exBody).foregroundStyle(Color.exTextSecondary)
                }.accessibilityElement(children: .combine)
                if let targets {
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Text("of \(targets.energy.formatted(.number.precision(.fractionLength(0))))\nkcal target")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                        .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                        .accessibilityIdentifier("nutrition.targetEnergy").accessibilityValue(String(targets.energy))
                }
            }
            if let targets { ExProgressBar(value: amounts[.energy] ?? 0, total: targets.energy) }
            if let energy = progress?.energy, let remaining = energy.remaining {
                let over = energy.over ?? 0
                Text("\((over > 0 ? over : remaining).formatted(.number.precision(.fractionLength(0)))) kcal \(over > 0 ? "over" : "left")")
                    .font(.exCaption.weight(.medium)).foregroundStyle(Color.exTextSecondary)
                    .accessibilityIdentifier("nutrition.energyRemaining")
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.content))
                : AnyLayout(HStackLayout(alignment: .top, spacing: ExSpacing.item))
            layout {
                macro(.protein, label: "Protein", target: targets?.protein, color: .exPrimaryText)
                macro(.carbohydrate, label: "Carbs", target: targets?.carbohydrate, color: .exAccent)
                macro(.fat, label: "Fat", target: targets?.fat, color: .exSecondary)
            }
            if let progress, [progress.energy, progress.protein, progress.carbohydrate, progress.fat].contains(where: { $0.unreported > 0 }) {
                Text("Some food labels omit nutrients. Totals may be low.")
                    .font(.exSmall).foregroundStyle(Color.exTextSecondary)
            }
            if targets == nil && showTargetNote {
                NavigationLink { ProgramView() } label: {
                    Label("Review nutrition targets", systemImage: "target").font(.exCaption).frame(minHeight: 44)
                }
                Text("No targets set for this day").font(.exSmall).foregroundStyle(Color.exTextSecondary)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func macro(_ nutrient: Nutrient, label: String, target: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 5, height: 5).accessibilityHidden(true)
                Text(label).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            Text(amount(nutrient).map { "\($0.formatted(.number.precision(.fractionLength(0)))) g" } ?? "–")
                .font(.exStatSmall).foregroundStyle(amount(nutrient) == nil ? Color.exTextSecondary : Color.exTextPrimary)
            if let target {
                ExProgressBar(value: amounts[nutrient] ?? 0, total: target, color: color)
                Text("of \(target.formatted(.number.precision(.fractionLength(0)))) g").font(.exSmall)
                    .foregroundStyle(Color.exTextSecondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore)
            .accessibilityLabel(nutrient.name)
            .accessibilityValue((amount(nutrient).map { "\($0.formatted(.number.precision(.fractionLength(0)))) grams" } ?? "Not reported") +
                                (target.map { ", target \($0.formatted(.number.precision(.fractionLength(0)))) grams" } ?? ""))
    }
}

enum NutritionFormat {
    static func summaryAmount(_ nutrient: Nutrient, amounts: NutrientAmounts, progress: DayProgress?) -> Double? {
        if let amount = amounts[nutrient] { return amount }
        guard let progress else { return nil }
        let value: NutrientProgress?
        switch nutrient {
        case .energy: value = progress.energy
        case .protein: value = progress.protein
        case .carbohydrate: value = progress.carbohydrate
        case .fat: value = progress.fat
        default: value = nil
        }
        // A day with no entries has zero logged intake. A food that omits a
        // nutrient still leaves that nutrient unknown, never an invented zero.
        guard let value, value.unreported == 0 else { return nil }
        return value.consumed
    }

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

    static func portion(_ entry: FoodEntry, roundedGrams: Bool = false) -> String {
        if entry.food.unweighed == true { return "Whole portion" }
        let grams = roundedGrams ? entry.grams.formatted(.number.precision(.fractionLength(0))) : TrainingFormat.number(entry.grams)
        if let serving = entry.serving, let quantity = entry.quantity {
            let measure = NutritionPortionMeasure.saved(serving, food: entry.food.foodForLogging())
            if !measure.symbol.isEmpty {
                return "\(TrainingFormat.number(quantity)) \(measure.symbol) · \(grams) g"
            }
            return "\(TrainingFormat.number(quantity)) × \(serving.name) · \(grams) g"
        }
        return "\(grams) g"
    }

    static func day(_ date: LocalDate, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
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
