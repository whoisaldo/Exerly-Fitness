import Foundation

/// The plates a gym has, in pairs, so both sides of a bar can match.
public struct PlateStock: Sendable, Codable, Hashable {
    public var weight: Mass
    public var pairs: Int

    public init(_ weight: Mass, pairs: Int) {
        self.weight = weight
        self.pairs = pairs
    }

    public static let standardKilograms: [PlateStock] = [25, 20, 15, 10, 5, 2.5, 1.25].map { PlateStock(.kg($0), pairs: 4) }
    public static let standardPounds: [PlateStock] = [45, 35, 25, 10, 5, 2.5].map { PlateStock(.lb($0), pairs: 4) }
}

/// How a barbell load is made: the bar plus the same plates on each side.
public struct PlateLoad: Sendable, Hashable {
    /// Heaviest first, for one side.
    public var perSide: [Mass]
    public var bar: Mass
    /// The load actually on the bar, in the bar's unit.
    public var total: Mass
    /// The target minus what could be loaded; zero when exact.
    public var shortBy: Mass
    /// The target is lighter than the bar alone, so nothing at or under it can
    /// be loaded; `total` is the bar. A lighter bar is needed.
    public var isBelowBar: Bool
}

public enum Plates {
    /// The heaviest load at or under `target` that the bar and plates can make,
    /// with the plates for each side. Plates of the other unit are converted.
    /// Of the combinations that reach it, the one with the fewest plates wins,
    /// then the one with heavier plates.
    public static func load(_ target: Mass, bar: Mass, stock: [PlateStock]) -> PlateLoad {
        let unit = bar.unit
        let wanted = target.value(in: unit)
        guard wanted >= bar.value - 1e-9 else {
            return PlateLoad(perSide: [], bar: bar, total: bar, shortBy: Mass(0, unit), isBelowBar: true)
        }
        let plates = stock.filter { $0.pairs > 0 && $0.weight.value > 0 }.sorted { $0.weight > $1.weight }
        let weights = plates.map { $0.weight.value(in: unit) }
        let counts = best(upTo: (wanted - bar.value) / 2, weights: weights, available: plates.map(\.pairs))
        let perSide = zip(plates, counts).flatMap { Array(repeating: $0.weight, count: $1) }
        let loaded = bar.value + 2 * zip(weights, counts).reduce(0) { $0 + $1.0 * Double($1.1) }
        return PlateLoad(perSide: perSide, bar: bar, total: Mass(loaded, unit), shortBy: Mass(max(0, wanted - loaded), unit),
                         isBelowBar: false)
    }

    /// How many of each plate, heaviest first, make the most weight at or under
    /// `limit`. A depth-first search that tries more of the heavier plates first,
    /// so on a tie in weight and count the heavier combination is found first.
    private static func best(upTo limit: Double, weights: [Double], available: [Int]) -> [Int] {
        let epsilon = 1e-9
        var remaining = Array(repeating: 0.0, count: weights.count + 1)
        for index in weights.indices.reversed() { remaining[index] = remaining[index + 1] + weights[index] * Double(available[index]) }
        var best = (total: 0.0, plates: 0, counts: Array(repeating: 0, count: weights.count))
        var counts = best.counts
        func search(_ index: Int, _ total: Double, _ plates: Int) {
            if total > best.total + epsilon || (abs(total - best.total) <= epsilon && plates < best.plates) {
                best = (total, plates, counts)
            }
            guard index < weights.count, total + remaining[index] >= best.total - epsilon,
                  !(best.total >= limit - epsilon && plates >= best.plates) else { return }
            let most = min(available[index], Int(((limit - total) / weights[index] + epsilon).rounded(.down)))
            for count in stride(from: max(0, most), through: 0, by: -1) {
                counts[index] = count
                search(index + 1, total + weights[index] * Double(count), plates + count)
            }
            counts[index] = 0
        }
        search(0, 0, 0)
        return best.counts
    }
}

/// Warm-up sets before a working load: fractions of it with reps, rounded to
/// loads the equipment can make. Strong's and MacroFactor's calculators offer
/// similar ramps; this one is Exerly's own.
public struct WarmUpScheme: Sendable, Codable, Hashable {
    public struct Step: Sendable, Codable, Hashable {
        public var fraction: Double
        public var reps: Int
        public init(_ fraction: Double, reps: Int) {
            self.fraction = fraction
            self.reps = reps
        }
    }

    public var steps: [Step]
    /// Start with a set of the empty bar for barbell lifts.
    public var emptyBar: Bool

    public init(steps: [Step], emptyBar: Bool = true) {
        self.steps = steps
        self.emptyBar = emptyBar
    }

    /// A general ramp: 40 % for 5, 60 % for 3, 80 % for 2.
    public static let standard = WarmUpScheme(steps: [Step(0.4, reps: 5), Step(0.6, reps: 3), Step(0.8, reps: 2)])
    /// For heavy singles to fives: adds 90 % for 1.
    public static let heavy = WarmUpScheme(steps: [Step(0.4, reps: 5), Step(0.55, reps: 3), Step(0.7, reps: 2), Step(0.85, reps: 1),
                                                   Step(0.92, reps: 1)])

    /// Warm-up sets for a working load: incomplete `warmUp` sets, lightest first.
    /// Loads round down to what the equipment can make, skip anything at or
    /// under the bar except the empty-bar set, and never repeat a load.
    public func sets(for working: Mass, exercise: Exercise, bar: Mass?, stock: [PlateStock],
                     increments: LoadIncrements? = nil) -> [PerformedSet] {
        guard exercise.metric == .weightReps, working.value > 0 else { return [] }
        let steps = increments ?? LoadIncrements.defaults(for: exercise)
        var loads: [(Mass, Int)] = []
        if let bar, emptyBar, working.kilograms > bar.kilograms * 1.25 { loads.append((bar, 10)) }
        for step in self.steps {
            let raw = Mass(working.value * step.fraction, working.unit)
            let load: Mass
            if let bar {
                guard raw.kilograms > bar.kilograms + 1e-9 else { continue }
                load = Plates.load(raw, bar: Mass(bar.value(in: working.unit), working.unit), stock: stock).total
            } else {
                let size = steps.step(in: working.unit)
                load = Mass((raw.value / size).rounded(.down) * size, working.unit)
            }
            guard load.value > 0, load.kilograms < working.kilograms - 1e-9,
                  !loads.contains(where: { abs($0.0.kilograms - load.kilograms) < 1e-9 })
            else { continue }
            loads.append((load, step.reps))
        }
        return loads.map { PerformedSet(kind: .warmUp, efforts: [Effort(reps: $0.1, load: $0.0)]) }
    }
}
