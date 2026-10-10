import ExerlyCore
import SwiftUI

/// The nutrients pinned to Today, under the macros: each one's day so far
/// against its goal, "Not reported" when no food logged reports it, and how
/// many foods its total comes from when some don't say. Side by side, or one
/// under another at large text sizes.
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

    /// Side by side: name, amount, bar, standing and completeness, a line
    /// each. Stacked: name and amount share a line where they fit, and so do
    /// standing and completeness.
    private func item(_ day: NutrientDay, stacked: Bool) -> some View {
        let warning = overLimit(day)
        let name = Text(IntakeFormat.name(day.nutrient)).font(.exLabel).foregroundStyle(Color.exTextSecondary)
        let amount = day.amount.map {
            Text(IntakeFormat.amount($0, day.nutrient)).font(.exStatSmall).monospacedDigit()
                .foregroundStyle(warning ? Color.exWarning : Color.exTextPrimary)
        } ?? Text("Not reported").font(.exLabel).foregroundStyle(Color.exTextMuted)
        let completeness = IntakeFormat.completeness(reporting: day.reporting, entries: day.entries)
        let standing = Text(IntakeFormat.standing(day)).font(.exSmall).monospacedDigit()
            .foregroundStyle(warning ? Color.exWarning : Color.exTextSecondary)
        return VStack(alignment: .leading, spacing: 4) {
            if stacked {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: ExSpacing.small) { name; Spacer(minLength: ExSpacing.small); amount }
                    VStack(alignment: .leading, spacing: 2) { name; amount }
                }
            } else {
                name.lineLimit(1).minimumScaleFactor(0.8)
                amount.lineLimit(1).minimumScaleFactor(0.7)
            }
            if day.goal != nil { NutrientGoalBar(average: day.amount, goal: day.goal, nutrient: day.nutrient, height: 5) }
            if stacked {
                Text("\(standing)\(Text(completeness.map { " · \($0)" } ?? "").font(.exSmall).foregroundStyle(Color.exTextMuted))")
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                standing.fixedSize(horizontal: false, vertical: true)
                if let completeness {
                    Text(completeness).font(.exSmall).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func overLimit(_ day: NutrientDay) -> Bool {
        if case .over = day.standing { return day.goal?.ceiling != nil }
        return false
    }

    private func spoken(_ day: NutrientDay) -> String {
        var parts = [day.amount.map { IntakeFormat.spokenAmount($0, day.nutrient) } ?? "Not reported",
                     IntakeFormat.standing(day, spoken: true)]
        if let completeness = IntakeFormat.completeness(reporting: day.reporting, entries: day.entries, spoken: true) {
            parts.append(completeness)
        }
        return parts.joined(separator: ", ")
    }
}
