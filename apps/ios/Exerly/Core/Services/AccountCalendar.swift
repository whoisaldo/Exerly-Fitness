import Foundation
import SwiftUI

/// A Gregorian calendar date, without an instant or a time zone.
struct CalendarDay: RawRepresentable, Codable, Hashable, Comparable, Sendable {
    let rawValue: String

    static var pickerCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    init?(rawValue: String) {
        let bytes = Array(rawValue.utf8)
        guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
              bytes.enumerated().allSatisfy({ [4, 7].contains($0.offset) || (48...57).contains($0.element) }) else { return nil }
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...9999).contains(parts[0]),
              let date = Self.pickerCalendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) else { return nil }
        let check = Self.pickerCalendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == parts[0], check.month == parts[1], check.day == parts[2] else { return nil }
        self.rawValue = rawValue
    }

    /// An anchor used only by date-only controls and charts. It is not the
    /// timestamp when the entry happened. Those controls must use pickerCalendar.
    var pickerDate: Date {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        return Self.pickerCalendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
    }

    init?(pickerDate: Date) {
        let parts = Self.pickerCalendar.dateComponents([.year, .month, .day], from: pickerDate)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        self.init(rawValue: String(format: "%04d-%02d-%02d", year, month, day))
    }

    func adding(days: Int) -> CalendarDay? {
        guard let date = Self.pickerCalendar.date(byAdding: .day, value: days, to: pickerDate) else { return nil }
        return CalendarDay(pickerDate: date)
    }

    func formatted(locale: Locale = .current, weekdayOnly: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Self.pickerCalendar
        formatter.timeZone = Self.pickerCalendar.timeZone
        if weekdayOnly { formatter.setLocalizedDateFormatFromTemplate("EEEE") }
        else { formatter.dateStyle = .medium }
        return formatter.string(from: pickerDate)
    }

    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool { lhs.rawValue < rhs.rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let day = CalendarDay(rawValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Gregorian calendar day")
        }
        self = day
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct AccountCalendar: Equatable, Sendable {
    let timeZoneIdentifier: String

    init(timeZoneIdentifier: String?) {
        if let timeZoneIdentifier, TimeZone(identifier: timeZoneIdentifier) != nil {
            self.timeZoneIdentifier = timeZoneIdentifier
        } else { self.timeZoneIdentifier = "UTC" }
    }

    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return value
    }

    func day(containing instant: Date) -> CalendarDay? {
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return CalendarDay(rawValue: String(format: "%04d-%02d-%02d", year, month, day))
    }

    func today(now: Date = Date()) -> CalendarDay {
        // The app's supported logging window uses present Gregorian dates.
        day(containing: now)!
    }
}

struct CalendarDayPicker: View {
    let title: String
    @Binding var selection: CalendarDay
    let today: CalendarDay
    let timeZoneIdentifier: String

    init(_ title: String, selection: Binding<CalendarDay>, today: CalendarDay, timeZoneIdentifier: String) {
        self.title = title
        _selection = selection
        self.today = today
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var body: some View {
        let earliest = today.adding(days: -3650)!
        // An existing selection outside the current bounds must remain visible
        // without DatePicker silently clamping and changing its stored day.
        let lower = min(earliest, selection).pickerDate
        let upper = max(today, selection).pickerDate
        VStack(alignment: .leading, spacing: 6) {
            DatePicker(title, selection: Binding(
                get: { selection.pickerDate },
                set: { value in
                    guard let day = CalendarDay(pickerDate: value), day >= earliest, day <= today else { return }
                    selection = day
                }
            ), in: lower...upper, displayedComponents: .date)
                .environment(\.calendar, CalendarDay.pickerCalendar)
                .environment(\.timeZone, CalendarDay.pickerCalendar.timeZone)
                .accessibilityValue(selection.rawValue)
            if selection > today {
                Text("This date is ahead of today in \(timeZoneIdentifier). Saved changes keep their original date. Retry when this date arrives, or review your time zone in Profile.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
