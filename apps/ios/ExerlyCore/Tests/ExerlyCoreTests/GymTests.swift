import Foundation
import Testing
@testable import ExerlyCore

@Suite struct GymProfileTests {
    let library = ExerciseLibrary.bundled
    let dumbbells: [Mass] = [20, 22.5, 25, 27.5, 30, 32.5, 35, 40].map { .kg($0) }

    func exercise(_ id: ExerciseID) -> Exercise { library.exercise(id)! }

    @Test func progressionRecommendsADumbbellTheGymHas() {
        let press = exercise("dumbbell-bench-press")
        let log = TrainingHistory(sessions: [7, 8].enumerated().map { index, reps in
            Fixture.session(days: Double(index * 3), [("dumbbell-bench-press", [Fixture.set(reps, 32.5, rir: 2)])])
        }, library: library)
        let target = SlotTarget(sets: 3, minReps: 6, maxReps: 8, rir: 2)
        // An e1RM of 43.3 kg asks for 33.7 kg. Steps of 2 kg say 32 kg, which this gym doesn't have.
        let stepped = Progression.recommend(target, exercise: press, history: log, bodyweight: nil)
        #expect(stepped.sets[0].effort.load == .kg(32))
        let gym = GymProfile(name: "Synthetic gym", loads: [.dumbbell: dumbbells])
        let real = Progression.recommend(target, exercise: press, history: log, bodyweight: nil,
                                         increments: gym.increments(for: press))
        #expect(real.sets[0].effort == Effort(reps: 8, load: .kg(32.5)))
        #expect(!real.outsideRange)
    }

    @Test func aGymAllowsExercisesItHasEverythingFor() {
        let home = GymProfile(name: "Home", equipment: [.dumbbell, .flatBench], excluded: ["push-up"])
        #expect(home.allows(exercise("dumbbell-bench-press")))
        #expect(!home.allows(exercise("incline-dumbbell-bench-press")), "No incline bench")
        #expect(!home.allows(exercise("barbell-bench-press")), "No barbell or rack")
        #expect(!home.allows(exercise("pull-up")), "No pull-up bar")
        #expect(!home.allows(exercise("push-up")), "Excluded")
        #expect(GymProfile(name: "Full").allows(exercise("back-squat")))
    }

    @Test func aBarbellStepsByTheSmallestPlatePairFromTheUsualBar() {
        let squat = exercise("back-squat")
        let plain = GymProfile(name: "Plain", bars: [.kg(15), .kg(20)], plates: [PlateStock(.kg(20), pairs: 4), PlateStock(.kg(2.5), pairs: 2)])
        let steps = plain.increments(for: squat)
        #expect(steps.kilograms == 5 && steps.minimum == .kg(15) && steps.available == nil)
        let poundPlates = [PlateStock(.lb(45), pairs: 4), PlateStock(.lb(2.5), pairs: 2), PlateStock(.lb(1.25), pairs: 0)]
        let pounds = GymProfile(name: "Pounds", bars: [.lb(45)], plates: poundPlates)
        #expect(pounds.increments(for: squat).pounds == 5, "A plate with no pairs doesn't count")
        #expect(GymProfile(name: "Any").increments(for: exercise("dumbbell-bench-press")) == .defaults(for: exercise("dumbbell-bench-press")))
    }

    @Test func profilesAreCheckedAndEncodeTheirLoadsByEquipment() throws {
        var bad = GymProfile(name: " ", bars: [.kg(0)], plates: [PlateStock(.kg(5), pairs: 99)], loads: [.kettlebell: [.kg(-4)]])
        #expect(bad.problems == ["The gym needs a name up to 60 characters", "A bar must weigh more than 0 and up to 60 kg",
                                 "Plates must weigh more than 0 and up to 50 kg, with 0 to 50 pairs",
                                 "kettlebell weights must be more than 0 and up to 500 kg, at most 200 of them"])
        bad = GymProfile(name: "Fine", loads: [.dumbbell: dumbbells], createdAt: Fixture.instant())
        let json = String(bytes: try ExerlyJSON.canonical(bad), encoding: .utf8)
        #expect(json?.contains(#""loads":{"dumbbell":["#) == true)
        #expect(try ExerlyJSON.decoder.decode(GymProfile.self, from: ExerlyJSON.canonical(bad)) == bad)
    }
}

@MainActor
@Suite struct GymStoreTests {
    @Test func theChosenGymSyncsAndSetsTheSteps() async throws {
        let server = FakeDocumentServer()
        let phoneStore = InMemoryTrainingPersistence(), tabletStore = InMemoryTrainingPersistence()
        var clock = Fixture.instant()
        let phone = try GymStore(persistence: phoneStore, now: { clock })
        let tablet = try GymStore(persistence: tabletStore)
        let press = ExerciseLibrary.bundled.exercise("dumbbell-bench-press")!
        #expect(phone.active == nil && phone.increments(for: press) == .defaults(for: press))

        let home = GymProfile(name: "Home", equipment: [.dumbbell, .flatBench], loads: [.dumbbell: [.kg(10), .kg(12.5)]])
        let commercial = GymProfile(name: "Commercial")
        try phone.save(home)
        try phone.save(commercial)
        try phone.activate(home.id)
        clock = Fixture.instant(minutes: 1)
        try phone.activate(commercial.id)
        #expect(phone.active?.id == commercial.id)
        try phone.archive(commercial.id)
        #expect(phone.active?.id == home.id, "Archiving the gym in use goes back to the one before")
        #expect(phone.increments(for: press).available == [.kg(10), .kg(12.5)])
        #expect(throws: GymStore.StoreError.invalid(["The gym needs a name up to 60 characters"])) {
            try phone.save(GymProfile(name: ""))
        }

        try await SyncEngine(hosts: [phone], state: phoneStore, api: server).sync()
        try await SyncEngine(hosts: [tablet], state: tabletStore, api: server).sync()
        #expect(tablet.gyms == phone.gyms && tablet.active?.id == home.id)
        #expect(try GymStore(persistence: phoneStore).gyms.map(\.name) == ["Commercial", "Home"])
    }
}
