import ExerlyCore
import SwiftUI

/// One nutrient over the span: its average against the goal, day by day, and
/// every food that supplied it with its share.
struct NutrientDetailView: View {
    let store: NutritionStore
    let row: NutrientOverview.Row
    let series: IntakeSeries
    let range: IntakeRange
    let today: LocalDate
    @State private var selection: LocalDate?
    @State private var showsAll = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var nutrient: Nutrient { row.nutrient }

    var body: some View {
        let contributions = store.contributions(of: nutrient, from: series.from, through: series.through)
        ExScreen {
            summary(contributions)
            if range != .yesterday, series.countedDays > 0 { chartCard }
            foods(contributions)
        }
        .navigationTitle(IntakeFormat.name(nutrient))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Summary

    private func summary(_ contributions: NutrientContributions) -> some View {
        let comparison = series.comparison(nutrient)
        return ExCard {
            ExEyebrow("\(IntakeFormat.spokenSpan(series.from, series.through, today: today)) · "
                + "\(IntakeFormat.days(series.countedDays)) counted", color: .exPrimaryText)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(row.observedDays > 0 ? IntakeFormat.number(row.average, nutrient.unit) : "–")
                        .font(.exStat).monospacedDigit().foregroundStyle(Color.exTextPrimary)
                    Text(nutrient.unit.rawValue).font(.exBodyMedium).foregroundStyle(Color.exTextSecondary)
                    if let share = row.shareOfGoal, row.observedDays > 0 {
                        Text(IntakeFormat.percent(share)).font(.exLabel).monospacedDigit().foregroundStyle(Color.exTextMuted)
                    }
                }
                Text(row.observedDays > 0 ? "Average per counted day" : "No food logged on these days reported it")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.observedDays > 0
                ? "\(IntakeFormat.spokenAmount(row.average, nutrient)) a day on average"
                    + (row.shareOfGoal.map { ", \(IntakeFormat.spokenPercent($0)) of goal" } ?? "")
                : "Not reported by any food logged on these days")
            .accessibilityIdentifier("nutrition.detail.average")
            NutrientGoalBar(average: row.observedDays > 0 ? row.average : nil, goal: row.goal, nutrient: nutrient, height: 8)
            if let goal = row.goal {
                fact("Goal", "\(IntakeFormat.goal(goal, nutrient)), \(goalSource)",
                     spoken: "\(IntakeFormat.spokenGoal(goal, nutrient)), \(goalSource)")
            }
            if let comparison, row.observedDays > 0 {
                fact("Days in range", "\(comparison.met) of \(IntakeFormat.days(comparison.days))",
                     spoken: "\(comparison.met) of \(IntakeFormat.days(comparison.days)) met the goal")
            }
            if contributions.unreported > 0 {
                Label {
                    Text("\(contributions.unreported) of \(IntakeFormat.entries(contributions.entries)) on counted days didn't report "
                        + "\(IntakeFormat.name(nutrient).lowercased()), so the real amount is likely higher.")
                } icon: {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(Color.exWarning)
                }
                .font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("nutrition.detail.unreported")
            }
        }
    }

    private var goalSource: String {
        if [.energy, .protein, .carbohydrate, .fat].contains(nutrient) { return "from your plan" }
        let plan = series.plans.last { $0.startDate <= series.through }
        if plan?.nutrientGoals?[nutrient] != nil { return "your goal" }
        return "US FDA daily value"
    }

    private func fact(_ title: String, _ value: String, spoken: String) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return layout {
            Text(title).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: ExSpacing.small) }
            Text(value).font(.exCaption.weight(.medium)).foregroundStyle(Color.exTextPrimary).monospacedDigit()
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(spoken)")
    }

    // MARK: Chart

    private var chartCard: some View {
        let bars = series.bars(nutrient, length: range.barDays)
        let picked = selection.flatMap { day in bars.first { $0.start == day } }
        return ExCard {
            HStack(alignment: .firstTextBaseline) {
                ExEyebrow(range.barDays == 7 ? "By week" : "By day")
                Spacer(minLength: ExSpacing.small)
                if picked != nil {
                    Button("Clear") { selection = nil }.font(.exCaption.weight(.semibold)).foregroundStyle(Color.exPrimaryText)
                        .frame(minHeight: 44)
                }
            }
            Text(pickedText(picked)).font(.exCaption).foregroundStyle(Color.exTextSecondary).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("nutrition.detail.readout")
            IntakeBarChart(bars: bars, nutrient: nutrient, average: series.average(nutrient), range: range, selection: $selection)
                .frame(height: typeSize.isAccessibilitySize ? 220 : 170)
                .accessibilityLabel("\(IntakeFormat.name(nutrient)) \(range.barDays == 7 ? "by week" : "by day"), \(IntakeFormat.spoken(range))")
                .accessibilityHint("Swipe up or down to step through the days")
        }
    }

    private func pickedText(_ picked: IntakeBar?) -> String {
        guard let picked else { return "Touch a bar for that day. The dashed line is the average; the solid line is the target." }
        let when = picked.days > 1 ? IntakeFormat.span(picked.start, picked.end, today: today) : BodyFormat.day(picked.start, today: today)
        if let value = picked.value {
            var text = "\(when): \(IntakeFormat.amount(value, nutrient))"
            if picked.days > 1 { text += " a day over \(IntakeFormat.days(picked.countedDays)) counted" }
            if let reference = picked.goal?.reference { text += " · goal \(IntakeFormat.amount(reference, nutrient))" }
            return text
        }
        if let logged = picked.uncounted { return "\(when): \(IntakeFormat.amount(logged, nutrient)) logged, marked partial, not counted" }
        return "\(when): nothing counted"
    }

    // MARK: Foods

    @ViewBuilder
    private func foods(_ contributions: NutrientContributions) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            ExSectionHeading("Foods", detail: contributions.foods.isEmpty ? nil
                : "\(contributions.foods.count) · \(IntakeFormat.amount(contributions.total, nutrient)) in all")
            if contributions.foods.isEmpty {
                ExCard {
                    Text(series.countedDays == 0 ? "No day in this span counts yet."
                         : "No food logged on counted days supplied any \(IntakeFormat.name(nutrient).lowercased()).")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                let shown = showsAll ? contributions.foods : Array(contributions.foods.prefix(12))
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, food in
                        if index > 0 { Rectangle().fill(Color.exBorder.opacity(0.45)).frame(height: 0.5).padding(.leading, ExSpacing.content) }
                        foodRow(food, rank: index + 1)
                            .accessibilityIdentifier("nutrition.contributor.\(index)")
                    }
                }
                .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous).strokeBorder(Color.exBorder.opacity(0.5), lineWidth: 0.5)
                }
                if contributions.foods.count > shown.count {
                    Button("Show all \(contributions.foods.count) foods") { showsAll = true }
                        .font(.exBodyMedium).foregroundStyle(Color.exPrimaryText).frame(maxWidth: .infinity, minHeight: 44)
                }
                Text("Shares are of the \(IntakeFormat.name(nutrient).lowercased()) every reporting entry added up to on counted days. "
                    + "Partial days are left out, as they are from the averages.")
                    .font(.exCaption).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func foodRow(_ food: FoodContribution, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: ExSpacing.small) {
                if !typeSize.isAccessibilitySize {
                    Text("\(rank)").font(.exCaption.weight(.semibold)).monospacedDigit().foregroundStyle(Color.exTextMuted)
                        .frame(minWidth: 18, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(food.name).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary).fixedSize(horizontal: false, vertical: true)
                    Text(foodDetail(food)).font(.exSmall).foregroundStyle(Color.exTextMuted).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: ExSpacing.small)
                Text(IntakeFormat.percent(food.share)).font(.exStatSmall).monospacedDigit().foregroundStyle(Color.exTextPrimary)
            }
            ExProgressBar(value: food.share, total: 1, color: IntakeFormat.color(nutrient))
                .padding(.leading, typeSize.isAccessibilitySize ? 0 : 26)
        }
        .padding(.horizontal, ExSpacing.content).padding(.vertical, ExSpacing.item)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(food.name), \(IntakeFormat.spokenPercent(food.share)), \(IntakeFormat.spokenAmount(food.amount, nutrient)) "
            + "in all, \(IntakeFormat.number(food.perDay, nutrient.unit)) a counted day, \(IntakeFormat.entries(food.entries))")
    }

    private func foodDetail(_ food: FoodContribution) -> String {
        var parts = [food.brand, "\(IntakeFormat.amount(food.amount, nutrient))"].compactMap { $0 }
        if range != .yesterday { parts.append("\(IntakeFormat.amount(food.perDay, nutrient)) a day") }
        parts.append(IntakeFormat.entries(food.entries))
        return parts.joined(separator: " · ")
    }
}
