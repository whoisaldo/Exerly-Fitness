import Foundation
import HealthKit

actor HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    private init() {}

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
}
