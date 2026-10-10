import ExerlyCore
import Foundation
import HealthKit

/// What one Health switch asks HealthKit for. Each asks only for its own types.
enum HealthCategory: String, CaseIterable, Codable, CodingKeyRepresentable, Identifiable {
    case readWeights, readActivity, writeFood, writeWeights, writeWorkouts

    var id: String { rawValue }

    /// The record kind a write switch writes.
    var recordKind: HealthRecordKind? {
        switch self {
        case .writeFood: .food
        case .writeWeights: .weight
        case .writeWorkouts: .workout
        case .readWeights, .readActivity: nil
        }
    }
}

/// Whether Health lets Exerly write a category. Health reveals this for
/// writing; it never reveals whether reading was allowed.
enum HealthWriteAccess: Equatable {
    case allowed, denied, notAsked
}

/// Steps and active energy on one day. Nil means Health shows no samples,
/// which can also mean reading isn't allowed; 0 is a measured zero.
struct HealthActivity: Equatable {
    var steps: Int?
    var activeKilocalories: Int?
}

/// What changed in Health's weight and body fat since the last read. Samples
/// Exerly wrote are left out, so its own weigh-ins never come back as Health's.
struct HealthWeightDelta {
    var addedMass: [HealthMassReading] = []
    var deletedMass: [UUID] = []
    var addedBodyFat: [HealthBodyFatReading] = []
    var deletedBodyFat: [UUID] = []
    var massAnchor: Data?
    var bodyFatAnchor: Data?
}

/// Every HealthKit call the app makes. `HealthSync` decides what and when;
/// tests replace this with a fake.
protocol HealthStoreClient: AnyObject, Sendable {
    var isAvailable: Bool { get }
    func requestAccess(_ category: HealthCategory) async throws
    func writeAccess(_ category: HealthCategory) -> HealthWriteAccess
    func weightChanges(massAnchor: Data?, bodyFatAnchor: Data?) async throws -> HealthWeightDelta
    func weights(in span: DateInterval) async throws -> (mass: [HealthMassReading], bodyFat: [HealthBodyFatReading])
    func remove(_ kind: HealthRecordKind, ids: [UUID]) async throws
    func saveFood(_ records: [HealthFoodRecord]) async throws
    func saveWeights(_ records: [HealthWeightRecord]) async throws
    func saveWorkout(_ record: HealthWorkoutRecord) async throws
    func activity(on date: LocalDate, timeZone: TimeZone) async -> HealthActivity
    /// Calls `onChange` when weight or body fat changes in Health, including
    /// in the background once delivery is on, and tells Health when it's done.
    func observeWeights(_ onChange: @escaping @Sendable () async -> Void)
    func stopObservingWeights()
}

final class HealthKitService: HealthStoreClient, @unchecked Sendable {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private let lock = NSLock()
    private var observers: [HKObserverQuery] = []

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: Types

    private static let bodyMass = HKQuantityType(.bodyMass)
    private static let bodyFat = HKQuantityType(.bodyFatPercentage)
    static let dietaryTypes: [HKQuantityType] = Nutrient.healthWritable.compactMap { nutrient in
        nutrient.healthType.map { HKQuantityType(HKQuantityTypeIdentifier(rawValue: $0)) }
    }

    private static func shareTypes(_ category: HealthCategory) -> Set<HKSampleType> {
        switch category {
        case .writeFood: Set(dietaryTypes)
        case .writeWeights: [bodyMass, bodyFat]
        case .writeWorkouts: [HKObjectType.workoutType()]
        case .readWeights, .readActivity: []
        }
    }

    private static func readTypes(_ category: HealthCategory) -> Set<HKObjectType> {
        switch category {
        case .readWeights: [bodyMass, bodyFat]
        case .readActivity: [HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned)]
        case .writeFood, .writeWeights, .writeWorkouts: []
        }
    }

    static func unit(_ unit: HealthUnit) -> HKUnit {
        switch unit {
        case .kilocalories: .kilocalorie()
        case .grams: .gram()
        case .milligrams: .gramUnit(with: .milli)
        case .micrograms: .gramUnit(with: .micro)
        case .kilograms: .gramUnit(with: .kilo)
        case .pounds: .pound()
        case .percent: .percent()
        }
    }

    // MARK: Access

    func requestAccess(_ category: HealthCategory) async throws {
        var share = Self.shareTypes(category)
        #if DEBUG
        // Seeding synthetic scale readings for UI tests needs to write them.
        if category == .readWeights, HealthDebugSeed.spec != nil { share.formUnion(Self.shareTypes(.writeWeights)) }
        #endif
        try await store.requestAuthorization(toShare: share, read: Self.readTypes(category))
    }

    func writeAccess(_ category: HealthCategory) -> HealthWriteAccess {
        let primary: HKObjectType? = switch category {
        case .writeFood: HKQuantityType(.dietaryEnergyConsumed)
        case .writeWeights: Self.bodyMass
        case .writeWorkouts: HKObjectType.workoutType()
        case .readWeights, .readActivity: nil
        }
        guard let primary else { return .allowed }
        switch store.authorizationStatus(for: primary) {
        case .sharingAuthorized: return .allowed
        case .sharingDenied: return .denied
        default: return .notAsked
        }
    }

    private func canWrite(_ type: HKObjectType) -> Bool { store.authorizationStatus(for: type) == .sharingAuthorized }

    // MARK: Reading weigh-ins

    func weightChanges(massAnchor: Data?, bodyFatAnchor: Data?) async throws -> HealthWeightDelta {
        let mass = try await changes(Self.bodyMass, anchor: massAnchor)
        let fat = try await changes(Self.bodyFat, anchor: bodyFatAnchor)
        return HealthWeightDelta(addedMass: mass.added.compactMap(Self.massReading), deletedMass: mass.deleted,
                                 addedBodyFat: fat.added.compactMap(Self.bodyFatReading), deletedBodyFat: fat.deleted,
                                 massAnchor: mass.anchor, bodyFatAnchor: fat.anchor)
    }

    func weights(in span: DateInterval) async throws -> (mass: [HealthMassReading], bodyFat: [HealthBodyFatReading]) {
        let predicate = HKQuery.predicateForSamples(withStart: span.start, end: span.end, options: [])
        func samples(_ type: HKQuantityType) async throws -> [HKQuantitySample] {
            try await HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)],
                                              sortDescriptors: [SortDescriptor(\.startDate)]).result(for: store)
        }
        return (try await samples(Self.bodyMass).compactMap(Self.massReading),
                try await samples(Self.bodyFat).compactMap(Self.bodyFatReading))
    }

    private func changes(_ type: HKQuantityType, anchor: Data?) async throws
        -> (added: [HKQuantitySample], deleted: [UUID], anchor: Data?) {
        let previous = anchor.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
        let result = try await HKAnchoredObjectQueryDescriptor(predicates: [.quantitySample(type: type)], anchor: previous)
            .result(for: store)
        let next = try NSKeyedArchiver.archivedData(withRootObject: result.newAnchor, requiringSecureCoding: true)
        return (result.addedSamples, result.deletedObjects.map(\.uuid), next)
    }

    private static func massReading(_ sample: HKQuantitySample) -> HealthMassReading? {
        guard !HealthMetadata.isFromExerly(sample.metadata) else { return nil }
        return HealthMassReading(id: sample.uuid, at: sample.startDate,
                                 kilograms: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                                 timeZone: (sample.metadata?[HKMetadataKeyTimeZone] as? String).flatMap(TimeZone.init(identifier:)),
                                 source: sample.sourceRevision.source.bundleIdentifier)
    }

    private static func bodyFatReading(_ sample: HKQuantitySample) -> HealthBodyFatReading? {
        guard !HealthMetadata.isFromExerly(sample.metadata) else { return nil }
        return HealthBodyFatReading(id: sample.uuid, at: sample.startDate, fraction: sample.quantity.doubleValue(for: .percent()),
                                    source: sample.sourceRevision.source.bundleIdentifier)
    }

    // MARK: Writing

    /// Removes every sample Exerly wrote for these records, of every type the
    /// kind writes and Health still lets Exerly change.
    func remove(_ kind: HealthRecordKind, ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthMetadata.recordID,
                                                    allowedValues: ids.map(\.uuidString))
        let types: [HKObjectType] = switch kind {
        case .food: [HKCorrelationType(.food)] + Self.dietaryTypes
        case .weight: [Self.bodyMass, Self.bodyFat]
        case .workout: [HKObjectType.workoutType()]
        }
        for type in types where type is HKCorrelationType || canWrite(type) {
            _ = try await store.deleteObjects(of: type, predicate: predicate)
        }
    }

    func saveFood(_ records: [HealthFoodRecord]) async throws {
        let objects: [HKObject] = records.compactMap { record in
            let samples = record.quantities.compactMap { quantity -> HKQuantitySample? in
                let type = HKQuantityType(HKQuantityTypeIdentifier(rawValue: quantity.type))
                guard canWrite(type) else { return nil }
                let part = quantity.type.replacingOccurrences(of: "HKQuantityTypeIdentifierDietary", with: "")
                return HKQuantitySample(type: type, quantity: HKQuantity(unit: Self.unit(quantity.unit), doubleValue: quantity.value),
                                        start: record.at, end: record.at,
                                        metadata: Self.metadata(.food, record.id, part: part, timeZone: record.timeZone,
                                                                extra: [HKMetadataKeyFoodType: record.name]))
            }
            guard !samples.isEmpty else { return nil }
            return HKCorrelation(type: HKCorrelationType(.food), start: record.at, end: record.at, objects: Set(samples),
                                 metadata: Self.metadata(.food, record.id, timeZone: record.timeZone,
                                                         extra: [HKMetadataKeyFoodType: record.name, "ExerlyMeal": record.meal]))
        }
        guard !objects.isEmpty else { return }
        try await store.save(objects)
    }

    func saveWeights(_ records: [HealthWeightRecord]) async throws {
        guard canWrite(Self.bodyMass) else { return }
        let fat = canWrite(Self.bodyFat)
        let objects: [HKObject] = records.flatMap { record -> [HKObject] in
            let entered: [String: Any] = [HKMetadataKeyWasUserEntered: true]
            var samples: [HKObject] = [
                HKQuantitySample(type: Self.bodyMass,
                                 quantity: HKQuantity(unit: Self.unit(record.weight.unit), doubleValue: record.weight.value),
                                 start: record.at, end: record.at,
                                 metadata: Self.metadata(.weight, record.id, timeZone: record.timeZone, extra: entered))
            ]
            if fat, let fraction = record.bodyFatFraction {
                samples.append(HKQuantitySample(type: Self.bodyFat, quantity: HKQuantity(unit: .percent(), doubleValue: fraction),
                                                start: record.at, end: record.at,
                                                metadata: Self.metadata(.weight, record.id, part: "bodyFat",
                                                                        timeZone: record.timeZone, extra: entered)))
            }
            return samples
        }
        guard !objects.isEmpty else { return }
        try await store.save(objects)
    }

    func saveWorkout(_ record: HealthWorkoutRecord) async throws {
        guard canWrite(HKObjectType.workoutType()) else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: record.start)
        try await builder.addMetadata(Self.metadata(.workout, record.id, timeZone: record.timeZone, extra: [:]))
        try await builder.endCollection(at: record.end)
        _ = try await builder.finishWorkout()
    }

    /// The record's ID, so its samples can be found again, and a sync
    /// identifier with an increasing version, so a retried save replaces the
    /// sample it already wrote instead of adding another.
    private static func metadata(_ kind: HealthRecordKind, _ id: UUID, part: String? = nil, timeZone: String,
                                 extra: [String: Any]) -> [String: Any] {
        var metadata = extra
        metadata[HealthMetadata.recordID] = id.uuidString
        metadata[HKMetadataKeySyncIdentifier] = HealthMetadata.syncIdentifier(kind, id, part: part)
        metadata[HKMetadataKeySyncVersion] = NSNumber(value: Int64(Date().timeIntervalSince1970 * 1000))
        metadata[HKMetadataKeyTimeZone] = timeZone
        return metadata
    }

    // MARK: Activity

    func activity(on date: LocalDate, timeZone: TimeZone) async -> HealthActivity {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let start = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)),
              let end = calendar.date(byAdding: .day, value: 1, to: start) else { return HealthActivity() }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: min(end, Date()), options: [])
        func sum(_ identifier: HKQuantityTypeIdentifier, _ unit: HKUnit) async -> Int? {
            guard start < Date() else { return nil }
            let descriptor = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: HKQuantityType(identifier),
                                                                                    predicate: predicate),
                                                         options: .cumulativeSum)
            return (try? await descriptor.result(for: store))?.sumQuantity().map { Int($0.doubleValue(for: unit).rounded()) }
        }
        return HealthActivity(steps: await sum(.stepCount, .count()),
                              activeKilocalories: await sum(.activeEnergyBurned, .kilocalorie()))
    }

    // MARK: Observing

    func observeWeights(_ onChange: @escaping @Sendable () async -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard observers.isEmpty else { return }
        for type in [Self.bodyMass, Self.bodyFat] {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                guard error == nil else { completion(); return }
                Task {
                    await onChange()
                    completion()
                }
            }
            observers.append(query)
            store.execute(query)
            // Needs the background delivery entitlement; without it Health
            // reports an error and Exerly reads on launch and foreground instead.
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        }
    }

    func stopObservingWeights() {
        lock.lock()
        let running = observers
        observers = []
        lock.unlock()
        for query in running { store.stop(query) }
        for type in [Self.bodyMass, Self.bodyFat] { store.disableBackgroundDelivery(for: type) { _, _ in } }
    }

    // MARK: Debug

    #if DEBUG
    /// Writes synthetic scale readings without Exerly's metadata, as another
    /// app would, after removing earlier ones. UI tests only.
    func seedDebugWeights(_ readings: [(at: Date, kilograms: Double, bodyFat: Double?)], timeZone: TimeZone) async throws {
        let marker = HKQuery.predicateForObjects(withMetadataKey: HealthDebugSeed.markerKey)
        for type in [Self.bodyMass, Self.bodyFat] where canWrite(type) {
            _ = try await store.deleteObjects(of: type, predicate: marker)
        }
        let metadata: [String: Any] = [HealthDebugSeed.markerKey: true, HKMetadataKeyTimeZone: timeZone.identifier]
        let objects: [HKObject] = readings.flatMap { reading -> [HKObject] in
            var samples: [HKObject] = [HKQuantitySample(type: Self.bodyMass, quantity: HKQuantity(unit: .gramUnit(with: .kilo),
                                                                                                  doubleValue: reading.kilograms),
                                                        start: reading.at, end: reading.at, metadata: metadata)]
            if let fat = reading.bodyFat {
                samples.append(HKQuantitySample(type: Self.bodyFat, quantity: HKQuantity(unit: .percent(), doubleValue: fat / 100),
                                                start: reading.at, end: reading.at, metadata: metadata))
            }
            return samples
        }
        guard !objects.isEmpty, canWrite(Self.bodyMass) else { return }
        try await store.save(objects)
    }

    /// How many samples of a kind Exerly wrote for these records.
    func debugCount(_ kind: HealthRecordKind, ids: [UUID]) async -> Int {
        guard !ids.isEmpty else { return 0 }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HealthMetadata.recordID, allowedValues: ids.map(\.uuidString))
        let type: HKSampleType = switch kind {
        case .food: HKCorrelationType(.food)
        case .weight: Self.bodyMass
        case .workout: HKObjectType.workoutType()
        }
        return await withCheckedContinuation { continuation in
            store.execute(HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                        sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            })
        }
    }
    #endif
}
