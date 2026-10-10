import Foundation
import Testing
@testable import ExerlyCore

/// What Exerly writes to Apple Health, and when. Synthetic data only.
@MainActor
@Suite struct HealthExportTests {
    private let newYork = Fixture.newYork

    private func entry(_ nutrients: [Nutrient: Double], grams: Double = 200, meal: String = "Lunch",
                       date: LocalDate? = nil, loggedAt: Date = Fixture.instant()) -> FoodEntry {
        let snapshot = FoodSnapshot(foodID: "synthetic-oats", name: "Synthetic oats", source: .custom,
                                    per100g: NutrientAmounts(nutrients))
        return FoodEntry(date: date ?? LocalDate(loggedAt, in: newYork), meal: meal, loggedAt: loggedAt, food: snapshot,
                         grams: grams)
    }

    @Test func everyMappedNutrientHasADietaryTypeInItsOwnUnit() {
        let mapped = Nutrient.healthWritable
        #expect(mapped.count == 33)
        #expect(Set(mapped.compactMap(\.healthType)).count == mapped.count, "Two nutrients must not share a Health type")
        #expect(mapped.allSatisfy { $0.healthType!.hasPrefix("HKQuantityTypeIdentifierDietary") })
        #expect(Nutrient.energy.healthUnit == .kilocalories)
        #expect(Nutrient.protein.healthUnit == .grams)
        #expect(Nutrient.sodium.healthUnit == .milligrams)
        #expect(Nutrient.vitaminD.healthUnit == .micrograms)
        // Health's water is drinking water and its alcohol is counted in drinks.
        for left in [Nutrient.water, .alcohol, .addedSugars, .transFat, .omega3, .choline, .leucine] {
            #expect(left.healthType == nil, "\(left) has no Health type to write")
        }
    }

    @Test func aFoodRecordScalesThePortionAndLeavesOutUnknownAndZeroAmounts() throws {
        let logged = entry([.energy: 380, .protein: 13.2, .fat: 6.9, .sodium: 0, .vitaminB12: 0.4, .water: 10, .leucine: 1.1],
                           grams: 50)
        let record = try #require(HealthFoodRecord(entry: logged, timeZone: newYork))
        #expect(record.id == logged.id)
        #expect(record.name == "Synthetic oats")
        let byType = Dictionary(uniqueKeysWithValues: record.quantities.map { ($0.type, $0) })
        #expect(byType.count == 4, "Zero sodium, water, an amino acid and the missing carbs aren't written")
        #expect(byType["HKQuantityTypeIdentifierDietaryEnergyConsumed"] == HealthQuantity(
            type: "HKQuantityTypeIdentifierDietaryEnergyConsumed", value: 190, unit: .kilocalories))
        #expect(close(byType["HKQuantityTypeIdentifierDietaryProtein"]?.value, 6.6))
        #expect(close(byType["HKQuantityTypeIdentifierDietaryVitaminB12"]?.value, 0.2))
        #expect(byType["HKQuantityTypeIdentifierDietaryVitaminB12"]?.unit == .micrograms)
        #expect(record.quantities.map(\.type) == record.quantities.map(\.type).sorted())

        #expect(HealthFoodRecord(entry: entry([.sodium: 0, .water: 90]), timeZone: newYork) == nil,
                "An entry with nothing Health can hold writes nothing")
    }

    @Test func aFoodIsDatedWhenEatenOrAtItsMealOnItsOwnDay() throws {
        // 2026-10-05 18:00 UTC is 14:00 in New York.
        let now = Fixture.instant()
        let today = LocalDate(now, in: newYork)
        #expect(HealthFoodRecord.eatenAt(entry([.energy: 1], date: today, loggedAt: now), timeZone: newYork) == now)

        // Logged today for yesterday's dinner: 18:30 yesterday, New York time.
        let yesterday = today.adding(days: -1)
        let late = entry([.energy: 1], meal: "Dinner", date: yesterday, loggedAt: now)
        let at = HealthFoodRecord.eatenAt(late, timeZone: newYork)
        #expect(LocalDate(at, in: newYork) == yesterday)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        #expect(calendar.dateComponents([.hour, .minute], from: at) == DateComponents(hour: 18, minute: 30))
        // A meal without a usual time lands at noon.
        let custom = entry([.energy: 1], meal: "Pre-workout", date: yesterday, loggedAt: now)
        #expect(calendar.component(.hour, from: HealthFoodRecord.eatenAt(custom, timeZone: newYork)) == 12)
    }

    @Test func onlyWeighInsEnteredInExerlyAreWrittenInTheirOwnUnit() throws {
        let typed = WeightEntry(at: Fixture.instant(), date: LocalDate(Fixture.instant(), in: newYork), weight: .lb(184.6),
                                bodyFat: 18.5)
        let record = try #require(HealthWeightRecord(entry: typed, timeZone: newYork))
        #expect(record.weight == HealthQuantity(type: "HKQuantityTypeIdentifierBodyMass", value: 184.6, unit: .pounds))
        #expect(record.bodyFatFraction == 0.185)
        #expect(record.timeZone == "America/New_York")

        var fromHealth = typed
        fromHealth.source = .appleHealth
        #expect(HealthWeightRecord(entry: fromHealth, timeZone: newYork) == nil, "Health's own readings aren't written back")
    }

    @Test func onlyFinishedWorkoutsAreWritten() throws {
        let finished = Fixture.session([("deadlift", [Fixture.set(5, 140)])])
        let record = try #require(HealthWorkoutRecord(session: finished))
        #expect(record.start == finished.startedAt)
        #expect(record.end.timeIntervalSince(record.start) == 3600)
        var running = finished
        running.endedAt = nil
        #expect(HealthWorkoutRecord(session: running) == nil)
    }

    @Test func fingerprintsAreStableAndFollowEveryWrittenValue() throws {
        let logged = entry([.energy: 380, .protein: 13])
        let a = try #require(HealthFoodRecord(entry: logged, timeZone: newYork))
        let b = try #require(HealthFoodRecord(entry: logged, timeZone: newYork))
        #expect(a.fingerprint == b.fingerprint)
        // A known value guards against an unstable hash creeping in: it must be
        // the same on every launch and device, unlike Swift's `hashValue`.
        let fixed = HealthWeightRecord(entry: WeightEntry(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                                                         at: Date(timeIntervalSince1970: 1_791_223_200),
                                                         date: LocalDate(year: 2026, month: 10, day: 5)!, weight: .kg(80)),
                                       timeZone: Fixture.utc)!
        #expect(fixed.fingerprint == "4aa9388d9f8a200e")
        var edited = logged
        edited.grams = 201
        #expect(try #require(HealthFoodRecord(entry: edited, timeZone: newYork)).fingerprint != a.fingerprint)
        edited = logged
        edited.food.name = "Synthetic rolled oats"
        #expect(try #require(HealthFoodRecord(entry: edited, timeZone: newYork)).fingerprint != a.fingerprint)
    }

    @Test func theLedgerWritesEachRecordOnceAndFollowsEditsAndDeletes() throws {
        let start = Fixture.instant(minutes: -60)
        let before = try #require(HealthFoodRecord(entry: entry([.energy: 100], loggedAt: Fixture.instant(minutes: -120)),
                                                   timeZone: newYork))
        let a = try #require(HealthFoodRecord(entry: entry([.energy: 200]), timeZone: newYork))
        let b = try #require(HealthFoodRecord(entry: entry([.energy: 300], loggedAt: Fixture.instant(minutes: 5)),
                                              timeZone: newYork))
        var ledger = HealthWriteLedger()

        let first = ledger.changes(for: [b, before, a], since: start)
        #expect(first.remove.isEmpty)
        #expect(first.write.map(\.id) == [a.id, b.id], "Earlier records stay out; the rest go oldest first")
        ledger.wrote(first.write)
        #expect(ledger.count(.food) == 2)

        // A retry, or a sync with nothing new, writes nothing.
        #expect(ledger.changes(for: [b, before, a], since: start).isEmpty)
        // A caller's cached digests stand in for computing them again.
        let cached = [a.id: a.fingerprint, b.id: "stale"]
        #expect(ledger.changes(for: [b, before, a], since: start) { cached[$0.id] ?? $0.fingerprint }.write == [b])

        // An edit replaces its record; a deletion removes it.
        var edited = a
        edited.quantities[0].value = 250
        let second = ledger.changes(for: [before, edited], since: start)
        #expect(second.remove == [a.id, b.id], "The edited record first, then the deleted one")
        #expect(second.write == [edited])
        ledger.removed(.food, second.remove)
        ledger.wrote(second.write)
        #expect(ledger.contains(.food, a.id))
        #expect(!ledger.contains(.food, b.id))
        #expect(ledger.changes(for: [before, edited], since: start).isEmpty)

        // A written record that moved before the start is still kept in step.
        var moved = edited
        moved.at = start.addingTimeInterval(-86_400)
        #expect(ledger.changes(for: [moved], since: start).write == [moved])
    }

    @Test func aFailedWriteAfterItsRemovalIsWrittenFreshNextTime() throws {
        let start = Fixture.instant(minutes: -60)
        let a = try #require(HealthFoodRecord(entry: entry([.energy: 200]), timeZone: newYork))
        var ledger = HealthWriteLedger()
        ledger.wrote([a])
        var edited = a
        edited.quantities[0].value = 210
        let changes = ledger.changes(for: [edited], since: start)
        // The removal succeeded, then the save failed.
        ledger.removed(.food, changes.remove)
        let retry = ledger.changes(for: [edited], since: start)
        #expect(retry.remove.isEmpty, "Nothing is left in Health to remove")
        #expect(retry.write == [edited])
    }

    @Test func kindsKeepSeparateLedgersAndTheLedgerSurvivesEncoding() throws {
        let start = Fixture.instant(minutes: -60)
        let weight = try #require(HealthWeightRecord(entry: WeightEntry(at: Fixture.instant(), date: LocalDate(Fixture.instant(), in: newYork),
                                                                        weight: .kg(80)), timeZone: newYork))
        var ledger = HealthWriteLedger()
        ledger.wrote([weight])
        #expect(ledger.changes(for: [HealthFoodRecord](), since: start).isEmpty, "Food doesn't remove weigh-ins")
        let decoded = try ExerlyJSON.decoder.decode(HealthWriteLedger.self, from: ExerlyJSON.canonical(ledger))
        #expect(decoded == ledger)
        #expect(decoded.changes(for: [weight], since: start).isEmpty)
        #expect(decoded.changes(for: [HealthWeightRecord](), since: start).remove == [weight.id])
    }

    @Test func syncIdentifiersAndExerlysOwnSamplesAreRecognised() {
        let id = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!
        #expect(HealthMetadata.syncIdentifier(.food, id, part: "protein") == "exerly.food.6f9619ff-8b86-d011-b42d-00c04fc964ff.protein")
        #expect(HealthMetadata.syncIdentifier(.weight, id) == "exerly.weight.6f9619ff-8b86-d011-b42d-00c04fc964ff")
        #expect(HealthMetadata.isFromExerly([HealthMetadata.recordID: id.uuidString]))
        #expect(HealthMetadata.isFromExerly([HealthMetadata.syncIdentifierKey: "exerly.weight.abc"]))
        #expect(!HealthMetadata.isFromExerly([HealthMetadata.syncIdentifierKey: "com.scale.reading.1"]))
        #expect(!HealthMetadata.isFromExerly(["HKWasUserEntered": true]))
        #expect(!HealthMetadata.isFromExerly(nil))
    }
}

/// Reading weigh-ins from Health: weight and body fat arrive as separate samples.
@MainActor
@Suite struct HealthWeightPairingTests {
    @Test func aScalesWeightAndBodyFatBecomeOneWeighIn() {
        let at = Fixture.instant()
        let weight = HealthMassReading(id: UUID(), at: at, kilograms: 80.2, source: "com.example.scale")
        let fat = HealthBodyFatReading(id: UUID(), at: at.addingTimeInterval(2), fraction: 0.185, source: "com.example.scale")
        let other = HealthMassReading(id: UUID(), at: at.addingTimeInterval(86_400), kilograms: 80)
        let paired = HealthWeightPairing.pair([weight, other], [fat])
        #expect(paired.weights.map(\.id) == [weight.id, other.id])
        #expect(paired.weights[0].bodyFatPercent == 18.5)
        #expect(paired.weights[1].bodyFatPercent == nil)
        #expect(paired.bodyFat == [fat.id: weight.id])
    }

    @Test func eachReadingGoesToTheNearestWeightFromTheSameApp() {
        let at = Fixture.instant()
        let first = HealthMassReading(id: UUID(), at: at, kilograms: 80, source: "com.example.scale")
        let second = HealthMassReading(id: UUID(), at: at.addingTimeInterval(120), kilograms: 80.1, source: "com.example.scale")
        let nearSecond = HealthBodyFatReading(id: UUID(), at: at.addingTimeInterval(110), fraction: 0.2, source: "com.example.scale")
        let otherApp = HealthBodyFatReading(id: UUID(), at: at, fraction: 0.3, source: "com.example.other")
        let tooFar = HealthBodyFatReading(id: UUID(), at: at.addingTimeInterval(-HealthWeightPairing.tolerance - 1), fraction: 0.25)
        let paired = HealthWeightPairing.pair([first, second], [nearSecond, otherApp, tooFar])
        #expect(paired.weights[0].bodyFatPercent == nil)
        #expect(paired.weights[1].bodyFatPercent == 20)
        #expect(paired.bodyFat == [nearSecond.id: second.id])
    }

    @Test func impossibleBodyFatIsDroppedWithoutLosingTheWeight() throws {
        let nutrition = try NutritionStore(persistence: InMemoryTrainingPersistence(), now: { Fixture.instant() })
        let at = Fixture.instant()
        let weight = HealthMassReading(id: UUID(), at: at, kilograms: 80)
        let paired = HealthWeightPairing.pair([weight], [HealthBodyFatReading(id: UUID(), at: at, fraction: 0.004)])
        #expect(paired.weights[0].bodyFatPercent == nil)
        #expect(paired.bodyFat.isEmpty)
        let result = try nutrition.importHealthWeights(paired.weights, timeZone: .gmt)
        #expect(result.added == 1)
    }

    @Test func aHalfPastMidnightReadingBelongsToThatLocalDay() throws {
        let newYork = Fixture.newYork
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let early = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 0, minute: 30))!
        let nutrition = try NutritionStore(persistence: InMemoryTrainingPersistence(), now: { Fixture.instant() })
        let paired = HealthWeightPairing.pair([HealthMassReading(id: UUID(), at: early, kilograms: 79.6, timeZone: newYork)], [])
        try nutrition.importHealthWeights(paired.weights, timeZone: Fixture.utc)
        #expect(nutrition.weights.first?.date == LocalDate(year: 2026, month: 10, day: 6))
        // Without the sample's zone, the account's zone decides.
        let unzoned = HealthWeightPairing.pair([HealthMassReading(id: UUID(), at: early.addingTimeInterval(86_400), kilograms: 79.5)], [])
        try nutrition.importHealthWeights(unzoned.weights, timeZone: newYork)
        #expect(nutrition.weights.last?.date == LocalDate(year: 2026, month: 10, day: 7))
    }

    @Test func theSpanCoversEveryChangeWithRoomForItsPartner() throws {
        #expect(HealthWeightPairing.span(around: []) == nil)
        let at = Fixture.instant()
        let span = try #require(HealthWeightPairing.span(around: [at.addingTimeInterval(3600), at]))
        #expect(span.start == at.addingTimeInterval(-HealthWeightPairing.tolerance))
        #expect(span.end == at.addingTimeInterval(3600 + HealthWeightPairing.tolerance))
    }
}
