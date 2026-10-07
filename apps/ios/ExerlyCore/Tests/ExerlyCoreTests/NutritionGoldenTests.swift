import Foundation
import Testing
@testable import ExerlyCore

/// `EnergyBalance` on fixed synthetic logs, written to
/// docs/api/golden/nutrition-v1.json. The API's JavaScript port asserts the
/// same file (apps/api/tests/nutrition.golden.test.js), so the trend weight and
/// expenditure an agent reads are the ones the phone shows.
/// Regenerate with `EXERLY_WRITE_GOLDEN=1 swift test --filter NutritionGoldenTests`.
@Suite struct NutritionGoldenTests {
    static let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/api/golden/nutrition-v1.json")

    struct Prior: Encodable { var mean: Double; var error: Double }
    struct Day: Encodable { var date: String; var intake: Double?; var weights: [Double] }
    struct Estimate: Encodable {
        var date: String
        var trend, trendError, expenditure, expenditureError: Double
        var weight, intake: Double?
    }
    struct Case: Encodable { var name: String; var prior: Prior?; var days: [Day]; var estimates: [Estimate] }
    struct Golden: Encodable {
        var version = 1
        /// Every nutrient name and food source ExerlyCore decodes, for the API's validators.
        var nutrients = Nutrient.allCases.map(\.rawValue)
        var foodSources = FoodSource.allCases.map(\.rawValue)
        /// Each nutrient's unit, for exports that label their columns.
        var nutrientUnits = Dictionary(uniqueKeysWithValues: Nutrient.allCases.map { ($0.rawValue, $0.unit.rawValue) })
        var cases: [Case]
    }

    static func make() -> Golden {
        var cases: [Case] = []
        func add(_ name: String, _ days: [EnergyBalance.Day], prior: (mean: Double, error: Double)?) {
            let estimates = EnergyBalance.estimate(days, prior: prior).map {
                Estimate(date: $0.date.description, trend: $0.trend, trendError: $0.trendError, expenditure: $0.expenditure,
                         expenditureError: $0.expenditureError, weight: $0.weight, intake: $0.intake)
            }
            cases.append(Case(name: name, prior: prior.map { Prior(mean: $0.mean, error: $0.error) },
                              days: days.map { Day(date: $0.date.description, intake: $0.intake, weights: $0.weights) },
                              estimates: estimates))
        }
        var dieting = EnergyBalanceTests.Person(seed: 7)
        dieting.days = 70
        dieting.phases = [(14, 0), (56, -500)]
        add("Daily weigh-ins through a diet, with a prior", EnergyBalanceTests.simulate(dieting).days, prior: (2500, 400))

        var sparse = EnergyBalanceTests.Person(seed: 11)
        sparse.days = 56
        sparse.weighInChance = 0.25
        sparse.completeChance = 0.6
        sparse.phases = [(14, 0), (42, 400)]
        // Drop some days entirely, so the estimator fills calendar gaps.
        let gapped = EnergyBalanceTests.simulate(sparse).days.enumerated().filter { $0.offset % 9 != 4 }.map(\.element)
        add("Sparse weigh-ins, missed logs and gaps, no prior", gapped, prior: nil)

        let start = LocalDate("2026-03-02")!
        var doubled: [EnergyBalance.Day] = []
        for offset in 0..<21 {
            let drop = Double(offset) * 0.02
            let weights: [Double] = offset % 3 == 0 ? [80.4 - drop, 80.1 - drop] : []
            let intake: Double? = offset % 5 == 2 ? nil : 2200
            doubled.append(EnergyBalance.Day(date: start.adding(days: offset), intake: intake, weights: weights))
        }
        add("Two readings on some days", doubled, prior: (2300, 300))
        return Golden(cases: cases)
    }

    @Test func theGoldenFileMatchesTheSwiftEstimator() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let generated = try encoder.encode(Self.make())
        if ProcessInfo.processInfo.environment["EXERLY_WRITE_GOLDEN"] != nil {
            try (generated + Data("\n".utf8)).write(to: Self.url)
        }
        let saved = try JSONValue(data: Data(contentsOf: Self.url))
        #expect(saved == (try JSONValue(data: generated)), "Regenerate with EXERLY_WRITE_GOLDEN=1 after an intended change")
    }
}
