import ExerlyCore
import SwiftUI

/// Every nutrient with an amount or a goal, grouped, each as its average per
/// counted day against its goal. Each row opens the foods behind it.
struct NutrientGroupsView<Detail: View>: View {
    let overview: NutrientOverview
    @ViewBuilder let detail: (NutrientOverview.Row) -> Detail

    /// The groups in reading order; energy and the macros read as one.
    static var groups: [[Nutrient.Group]] {
        [[.energy, .macros], [.carbohydrates], [.fats], [.vitamins], [.minerals], [.aminoAcids], [.other]]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            ExSectionHeading("Every nutrient", detail: "Average per counted day")
            ForEach(Self.groups, id: \.self) { groups in
                let rows = overview.rows.filter { groups.contains($0.nutrient.group) }
                if !rows.isEmpty { group(groups[0], rows: rows) }
            }
            Text("Percentages compare each counted day with the goal in force that day. Goals without your own come from "
                + "the US FDA's daily values. A food that doesn't report a nutrient adds nothing, so check how many entries reported it.")
                .font(.exCaption).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func group(_ group: Nutrient.Group, rows: [NutrientOverview.Row]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                ExEyebrow(IntakeFormat.group(group), color: .exPrimaryText)
                Spacer(minLength: ExSpacing.small)
                let missing = rows.filter { $0.observedDays == 0 }.count
                if missing > 0 {
                    Text("\(missing) not reported").font(.exSmall).foregroundStyle(Color.exTextMuted)
                }
            }
            .padding(.horizontal, ExSpacing.content).padding(.top, ExSpacing.content).padding(.bottom, ExSpacing.tight)
            ForEach(Array(rows.enumerated()), id: \.element.nutrient) { index, row in
                if index > 0 { Rectangle().fill(Color.exBorder.opacity(0.45)).frame(height: 0.5).padding(.leading, ExSpacing.content) }
                NavigationLink { detail(row) } label: { NutrientRow(row: row) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("nutrition.nutrient.\(row.nutrient.rawValue)")
            }
        }
        .padding(.bottom, ExSpacing.small)
        .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous).strokeBorder(Color.exBorder.opacity(0.5), lineWidth: 0.5)
        }
    }
}

/// One nutrient: its average, the share of its goal, a bar with the goal
/// marked, and how many entries reported it.
struct NutrientRow: View {
    let row: NutrientOverview.Row
    @Environment(\.dynamicTypeSize) private var typeSize

    private var reported: Bool { row.observedDays > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: ExSpacing.small))
            layout {
                Text(IntakeFormat.name(row.nutrient)).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !typeSize.isAccessibilitySize { Spacer(minLength: ExSpacing.small) }
                HStack(alignment: .firstTextBaseline, spacing: ExSpacing.small) {
                    if reported {
                        Text(IntakeFormat.amount(row.average, row.nutrient)).font(.exStatSmall).monospacedDigit()
                            .foregroundStyle(Color.exTextPrimary)
                    } else {
                        Text("Not reported").font(.exLabel).foregroundStyle(Color.exTextMuted)
                    }
                    if reported, let share = row.shareOfGoal {
                        Text(IntakeFormat.percent(share)).font(.exCaption.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(shareColor).frame(minWidth: 44, alignment: .trailing)
                    }
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.exTextMuted)
                }
            }
            NutrientGoalBar(average: reported ? row.average : nil, goal: row.goal, nutrient: row.nutrient)
            if let note {
                Text(note).font(.exSmall).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, ExSpacing.content).padding(.vertical, ExSpacing.item)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityHint("Shows the foods that supplied it")
    }

    /// Over a limit warns; meeting the goal reads plainly; short of it is muted.
    private var shareColor: Color {
        guard let goal = row.goal else { return .exTextSecondary }
        if let ceiling = goal.ceiling, row.average > ceiling { return .exWarning }
        return goal.contains(row.average) ? .exTextPrimary : .exTextSecondary
    }

    private var note: String? {
        var parts: [String] = []
        if let goal = row.goal { parts.append(goalText(goal)) }
        if !reported {
            parts.append("no food logged reported it")
        } else if row.completeness < 0.95 {
            parts.append("reported by \(IntakeFormat.percent(row.completeness)) of entries")
        }
        guard !parts.isEmpty else { return nil }
        let text = parts.joined(separator: " · ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func goalText(_ goal: NutrientGoal) -> String {
        if goal.target == nil, goal.floor != nil, goal.ceiling == nil { return "Floor \(IntakeFormat.amount(goal.floor!, row.nutrient))" }
        if goal.target == nil, goal.floor == nil, let ceiling = goal.ceiling { return "Limit \(IntakeFormat.amount(ceiling, row.nutrient))" }
        return "Goal \(IntakeFormat.goal(goal, row.nutrient))"
    }

    private var spoken: String {
        var parts = [IntakeFormat.name(row.nutrient)]
        if reported {
            parts.append("\(IntakeFormat.spokenAmount(row.average, row.nutrient)) a day on average")
            if let share = row.shareOfGoal { parts.append("\(IntakeFormat.spokenPercent(share)) of goal") }
        } else {
            parts.append("not reported by any food logged")
        }
        if let goal = row.goal { parts.append("goal \(IntakeFormat.spokenGoal(goal, row.nutrient))") }
        if reported, row.completeness < 0.95 { parts.append("reported by \(IntakeFormat.spokenPercent(row.completeness)) of entries") }
        return parts.joined(separator: ", ")
    }
}

/// A bar of an amount against its goal: the floor, target and limit marked,
/// with the highest mark at four fifths of the width.
struct NutrientGoalBar: View {
    let average: Double?
    let goal: NutrientGoal?
    let nutrient: Nutrient
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let scale = self.scale
            ZStack(alignment: .leading) {
                Capsule().fill(Color.exTextSecondary.opacity(0.14))
                if let average, average > 0 {
                    Capsule().fill(fill).frame(width: max(height, width * min(average / scale, 1)))
                }
                ForEach(marks, id: \.0) { mark in
                    RoundedRectangle(cornerRadius: 1).fill(mark.2)
                        .frame(width: 2, height: height + 6)
                        .offset(x: max(0, min(width * mark.1 / scale, width - 2) - 1))
                }
            }
            .frame(height: height + 6)
        }
        .frame(height: height + 6)
        .accessibilityHidden(true)
    }

    private var marks: [(String, Double, Color)] {
        guard let goal else { return [] }
        var marks: [(String, Double, Color)] = []
        if let floor = goal.floor { marks.append(("floor", floor, Color.exTextSecondary)) }
        if let target = goal.target { marks.append(("target", target, Color.exTextPrimary)) }
        if let ceiling = goal.ceiling { marks.append(("ceiling", ceiling, Color.exWarning)) }
        return marks
    }

    private var scale: Double {
        let highest = marks.map(\.1).max() ?? 0
        if highest > 0 { return highest / 0.8 }
        return max(average ?? 1, 1)
    }

    private var fill: AnyShapeStyle {
        guard let average, let goal else { return AnyShapeStyle(IntakeFormat.color(nutrient).opacity(0.7)) }
        if let ceiling = goal.ceiling, average > ceiling { return AnyShapeStyle(Color.exWarning) }
        if goal.contains(average) {
            return AnyShapeStyle(LinearGradient(colors: [.exPrimary, .exAccent], startPoint: .leading, endPoint: .trailing))
        }
        return AnyShapeStyle(Color.exPrimary.opacity(0.6))
    }
}
