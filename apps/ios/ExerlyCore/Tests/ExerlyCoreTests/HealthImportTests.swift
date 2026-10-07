import Foundation
import Testing
@testable import ExerlyCore

@MainActor
@Suite struct HealthImportTests {
    @Test func healthWeighInsMergeIdempotentlyAndFollowHealthDeletions() throws {
        let persistence = InMemoryTrainingPersistence()
        let nutrition = try NutritionStore(persistence: persistence, now: { Fixture.instant() })
        let typed = try nutrition.logWeight(.kg(81), timeZone: .gmt)
        let morning = Fixture.instant(minutes: 7 * 60)
        let a = HealthWeight(id: UUID(), at: morning, kilograms: 80.2, bodyFatPercent: 18.5)
        let b = HealthWeight(id: UUID(), at: morning.addingTimeInterval(86_400), kilograms: 80.0)
        let broken = HealthWeight(id: UUID(), at: morning, kilograms: 8000)

        let first = try nutrition.importHealthWeights([a, b, broken], timeZone: .gmt)
        #expect(first == HealthWeightImport(added: 2, updated: 0, removed: 0, skipped: 1))
        #expect(nutrition.weights.filter { $0.source == .appleHealth }.map(\.id) == [a.id, b.id])
        #expect(try nutrition.importHealthWeights([a, b], timeZone: .gmt) == HealthWeightImport(), "Nothing changed")

        var corrected = b
        corrected.kilograms = 79.9
        let second = try nutrition.importHealthWeights([corrected], deleted: [a.id, typed.id], timeZone: .gmt)
        #expect(second == HealthWeightImport(added: 0, updated: 1, removed: 1, skipped: 0))
        #expect(nutrition.weights.map(\.id) == [typed.id, b.id], "The weigh-in typed in Exerly stays")
        #expect(nutrition.weights.last?.weight == .kg(79.9))

        // Health stays the source of truth, and survives a relaunch.
        #expect(throws: NutritionStore.StoreError.self) { try nutrition.deleteWeight(b.id) }
        let reopened = try NutritionStore(persistence: persistence)
        #expect(reopened.weights == nutrition.weights)
    }

    @Test func aSampleIsDatedInTheTimeZoneItWasRecordedIn() throws {
        let nutrition = try NutritionStore(persistence: InMemoryTrainingPersistence(), now: { Fixture.instant() })
        // 02:00 UTC is still the previous evening in New York.
        let late = Fixture.instant(minutes: 8 * 60) // Fixture.instant() is 18:00 UTC.
        let newYork = TimeZone(identifier: "America/New_York")!
        try nutrition.importHealthWeights([HealthWeight(id: UUID(), at: late, kilograms: 80, timeZone: newYork)], timeZone: .gmt)
        #expect(nutrition.weights.first?.date == LocalDate(late, in: newYork))
        #expect(LocalDate(late, in: newYork) != LocalDate(late, in: .gmt))
    }
}
