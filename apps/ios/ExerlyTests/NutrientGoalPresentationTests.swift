import XCTest
import ExerlyCore
@testable import Exerly

@MainActor
final class NutrientGoalPresentationTests: XCTestCase {
    func testADraftOpensOnThePresetItsGoalReadsAs() {
        XCTAssertEqual(NutrientGoalDraft(NutrientGoal(floor: 28)).kind, .atLeast)
        XCTAssertEqual(NutrientGoalDraft(NutrientGoal(target: 35)).kind, .about)
        XCTAssertEqual(NutrientGoalDraft(NutrientGoal(ceiling: 2300)).kind, .atMost)
        XCTAssertEqual(NutrientGoalDraft(NutrientGoal(floor: 25, target: 35)).kind, .range)
        XCTAssertEqual(NutrientGoalDraft(nil).kind, .atLeast)
        XCTAssertEqual(NutrientGoalDraft(NutrientGoal(ceiling: 0.9)).ceiling, "0.9")
    }

    func testSwitchingPresetsCarriesTheAmountAndKeepsARange() {
        var draft = NutrientGoalDraft(NutrientGoal(floor: 28))
        draft.choose(.about)
        XCTAssertEqual(draft.goal(.fiber).goal, NutrientGoal(target: 28))
        draft.choose(.atMost)
        XCTAssertEqual(draft.goal(.fiber).goal, NutrientGoal(ceiling: 28))
        draft.choose(.range)
        XCTAssertEqual(draft.goal(.fiber).goal, NutrientGoal(floor: 28, target: 28, ceiling: 28), "Each part kept what was typed")

        var range = NutrientGoalDraft(NutrientGoal(floor: 25, target: 35, ceiling: 70))
        range.choose(.atLeast)
        XCTAssertEqual(range.goal(.fiber).goal, NutrientGoal(floor: 25), "A preset uses only its own part")
        range.choose(.range)
        XCTAssertEqual(range.goal(.fiber).goal, NutrientGoal(floor: 25, target: 35, ceiling: 70))
    }

    func testAnOrderingProblemNamesBothAmountsAndGivesNoGoal() {
        var draft = NutrientGoalDraft(NutrientGoal(floor: 25, target: 35))
        draft.floor = "40"
        let typed = draft.goal(.fiber)
        XCTAssertNil(typed.goal)
        XCTAssertEqual(typed.problem, "The floor, 40 g, can't be above the target, 35 g.")
        draft.target = ""
        draft.ceiling = "2,000"
        XCTAssertEqual(draft.goal(.fiber).problem, "Enter amounts as numbers.")
        draft = NutrientGoalDraft(NutrientGoal(floor: 25))
        draft.floor = ""
        XCTAssertTrue(draft.goal(.fiber) == (nil, nil), "Nothing typed is no goal and no problem yet")
    }

    func testGoalsReadInThePresetsWords() {
        XCTAssertEqual(IntakeFormat.goalSummary(NutrientGoal(floor: 28), .fiber), "At least 28 g")
        XCTAssertEqual(IntakeFormat.goalSummary(NutrientGoal(floor: 25, target: 35), .fiber), "At least 25 g, about 35 g")
        XCTAssertEqual(IntakeFormat.goalSummary(NutrientGoal(ceiling: 2300), .sodium, spoken: true), "At most 2,300 milligrams")
    }

    func testAPinnedDaySaysWhatsLeftAndNeverReadsUnknownAsZero() {
        func day(_ amount: Double?, _ goal: NutrientGoal?, reporting: Int = 2, entries: Int = 2) -> NutrientDay {
            NutrientDay(nutrient: .sodium, amount: amount, goal: goal, entries: entries, reporting: reporting)
        }
        XCTAssertEqual(IntakeFormat.standing(day(1240, NutrientGoal(ceiling: 2300))), "1,060 mg left")
        XCTAssertEqual(IntakeFormat.standing(day(2540, NutrientGoal(ceiling: 2300))), "240 mg over")
        XCTAssertEqual(IntakeFormat.standing(day(400, NutrientGoal(floor: 1500))), "1,100 mg to go")
        XCTAssertEqual(IntakeFormat.standing(day(1600, NutrientGoal(floor: 1500))), "Goal met")
        XCTAssertEqual(IntakeFormat.standing(day(1600, NutrientGoal(floor: 1500, target: 2000))), "400 mg to target")
        XCTAssertEqual(IntakeFormat.standing(day(nil, NutrientGoal(ceiling: 2300), reporting: 0)), "At most 2,300 mg")
        XCTAssertEqual(IntakeFormat.standing(day(300, nil)), "No goal")
        XCTAssertEqual(IntakeFormat.completeness(reporting: 3, entries: 5), "From 3 of 5 foods")
        XCTAssertEqual(IntakeFormat.completeness(reporting: 3, entries: 5, spoken: true), "From 3 of 5 foods that report it")
        XCTAssertNil(IntakeFormat.completeness(reporting: 5, entries: 5), "Nothing to qualify")
        XCTAssertNil(IntakeFormat.completeness(reporting: 0, entries: 5), "Not reported says it already")
    }
}
