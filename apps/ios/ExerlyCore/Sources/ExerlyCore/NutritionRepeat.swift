import Foundation

/// A meal, or a whole day, that can be logged again in one tap.
public struct MealRepeat: Sendable, Hashable {
    /// The day the entries come from.
    public var source: LocalDate
    /// The meal repeated; nil for the whole day.
    public var meal: String?
    public var entries: [FoodEntry]
    /// Logged energy of the entries, in kcal.
    public var energy: Double { entries.reduce(0) { $0 + $1.nutrients.energy } }
}

extension NutritionStore {
    /// From 10 PM to 4 AM a clock hour reads oddly as a habit ("usual around
    /// 12 AM"), so foods eaten around then are "usual around now".
    public static func isLateNight(_ time: Date, timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: time)
        return hour >= 22 || hour < 4
    }

    /// The meal a person is most likely logging at a local time.
    ///
    /// A habit wins over the clock: the meal logged most often within 90
    /// minutes of this time of day over the last 28 days, if it was logged on
    /// at least 3 of them. Only entries logged on the day they count for say
    /// when someone eats; a dinner backfilled next morning doesn't.
    public func suggestedMeal(at time: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        func minute(_ date: Date) -> Int {
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
        let today = LocalDate(time, in: timeZone), now = minute(time)
        var days: [String: Set<LocalDate>] = [:]
        for entry in entries where entry.date >= today.adding(days: -28) && entry.date < today
            && LocalDate(entry.loggedAt, in: timeZone) == entry.date {
            let gap = abs(minute(entry.loggedAt) - now)
            guard min(gap, 24 * 60 - gap) <= 90 else { continue }
            days[entry.meal, default: []].insert(entry.date)
        }
        if let habit = days.filter({ $0.value.count >= 3 })
            .max(by: { ($0.value.count, $1.key) < ($1.value.count, $0.key) }) {
            return habit.key
        }
        return Self.meal(atMinute: now)
    }

    /// The meal the clock alone suggests at a minute of the local day, before
    /// any habit: breakfast from 4:00, lunch from 10:30 to 14:30, dinner from
    /// 17:00 to 21:30, and snacks otherwise.
    public nonisolated static func meal(atMinute minute: Int) -> String {
        switch minute {
        case 4 * 60..<(10 * 60 + 30): return "Breakfast"
        case (10 * 60 + 30)..<(14 * 60 + 30): return "Lunch"
        case (17 * 60)..<(21 * 60 + 30): return "Dinner"
        default: return "Snacks"
        }
    }

    /// The latest day before `date`, within `days`, with entries in `meal`
    /// (or any entries, for the whole day), and those entries.
    public func repeatable(_ meal: String?, for date: LocalDate, within days: Int = 7) -> MealRepeat? {
        let earliest = date.adding(days: -days)
        let candidates = entries.filter { $0.date < date && $0.date >= earliest && (meal == nil || $0.meal == meal) }
        guard let source = candidates.map(\.date).max() else { return nil }
        return MealRepeat(source: source, meal: meal, entries: candidates.filter { $0.date == source })
    }

    /// Logs a repeat's entries on `date` as new entries, all or none.
    @discardableResult
    public func apply(_ repeated: MealRepeat, to date: LocalDate) throws -> [FoodEntry] {
        try copy(repeated.entries.map(\.id), to: date)
    }
}
