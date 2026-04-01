import Foundation

struct StreakInfo {
    let currentStreak: Int
    let longestStreak: Int
    let isAtRisk: Bool
    let milestone: Int?
}

struct StreakService {
    static func calculateStreak(activityDates: [Date]) -> StreakInfo {
        let calendar = Calendar.current
        let uniqueDays = Set(activityDates.map { calendar.startOfDay(for: $0) })
            .sorted(by: >)

        guard let mostRecent = uniqueDays.first else {
            return StreakInfo(currentStreak: 0, longestStreak: 0, isAtRisk: false, milestone: nil)
        }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Check if streak is still active
        guard mostRecent >= yesterday else {
            return StreakInfo(currentStreak: 0, longestStreak: longestStreak(from: uniqueDays), isAtRisk: false, milestone: nil)
        }

        var streak = 1
        var checkDate = mostRecent

        for day in uniqueDays.dropFirst() {
            let expected = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            if day == expected {
                streak += 1
                checkDate = day
            } else {
                break
            }
        }

        let isAtRisk = mostRecent == yesterday
        let milestone = nextMilestone(streak)
        let longest = longestStreak(from: uniqueDays)

        return StreakInfo(
            currentStreak: streak,
            longestStreak: max(longest, streak),
            isAtRisk: isAtRisk,
            milestone: milestone
        )
    }

    private static func longestStreak(from days: [Date]) -> Int {
        let calendar = Calendar.current
        guard !days.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<days.count {
            let expected = calendar.date(byAdding: .day, value: -1, to: days[i - 1])!
            if days[i] == expected {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private static func nextMilestone(_ streak: Int) -> Int? {
        let milestones = [3, 7, 14, 30, 60, 90, 180, 365]
        return milestones.first { $0 > streak }
    }
}
