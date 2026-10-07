import Foundation

/// One night and morning from Apple Health: sleep, heart rate variability and
/// resting heart rate. Any of them may be missing.
public struct RecoveryDay: Sendable, Codable, Hashable {
    public var date: LocalDate
    public var sleepHours: Double?
    /// Heart rate variability in milliseconds (SDNN, as Apple Health records it).
    public var hrv: Double?
    /// Resting heart rate in beats a minute.
    public var restingHeartRate: Double?

    public init(date: LocalDate, sleepHours: Double? = nil, hrv: Double? = nil, restingHeartRate: Double? = nil) {
        self.date = date
        self.sleepHours = sleepHours
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
    }
}

/// Whether the last few days look like poor recovery against the person's own
/// baseline. PARITY B05; see docs/design/020-recovery.md for the method and
/// its measured error.
public struct RecoveryStatus: Sendable, Hashable {
    public enum State: String, Sendable, Hashable {
        /// Fewer than 14 days of baseline for at least two of the signals.
        case notEnoughData
        case normal
        /// At least two signals worse than usual by a standard deviation.
        case strained
    }

    public enum Signal: String, Sendable, Hashable, CaseIterable {
        case sleep, hrv, restingHeartRate
    }

    /// One signal's last days against its baseline.
    public struct Reading: Sendable, Hashable {
        public var signal: Signal
        /// The mean of the last days.
        public var recent: Double
        /// The baseline's median and spread (a robust standard deviation).
        public var baseline: Double
        public var spread: Double
        /// Standard deviations from the baseline, signed so that negative is worse.
        public var score: Double
        public var adverse: Bool
    }

    public var date: LocalDate
    public var state: State
    public var readings: [Reading]

    /// Days in the recent window, and in the baseline before it.
    public static let window = 3
    public static let baselineDays = 28
    public static let minimumBaseline = 14

    /// The status on `date`, from the days up to and including it.
    public static func assess(_ days: [RecoveryDay], on date: LocalDate) -> RecoveryStatus {
        let byDate = Dictionary(days.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
        let recentDates = (0..<window).map { date.adding(days: -$0) }
        let baselineDates = (window..<(window + baselineDays)).map { date.adding(days: -$0) }
        var readings: [Reading] = []
        for signal in Signal.allCases {
            let recent = recentDates.compactMap { byDate[$0].flatMap(signal.value) }
            let baseline = baselineDates.compactMap { byDate[$0].flatMap(signal.value) }
            guard recent.count >= 2, baseline.count >= minimumBaseline else { continue }
            let median = Self.median(baseline)
            let mad = Self.median(baseline.map { abs($0 - median) })
            let spread = max(1.4826 * mad, signal.smallestSpread(median))
            let mean = recent.reduce(0, +) / Double(recent.count)
            // Higher heart rate is worse; for sleep and HRV, lower is.
            let score = (signal == .restingHeartRate ? median - mean : mean - median) / spread
            readings.append(Reading(signal: signal, recent: mean, baseline: median, spread: spread, score: score,
                                    adverse: score <= -1))
        }
        let state: State = readings.count < 2 ? .notEnoughData
            : readings.filter(\.adverse).count >= 2 ? .strained : .normal
        return RecoveryStatus(date: date, state: state, readings: readings)
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// Words for the readings that are worse than usual, such as
    /// "HRV 41 ms against a usual 52 ms".
    public var summary: String {
        readings.filter(\.adverse).map { reading in
            switch reading.signal {
            case .sleep: "sleep \(Self.number(reading.recent)) h against a usual \(Self.number(reading.baseline)) h"
            case .hrv: "HRV \(Int(reading.recent.rounded())) ms against a usual \(Int(reading.baseline.rounded())) ms"
            case .restingHeartRate:
                "resting heart rate \(Int(reading.recent.rounded())) bpm against a usual \(Int(reading.baseline.rounded())) bpm"
            }
        }.joined(separator: ", ")
    }

    private static func number(_ value: Double) -> String { String(format: "%.1f", value) }
}

extension RecoveryStatus.Signal {
    func value(_ day: RecoveryDay) -> Double? {
        let value: Double? = switch self {
        case .sleep: day.sleepHours
        case .hrv: day.hrv
        case .restingHeartRate: day.restingHeartRate
        }
        return value.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    /// A floor under the spread, so a very regular baseline doesn't turn a
    /// small change into a large score: 20 minutes of sleep, 5 % of HRV, and
    /// 1.5 beats a minute.
    func smallestSpread(_ median: Double) -> Double {
        switch self {
        case .sleep: 1.0 / 3
        case .hrv: 0.05 * median
        case .restingHeartRate: 1.5
        }
    }
}

extension WorkoutPlan {
    /// A lighter version for a strained day: two thirds of each exercise's
    /// working sets, rounded up, and one more rep in reserve, up to 5. Loads
    /// and reps stay as recommended; warm-ups are kept.
    public func lightened() -> WorkoutPlan {
        var plan = self
        for index in plan.exercises.indices {
            var exercise = plan.exercises[index]
            let working = exercise.recommendation.sets.filter { $0.kind != .warmUp }
            let keep = Int((Double(working.count) * 2 / 3).rounded(.up))
            var kept = 0
            exercise.recommendation.sets = exercise.recommendation.sets.compactMap { set in
                guard set.kind != .warmUp else { return set }
                kept += 1
                guard kept <= keep else { return nil }
                var lighter = set
                lighter.rir = min(5, set.rir + 1)
                return lighter
            }
            exercise.target.sets = keep
            exercise.target.rir = min(5, exercise.target.rir + 1)
            plan.exercises[index] = exercise
        }
        return plan
    }
}
