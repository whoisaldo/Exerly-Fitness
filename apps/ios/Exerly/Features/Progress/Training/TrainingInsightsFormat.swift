import ExerlyCore
import SwiftUI

/// How Progress → Training writes and speaks loads, volume, changes and dates.
/// Every load arrives in kilograms and leaves in the account's unit.
enum InsightFormat {
    static func unitName(_ unit: MassUnit) -> String { unit == .pounds ? "pounds" : "kilograms" }

    /// An estimate: whole pounds, or kilograms to 0.5.
    static func estimate(_ kilograms: Double, _ unit: MassUnit, withUnit: Bool = true) -> String {
        let value = Mass.kg(kilograms).value(in: unit)
        let rounded = unit == .pounds ? value.rounded() : (value * 2).rounded() / 2
        let text = rounded.formatted(.number.precision(.fractionLength(0...1)))
        return withUnit ? "\(text) \(unit.rawValue)" : text
    }

    static func spokenEstimate(_ kilograms: Double, _ unit: MassUnit) -> String {
        "\(estimate(kilograms, unit, withUnit: false)) \(unitName(unit))"
    }

    /// A logged load as entered, to 0.1 at most.
    static func load(_ kilograms: Double, _ unit: MassUnit, withUnit: Bool = true) -> String {
        let text = Mass.kg(kilograms).value(in: unit).formatted(.number.precision(.fractionLength(0...1)))
        return withUnit ? "\(text) \(unit.rawValue)" : text
    }

    /// "+12 lb", "−2.5 kg" or "±0 lb", with a true minus sign.
    static func change(_ kilograms: Double, _ unit: MassUnit, suffix: String = "") -> String {
        let value = Mass.kg(kilograms).value(in: unit)
        let step = unit == .pounds ? 1.0 : 0.5
        let rounded = (value / step).rounded() * step
        let sign = rounded > 0 ? "+" : rounded < 0 ? "−" : "±"
        return "\(sign)\(abs(rounded).formatted(.number.precision(.fractionLength(0...1)))) \(unit.rawValue)\(suffix)"
    }

    /// A small weekly rate, to 0.1.
    static func rate(_ kilograms: Double, _ unit: MassUnit) -> String {
        let value = Mass.kg(kilograms).value(in: unit)
        let rounded = (value * 10).rounded() / 10
        let sign = rounded > 0 ? "+" : rounded < 0 ? "−" : "±"
        return "\(sign)\(abs(rounded).formatted(.number.precision(.fractionLength(1)))) \(unit.rawValue)"
    }

    /// A small unsigned amount, to 0.1: "0.3 lb".
    static func amount(_ kilograms: Double, _ unit: MassUnit, withUnit: Bool = true) -> String {
        let text = abs(Mass.kg(kilograms).value(in: unit)).formatted(.number.precision(.fractionLength(1)))
        return withUnit ? "\(text) \(unit.rawValue)" : text
    }

    static func spokenRate(_ kilograms: Double, _ unit: MassUnit) -> String {
        let value = (Mass.kg(kilograms).value(in: unit) * 10).rounded() / 10
        guard value != 0 else { return "flat" }
        return "\(value < 0 ? "down" : "up") \(abs(value).formatted(.number.precision(.fractionLength(1)))) \(unitName(unit)) a week"
    }

    static func spokenChange(_ kilograms: Double, _ unit: MassUnit) -> String {
        let value = Mass.kg(kilograms).value(in: unit)
        let step = unit == .pounds ? 1.0 : 0.5
        let rounded = (abs(value) / step).rounded() * step
        guard rounded > 0 else { return "no change" }
        return "\(value < 0 ? "down" : "up") \(rounded.formatted(.number.precision(.fractionLength(0...1)))) \(unitName(unit))"
    }

    static func percent(_ share: Double) -> String {
        let value = (share * 100).rounded()
        let sign = value > 0 ? "+" : value < 0 ? "−" : "±"
        return "\(sign)\(Int(abs(value)))%"
    }

    /// Volume in unit-reps: "52.3K lb", spoken in full.
    static func volume(_ kilograms: Double, _ unit: MassUnit, withUnit: Bool = true) -> String {
        let value = Mass.kg(kilograms).value(in: unit)
        let text = value >= 10_000
            ? value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
            : value.formatted(.number.precision(.fractionLength(0)))
        return withUnit ? "\(text) \(unit.rawValue)" : text
    }

    static func spokenVolume(_ kilograms: Double, _ unit: MassUnit) -> String {
        "\(Mass.kg(kilograms).value(in: unit).formatted(.number.precision(.fractionLength(0)))) \(unitName(unit))"
    }

    /// Fractional sets to 0.5 at most: "12", "7.5".
    static func sets(_ value: Double) -> String {
        ((value * 2).rounded() / 2).formatted(.number.precision(.fractionLength(0...1)))
    }

    static func hours(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    /// "Today", "Yesterday", "Tue, Oct 6", or "Oct 6, 2025" in another year.
    static func day(_ date: LocalDate, today: LocalDate) -> String { BodyFormat.day(date, today: today) }
    static func shortDate(_ date: LocalDate) -> String { BodyFormat.shortDate(date) }

    static func weeks(_ count: Int) -> String { count == 1 ? "1 week" : "\(count) weeks" }
    static func sessions(_ count: Int) -> String { count == 1 ? "1 session" : "\(count) sessions" }
    static func workouts(_ count: Int) -> String { count == 1 ? "1 workout" : "\(count) workouts" }

    static func spanPhrase(_ span: TrainingInsights.Span) -> String {
        switch span {
        case .fourWeeks: "the last 4 weeks"
        case .threeMonths: "the last 3 months"
        case .sixMonths: "the last 6 months"
        case .year: "the last year"
        case .all: "all your training"
        }
    }

    static func spokenSpan(_ span: TrainingInsights.Span) -> String {
        switch span {
        case .fourWeeks: "4 weeks"
        case .threeMonths: "3 months"
        case .sixMonths: "6 months"
        case .year: "1 year"
        case .all: "All time"
        }
    }

    static func axisFormat(_ span: TrainingInsights.Span) -> Date.FormatStyle {
        let style = Date.FormatStyle(timeZone: BodyDates.utc)
        return switch span {
        case .fourWeeks, .threeMonths: style.month(.abbreviated).day()
        case .sixMonths, .year: style.month(.abbreviated)
        case .all: style.month(.abbreviated).year(.twoDigits)
        }
    }

    /// A set as "225 lb × 5 · RIR 1".
    static func set(_ set: PerformedSet, unit: MassUnit, bodyweight: Bool = false) -> String {
        let effort = set.primary
        var text: String
        if let load = effort.load, !load.isZero {
            text = "\(load.value(in: unit).formatted(.number.precision(.fractionLength(0...2)))) \(unit.rawValue)"
            if bodyweight { text = "BW + " + text }
        } else {
            text = bodyweight ? "Bodyweight" : "–"
        }
        if let reps = effort.reps { text += " × \(reps)" }
        if let rir = set.effectiveRIR { text += " · RIR \(rir >= 6 ? "6+" : rir.formatted(.number.precision(.fractionLength(0...1))))" }
        return text
    }

    // MARK: Records

    static func recordTitle(_ kind: PersonalRecord.Kind) -> String {
        switch kind {
        case .oneRepMax: "Estimated 1RM"
        case .heaviestLoad: "Heaviest weight"
        case .setVolume: "Best set volume"
        case .repsAtLoad: "Rep record"
        case .duration: "Longest set"
        case .distance: "Longest distance"
        }
    }

    static func recordIcon(_ kind: PersonalRecord.Kind) -> String {
        switch kind {
        case .oneRepMax: "bolt.fill"
        case .heaviestLoad: "scalemass.fill"
        case .setVolume: "square.stack.3d.up.fill"
        case .repsAtLoad: "repeat"
        case .duration: "timer"
        case .distance: "figure.run"
        }
    }

    /// The record's value and what it beat, in the account's unit.
    static func recordValue(_ record: PersonalRecord, unit: MassUnit) -> (value: String, detail: String, spoken: String) {
        switch record.kind {
        case .oneRepMax, .heaviestLoad:
            return (estimate(record.value, unit), "was \(estimate(record.previous, unit))",
                    "\(spokenEstimate(record.value, unit)), previous best \(spokenEstimate(record.previous, unit))")
        case .setVolume:
            return (volume(record.value, unit), "was \(volume(record.previous, unit))",
                    "\(spokenVolume(record.value, unit)), previous best \(spokenVolume(record.previous, unit))")
        case .repsAtLoad:
            let reps = Int(record.value), before = Int(record.previous)
            let load = record.load.map { self.load($0.kilograms, unit) } ?? "this weight"
            let spokenLoad = record.load.map { "\(self.load($0.kilograms, unit, withUnit: false)) \(unitName(unit))" } ?? load
            return ("\(reps) × \(load)", "was \(before) reps", "\(reps) reps at \(spokenLoad), previous best \(before)")
        case .duration:
            let value = Duration.seconds(record.value).formatted(.time(pattern: .minuteSecond))
            let previous = Duration.seconds(record.previous).formatted(.time(pattern: .minuteSecond))
            return (value, "was \(previous)", "\(value), previous best \(previous)")
        case .distance:
            let value = Foundation.Measurement(value: record.value, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated))
            let previous = Foundation.Measurement(value: record.previous, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated))
            return (value, "was \(previous)", "\(value), previous best \(previous)")
        }
    }
}

/// The span picker shared by the overview and a lift's detail.
struct InsightSpanPicker: View {
    @Binding var span: TrainingInsights.Span
    var identifier = "training.span"
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            Picker("Span", selection: $span) {
                ForEach(TrainingInsights.Span.allCases) { Text(InsightFormat.spokenSpan($0)).tag($0) }
            }
            .pickerStyle(.menu).tint(Color.exPrimaryText)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityIdentifier(identifier)
        } else {
            HStack(spacing: 2) {
                ForEach(TrainingInsights.Span.allCases) { option in
                    Button { span = option } label: {
                        Text(option.rawValue).font(.exLabel)
                            .foregroundStyle(option == span ? Color.white : Color.exTextSecondary)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(option == span ? Color.exActionFill : .clear,
                                        in: RoundedRectangle(cornerRadius: ExRadius.control - 4))
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(InsightFormat.spokenSpan(option))
                    .accessibilityAddTraits(option == span ? .isSelected : [])
                    .accessibilityIdentifier("\(identifier).\(option.rawValue)")
                }
            }
            .padding(.horizontal, 3)
            .background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
            .sensoryFeedback(.selection, trigger: span)
        }
    }
}

/// A small coloured symbol tile, used beside rows.
struct InsightIcon: View {
    let systemName: String
    var color: Color = .exPrimaryText

    var body: some View {
        Image(systemName: systemName).font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color).frame(width: 32, height: 32)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }
}
