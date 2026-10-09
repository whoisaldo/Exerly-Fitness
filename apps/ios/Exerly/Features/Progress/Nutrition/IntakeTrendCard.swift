import ExerlyCore
import SwiftUI

/// Calories and the three macros over the span: an average for each against
/// its target, then the chosen one day by day, with a readout for the day
/// under a finger.
struct IntakeTrendCard: View {
    let series: IntakeSeries
    let range: IntakeRange
    let today: LocalDate
    @State private var metric: Nutrient = .energy
    @State private var selection: LocalDate?
    @Environment(\.dynamicTypeSize) private var typeSize

    static let metrics: [Nutrient] = [.energy, .protein, .carbohydrate, .fat]

    var body: some View {
        let bars = series.bars(metric, length: range.barDays)
        ExCard {
            ExEyebrow("Calories and macros", color: .exPrimaryText)
            tiles
            readout(bars)
            if range != .yesterday, series.countedDays + series.partialDays > 0 {
                IntakeBarChart(bars: bars, nutrient: metric, average: series.average(metric), range: range, selection: $selection)
                    .frame(height: typeSize.isAccessibilitySize ? 240 : 190)
                    .accessibilityLabel("\(IntakeFormat.name(metric)) \(range.barDays == 7 ? "by week" : "by day"), \(IntakeFormat.spoken(range))")
                    .accessibilityValue(chartSummary(bars))
                    .accessibilityHint("Swipe up or down to step through the days")
                    .accessibilityIdentifier("nutrition.chart")
                legend
            }
            energySplit
        }
        .onChange(of: range) { _, _ in selection = nil }
        .onChange(of: metric) { _, _ in UISelectionFeedbackGenerator().selectionChanged() }
    }

    // MARK: Tiles

    private var tiles: some View {
        let columns = typeSize.isAccessibilitySize ? 1 : typeSize >= .xxLarge ? 2 : 4
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: ExSpacing.small), count: columns),
                         spacing: ExSpacing.small) {
            ForEach(Self.metrics, id: \.self) { tile($0) }
        }
    }

    private func tile(_ nutrient: Nutrient) -> some View {
        let average = series.average(nutrient)
        let comparison = series.comparison(nutrient)
        let selected = nutrient == metric
        return Button {
            withAnimation(.snappy) { metric = nutrient }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Circle().fill(IntakeFormat.color(nutrient)).frame(width: 6, height: 6)
                    Text(IntakeFormat.name(nutrient, short: true)).font(.exCaption.weight(.medium))
                        .foregroundStyle(Color.exTextSecondary).lineLimit(1)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(average.map { IntakeFormat.number($0, nutrient.unit) } ?? "–").font(.exStatSmall).monospacedDigit()
                        .foregroundStyle(Color.exTextPrimary)
                    Text(nutrient.unit.rawValue).font(.exSmall).foregroundStyle(Color.exTextMuted)
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                ExProgressBar(value: comparison?.share ?? 0, total: 1, color: IntakeFormat.color(nutrient))
                Text(comparison?.share.map(IntakeFormat.percent) ?? "No target").font(.exSmall).monospacedDigit()
                    .foregroundStyle(Color.exTextMuted).lineLimit(1)
            }
            .padding(ExSpacing.small + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.exPrimary.opacity(0.12) : Color.exSurface2,
                        in: RoundedRectangle(cornerRadius: ExRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ExRadius.control, style: .continuous)
                    .strokeBorder(selected ? Color.exPrimary.opacity(0.7) : .clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(TodayPressStyle())
        .accessibilityLabel(IntakeFormat.name(nutrient))
        .accessibilityValue(tileSummary(nutrient, average: average, comparison: comparison))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Shows it on the chart")
        .accessibilityIdentifier("nutrition.metric.\(nutrient.rawValue)")
    }

    private func tileSummary(_ nutrient: Nutrient, average: Double?, comparison: GoalComparison?) -> String {
        guard let average else { return "No counted days" }
        var text = "\(IntakeFormat.spokenAmount(average, nutrient)) average per counted day"
        if let comparison, let share = comparison.share {
            text += ", target \(IntakeFormat.spokenAmount(comparison.reference, nutrient)), \(IntakeFormat.spokenPercent(share))"
        }
        return text
    }

    // MARK: Readout

    /// The span's average for the chosen metric, or the picked bar's values.
    @ViewBuilder
    private func readout(_ bars: [IntakeBar]) -> some View {
        let picked = selection.flatMap { day in bars.first { $0.start == day } }
        HStack(alignment: .top, spacing: ExSpacing.small) {
            VStack(alignment: .leading, spacing: 3) {
                ExEyebrow(readoutTitle(picked))
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(readoutValue(picked).map { IntakeFormat.number($0, metric.unit) } ?? "–")
                        .font(.exStat).monospacedDigit().foregroundStyle(Color.exTextPrimary)
                        .contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.6)
                    Text(metric.unit.rawValue).font(.exBodyMedium).foregroundStyle(Color.exTextSecondary)
                }
                Text(readoutDetail(picked)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(readoutTitle(picked)). " + (readoutValue(picked).map { IntakeFormat.spokenAmount($0, metric) } ?? "Nothing counted")
                + ". \(readoutDetail(picked))")
            .accessibilityIdentifier("nutrition.readout")
            Spacer(minLength: 0)
            if picked != nil {
                Button {
                    withAnimation(.snappy) { selection = nil }
                } label: {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Color.exTextSecondary)
                        .frame(width: 30, height: 30).background(Color.exSurface2, in: Circle())
                        .frame(width: 44, height: 44).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show the average")
                .accessibilityIdentifier("nutrition.clearSelection")
            }
        }
    }

    private func readoutTitle(_ picked: IntakeBar?) -> String {
        guard let picked else {
            return range == .yesterday ? BodyFormat.day(series.through, today: today)
                : "Average · \(IntakeFormat.days(series.countedDays)) counted"
        }
        if picked.days > 1 {
            return "\(IntakeFormat.span(picked.start, picked.end, today: today)) · \(IntakeFormat.days(picked.countedDays)) counted"
        }
        let day = series.days.first { $0.date == picked.start }
        let status = if let day, day.counted {
            day.status == .fasting ? "Fast" : day.status == .complete ? "Complete" : "Counted"
        } else {
            day?.isPartial == true ? "Partial, not counted" : "Not logged"
        }
        return "\(BodyFormat.day(picked.start, today: today)) · \(status)"
    }

    private func readoutValue(_ picked: IntakeBar?) -> Double? {
        guard let picked else { return series.average(metric) }
        return picked.value ?? picked.uncounted
    }

    private func readoutDetail(_ picked: IntakeBar?) -> String {
        guard let picked else {
            guard series.countedDays > 0 else { return "No day in this span counts yet." }
            guard let comparison = series.comparison(metric), let share = comparison.share else {
                return "No target was set for these days."
            }
            var parts = ["Target \(IntakeFormat.amount(comparison.reference, metric))",
                         "\(IntakeFormat.signed(comparison.difference, metric)) (\(IntakeFormat.percent(share)))"]
            if range != .yesterday {
                parts.append("\(comparison.met) of \(IntakeFormat.days(comparison.days)) within 10%")
            }
            return parts.joined(separator: " · ")
        }
        if picked.value == nil {
            if picked.uncounted != nil { return "Marked partial, so it's left out of averages." }
            return picked.days > 1 ? "No day in this week counts." : "Nothing was logged."
        }
        var parts: [String] = []
        if let reference = picked.goal?.reference, let value = picked.value {
            parts.append("Target \(IntakeFormat.amount(reference, metric))")
            parts.append(IntakeFormat.signed(value - reference, metric))
        }
        if picked.days == 1, let day = series.days.first(where: { $0.date == picked.start }) {
            let macros = Self.metrics.filter { $0 != metric && $0 != .energy }.map { nutrient in
                "\(String(IntakeFormat.name(nutrient, short: true).prefix(1))) \(IntakeFormat.amount(day.totals[nutrient] ?? 0, nutrient))"
            }
            parts.append(macros.joined(separator: " "))
        }
        return parts.joined(separator: " · ")
    }

    private func chartSummary(_ bars: [IntakeBar]) -> String {
        let values = bars.compactMap(\.value)
        guard let low = values.min(), let high = values.max() else { return "No counted days" }
        var text = "\(values.count) \(range.barDays == 7 ? "weeks" : "counted days") from \(IntakeFormat.spokenAmount(low, metric)) "
            + "to \(IntakeFormat.spokenAmount(high, metric))"
        if let average = series.average(metric) { text += ", averaging \(IntakeFormat.spokenAmount(average, metric))" }
        if series.partialDays > 0 { text += ". \(IntakeFormat.days(series.partialDays)) marked partial, not counted" }
        return text
    }

    // MARK: Legend and split

    private var legend: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.tight))
            : AnyLayout(HStackLayout(spacing: ExSpacing.item))
        return layout {
            legendItem(Text(metric == .energy ? "Within 10%" : "Target ±10%")) {
                RoundedRectangle(cornerRadius: 2).fill(Color.exTextSecondary.opacity(0.25)).frame(width: 12, height: 8)
                    .overlay { Rectangle().fill(Color.exTextPrimary.opacity(0.7)).frame(height: 1.4) }
            }
            legendItem(Text("Average")) {
                Capsule().fill(Color.exAccent).frame(width: 12, height: 2)
            }
            if series.partialDays > 0 {
                legendItem(Text("Partial")) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.exTextMuted.opacity(0.45)).frame(width: 8, height: 10)
                }
            }
        }
        .font(.exSmall).foregroundStyle(Color.exTextMuted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The shaded band is within 10 percent of the target, the line is the target, and the dashed line is "
            + "the average. Faded bars are days marked partial, which don't count.")
    }

    private func legendItem(_ label: Text, @ViewBuilder symbol: () -> some View) -> some View {
        HStack(spacing: 5) { symbol(); label.lineLimit(typeSize.isAccessibilitySize ? nil : 1) }
    }

    /// Where the average day's energy came from.
    @ViewBuilder
    private var energySplit: some View {
        let shares = series.energyShares
        let parts = [Nutrient.protein, .carbohydrate, .fat, .alcohol].compactMap { nutrient in shares[nutrient].map { (nutrient, $0) } }
        if !parts.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Energy from macros").font(.exCaption.weight(.medium)).foregroundStyle(Color.exTextSecondary)
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(parts, id: \.0) { part in
                            Rectangle().fill(IntakeFormat.color(part.0))
                                .frame(width: max(0, geometry.size.width - CGFloat(parts.count - 1) * 2) * part.1)
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 8)
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(spacing: ExSpacing.item))
                layout {
                    ForEach(parts, id: \.0) { part in
                        HStack(spacing: 4) {
                            Circle().fill(IntakeFormat.color(part.0)).frame(width: 6, height: 6)
                            Text("\(IntakeFormat.name(part.0, short: true)) \(IntakeFormat.percent(part.1))").monospacedDigit()
                        }
                    }
                }
                .font(.exSmall).foregroundStyle(Color.exTextSecondary)
            }
            .padding(.top, ExSpacing.tight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Energy from macros on the average counted day: "
                + parts.map { "\(IntakeFormat.name($0.0)) \(IntakeFormat.spokenPercent($0.1))" }.joined(separator: ", "))
            .accessibilityIdentifier("nutrition.energySplit")
        }
    }
}
