import Foundation

/// The App Group Exerly shares with its widgets. The app writes the widget
/// snapshot into its container; the widgets only read it.
enum ExerlyAppGroup {
    static let identifier = "group.com.exerly.fitness"
}

/// Everything the widgets show, written by the app whenever it changes:
/// calories and macros for today and tomorrow, and the workout to show.
/// Widgets run in another process and never open the app's database.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct Amount: Codable, Equatable, Sendable {
        var consumed: Double
        var target: Double?

        var remaining: Double? { target.map { max(0, $0 - consumed) } }
        var over: Double? { target.map { max(0, consumed - $0) } }
        var fraction: Double? { target.flatMap { $0 > 0 ? consumed / $0 : nil } }
    }

    /// One calendar day in the account's time zone, midnight to midnight.
    struct Day: Codable, Equatable, Sendable {
        var start: Date
        var end: Date
        var energy: Amount
        var protein: Amount
        var carbohydrate: Amount
        var fat: Amount
    }

    struct ActiveWorkout: Codable, Equatable, Sendable {
        var name: String
        var startedAt: Date
        var completedSets: Int
        var totalSets: Int
    }

    struct DoneWorkout: Codable, Equatable, Sendable {
        var name: String
        var workingSets: Int
        /// The end of the day it was done, after which it's no longer today's.
        var until: Date
    }

    struct PlannedWorkout: Codable, Equatable, Sendable {
        struct Exercise: Codable, Equatable, Sendable {
            var name: String
            var sets: Int
        }

        var name: String
        var program: String?
        var isDeload: Bool
        var exercises: [Exercise]
    }

    enum Workout: Equatable, Sendable {
        case active(ActiveWorkout)
        case done(DoneWorkout, next: PlannedWorkout?)
        case planned(PlannedWorkout)
        case none
    }

    /// Today, then tomorrow, so widgets turn over at midnight on their own.
    var days: [Day]
    var active: ActiveWorkout?
    var done: DoneWorkout?
    var planned: PlannedWorkout?

    func day(at date: Date) -> Day? { days.first { $0.start <= date && date < $0.end } }

    /// The workout to show at `date`: the one in progress, then today's
    /// finished one, then the program's next.
    func workout(at date: Date) -> Workout {
        if let active { return .active(active) }
        if let done, date < done.until { return .done(done, next: planned) }
        if let planned { return .planned(planned) }
        return .none
    }

    /// When what the widgets show changes on its own: the day boundaries after `date`.
    func changes(after date: Date) -> [Date] {
        Array(Set(days.flatMap { [$0.start, $0.end] } + [done?.until].compactMap { $0 }))
            .filter { $0 > date }.sorted()
    }
}

extension WidgetSnapshot {
    static let fileName = "widget-snapshot.json"

    /// Nil when the App Group isn't available to this build.
    static var defaultURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ExerlyAppGroup.identifier)?
            .appendingPathComponent(fileName)
    }

    static func read(from url: URL? = defaultURL) -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Saves the snapshot unless the saved one is the same. Returns whether it
    /// wrote. Readable after first unlock, so Lock Screen widgets can show it.
    @discardableResult
    func write(to url: URL? = defaultURL) throws -> Bool {
        guard let url, Self.read(from: url) != self else { return false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        try encoder.encode(self).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return true
    }

    /// Removes the snapshot, at sign-out. Returns whether one was there.
    @discardableResult
    static func remove(at url: URL? = defaultURL) -> Bool {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return false }
        return (try? FileManager.default.removeItem(at: url)) != nil
    }
}
