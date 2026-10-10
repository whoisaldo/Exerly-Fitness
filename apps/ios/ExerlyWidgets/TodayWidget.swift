import SwiftUI
import WidgetKit

/// Calories left today as the app's ring, with protein, carbs and fat.
struct TodayWidget: Widget {
    static let kind = "ExerlyToday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SnapshotProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetSurface() }
                .widgetURL(ExerlyLinks.today)
        }
        .configurationDisplayName("Today")
        .description("Calories left and your macros for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let day = entry.snapshot?.day(at: entry.date) {
            content(day)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.spoken(day))
        } else {
            OpenExerlyPrompt(family: family)
        }
    }

    @ViewBuilder private func content(_ day: WidgetSnapshot.Day) -> some View {
        switch family {
        case .accessoryInline:
            Label(Self.headline(day.energy), systemImage: "flame")
        case .accessoryCircular:
            Gauge(value: min(day.energy.fraction ?? 0, 1)) {
                Text("kcal")
            } currentValueLabel: {
                Text((day.energy.over ?? 0) > 0 ? "+\(Self.plain(day.energy.over ?? 0))" : Self.plain(day.energy.remaining ?? day.energy.consumed))
                    .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.headline(day.energy)).font(.headline).widgetAccentable()
                Text("P \(Self.amount(day.protein)) · C \(Self.amount(day.carbohydrate)) · F \(Self.amount(day.fat))")
                    .font(.caption).monospacedDigit()
                Gauge(value: min(day.energy.fraction ?? 0, 1)) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
        case .systemMedium:
            HStack(spacing: 16) {
                CalorieRing(energy: day.energy, lineWidth: 10)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        PulseMark(size: 14)
                        WidgetEyebrow(text: "Today")
                    }
                    MacroRow(title: "Protein", amount: day.protein, color: WidgetPalette.primaryText)
                    MacroRow(title: "Carbs", amount: day.carbohydrate, color: WidgetPalette.accent)
                    MacroRow(title: "Fat", amount: day.fat, color: WidgetPalette.secondary)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    PulseMark(size: 14)
                    WidgetEyebrow(text: "Today")
                }
                CalorieRing(energy: day.energy, lineWidth: 9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    static func plain(_ value: Double) -> String { value.formatted(.number.grouping(.never).precision(.fractionLength(0))) }

    static func amount(_ amount: WidgetSnapshot.Amount) -> String {
        amount.target.map { "\(WidgetFormat.number(amount.consumed))/\(WidgetFormat.number($0))" } ?? WidgetFormat.number(amount.consumed)
    }

    /// "1,240 kcal left", "150 kcal over" or "1,060 kcal eaten".
    static func headline(_ energy: WidgetSnapshot.Amount) -> String {
        guard energy.target != nil else { return "\(WidgetFormat.number(energy.consumed)) kcal eaten" }
        if let over = energy.over, over > 0 { return "\(WidgetFormat.number(over)) kcal over" }
        return "\(WidgetFormat.number(energy.remaining ?? 0)) kcal left"
    }

    static func spoken(_ day: WidgetSnapshot.Day) -> String {
        func macro(_ name: String, _ amount: WidgetSnapshot.Amount) -> String {
            amount.target.map { "\(name) \(WidgetFormat.number(amount.consumed)) of \(WidgetFormat.number($0)) grams" }
                ?? "\(name) \(WidgetFormat.number(amount.consumed)) grams"
        }
        let calories = day.energy.target.map { "\(headline(day.energy).replacingOccurrences(of: "kcal", with: "calories")), \(WidgetFormat.number(day.energy.consumed)) of \(WidgetFormat.number($0)) eaten" }
            ?? "\(WidgetFormat.number(day.energy.consumed)) calories eaten"
        return "Today, \(calories). \(macro("Protein", day.protein)), \(macro("Carbs", day.carbohydrate)), \(macro("Fat", day.fat))."
    }
}

/// The app's calorie ring: what's left in the middle, eaten over target beneath.
struct CalorieRing: View {
    let energy: WidgetSnapshot.Amount
    let lineWidth: CGFloat

    var body: some View {
        let over = (energy.over ?? 0) > 0
        ZStack {
            Circle().stroke(WidgetPalette.primary.opacity(0.16), lineWidth: lineWidth)
            Circle().trim(from: 0, to: min(energy.fraction ?? 0, 1))
                .stroke(WidgetPalette.ring, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(WidgetFormat.number(energy.target == nil ? energy.consumed : over ? energy.over ?? 0 : energy.remaining ?? 0))
                    .font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit()
                    .foregroundStyle(over ? WidgetPalette.accent : WidgetPalette.textPrimary)
                Text(energy.target == nil ? "kcal eaten" : over ? "kcal over" : "kcal left")
                    .font(.caption2.weight(.medium)).foregroundStyle(WidgetPalette.textSecondary)
                if let target = energy.target {
                    Text("\(WidgetFormat.number(energy.consumed)) / \(WidgetFormat.number(target))")
                        .font(.caption2).monospacedDigit().foregroundStyle(WidgetPalette.textMuted)
                }
            }
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(lineWidth + 4)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct MacroRow: View {
    let title: String
    let amount: WidgetSnapshot.Amount
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title).font(.caption.weight(.medium)).foregroundStyle(WidgetPalette.textSecondary)
                Spacer(minLength: 4)
                let consumed = Text(WidgetFormat.number(amount.consumed)).font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(WidgetPalette.textPrimary)
                let target = Text(amount.target.map { " / \(WidgetFormat.number($0)) g" } ?? " g").font(.caption2)
                    .foregroundStyle(WidgetPalette.textMuted)
                Text("\(consumed)\(target)")
            }
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            WidgetBar(fraction: amount.fraction ?? 0, color: color)
        }
    }
}
