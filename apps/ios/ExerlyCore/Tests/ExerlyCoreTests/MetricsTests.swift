import Foundation
import Testing
@testable import ExerlyCore

@MainActor
@Suite struct MetricsTests {
    let start = LocalDate("2026-09-01")!

    @Test func seriesIDsRoundTripAsText() throws {
        for text in ["nutrient:protein", "body:trend", "body:scale", "exercise:e1rm:back-squat", "tag:travel",
                     "metric:\(UUID().uuidString)"] {
            #expect(SeriesID(text)?.description == text)
        }
        #expect(SeriesID("nutrient:calories") == nil && SeriesID("tag:") == nil && SeriesID("body") == nil)
        let id = SeriesID(.oneRepMax("deadlift"))
        #expect(try ExerlyJSON.decoder.decode(SeriesID.self, from: ExerlyJSON.canonical(id)) == id)
    }

    @Test func metricValuesAreCheckedAndOnePerDayOnEveryDevice() throws {
        let persistence = InMemoryTrainingPersistence()
        let metrics = try MetricsStore(persistence: persistence)
        let sleep = CustomMetric(name: "Sleep quality", kind: .scale)
        try metrics.saveMetric(sleep)
        try metrics.setValue(4, for: sleep.id, on: start)
        try metrics.setValue(3, for: sleep.id, on: start)
        #expect(metrics.values(of: sleep.id) == [start: 3])
        #expect(throws: MetricsStore.StoreError.invalid(["Sleep quality takes a whole number from 1 to 5"])) {
            try metrics.setValue(6, for: sleep.id, on: start)
        }
        #expect(MetricEntry(metricID: sleep.id, date: start, value: 1).id == metrics.entries[0].id, "Same metric and day, same ID")
        try metrics.setValue(nil, for: sleep.id, on: start)
        #expect(metrics.entries.isEmpty)
        #expect(throws: MetricsStore.StoreError.self) {
            try metrics.saveExperiment(Experiment(name: "Overlap", change: "x", metric: SeriesID(.metric(sleep.id)),
                                                  baselineStart: start, baselineEnd: start.adding(days: 10),
                                                  interventionStart: start.adding(days: 5), interventionEnd: start.adding(days: 20)))
        }
        #expect(try MetricsStore(persistence: persistence).metrics == [sleep])
    }

    @Test func tagsAreCleanedAndMergeAsASet() throws {
        let nutrition = try NutritionStore(persistence: InMemoryTrainingPersistence())
        try nutrition.setTags([" Travel ", "creatine", "travel"], on: start)
        #expect(nutrition.day(start).tags == ["creatine", "travel"])
        let base = NutritionDay(date: start, tags: ["creatine", "travel"])
        let mine = NutritionDay(date: start, tags: ["creatine", "late caffeine"])
        let theirs = NutritionDay(date: start, tags: ["creatine", "travel", "sick"])
        let merged = try ExerlyJSON.decoder.decode(NutritionDay.self, from: nutrition.merge(
            kind: "nutrition_day", base: ExerlyJSON.canonical(base), local: ExerlyJSON.canonical(mine), remote: ExerlyJSON.canonical(theirs)))
        #expect(merged.tags == ["creatine", "late caffeine", "sick"], "My removal of travel and both additions survive")
    }

    @Test func seriesFollowTheDataRulesAndAnExperimentFindsARealChange() throws {
        let persistence = InMemoryTrainingPersistence()
        let nutrition = try NutritionStore(persistence: persistence, now: { Fixture.instant() })
        let metrics = try MetricsStore(persistence: persistence)
        let energy = Food(name: "Oats", per100g: NutrientAmounts([.energy: 400, .protein: 10]))
        let mood = CustomMetric(name: "Mood", kind: .number)
        try metrics.saveMetric(mood)
        var random = TrainingSimulator.Random(state: 3)
        for offset in 0..<28 {
            let date = start.adding(days: offset)
            try nutrition.log(energy, grams: 400 + Double(offset % 3) * 50, on: date, meal: "Lunch")
            try nutrition.setStatus(offset == 2 ? .partial : .complete, on: date)
            if offset >= 14 { try nutrition.setTags(["creatine"], on: date) }
            try metrics.setValue((offset >= 14 ? 6 : 5) + random.normal() * 0.3, for: mood.id, on: date)
        }
        try nutrition.setStatus(.fasting, on: start.adding(days: 30))
        let sources = SeriesSources(nutrition: nutrition, metrics: metrics)

        let protein = sources.values(.init(.nutrient(.protein)), from: start, through: start.adding(days: 30))
        #expect(protein[start] == 40 && protein[start.adding(days: 2)] == nil, "A partial day is missing")
        #expect(protein[start.adding(days: 30)] == 0 && protein[start.adding(days: 29)] == nil, "Fasting is a real zero")
        let tag = sources.values(.init(.tag("creatine")), from: start, through: start.adding(days: 30))
        #expect(tag[start] == 0 && tag[start.adding(days: 14)] == 1 && tag[start.adding(days: 29)] == nil)

        let experiment = Experiment(name: "Creatine and mood", change: "5 g creatine a day", metric: .init(.metric(mood.id)),
                                    baselineStart: start, baselineEnd: start.adding(days: 13),
                                    interventionStart: start.adding(days: 14), interventionEnd: start.adding(days: 27))
        let analysis = sources.analyze(experiment)
        #expect(analysis.comparison.verdict == .clearIncrease, "\(analysis.comparison)")
        #expect(abs(analysis.comparison.difference - 1) < 0.3)
        #expect(analysis.caveats.contains { $0.hasPrefix("\"creatine\" was on 0 % of baseline days and 100 %") })
    }
}
