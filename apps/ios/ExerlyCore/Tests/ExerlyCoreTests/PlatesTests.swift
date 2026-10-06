import Foundation
import Testing
@testable import ExerlyCore

@Suite struct PlatesTests {
    let bar = Mass.kg(20)

    @Test func loadsTheBarWithMatchingPlatesHeaviestFirst() {
        let hundred = Plates.load(.kg(100), bar: bar, stock: PlateStock.standardKilograms)
        #expect(hundred.perSide == [.kg(25), .kg(15)] && hundred.total == .kg(100) && hundred.shortBy == .kg(0))
        #expect(Plates.load(.kg(102.5), bar: bar, stock: PlateStock.standardKilograms).perSide == [.kg(25), .kg(15), .kg(1.25)])
        let odd = Plates.load(.kg(101), bar: bar, stock: PlateStock.standardKilograms)
        #expect(odd.total == .kg(100) && odd.shortBy == .kg(1))
        #expect(Plates.load(.lb(225), bar: .lb(45), stock: PlateStock.standardPounds).perSide == [.lb(45), .lb(45)])
    }

    @Test func respectsLimitedPlatesAndTheEmptyBar() {
        let stock = [PlateStock(.kg(25), pairs: 1), PlateStock(.kg(20), pairs: 4), PlateStock(.kg(5), pairs: 2)]
        #expect(Plates.load(.kg(150), bar: bar, stock: stock).perSide == [.kg(25), .kg(20), .kg(20)])
        let light = Plates.load(.kg(15), bar: bar, stock: stock)
        #expect(light.perSide.isEmpty && light.total == .kg(20))
        // Kilogram plates on a pound bar are converted.
        let mixed = Plates.load(.lb(135), bar: .lb(45), stock: [PlateStock(.kg(20), pairs: 2)])
        #expect(mixed.perSide == [.kg(20)])
        #expect(close(mixed.total.value, 45 + 2 * 20 / 0.453_592_37, tolerance: 1e-9))
    }

    @Test func warmUpsRampToTheWorkingLoadOnLoadableWeights() throws {
        let squat = try #require(ExerciseLibrary.bundled.exercise("back-squat"))
        let sets = WarmUpScheme.standard.sets(for: .kg(140), exercise: squat, bar: bar, stock: PlateStock.standardKilograms)
        #expect(sets.map(\.primary.load) == [.kg(20), .kg(55), .kg(82.5), .kg(110)])
        #expect(sets.map(\.primary.reps) == [10, 5, 3, 2])
        #expect(sets.allSatisfy { $0.kind == .warmUp && !$0.isCompleted })

        let press = try #require(ExerciseLibrary.bundled.exercise("dumbbell-bench-press"))
        let dumbbells = WarmUpScheme.standard.sets(for: .kg(30), exercise: press, bar: nil, stock: [])
        #expect(dumbbells.map(\.primary.load) == [.kg(12), .kg(18), .kg(24)])

        #expect(WarmUpScheme.standard.sets(for: .kg(25), exercise: squat, bar: bar, stock: PlateStock.standardKilograms).isEmpty)
        let pullUp = try #require(ExerciseLibrary.bundled.exercise("pull-up"))
        #expect(WarmUpScheme.standard.sets(for: .kg(20), exercise: pullUp, bar: nil, stock: []).isEmpty)
        let heavy = WarmUpScheme.heavy.sets(for: .lb(405), exercise: squat, bar: .lb(45), stock: PlateStock.standardPounds)
        #expect(heavy.count == 6 && heavy.last!.primary.load!.value < 405)
        #expect(Set(heavy.compactMap(\.primary.load)).count == heavy.count, "No load repeats")
    }
}
