import Foundation

/// A body mass sample read from Health, before body fat is attached.
public struct HealthMassReading: Sendable, Hashable {
    public var id: UUID
    public var at: Date
    public var kilograms: Double
    public var timeZone: TimeZone?
    /// The writing app's bundle identifier, when Health reports it.
    public var source: String?

    public init(id: UUID, at: Date, kilograms: Double, timeZone: TimeZone? = nil, source: String? = nil) {
        self.id = id
        self.at = at
        self.kilograms = kilograms
        self.timeZone = timeZone
        self.source = source
    }
}

/// A body fat percentage sample read from Health.
public struct HealthBodyFatReading: Sendable, Hashable {
    public var id: UUID
    public var at: Date
    /// As Health stores it: 0.185 for 18.5 %.
    public var fraction: Double
    public var source: String?

    public init(id: UUID, at: Date, fraction: Double, source: String? = nil) {
        self.id = id
        self.at = at
        self.fraction = fraction
        self.source = source
    }
}

/// Health keeps weight and body fat as separate samples. A smart scale writes
/// both at the same instant; this joins them back into one weigh-in.
public enum HealthWeightPairing {
    /// How far apart a weight and a body fat reading can be and still be one weigh-in.
    public static let tolerance: TimeInterval = 5 * 60

    /// Weigh-ins with the body fat measured with them. Each body fat reading
    /// goes to the nearest weight within `tolerance`, from the same app when
    /// both name one, and each weight takes at most one. A body fat outside 1
    /// to 75 % is left off rather than losing the weight with it. Also returns
    /// which weigh-in each body fat reading went to, by body fat sample ID.
    public static func pair(_ mass: [HealthMassReading], _ bodyFat: [HealthBodyFatReading])
        -> (weights: [HealthWeight], bodyFat: [UUID: UUID]) {
        let usable = bodyFat.filter { $0.fraction.isFinite && $0.fraction * 100 > 1 && $0.fraction * 100 < 75 }
        var candidates: [(gap: TimeInterval, mass: Int, fat: Int)] = []
        for (m, weight) in mass.enumerated() {
            for (f, fat) in usable.enumerated() {
                let gap = abs(weight.at.timeIntervalSince(fat.at))
                guard gap <= tolerance else { continue }
                if let a = weight.source, let b = fat.source, a != b { continue }
                candidates.append((gap, m, f))
            }
        }
        // Closest first; ties go to the earlier weight, then the earlier reading.
        candidates.sort { ($0.gap, $0.mass, $0.fat) < ($1.gap, $1.mass, $1.fat) }
        var fatFor: [Int: Int] = [:]
        var taken = Set<Int>()
        for candidate in candidates where fatFor[candidate.mass] == nil && !taken.contains(candidate.fat) {
            fatFor[candidate.mass] = candidate.fat
            taken.insert(candidate.fat)
        }
        var pairs: [UUID: UUID] = [:]
        let weights = mass.enumerated().map { m, reading in
            let fat = fatFor[m].map { usable[$0] }
            if let fat { pairs[fat.id] = reading.id }
            return HealthWeight(id: reading.id, at: reading.at, kilograms: reading.kilograms,
                                bodyFatPercent: fat.map { ($0.fraction * 1000).rounded() / 10 }, timeZone: reading.timeZone)
        }
        return (weights, pairs)
    }

    /// The span to read again so weigh-ins and their body fat pair up after a
    /// change: from `tolerance` before the earliest instant to `tolerance`
    /// after the latest. Nil when there's nothing to read.
    public static func span(around instants: [Date]) -> DateInterval? {
        guard let first = instants.min(), let last = instants.max() else { return nil }
        return DateInterval(start: first.addingTimeInterval(-tolerance), end: last.addingTimeInterval(tolerance))
    }
}
