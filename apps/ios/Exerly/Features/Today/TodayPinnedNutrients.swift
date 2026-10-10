import ExerlyCore
import SwiftUI

/// The nutrients pinned to Today, under the macros and read the same way:
/// what's left to go first, then what's eaten of the goal, "Not reported"
/// when no food logged reports it, and how many foods the total comes from
/// when some don't say. Side by side, or one under another at large text sizes.
struct TodayPinnedNutrients: View {
    let days: [NutrientDay]
    /// Opens nutrient goals and pins.
    let open: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stacked = typeSize >= .xxLarge
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.item))
            : AnyLayout(HStackLayout(alignment: .top, spacing: ExSpacing.item))
        layout {
            ForEach(days) { day in
                Button(action: open) { item(day, stacked: stacked) }
                    .buttonStyle(TodayPressStyle())
                    .accessibilityLabel(IntakeFormat.name(day.nutrient))
                    .accessibilityValue(spoken(day))
                    .accessibilityHint("Opens nutrient goals and pins")
                    .accessibilityIdentifier("today.pinned.\(day.nutrient.rawValue)")
            }
        }
    }

    /// Side by side: name, standing, bar, then eaten of the goal and
    /// completeness, a line each. Stacked: name and standing share a line
    /// where they fit, and so do the last two.
    private func item(_ day: NutrientDay, stacked: Bool) -> some View {
        let name = Text(IntakeFormat.name(day.nutrient)).font(.exLabel).foregroundStyle(Color.exTextSecondary)
        let status = standing(day)
        let details = [IntakeFormat.eatenOfGoal(day) ?? day.goal.map { IntakeFormat.goalSummary($0, day.nutrient) } ?? "No goal",
                       IntakeFormat.completeness(reporting: day.reporting, entries: day.entries)].compactMap { $0 }
        return VStack(alignment: .leading, spacing: 4) {
            if stacked {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: ExSpacing.small) { name; Spacer(minLength: ExSpacing.small); status }
                    VStack(alignment: .leading, spacing: 2) { name; status }
                }
            } else {
                name.lineLimit(1).minimumScaleFactor(0.8)
                status.lineLimit(1).minimumScaleFactor(0.7)
            }
            if day.goal != nil { NutrientGoalBar(average: day.amount, goal: day.goal, nutrient: day.nutrient, height: 5) }
            if stacked {
                Text(details.joined(separator: " · ")).font(.exSmall).monospacedDigit().foregroundStyle(Color.exTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(details, id: \.self) {
                    Text($0).font(.exSmall).monospacedDigit().foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// "16 g to go" with its amount large, as a macro's "57 g left"; over a
    /// limit in the warning colour, over a target in the ring's.
    private func standing(_ day: NutrientDay) -> Text {
        guard let eaten = day.amount else { return Text("Not reported").font(.exLabel).foregroundStyle(Color.exTextMuted) }
        guard let parts = IntakeFormat.standingParts(day) else {
            return Text(IntakeFormat.amount(eaten, day.nutrient)).font(.exStatSmall).foregroundStyle(Color.exTextPrimary)
        }
        guard let value = parts.amount else { return Text(parts.words).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary) }
        var color = Color.exTextPrimary
        if case .over = day.standing { color = day.goal?.ceiling != nil ? .exWarning : .exAccent }
        let amount = Text(IntakeFormat.number(value, day.nutrient.unit)).font(.exStatSmall).foregroundStyle(color)
        let words = Text(" \(day.nutrient.unit.rawValue) \(parts.words)").font(.exCaption).foregroundStyle(Color.exTextSecondary)
        return Text("\(amount)\(words)").monospacedDigit()
    }

    private func spoken(_ day: NutrientDay) -> String {
        var parts = [day.amount.map { day.goal == nil ? IntakeFormat.spokenAmount($0, day.nutrient) : IntakeFormat.standing(day, spoken: true) }
            ?? "Not reported"]
        parts.append(IntakeFormat.eatenOfGoal(day, spoken: true)
            ?? day.goal.map { IntakeFormat.goalSummary($0, day.nutrient, spoken: true) } ?? "No goal")
        if let completeness = IntakeFormat.completeness(reporting: day.reporting, entries: day.entries, spoken: true) {
            parts.append(completeness)
        }
        return parts.joined(separator: ", ")
    }
}
