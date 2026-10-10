import XCTest
import ExerlyCore
@testable import Exerly

@MainActor
final class NutritionInsightsPresentationTests: XCTestCase {
    func testAmountsKeepPrecisionThatMattersForTheirUnit() {
        XCTAssertEqual(IntakeFormat.amount(2_143.6, .energy), "2,144 kcal")
        XCTAssertEqual(IntakeFormat.amount(9.24, .energy), "9 kcal", "Calories are always whole")
        XCTAssertEqual(IntakeFormat.amount(152.4, .protein), "152 g")
        XCTAssertEqual(IntakeFormat.amount(9.24, .iron), "9.2 mg")
        XCTAssertEqual(IntakeFormat.amount(0.456, .thiamin), "0.46 mg")
        XCTAssertEqual(IntakeFormat.amount(480, .vitaminA), "480 mcg")
        XCTAssertEqual(IntakeFormat.spokenAmount(9.24, .iron), "9.2 milligrams")
    }

    func testDifferencesUseATrueMinusAndNeverASignedZero() {
        XCTAssertEqual(IntakeFormat.signed(-60.2, .energy), "−60 kcal")
        XCTAssertEqual(IntakeFormat.signed(110, .energy), "+110 kcal")
        XCTAssertEqual(IntakeFormat.signed(-0.3, .energy), "0 kcal")
        XCTAssertEqual(IntakeFormat.spokenSigned(-60, .energy), "60 kilocalories under")
        XCTAssertEqual(IntakeFormat.spokenSigned(0.2, .energy), "on target")
        XCTAssertEqual(IntakeFormat.percent(0.974), "97%")
    }

    func testSpansNameTheirYearsOnlyWhenTheyLeaveThisYear() throws {
        let today = try XCTUnwrap(LocalDate("2026-10-09"))
        let week = IntakeRange.week.span(today: today)
        XCTAssertEqual(IntakeFormat.span(week.lowerBound, week.upperBound, today: today), "Oct 2 – Oct 8")
        XCTAssertEqual(IntakeFormat.spokenSpan(week.lowerBound, week.upperBound, today: today), "Oct 2 to Oct 8")
        let year = IntakeRange.year.span(today: today)
        XCTAssertEqual(IntakeFormat.span(year.lowerBound, year.upperBound, today: today), "Oct 9, 2025 – Oct 8, 2026")
        let yesterday = IntakeRange.yesterday.span(today: today)
        XCTAssertEqual(IntakeFormat.span(yesterday.lowerBound, yesterday.upperBound, today: today), "Yesterday")
    }

    func testGoalsReadAsTheirParts() {
        XCTAssertEqual(IntakeFormat.goal(NutrientGoal(floor: 25, target: 35), .fiber), "Target 35 g · floor 25 g")
        XCTAssertEqual(IntakeFormat.goal(NutrientGoal(ceiling: 2300), .sodium), "Limit 2,300 mg")
        XCTAssertEqual(IntakeFormat.goal(NutrientGoal(target: 2150), .energy), "Target 2,150 kcal")
        XCTAssertEqual(IntakeFormat.spokenGoal(NutrientGoal(floor: 18), .iron), "at least 18 milligrams")
    }

    func testRangesHaveShortTitlesAndSpokenNames() {
        let today = LocalDate("2026-10-10")!
        XCTAssertEqual(IntakeRange.allCases.map { IntakeFormat.title($0, today: today) }, ["Yesterday", "1W", "Oct", "1M", "3M", "1Y"])
        XCTAssertEqual(IntakeFormat.spoken(.quarter), "3 months")
        XCTAssertEqual(IntakeFormat.spoken(.thisMonth), "This month")
        XCTAssertEqual(IntakeFormat.name(.energy), "Calories")
        XCTAssertEqual(IntakeFormat.name(.carbohydrate, short: true), "Carbs")
        XCTAssertEqual(IntakeFormat.group(.macros), IntakeFormat.group(.energy))
    }
}
