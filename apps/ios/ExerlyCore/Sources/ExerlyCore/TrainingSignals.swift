import Foundation

/// A finding about training that is shown with its evidence but changes
/// nothing: a stall, or a sign that a deload may help. Screens and agents show
/// the same title, numbers and caveats.
public struct Diagnosis: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        case stall, deload
    }

    public var kind: Kind
    public var title: String
    public var summary: String
    public var exerciseIDs: [ExerciseID]
    public var evidence: [Evidence]
}

/// Stall diagnosis and the deload signal. See
/// docs/design/005-training-detectors.md for how they were checked against
/// simulated lifters, and with what error.
public enum TrainingSignals {
    /// The e1RM trend of one exercise over a window, from each session's best set.
    public struct Trend: Sendable, Hashable {
        public var exerciseID: ExerciseID
        public var sessions: Int
        public var from: LocalDate
        public var through: LocalDate
        /// Least-squares slope of the best e1RM per session, in kilograms per week.
        public var slopePerWeek: Double
        public var standardError: Double
        /// Mean of the session bests, in kilograms.
        public var meanOneRepMax: Double
        /// Slope as a share of the mean, per week.
        public var relativeSlopePerWeek: Double { slopePerWeek / meanOneRepMax }
        /// Mean RIR of each session's top set, where recorded.
        public var meanTopRIR: Double?
        public var setsWithoutRIR: Int
    }

    public static let stallWindowDays = 56
    public static let stallMinimumSessions = 6
    public static let stallMinimumSpanDays = 21
    /// A stall: the trend's best case is still under this gain per week.
    public static let stallCeiling = 0.003
    /// How many standard errors above the trend the best case is taken.
    public static let stallErrorMultiple = 1.0

    public static func trend(of exerciseID: ExerciseID, in history: TrainingHistory, through end: LocalDate,
                             days: Int = stallWindowDays) -> Trend? {
        guard let exercise = history.library.exercise(exerciseID), exercise.metric.tracksReps else { return nil }
        let start = end.adding(days: -(days - 1))
        var bests: [(date: LocalDate, sessionID: UUID, value: Double, rir: Double?)] = []
        var withoutRIR = 0
        for record in history.sets(of: exerciseID, from: start, through: end) {
            guard let e1rm = ExerciseStatistics.oneRepMax(record.set, exercise: exercise, bodyweight: record.bodyweight) else {
                continue
            }
            if record.set.effectiveRIR == nil { withoutRIR += 1 }
            if let last = bests.last, last.sessionID == record.sessionID {
                if e1rm > last.value { bests[bests.count - 1] = (record.date, record.sessionID, e1rm, record.set.effectiveRIR) }
            } else {
                bests.append((record.date, record.sessionID, e1rm, record.set.effectiveRIR))
            }
        }
        guard bests.count >= 3, let first = bests.first?.date, let last = bests.last?.date else { return nil }
        let xs = bests.map { Double(first.days(until: $0.date)) / 7 }
        let ys = bests.map(\.value)
        let n = Double(bests.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        let sxx = xs.reduce(0) { $0 + ($1 - meanX) * ($1 - meanX) }
        guard sxx > 0 else { return nil }
        let sxy = zip(xs, ys).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let slope = sxy / sxx
        let residuals = zip(xs, ys).reduce(0) { total, point in
            let fitted = meanY + slope * (point.0 - meanX)
            return total + (point.1 - fitted) * (point.1 - fitted)
        }
        let standardError = bests.count > 2 ? (residuals / (n - 2) / sxx).squareRoot() : .infinity
        let rirs = bests.compactMap(\.rir)
        return Trend(exerciseID: exerciseID, sessions: bests.count, from: first, through: last, slopePerWeek: slope,
                     standardError: standardError, meanOneRepMax: meanY,
                     meanTopRIR: rirs.isEmpty ? nil : rirs.reduce(0, +) / Double(rirs.count), setsWithoutRIR: withoutRIR)
    }

    /// A stall: over the last eight weeks, at least six sessions spanning three
    /// weeks, and even the optimistic end of the trend (one standard error up)
    /// gains less than 0.3 % a week.
    public static func stall(of exerciseID: ExerciseID, in history: TrainingHistory, through end: LocalDate,
                             firstWeekday: Weekday = .monday) -> Diagnosis? {
        guard let trend = trend(of: exerciseID, in: history, through: end),
              trend.sessions >= stallMinimumSessions,
              trend.from.days(until: trend.through) >= stallMinimumSpanDays,
              (trend.slopePerWeek + stallErrorMultiple * trend.standardError) / trend.meanOneRepMax < stallCeiling,
              let exercise = history.library.exercise(exerciseID)
        else { return nil }
        let halfway = trend.from.adding(days: trend.from.days(until: trend.through) / 2)
        let earlyBest = history.statistics(of: exerciseID, from: trend.from, through: halfway)?.estimatedOneRepMax?.kilograms
        let lateBest = history.statistics(of: exerciseID, from: halfway.adding(days: 1), through: trend.through)?
            .estimatedOneRepMax?.kilograms
        var caveats = ["Your own log (n=1)", "\(trend.sessions) sessions over \(trend.from.days(until: trend.through) + 1) days"]
        if trend.setsWithoutRIR > 0 { caveats.append("RIR not recorded on \(trend.setsWithoutRIR) sets, so effort is uncertain") }
        if let change = volumeChange(exercise, in: history, from: trend.from, through: trend.through, firstWeekday: firstWeekday) {
            caveats.append(change)
        }
        var evidence = [Evidence(
            claim: "Your best \(exercise.name) e1RM per session moved \(signed(trend.slopePerWeek)) kg a week "
                + "(± \(oneDecimal(trend.standardError))), around \(oneDecimal(trend.meanOneRepMax)) kg.",
            level: .personalData, caveats: caveats,
            dataRefs: [DataRef(kind: "exercise", id: exerciseID.rawValue)])]
        if let earlyBest, let lateBest {
            evidence.append(Evidence(
                claim: "Best e1RM was \(oneDecimal(earlyBest)) kg in the first half and \(oneDecimal(lateBest)) kg in the second.",
                level: .personalData, caveats: ["Single best sets are noisy"],
                metric: .bestOneRepMax(exercise: exerciseID, from: halfway.adding(days: 1), through: trend.through,
                                       claimedKilograms: lateBest)))
        }
        if let rir = trend.meanTopRIR {
            evidence.append(Evidence(claim: "Your top sets averaged \(oneDecimal(rir)) reps in reserve.", level: .personalData,
                                     caveats: rir >= 3 ? ["Top sets this far from failure may not be hard enough to drive progress"] : []))
        }
        // A stall includes a decline; say which, so a falling lift isn't called unchanged.
        let weeks = trend.from.days(until: trend.through) / 7
        let falling = trend.slopePerWeek + trend.standardError < 0
        return Diagnosis(kind: .stall, title: falling ? "\(exercise.name) has dropped" : "\(exercise.name) has stalled",
                         summary: falling ? "Your \(exercise.name) estimate has gone down over the last \(weeks) weeks."
                             : "Your \(exercise.name) estimate hasn't improved for \(weeks) weeks.",
                         exerciseIDs: [exerciseID], evidence: evidence)
    }

    /// Stalls across every exercise logged in the window, most sessions first.
    public static func stalls(in history: TrainingHistory, through end: LocalDate, firstWeekday: Weekday = .monday) -> [Diagnosis] {
        let start = end.adding(days: -(stallWindowDays - 1))
        let ids = Set(history.sessions.filter { (start...end).contains($0.localDate) }.flatMap { $0.exercises.map(\.exerciseID) })
        return ids.sorted().compactMap { stall(of: $0, in: history, through: end, firstWeekday: firstWeekday) }
    }

    public static let deloadRecentDays = 10
    public static let deloadBaselineDays = 28
    /// A lift counts as down when its recent mean e1RM is this far under baseline.
    public static let deloadDrop = 0.04

    /// Several lifts down together: in the last ten days, at least two
    /// exercises, and at least half of those with enough data, average 4 % or
    /// more under their mean e1RM of the four weeks before. Effort is already
    /// in the e1RM through reps in reserve.
    public static func deload(in history: TrainingHistory, through end: LocalDate) -> Diagnosis? {
        let recentStart = end.adding(days: -(deloadRecentDays - 1))
        let baselineEnd = recentStart.adding(days: -1)
        let baselineStart = baselineEnd.adding(days: -(deloadBaselineDays - 1))
        let ids = Set(history.sessions.filter { (recentStart...end).contains($0.localDate) }.flatMap { $0.exercises.map(\.exerciseID) })
        var changes: [(ExerciseID, Double, Double)] = []
        for id in ids.sorted() {
            guard let recent = sessionBests(id, in: history, from: recentStart, through: end), recent.count >= 2,
                  let baseline = sessionBests(id, in: history, from: baselineStart, through: baselineEnd), baseline.count >= 3
            else { continue }
            let recentMean = recent.reduce(0, +) / Double(recent.count)
            let baselineMean = baseline.reduce(0, +) / Double(baseline.count)
            changes.append((id, baselineMean, recentMean))
        }
        let down = changes.filter { $0.2 < $0.1 * (1 - deloadDrop) }
        guard down.count >= 2, down.count * 2 >= changes.count else { return nil }
        let names = down.map { history.library.exercise($0.0)?.name ?? $0.0.rawValue }
        let evidence = down.map { id, baseline, recent in
            Evidence(claim: "\(history.library.exercise(id)?.name ?? id.rawValue): e1RM averaged \(oneDecimal(recent)) kg "
                + "in the last \(deloadRecentDays) days against \(oneDecimal(baseline)) kg in the \(deloadBaselineDays) days before "
                + "(\(signed((recent / baseline - 1) * 100)) %).",
                level: .personalData,
                caveats: ["Your own log (n=1)", "Fatigue, poor sleep, illness and technique changes look alike here"],
                dataRefs: [DataRef(kind: "exercise", id: id.rawValue)])
        }
        return Diagnosis(kind: .deload, title: "Several lifts are down together",
                         summary: "\(names.joined(separator: ", ")) dropped at the same time, which can mean accumulated fatigue. "
                             + "A lighter week often helps; it's a signal, not a diagnosis.",
                         exerciseIDs: down.map(\.0), evidence: evidence)
    }

    // MARK: Helpers

    private static func sessionBests(_ id: ExerciseID, in history: TrainingHistory, from: LocalDate, through: LocalDate) -> [Double]? {
        guard let exercise = history.library.exercise(id) else { return nil }
        var bests: [UUID: Double] = [:]
        for record in history.sets(of: id, from: from, through: through) {
            guard let e1rm = ExerciseStatistics.oneRepMax(record.set, exercise: exercise, bodyweight: record.bodyweight) else {
                continue
            }
            bests[record.sessionID] = max(bests[record.sessionID] ?? 0, e1rm)
        }
        return bests.isEmpty ? nil : Array(bests.values)
    }

    /// A caveat when the exercise's target muscles got much more or less work
    /// in the second half of the window than in the first.
    private static func volumeChange(_ exercise: Exercise, in history: TrainingHistory, from: LocalDate, through: LocalDate,
                                     firstWeekday: Weekday) -> String? {
        guard let muscle = exercise.targetMuscles.first else { return nil }
        let halfway = from.adding(days: from.days(until: through) / 2)
        let early = history.muscleVolume(from: from, through: halfway)[muscle]?.sets ?? 0
        let late = history.muscleVolume(from: halfway.adding(days: 1), through: through)[muscle]?.sets ?? 0
        guard early > 0, abs(late / early - 1) > 0.3 else { return nil }
        return "\(muscle.name) sets changed from \(oneDecimal(early)) to \(oneDecimal(late)) between the halves of the window"
    }

    private static func oneDecimal(_ value: Double) -> String { String(format: "%.1f", value) }
    private static func signed(_ value: Double) -> String { String(format: "%+.1f", value) }
}
