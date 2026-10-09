import Foundation

/// Progress → Training's numbers: weekly sessions, sets and volume, sets per
/// muscle against Exerly's weekly ranges, each lift's estimated 1RM over a
/// span, records set in the span, and the evidence behind stall and deload
/// signals. Loads are kilograms; screens convert. Nothing here changes data.
public enum TrainingInsights {
    /// The spans the screen offers. Fixed spans are whole calendar weeks
    /// ending with the current one, so weekly bars line up with the calendar.
    public enum Span: String, Sendable, Hashable, CaseIterable, Identifiable {
        case fourWeeks = "4W", threeMonths = "3M", sixMonths = "6M", year = "1Y", all = "All"

        public var id: String { rawValue }

        /// Calendar weeks shown, including the current one; nil for everything.
        public var weeks: Int? {
            switch self {
            case .fourWeeks: 4
            case .threeMonths: 13
            case .sixMonths: 26
            case .year: 52
            case .all: nil
            }
        }

        /// The first date in the span. "All" starts on the week of the first session.
        public func start(through end: LocalDate, firstSession: LocalDate?, firstWeekday: Weekday) -> LocalDate {
            let thisWeek = end.startOfWeek(firstWeekday: firstWeekday)
            guard let weeks else { return min(firstSession ?? end, end).startOfWeek(firstWeekday: firstWeekday) }
            return thisWeek.adding(days: -7 * (weeks - 1))
        }
    }

    /// One calendar week of training.
    public struct Week: Sendable, Hashable {
        public var start: LocalDate
        public var sessions: Int
        /// Fractional hard sets, counted as `Volume.setCredit` counts them.
        public var sets: Double
        public var tonnage: Tonnage
        /// Seconds from start to end, summed over sessions.
        public var duration: Double
        /// The week has days after the span's end: it is still going.
        public var isPartial: Bool
    }

    public enum VolumeStatus: String, Sendable, Hashable {
        case below, within, above
        /// Exerly sets no weekly range for this muscle.
        case noRange
    }

    /// Weekly sets for one muscle over the span's complete weeks.
    public struct MuscleLoad: Sendable, Hashable {
        public var muscle: Muscle
        /// Mean fractional sets per complete week, or this week's so far when
        /// there is no complete week yet.
        public var averageSets: Double
        /// Sets so far in the current week.
        public var thisWeek: Double
        public var range: ClosedRange<Double>?
        public var status: VolumeStatus
        /// Exercises that contributed, most sets first, over the averaged weeks.
        public var contributors: [Contribution]

        public struct Contribution: Sendable, Hashable {
            public var exerciseID: ExerciseID
            public var sets: Double
        }
    }

    /// One session's best e1RM for a lift.
    public struct LiftPoint: Sendable, Hashable {
        public var date: LocalDate
        public var sessionID: UUID
        /// Kilograms.
        public var oneRepMax: Double
    }

    /// A lift's estimated 1RM over the span.
    public struct LiftSummary: Sendable, Hashable {
        public var exerciseID: ExerciseID
        public var sessions: Int
        public var sets: Int
        /// Each session's best e1RM, oldest first.
        public var points: [LiftPoint]
        /// The best e1RM in the span and the session it came from.
        public var best: LiftPoint
        public var latest: LiftPoint
        /// The least-squares trend over the span, from three sessions on.
        public var trend: TrainingSignals.Trend?

        /// The trend's change from the first session to the last, in kilograms.
        public var change: Double? { trend.map { $0.slopePerWeek * Double($0.from.days(until: $0.through)) / 7 } }
        /// The change as a share of the trend's mean.
        public var relativeChange: Double? { trend.flatMap { trend in change.map { $0 / trend.meanOneRepMax } } }
    }

    /// A personal record with the day and workout it was set in.
    public struct DatedRecord: Sendable, Hashable {
        public var record: PersonalRecord
        public var date: LocalDate
        public var sessionName: String
    }

    /// A stall or deload diagnosis with numbers in kilograms per lift, so a
    /// screen can show them in the person's unit.
    public struct Signal: Sendable, Hashable {
        public var diagnosis: Diagnosis
        public var lifts: [SignalLift]
        /// The diagnosis's caveats, each once, in order. None mentions a unit.
        public var caveats: [String] {
            var seen = Set<String>()
            return diagnosis.evidence.flatMap(\.caveats).filter { seen.insert($0).inserted }
        }
    }

    public struct SignalLift: Sendable, Hashable {
        public var exerciseID: ExerciseID
        /// Session bests in the window the signal looked at, oldest first.
        public var points: [LiftPoint]
        /// For a stall: the trend over the stall window.
        public var trend: TrainingSignals.Trend?
        /// For a deload: mean session-best e1RM in the baseline and recent windows.
        public var baseline: Double?
        public var recent: Double?

        public var recentChange: Double? {
            guard let baseline, let recent, baseline > 0 else { return nil }
            return recent / baseline - 1
        }
    }

    public struct Report: Sendable, Hashable {
        public var span: Span
        public var from: LocalDate
        public var through: LocalDate
        /// The first session ever, or nil with no history.
        public var firstSession: LocalDate?
        /// Every week in the span from the first session's week on, oldest first.
        public var weeks: [Week]
        /// Weeks in `weeks` that are complete.
        public var completeWeeks: Int
        public var sessions: Int
        public var muscles: [MuscleLoad]
        /// Lifts with an e1RM in the span, most sessions first.
        public var lifts: [LiftSummary]
        /// Records set in the span, newest first.
        public var records: [DatedRecord]
        public var signals: [Signal]

        /// True when there are too few complete weeks to judge weekly volume.
        public var isVolumeProvisional: Bool { completeWeeks < minimumWeeksToJudge }
        public var tonnage: Tonnage { weeks.reduce(.zero) { $0 + $1.tonnage } }
        public var sets: Double { weeks.reduce(0) { $0 + $1.sets } }
    }

    /// Weekly volume is judged against ranges only from this many complete weeks.
    public static let minimumWeeksToJudge = 2

    // MARK: Report

    public static func report(_ history: TrainingHistory, span: Span, through end: LocalDate,
                              firstWeekday: Weekday = .monday) -> Report {
        let firstSession = history.sessions.map(\.localDate).min()
        let from = span.start(through: end, firstSession: firstSession, firstWeekday: firstWeekday)
        let weeks = weeks(history, from: from, through: end, firstWeekday: firstWeekday)
        let complete = weeks.filter { !$0.isPartial }.count
        let sessions = history.sessions.filter { (from...end).contains($0.localDate) }.count
        return Report(span: span, from: from, through: end, firstSession: firstSession, weeks: weeks, completeWeeks: complete,
                      sessions: sessions,
                      muscles: muscles(history, from: from, through: end, firstWeekday: firstWeekday),
                      lifts: lifts(history, from: from, through: end),
                      records: records(history, from: from, through: end),
                      signals: signals(history, through: end, firstWeekday: firstWeekday))
    }

    // MARK: Weeks

    /// Each calendar week from the week of `from` (or of the first session,
    /// if later) through the week of `end`. Weeks without training are zero.
    public static func weeks(_ history: TrainingHistory, from: LocalDate, through end: LocalDate,
                             firstWeekday: Weekday = .monday) -> [Week] {
        guard let first = history.sessions.map(\.localDate).min(), first <= end else { return [] }
        let start = max(from.startOfWeek(firstWeekday: firstWeekday), first.startOfWeek(firstWeekday: firstWeekday))
        let last = end.startOfWeek(firstWeekday: firstWeekday)
        var weeks: [LocalDate: Week] = [:]
        var cursor = start
        while cursor <= last {
            weeks[cursor] = Week(start: cursor, sessions: 0, sets: 0, tonnage: .zero, duration: 0, isPartial: cursor.adding(days: 6) > end)
            cursor = cursor.adding(days: 7)
        }
        for session in history.sessions where (start...end).contains(session.localDate) {
            let key = session.localDate.startOfWeek(firstWeekday: firstWeekday)
            guard var week = weeks[key] else { continue }
            week.sessions += 1
            week.duration += session.duration ?? 0
            for performed in session.exercises {
                guard let exercise = history.library.exercise(performed.exerciseID) else { continue }
                for set in performed.sets where set.counts {
                    week.sets += Volume.setCredit(set, exercise: exercise)
                    week.tonnage += Volume.tonnage(set, exercise: exercise, bodyweight: session.bodyweight)
                }
            }
            weeks[key] = week
        }
        return weeks.values.sorted { $0.start < $1.start }
    }

    // MARK: Muscles

    /// Exerly's weekly set range for a muscle: from the beginner to the
    /// advanced hypertrophy target that program generation uses. Nil for
    /// muscles Exerly sets no target for, which compound lifts mostly cover.
    public static func weeklySetRange(for muscle: Muscle) -> ClosedRange<Double>? {
        let low = ProgramGeneration.targets(for: .init(daysPerWeek: 3, goal: .hypertrophy, experience: .beginner))
        let high = ProgramGeneration.targets(for: .init(daysPerWeek: 3, goal: .hypertrophy, experience: .advanced))
        guard let lower = low[muscle], let upper = high[muscle] else { return nil }
        return lower...upper
    }

    /// Average weekly sets per muscle over the complete weeks from `from`
    /// (or the first session's week) through `end`, with this week's so far.
    /// Every muscle with a range is listed; others only when trained.
    /// Sorted by average, highest first.
    public static func muscles(_ history: TrainingHistory, from: LocalDate, through end: LocalDate,
                               firstWeekday: Weekday = .monday) -> [MuscleLoad] {
        guard let first = history.sessions.map(\.localDate).min(), first <= end else { return [] }
        let thisWeek = end.startOfWeek(firstWeekday: firstWeekday)
        let start = max(from.startOfWeek(firstWeekday: firstWeekday), first.startOfWeek(firstWeekday: firstWeekday))
        let completeWeeks = max(0, start.days(until: thisWeek) / 7)
        // With no complete week yet, the current week stands in, provisionally.
        let averagedEnd = completeWeeks > 0 ? thisWeek.adding(days: -1) : end
        let divisor = Double(max(1, completeWeeks))
        var totals: [Muscle: Double] = [:]
        var current: [Muscle: Double] = [:]
        var byExercise: [Muscle: [ExerciseID: Double]] = [:]
        for session in history.sessions where (start...end).contains(session.localDate) {
            let averaged = session.localDate <= averagedEnd
            let isCurrent = session.localDate >= thisWeek
            for performed in session.exercises {
                guard let exercise = history.library.exercise(performed.exerciseID) else { continue }
                let credit = performed.sets.reduce(0) { $0 + Volume.setCredit($1, exercise: exercise) }
                guard credit > 0 else { continue }
                for (muscle, share) in exercise.muscles {
                    if averaged {
                        totals[muscle, default: 0] += credit * share
                        byExercise[muscle, default: [:]][exercise.id, default: 0] += credit * share
                    }
                    if isCurrent { current[muscle, default: 0] += credit * share }
                }
            }
        }
        let listed = Muscle.allCases.filter { weeklySetRange(for: $0) != nil || (totals[$0] ?? 0) > 0 || (current[$0] ?? 0) > 0 }
        return listed.map { muscle in
            let average = (totals[muscle] ?? 0) / divisor
            let range = weeklySetRange(for: muscle)
            let status: VolumeStatus = range.map { average < $0.lowerBound ? .below : average > $0.upperBound ? .above : .within } ?? .noRange
            let contributors = (byExercise[muscle] ?? [:])
                .map { MuscleLoad.Contribution(exerciseID: $0.key, sets: $0.value / divisor) }
                .sorted { ($0.sets, $1.exerciseID) > ($1.sets, $0.exerciseID) }
            return MuscleLoad(muscle: muscle, averageSets: average, thisWeek: current[muscle] ?? 0, range: range,
                              status: status, contributors: contributors)
        }.sorted { ($0.averageSets, $1.muscle.rawValue) > ($1.averageSets, $0.muscle.rawValue) }
    }

    // MARK: Lifts

    /// Each session's best e1RM for a lift in the inclusive range, oldest first.
    public static func points(of exerciseID: ExerciseID, in history: TrainingHistory, from: LocalDate,
                              through end: LocalDate) -> [LiftPoint] {
        history.oneRepMaxTrend(of: exerciseID)
            .filter { (from...end).contains($0.date) }
            .map { LiftPoint(date: $0.date, sessionID: $0.sessionID, oneRepMax: $0.oneRepMax.kilograms) }
    }

    /// Lifts with an e1RM in the range, most sessions first, then most sets.
    public static func lifts(_ history: TrainingHistory, from: LocalDate, through end: LocalDate) -> [LiftSummary] {
        let ids = Set(history.sessions.filter { (from...end).contains($0.localDate) }.flatMap { $0.exercises.map(\.exerciseID) })
        let days = from.days(until: end) + 1
        let lifts = ids.compactMap { id -> LiftSummary? in
            let points = points(of: id, in: history, from: from, through: end)
            guard let latest = points.last, let best = points.max(by: { $0.oneRepMax < $1.oneRepMax }) else { return nil }
            return LiftSummary(exerciseID: id, sessions: points.count, sets: history.sets(of: id, from: from, through: end).count,
                               points: points, best: best, latest: latest,
                               trend: TrainingSignals.trend(of: id, in: history, through: end, days: days))
        }
        return lifts.sorted { ($0.sessions, $0.sets, $1.exerciseID) > ($1.sessions, $1.sets, $0.exerciseID) }
    }

    /// One session of a lift: its statistics and its best set by e1RM.
    public struct LiftSession: Sendable, Hashable {
        public var date: LocalDate
        public var sessionID: UUID
        public var statistics: ExerciseStatistics
        /// The set with the highest e1RM, and that e1RM in kilograms.
        public var bestSet: PerformedSet?
        public var bestSetOneRepMax: Double?
    }

    /// Every session of a lift in the range, oldest first.
    public static func sessions(of exerciseID: ExerciseID, in history: TrainingHistory, from: LocalDate,
                                through end: LocalDate) -> [LiftSession] {
        guard let exercise = history.library.exercise(exerciseID) else { return [] }
        var groups: [(UUID, [SetRecord])] = []
        for record in history.sets(of: exerciseID, from: from, through: end) {
            if groups.last?.0 == record.sessionID { groups[groups.count - 1].1.append(record) } else { groups.append((record.sessionID, [record])) }
        }
        return groups.map { id, records in
            let best = records.compactMap { record in
                ExerciseStatistics.oneRepMax(record.set, exercise: exercise, bodyweight: record.bodyweight).map { (record.set, $0) }
            }.max { $0.1 < $1.1 }
            return LiftSession(date: records[0].date, sessionID: id, statistics: ExerciseStatistics(exercise: exercise, sets: records),
                               bestSet: best?.0, bestSetOneRepMax: best?.1)
        }
    }

    /// A set with its e1RM, for a best-sets list.
    public struct RankedSet: Sendable, Hashable {
        public var record: SetRecord
        /// Kilograms.
        public var oneRepMax: Double
    }

    /// The range's sets with the highest e1RM, best first; ties go to the earlier set.
    public static func bestSets(of exerciseID: ExerciseID, in history: TrainingHistory, from: LocalDate,
                                through end: LocalDate, limit: Int = 5) -> [RankedSet] {
        guard let exercise = history.library.exercise(exerciseID) else { return [] }
        let ranked = history.sets(of: exerciseID, from: from, through: end).enumerated().compactMap { index, record in
            ExerciseStatistics.oneRepMax(record.set, exercise: exercise, bodyweight: record.bodyweight)
                .map { (index, RankedSet(record: record, oneRepMax: $0)) }
        }
        return ranked.sorted { ($0.1.oneRepMax, -$0.0) > ($1.1.oneRepMax, -$1.0) }.prefix(limit).map(\.1)
    }

    // MARK: Records

    /// Records set by sessions in the range, each against everything before
    /// it, newest first. Within a session, records keep Core's order.
    public static func records(_ history: TrainingHistory, from: LocalDate, through end: LocalDate) -> [DatedRecord] {
        history.sessions.filter { (from...end).contains($0.localDate) }.reversed().flatMap { session in
            history.records(in: session).map { DatedRecord(record: $0, date: session.localDate, sessionName: session.name) }
        }
    }

    // MARK: Signals

    /// Stalls and the deload signal through `end`, with per-lift numbers.
    /// The deload signal comes first: it concerns several lifts.
    public static func signals(_ history: TrainingHistory, through end: LocalDate, firstWeekday: Weekday = .monday) -> [Signal] {
        var signals: [Signal] = []
        if let deload = TrainingSignals.deload(in: history, through: end) {
            let recentStart = end.adding(days: -(TrainingSignals.deloadRecentDays - 1))
            let baselineStart = recentStart.adding(days: -TrainingSignals.deloadBaselineDays)
            signals.append(Signal(diagnosis: deload, lifts: deload.exerciseIDs.map { id in
                let points = points(of: id, in: history, from: baselineStart, through: end)
                let baseline = mean(points.filter { $0.date < recentStart }.map(\.oneRepMax))
                let recent = mean(points.filter { $0.date >= recentStart }.map(\.oneRepMax))
                return SignalLift(exerciseID: id, points: points, trend: nil, baseline: baseline, recent: recent)
            }))
        }
        let windowStart = end.adding(days: -(TrainingSignals.stallWindowDays - 1))
        for stall in TrainingSignals.stalls(in: history, through: end, firstWeekday: firstWeekday) {
            signals.append(Signal(diagnosis: stall, lifts: stall.exerciseIDs.map { id in
                SignalLift(exerciseID: id, points: points(of: id, in: history, from: windowStart, through: end),
                           trend: TrainingSignals.trend(of: id, in: history, through: end))
            }))
        }
        return signals
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
