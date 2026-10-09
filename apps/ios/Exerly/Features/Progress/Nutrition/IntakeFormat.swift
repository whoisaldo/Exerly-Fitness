import ExerlyCore
import SwiftUI

/// Amounts, spans and hours as Progress → Nutrition writes and speaks them.
enum IntakeFormat {
    static func title(_ range: IntakeRange) -> String {
        switch range {
        case .yesterday: "Yesterday"
        case .week: "1W"
        case .month: "1M"
        case .quarter: "3M"
        case .year: "1Y"
        }
    }

    static func spoken(_ range: IntakeRange) -> String {
        switch range {
        case .yesterday: "Yesterday"
        case .week: "1 week"
        case .month: "1 month"
        case .quarter: "3 months"
        case .year: "1 year"
        }
    }

    /// "Calories" for energy, "Carbs" where space is short.
    static func name(_ nutrient: Nutrient, short: Bool = false) -> String {
        switch nutrient {
        case .energy: "Calories"
        case .carbohydrate: short ? "Carbs" : "Carbohydrate"
        default: nutrient.name
        }
    }

    /// Whole numbers from 10, a decimal from 1, two below.
    static func number(_ value: Double, _ unit: Nutrient.Unit) -> String {
        let magnitude = abs(value)
        let digits = unit == .kilocalories || magnitude >= 10 ? 0...0 : magnitude >= 1 ? 0...1 : 0...2
        return value.formatted(.number.precision(.fractionLength(digits)))
    }

    static func amount(_ value: Double, _ nutrient: Nutrient) -> String {
        "\(number(value, nutrient.unit)) \(nutrient.unit.rawValue)"
    }

    static func spokenAmount(_ value: Double, _ nutrient: Nutrient) -> String {
        "\(number(value, nutrient.unit)) \(unitName(nutrient.unit))"
    }

    static func unitName(_ unit: Nutrient.Unit) -> String {
        switch unit {
        case .kilocalories: "kilocalories"
        case .grams: "grams"
        case .milligrams: "milligrams"
        case .micrograms: "micrograms"
        }
    }

    /// "+110 kcal", "−60 g", with a true minus sign.
    static func signed(_ value: Double, _ nutrient: Nutrient) -> String {
        let text = number(abs(value), nutrient.unit)
        let sign = text == number(0, nutrient.unit) ? "" : value > 0 ? "+" : "−"
        return "\(sign)\(text) \(nutrient.unit.rawValue)"
    }

    static func spokenSigned(_ value: Double, _ nutrient: Nutrient) -> String {
        let text = number(abs(value), nutrient.unit)
        guard text != number(0, nutrient.unit) else { return "on target" }
        return "\(text) \(unitName(nutrient.unit)) \(value > 0 ? "over" : "under")"
    }

    static func percent(_ share: Double) -> String { "\(Int((share * 100).rounded()))%" }
    static func spokenPercent(_ share: Double) -> String { "\(Int((share * 100).rounded())) percent" }

    /// "Sep 9 – Oct 8", or one day's name.
    static func span(_ from: LocalDate, _ through: LocalDate, today: LocalDate) -> String {
        from == through ? BodyFormat.day(from, today: today) : "\(BodyFormat.shortDate(from)) – \(BodyFormat.shortDate(through))"
    }

    static func spokenSpan(_ from: LocalDate, _ through: LocalDate, today: LocalDate) -> String {
        from == through ? BodyFormat.day(from, today: today) : "\(BodyFormat.shortDate(from)) to \(BodyFormat.shortDate(through))"
    }

    /// "7 AM" or "19", in the person's clock style.
    static func hour(_ hour: Int) -> String {
        let anchor = BodyDates.calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour % 24))!
        var style = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .abbreviated))
        style.timeZone = BodyDates.utc
        return anchor.formatted(style)
    }

    static func hours(_ start: Int, _ end: Int) -> String { "\(hour(start))–\(hour(end))" }

    static func spokenHours(_ start: Int, _ end: Int) -> String { "\(hour(start)) to \(hour(end))" }

    /// How a goal reads: "at least 18 mg", "up to 2,300 mg", "35 g" or a range.
    static func goal(_ goal: NutrientGoal, _ nutrient: Nutrient) -> String {
        switch (goal.floor, goal.target, goal.ceiling) {
        case let (floor?, target?, ceiling?):
            "\(amount(target, nutrient)) (\(number(floor, nutrient.unit))–\(amount(ceiling, nutrient)))"
        case let (floor?, target?, nil): "\(amount(target, nutrient)), at least \(amount(floor, nutrient))"
        case let (nil, target?, ceiling?): "\(amount(target, nutrient)), up to \(amount(ceiling, nutrient))"
        case let (floor?, nil, ceiling?): "\(number(floor, nutrient.unit))–\(amount(ceiling, nutrient))"
        case let (floor?, nil, nil): "at least \(amount(floor, nutrient))"
        case let (nil, nil, ceiling?): "up to \(amount(ceiling, nutrient))"
        case let (nil, target?, nil): amount(target, nutrient)
        case (nil, nil, nil): ""
        }
    }

    static func spokenGoal(_ goal: NutrientGoal, _ nutrient: Nutrient) -> String {
        var parts: [String] = []
        if let target = goal.target { parts.append("target \(spokenAmount(target, nutrient))") }
        if let floor = goal.floor { parts.append("at least \(spokenAmount(floor, nutrient))") }
        if let ceiling = goal.ceiling { parts.append("up to \(spokenAmount(ceiling, nutrient))") }
        return parts.joined(separator: ", ")
    }

    static func days(_ count: Int) -> String { count == 1 ? "1 day" : "\(count) days" }
    static func entries(_ count: Int) -> String { count == 1 ? "1 entry" : "\(count) entries" }

    /// The colour each of energy and the macros is drawn in, as on Today.
    static func color(_ nutrient: Nutrient) -> Color {
        switch nutrient {
        case .protein: .exPrimaryText
        case .carbohydrate: .exAccent
        case .fat: .exSecondary
        case .alcohol: .exTextMuted
        default: .exPrimary
        }
    }

    static func group(_ group: Nutrient.Group) -> String {
        switch group {
        case .energy, .macros: "Energy and macros"
        case .carbohydrates: "Carbohydrate detail"
        case .fats: "Fats"
        case .vitamins: "Vitamins"
        case .minerals: "Minerals"
        case .aminoAcids: "Amino acids"
        case .other: "Other"
        }
    }
}

extension View {
    /// Charts read dates in UTC, where `BodyDates` anchors each local date.
    func intakeChartDates() -> some View {
        environment(\.timeZone, BodyDates.utc).environment(\.calendar, BodyDates.calendar)
    }
}
