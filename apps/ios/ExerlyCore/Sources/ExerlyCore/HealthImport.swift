import Foundation

/// A weigh-in as the app reads it from Apple Health.
public struct HealthWeight: Sendable, Hashable {
    /// The Health sample's UUID, which becomes the weigh-in's ID.
    public var id: UUID
    public var at: Date
    public var kilograms: Double
    /// Body fat in percent (Health's fraction times 100), when the same reading has it.
    public var bodyFatPercent: Double?
    /// The time zone recorded with the sample, if any.
    public var timeZone: TimeZone?

    public init(id: UUID, at: Date, kilograms: Double, bodyFatPercent: Double? = nil, timeZone: TimeZone? = nil) {
        self.id = id
        self.at = at
        self.kilograms = kilograms
        self.bodyFatPercent = bodyFatPercent
        self.timeZone = timeZone
    }
}

public struct HealthWeightImport: Sendable, Hashable {
    public var added = 0
    public var updated = 0
    public var removed = 0
    /// Readings outside 20 to 400 kg, or with impossible body fat.
    public var skipped = 0
}

extension NutritionStore {
    /// Merges weigh-ins read from Apple Health, as one unit. Each keeps its
    /// sample's ID, so importing the same samples again changes nothing, on this
    /// device or another. A changed sample updates its weigh-in, and `deleted`
    /// sample IDs (from an anchored query) remove theirs. Weigh-ins entered in
    /// Exerly are never touched.
    @discardableResult
    public func importHealthWeights(_ samples: [HealthWeight], deleted: [UUID] = [],
                                    timeZone: TimeZone) throws -> HealthWeightImport {
        var result = HealthWeightImport()
        var writes: [(id: UUID, entry: WeightEntry?)] = []
        for id in Set(deleted) where weights.contains(where: { $0.id == id && $0.source == .appleHealth }) {
            writes.append((id, nil))
            result.removed += 1
        }
        for sample in samples where !deleted.contains(sample.id) {
            let at = sample.at.roundedToMilliseconds
            let entry = WeightEntry(id: sample.id, at: at, date: LocalDate(at, in: sample.timeZone ?? timeZone),
                                    weight: .kg(sample.kilograms), bodyFat: sample.bodyFatPercent, source: .appleHealth)
            guard entry.problems.isEmpty else {
                result.skipped += 1
                continue
            }
            if let existing = weights.first(where: { $0.id == sample.id }) {
                guard existing.source == .appleHealth, existing != entry else { continue }
                result.updated += 1
            } else {
                result.added += 1
            }
            writes.append((sample.id, entry))
        }
        guard !writes.isEmpty else { return result }
        var publish: [() -> Void] = []
        try persistence.performAtomically {
            publish = try writes.map { write in
                try prepareWrite(kind: Self.weightKind, id: write.id.uuidString, payload: write.entry.map(ExerlyJSON.canonical))
            }
        }
        publish.forEach { $0() }
        return result
    }
}
