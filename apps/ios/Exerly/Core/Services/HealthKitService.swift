import Foundation
import HealthKit

actor HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]

        let writeTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
        ]

        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            return false
        }
    }

    /// Today's steps so far, or nil when Health shows no samples. Health
    /// doesn't say whether reading was refused, so nil means "none visible",
    /// never zero; 0 is a measured zero.
    func stepsToday() async -> Int? {
        await sumToday(.stepCount, unit: .count()).map { Int($0) }
    }

    /// Today's active energy in kcal so far, or nil when Health shows no samples.
    func activeCaloriesToday() async -> Int? {
        await sumToday(.activeEnergyBurned, unit: .kilocalorie()).map { Int($0) }
    }

    /// Zero when there are no samples. Prefer `stepsToday()`.
    func fetchStepsToday() async -> Int { await stepsToday() ?? 0 }

    /// Zero when there are no samples. Prefer `activeCaloriesToday()`.
    func fetchActiveCaloriesToday() async -> Int { await activeCaloriesToday() ?? 0 }

    private func sumToday(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(identifier)
        let start = Calendar.current.startOfDay(for: Date())
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    func saveWorkout(
        type: HKWorkoutActivityType,
        start: Date,
        end: Date,
        calories: Double
    ) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: .local()
        )

        try await builder.beginCollection(at: start)

        if calories > 0,
           let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: quantity,
                start: start,
                end: end
            )
            try await builder.addSamples([energySample])
        }

        try await builder.endCollection(at: end)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.finishWorkout { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
