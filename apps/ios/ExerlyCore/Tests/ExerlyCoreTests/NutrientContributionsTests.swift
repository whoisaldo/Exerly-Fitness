import Foundation
import Testing
@testable import ExerlyCore

@MainActor
@Suite struct NutrientContributionsTests {
    let monday = LocalDate("2026-10-05")!
    let oats = Food(name: "Oats", per100g: NutrientAmounts([.energy: 380, .protein: 13, .iron: 4.3]))
    let milk = Food(name: "Milk", per100g: NutrientAmounts([.energy: 60, .protein: 3.3, .iron: 0]))
    let bar = Food(name: "Protein bar", per100g: NutrientAmounts([.energy: 350, .protein: 30]))

    func store() throws -> NutritionStore {
        try NutritionStore(persistence: InMemoryTrainingPersistence(), now: { Fixture.instant() })
    }

    @Test func foodsAddUpOverTheCountedDaysOnly() throws {
        let nutrition = try store()
        try nutrition.log(oats, grams: 100, on: monday, meal: "Breakfast")
        try nutrition.log(milk, grams: 250, on: monday, meal: "Breakfast")
        try nutrition.log(bar, grams: 60, on: monday, meal: "Snacks")
        try nutrition.log(oats, grams: 50, on: monday.adding(days: 2), meal: "Breakfast")
        // A partial day stays out, as it does from the averages.
        try nutrition.log(oats, grams: 900, on: monday.adding(days: 1), meal: "Breakfast")
        try nutrition.setStatus(.partial, on: monday.adding(days: 1))
        try nutrition.setStatus(.fasting, on: monday.adding(days: 3))

        let iron = nutrition.contributions(of: .iron, from: monday, through: monday.adding(days: 6))
        #expect(iron.countedDays == 3 && iron.entries == 4)
        #expect(iron.unreported == 1, "The bar doesn't report iron")
        #expect(iron.foods.count == 1, "Milk reports zero iron, so it supplied none")
        let first = try #require(iron.foods.first)
        #expect(first.name == "Oats" && first.id == oats.id && first.entries == 2 && first.days == 2)
        #expect(close(first.amount, 6.45) && first.share == 1 && close(first.perDay, 6.45 / 3))
        #expect(close(iron.total, 6.45))

        let energy = nutrition.contributions(of: .energy, from: monday, through: monday.adding(days: 6))
        #expect(energy.foods.map(\.name) == ["Oats", "Protein bar", "Milk"])
        #expect(close(energy.total, 570 + 210 + 150))
        #expect(close(energy.foods.reduce(0) { $0 + $1.share }, 1))
        #expect(close(energy.foods[1].share, 210.0 / 930))
    }

    @Test func quickAddsGroupByNameAndFoodsKeepTheirLatestName() throws {
        let nutrition = try store()
        try nutrition.quickAdd(NutrientAmounts([.energy: 300]), name: "Coffee shop", on: monday, meal: "Snacks")
        try nutrition.quickAdd(NutrientAmounts([.energy: 200]), name: "Coffee shop", on: monday.adding(days: 1), meal: "Snacks")
        try nutrition.quickAdd(NutrientAmounts([.energy: 250]), name: "Party", on: monday.adding(days: 1), meal: "Dinner")
        var renamed = oats
        renamed.name = "Rolled oats"
        try nutrition.log(oats, grams: 100, on: monday, meal: "Breakfast")
        try nutrition.log(renamed, grams: 100, on: monday.adding(days: 1), meal: "Breakfast")
        let energy = nutrition.contributions(of: .energy, from: monday, through: monday.adding(days: 1))
        #expect(energy.foods.map(\.name) == ["Rolled oats", "Coffee shop", "Party"])
        #expect(energy.foods[0].amount == 760 && energy.foods[0].entries == 2)
        #expect(energy.foods[1].amount == 500 && energy.foods[1].days == 2)
        #expect(NutrientContributions.quickAddPrefix == NutritionStore.quickAddPrefix)
    }

    @Test func tiesRankByNameAndNothingCountedIsEmpty() {
        let a = FoodEntry(date: monday, meal: "Lunch", loggedAt: Fixture.instant(), food: bar.snapshot, grams: 100)
        let b = FoodEntry(date: monday, meal: "Lunch", loggedAt: Fixture.instant(),
                          food: Food(name: "Apple", per100g: NutrientAmounts([.energy: 350])).snapshot, grams: 100)
        let result = NutrientContributions.aggregate([a, b], of: .energy, countedDays: 1)
        #expect(result.foods.map(\.name) == ["Apple", "Protein bar"])
        let none = NutrientContributions.aggregate([], of: .energy, countedDays: 0)
        #expect(none.foods.isEmpty && none.total == 0 && none.unreported == 0)
    }

    @Test func timingSplitsTheDayIntoWindowsThatWrapPastMidnight() {
        var hours = (0..<24).map { IntakeTiming.Hour(hour: $0, energy: 0, entries: 0) }
        for (hour, energy) in [(2, 100.0), (8, 300), (13, 600), (19, 900), (23, 200)] {
            hours[hour].energy = energy
            hours[hour].entries = 1
        }
        let timing = IntakeTiming(hours: hours, untimedEntries: 2)
        #expect(timing.timedEnergy == 2100 && timing.timedEntries == 5)
        #expect(timing.shares[19] == 900.0 / 2100 && timing.shares[0] == 0)
        let windows = timing.windows()
        #expect(windows.map(\.start) == [5, 11, 16, 21] && windows.map(\.end) == [11, 16, 21, 5])
        #expect(windows.map(\.energy) == [300, 600, 900, 300], "Night runs from 21:00 to 05:00")
        #expect(close(windows.reduce(0) { $0 + $1.share }, 1))
        #expect(timing.peakHour == 19)
        #expect(timing.windows([0]).first?.energy == 2100)

        let empty = IntakeTiming(hours: (0..<24).map { IntakeTiming.Hour(hour: $0, energy: 0, entries: 0) }, untimedEntries: 0)
        #expect(empty.peakHour == nil && empty.shares.allSatisfy { $0 == 0 } && empty.windows().allSatisfy { $0.share == 0 })
    }
}
