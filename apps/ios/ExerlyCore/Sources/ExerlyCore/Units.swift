import Foundation

public enum MassUnit: String, Sendable, Codable, Hashable, CaseIterable {
    case kilograms = "kg"
    case pounds = "lb"

    /// Kilograms per unit. The pound is defined as exactly 0.45359237 kg.
    public var kilogramsPerUnit: Double {
        switch self {
        case .kilograms: 1
        case .pounds: 0.453_592_37
        }
    }
}

/// A mass as the person entered it. The value and unit are kept so that
/// `225 lb` is shown as 225, never as a rounded conversion. Maths uses
/// `kilograms`.
public struct Mass: Sendable, Codable, Hashable, Comparable, CustomStringConvertible {
    public var value: Double
    public var unit: MassUnit

    public init(_ value: Double, _ unit: MassUnit) {
        self.value = value
        self.unit = unit
    }

    /// Returns nil for negative or non-finite values.
    public init?(validating value: Double, _ unit: MassUnit) {
        guard value.isFinite, value >= 0 else { return nil }
        self.init(value, unit)
    }

    public static func kg(_ value: Double) -> Mass { Mass(value, .kilograms) }
    public static func lb(_ value: Double) -> Mass { Mass(value, .pounds) }

    public var kilograms: Double { value * unit.kilogramsPerUnit }
    public var isZero: Bool { value == 0 }

    public func value(in target: MassUnit) -> Double {
        target == unit ? value : kilograms / target.kilogramsPerUnit
    }

    public func converted(to target: MassUnit) -> Mass {
        Mass(value(in: target), target)
    }

    public static func < (lhs: Mass, rhs: Mass) -> Bool { lhs.kilograms < rhs.kilograms }

    public var description: String {
        let number = value.rounded() == value ? String(Int(value)) : String(value)
        return "\(number) \(unit.rawValue)"
    }
}

public enum Weekday: Int, Sendable, Codable, Hashable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

/// A calendar date with no time or zone, written `YYYY-MM-DD` like the API.
public struct LocalDate: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    public init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year), (1...12).contains(month),
              let first = Self.calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let days = Self.calendar.range(of: .day, in: .month, for: first),
              days.contains(day)
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        self.init(year: y, month: m, day: d)
    }

    /// The calendar date of `instant` as seen in `timeZone`.
    public init(_ instant: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        self.year = parts.year!
        self.month = parts.month!
        self.day = parts.day!
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let date = LocalDate(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date \(text)")
        }
        self = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Midnight UTC on this date. Only used for whole-day arithmetic.
    private var utcMidnight: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days: Int) -> LocalDate {
        LocalDate(Self.calendar.date(byAdding: .day, value: days, to: utcMidnight)!, in: Self.calendar.timeZone)
    }

    public func days(until other: LocalDate) -> Int {
        Self.calendar.dateComponents([.day], from: utcMidnight, to: other.utcMidnight).day!
    }

    public var weekday: Weekday {
        Weekday(rawValue: Self.calendar.component(.weekday, from: utcMidnight))!
    }

    public func startOfWeek(firstWeekday: Weekday) -> LocalDate {
        let offset = (weekday.rawValue - firstWeekday.rawValue + 7) % 7
        return adding(days: -offset)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
