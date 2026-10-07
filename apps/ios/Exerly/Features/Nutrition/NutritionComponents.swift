import ExerlyCore
import SwiftUI

struct NutritionNumberInput: View {
    let title: String
    @Binding var text: String
    var identifier = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.exLabel).foregroundStyle(Color.exTextSecondary)
            TextField("Unknown", text: $text).keyboardType(.decimalPad).font(.exStatMedium)
                .padding(ExSpacing.item).background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                .accessibilityLabel(title).accessibilityIdentifier(identifier)
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
    @Environment(\.dynamicTypeSize) private var typeSize

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
            .background(Color.exBackground)
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
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
    var showHeading = true
    var showTargetNote = true
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var energySize: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: ExSpacing.page) {
            if showHeading { ExEyebrow("Daily nutrition", color: .exPrimary) }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(amounts[.energy].map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—")
                    .font(.system(size: energySize, weight: .bold, design: .rounded)).foregroundStyle(Color.exTextPrimary)
                    .contentTransition(.numericText())
                Text("kcal").font(.exBody).foregroundStyle(Color.exTextSecondary)
            }.accessibilityElement(children: .combine)
            if let targets {
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    ExProgressBar(value: amounts[.energy] ?? 0, total: targets.energy)
                    Text("of \(targets.energy.formatted(.number.precision(.fractionLength(0)))) kcal target")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                        .accessibilityIdentifier("nutrition.targetEnergy").accessibilityValue(String(targets.energy))
                }
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.content))
                : AnyLayout(HStackLayout(alignment: .top, spacing: ExSpacing.item))
            layout {
                macro(.protein, label: "Protein", target: targets?.protein, color: .exPrimary)
                macro(.carbohydrate, label: "Carbs", target: targets?.carbohydrate, color: .exAccent)
                macro(.fat, label: "Fat", target: targets?.fat, color: .exSecondary)
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
            Text(amounts[nutrient].map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) g" } ?? "—")
                .font(.exStatSmall).foregroundStyle(Color.exTextPrimary)
            if let target {
                ExProgressBar(value: amounts[nutrient] ?? 0, total: target, color: color)
                Text("of \(target.formatted(.number.precision(.fractionLength(0)))) g").font(.exSmall)
                    .foregroundStyle(Color.exTextSecondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .ignore)
            .accessibilityLabel(nutrient.name)
            .accessibilityValue(amounts[nutrient].map { "\(TrainingFormat.number($0)) grams" } ?? "Not reported")
    }
}

enum NutritionFormat {
    /// Preserve reviewed account targets while the account has no Core plan.
    /// This is a read-only field mapping; it never estimates or saves a target.
    static func displayTargets(current: DailyTargets?, saved: SummaryTargetsDTO?, savedDate: String?, on date: LocalDate) -> DailyTargets? {
        if let current { return current }
        guard savedDate == date.description, let saved, let energy = saved.calories,
              let protein = saved.proteinG, let fat = saved.fatG, let carbohydrate = saved.carbsG else { return nil }
        return DailyTargets(energy: Double(energy), protein: protein, fat: fat, carbohydrate: carbohydrate)
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

    static func portion(_ entry: FoodEntry) -> String {
        if let serving = entry.serving, let quantity = entry.quantity {
            return "\(TrainingFormat.number(quantity)) × \(serving.name) · \(entry.grams.formatted(.number.precision(.fractionLength(0)))) g"
        }
        return "\(entry.grams.formatted(.number.precision(.fractionLength(0)))) g"
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
