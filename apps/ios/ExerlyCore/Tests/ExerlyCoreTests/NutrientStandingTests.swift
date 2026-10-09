import Foundation
import Testing
@testable import ExerlyCore

@MainActor
@Suite struct NutrientStandingTests {
    @Test func averagesStandAgainstFloorsTargetsAndLimits() {
        let fiber = NutrientGoal(floor: 25, target: 35)
        #expect(NutrientStanding(average: 20, reported: true, goal: fiber) == .short)
        #expect(NutrientStanding(average: 25, reported: true, goal: fiber) == .met)
        #expect(NutrientStanding(average: 60, reported: true, goal: fiber) == .met, "More than a floor's target is fine")
        let sodium = NutrientGoal(ceiling: 2300)
        #expect(NutrientStanding(average: 2301, reported: true, goal: sodium) == .over)
        #expect(NutrientStanding(average: 0.5, reported: true, goal: sodium) == .met)
        let energy = NutrientGoal(target: 2000)
        #expect(NutrientStanding(average: 1799, reported: true, goal: energy) == .short)
        #expect(NutrientStanding(average: 2200, reported: true, goal: energy) == .met)
        #expect(NutrientStanding(average: 2201, reported: true, goal: energy) == .over)
        #expect(NutrientStanding(average: 0, reported: false, goal: energy) == .unreported, "Unknown isn't short")
        #expect(NutrientStanding(average: 12, reported: true, goal: nil) == .noGoal)
    }

    @Test func aSpanCountsItsNutrientsByStanding() throws {
        let monday = LocalDate("2026-10-05")!
        let nutrition = try NutritionStore(persistence: InMemoryTrainingPersistence(), now: { Fixture.instant() })
        let plan = NutritionPlan(startDate: monday, createdAt: Fixture.instant(), goal: NutritionGoal(.maintain),
                                 targets: Array(repeating: DailyTargets(energy: 2000, protein: 150, fat: 70, carbohydrate: 250), count: 7))
        try nutrition.prepareWrite(kind: "nutrition_plan", id: plan.id.uuidString, payload: ExerlyJSON.canonical(plan))()
        // 2,000 kcal on target; 40 g protein short; 100 g fat over; sodium under its limit; sugars without a goal.
        let plate = Food(name: "Plate", per100g: NutrientAmounts([.energy: 2000, .protein: 40, .fat: 100, .carbohydrate: 250,
                                                                  .sodium: 900, .sugars: 30]))
        try nutrition.log(plate, grams: 100, on: monday, meal: "Lunch")
        let overview = nutrition.overview(from: monday, through: monday)
        let series = nutrition.intakeSeries(from: monday, through: monday)
        let byNutrient = Dictionary(uniqueKeysWithValues: overview.rows.map { ($0.nutrient, series.standing($0)) })
        #expect(byNutrient[.energy] == .met && byNutrient[.protein] == .short && byNutrient[.fat] == .over)
        #expect(byNutrient[.sodium] == .met && byNutrient[.sugars] == .noGoal && byNutrient[.iron] == .unreported)
        let counts = series.standings(overview)
        #expect(counts.values.reduce(0, +) == overview.rows.count)
        #expect(counts[.over] == 1 && counts[.noGoal] == 1)
    }
}
