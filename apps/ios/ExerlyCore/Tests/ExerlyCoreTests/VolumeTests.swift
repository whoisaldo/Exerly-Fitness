import Foundation
import Testing
@testable import ExerlyCore

@Suite struct VolumeTests {
    let library = Fixture.library
    func exercise(_ id: ExerciseID) -> Exercise { library.exercise(id)! }

    @Test func externalLoadIsTheEnteredLoadInKilograms() {
        let bench = exercise("barbell-bench-press")
        #expect(Volume.effectiveLoad(Effort(reps: 5, load: .kg(100)), exercise: bench, bodyweight: nil) == 100)
        #expect(Volume.effectiveLoad(Effort(reps: 5, load: .lb(225)), exercise: bench, bodyweight: nil) == 225 * 0.453_592_37)
        #expect(Volume.effectiveLoad(Effort(reps: 5), exercise: bench, bodyweight: nil) == nil)
    }

    @Test func bodyweightExercisesAddAShareOfBodyweight() throws {
        let pullUp = exercise("pull-up")
        let bodyweight = Mass.kg(80)
        #expect(close(Volume.effectiveLoad(Effort(reps: 8), exercise: pullUp, bodyweight: bodyweight), 76))
        #expect(close(Volume.effectiveLoad(Effort(reps: 5, load: .kg(20)), exercise: pullUp, bodyweight: bodyweight), 96))
        #expect(Volume.effectiveLoad(Effort(reps: 8), exercise: pullUp, bodyweight: nil) == nil)

        let assisted = exercise("assisted-pull-up")
        #expect(close(Volume.effectiveLoad(Effort(reps: 8, load: .kg(30)), exercise: assisted, bodyweight: bodyweight), 46))
        #expect(Volume.effectiveLoad(Effort(reps: 8, load: .kg(90)), exercise: assisted, bodyweight: bodyweight) == 0)
    }

    @Test func tonnageSeparatesResistanceAndBodyweight() {
        let pullUp = exercise("pull-up")
        let weighted = Fixture.set(5, 20)
        let tonnage = Volume.tonnage(weighted, exercise: pullUp, bodyweight: .kg(80))
        #expect(tonnage.resistance == 100)
        #expect(close(tonnage.bodyweight, 380))
        #expect(close(tonnage.total, 480))
        #expect(tonnage.isComplete)

        let unknown = Volume.tonnage(Fixture.set(5), exercise: pullUp, bodyweight: nil)
        #expect(unknown.total == 0)
        #expect(!unknown.isComplete)

        let assisted = Volume.tonnage(Fixture.set(10, 30), exercise: exercise("assisted-dip"), bodyweight: .kg(80))
        #expect(assisted.resistance == 0)
        #expect(close(assisted.bodyweight, 460))
    }

    @Test func dropSetTonnageSumsEveryEffort() {
        var drop = Fixture.set(8, 100, kind: .drop)
        drop.efforts.append(Effort(reps: 6, load: .kg(80)))
        drop.efforts.append(Effort(reps: 6, load: .kg(60)))
        let tonnage = Volume.tonnage(drop, exercise: exercise("barbell-bench-press"), bodyweight: nil)
        #expect(tonnage.resistance == 800 + 480 + 360)
    }

    @Test func timedAndCardioSetsHaveNoTonnage() {
        let plank = PerformedSet(efforts: [Effort(duration: 60)], completedAt: Fixture.instant())
        #expect(Volume.tonnage(plank, exercise: exercise("plank"), bodyweight: .kg(80)).total == 0)
        let carry = PerformedSet(efforts: [Effort(load: .kg(40), distance: 30)], completedAt: Fixture.instant())
        #expect(Volume.tonnage(carry, exercise: exercise("farmers-carry"), bodyweight: .kg(80)).total == 0)
    }

    @Test func setCreditIgnoresWarmUpsIncompleteSetsAndCardio() {
        let bench = exercise("barbell-bench-press")
        #expect(Volume.setCredit(Fixture.set(5, 100), exercise: bench) == 1)
        #expect(Volume.setCredit(Fixture.set(5, 60, kind: .warmUp), exercise: bench) == 0)
        #expect(Volume.setCredit(Fixture.set(5, 100, done: false), exercise: bench) == 0)
        #expect(Volume.setCredit(Fixture.set(5, 100, kind: .drop), exercise: bench) == 1)
        let run = PerformedSet(efforts: [Effort(duration: 1800, distance: 5000)], completedAt: Fixture.instant())
        #expect(Volume.setCredit(run, exercise: exercise("running")) == 0)
    }

    @Test func oneSideOfAUnilateralExerciseIsHalfASet() {
        let row = exercise("one-arm-dumbbell-row")
        #expect(Volume.setCredit(Fixture.set(10, 30, side: .left), exercise: row) == 0.5)
        #expect(Volume.setCredit(Fixture.set(10, 30), exercise: row) == 1)
    }

    @Test func muscleVolumeIsFractional() throws {
        let session = Fixture.session([
            ("barbell-bench-press", [Fixture.set(5, 60, kind: .warmUp), Fixture.set(5, 100), Fixture.set(5, 100)]),
            ("one-arm-dumbbell-row", [Fixture.set(10, 30, side: .left), Fixture.set(10, 30, side: .right)]),
        ])
        let volume = Volume.byMuscle([session], library: library)
        #expect(volume[.chest]?.sets == 2)
        #expect(volume[.chest]?.tonnage.resistance == 1000)
        #expect(volume[.triceps]?.sets == 1)
        #expect(volume[.triceps]?.tonnage.resistance == 500)
        #expect(volume[.lats]?.sets == 1)
        #expect(volume[.lats]?.tonnage.resistance == 600)
        #expect(volume[.biceps]?.sets == 0.5)
        #expect(volume[.quads] == nil)
    }

    @Test func weeklyVolumeBucketsByLocalDateAndWeekStart() throws {
        // Monday, Sunday and the following Monday.
        let sessions = [0.0, 6, 7].map { days in
            Fixture.session(days: days, [("leg-extension", [Fixture.set(10, 50)])])
        }
        let weeks = Volume.weeklyByMuscle(sessions, library: library, firstWeekday: .monday)
        let first = try #require(LocalDate("2026-10-05"))
        let second = try #require(LocalDate("2026-10-12"))
        #expect(weeks.keys.sorted() == [first, second])
        #expect(weeks[first]?[.quads]?.sets == 2)
        #expect(weeks[second]?[.quads]?.sets == 1)

        let sundayWeeks = Volume.weeklyByMuscle(sessions, library: library, firstWeekday: .sunday)
        #expect(sundayWeeks.keys.sorted().map(\.description) == ["2026-10-04", "2026-10-11"])
    }

    @Test func aLateSessionBelongsToItsOwnLocalDay() throws {
        // 18:00 UTC on Sunday 2026-10-11 + 5h = 23:00 UTC = 19:00 in New York, still Sunday.
        var session = Fixture.session(days: 6, zone: Fixture.newYork, [("leg-extension", [Fixture.set(10, 50)])])
        session.startedAt = Fixture.instant(days: 6, minutes: 300)
        #expect(session.localDate.description == "2026-10-11")
        let weeks = Volume.weeklyByMuscle([session], library: library, firstWeekday: .monday)
        #expect(weeks.keys.first?.description == "2026-10-05")
    }
}
