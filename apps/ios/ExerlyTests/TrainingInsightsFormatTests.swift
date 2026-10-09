import XCTest
import ExerlyCore
@testable import Exerly

/// Progress → Training writes every load in the account's unit and dates in
/// the account's zone.
@MainActor
final class TrainingInsightsFormatTests: XCTestCase {
    func testEstimatesAndChangesUseTheAccountsUnit() {
        XCTAssertEqual(InsightFormat.estimate(100, .pounds), "220 lb")
        XCTAssertEqual(InsightFormat.estimate(102.3, .kilograms), "102.5 kg")
        XCTAssertEqual(InsightFormat.spokenEstimate(100, .pounds), "220 pounds")
        XCTAssertEqual(InsightFormat.change(-1.2, .kilograms), "−1 kg")
        XCTAssertEqual(InsightFormat.change(-1.2, .pounds), "−3 lb")
        XCTAssertEqual(InsightFormat.change(0.1, .pounds), "±0 lb")
        XCTAssertEqual(InsightFormat.change(10, .pounds), "+22 lb")
        XCTAssertEqual(InsightFormat.spokenChange(-1.2, .pounds), "down 3 pounds")
        XCTAssertEqual(InsightFormat.rate(0.2, .pounds), "+0.4 lb")
        XCTAssertEqual(InsightFormat.amount(-0.2, .kilograms), "0.2 kg")
        XCTAssertEqual(InsightFormat.percent(-0.152), "−15%")
    }

    func testVolumeAndSetsAreCompact() {
        XCTAssertEqual(InsightFormat.volume(Mass.lb(52_300).kilograms, .pounds), "52.3K lb")
        XCTAssertEqual(InsightFormat.volume(Mass.lb(1_680).kilograms, .pounds), "1,680 lb")
        XCTAssertEqual(InsightFormat.spokenVolume(Mass.lb(52_300).kilograms, .pounds), "52,300 pounds")
        XCTAssertEqual(InsightFormat.sets(7.25), "7.2")
        XCTAssertEqual(InsightFormat.sets(7.96), "7.9", "Just under a range of 8 never reads as 8")
        XCTAssertEqual(InsightFormat.sets(12), "12")
        XCTAssertEqual(InsightFormat.sets(0.3 * 3 * 10), "9", "Floating error doesn't cut a whole number")
    }

    func testRecordsReadInTheAccountsUnit() throws {
        let records = try records(first: (5, .lb(220)), second: (8, .lb(220)))
        let reps = try XCTUnwrap(records.first { $0.kind == .repsAtLoad })
        XCTAssertEqual(InsightFormat.recordValue(reps, unit: .pounds).value, "8 × 220 lb")
        XCTAssertEqual(InsightFormat.recordValue(reps, unit: .pounds).detail, "was 5 reps")
        XCTAssertEqual(InsightFormat.recordValue(reps, unit: .kilograms).value, "8 × 99.8 kg")
        let heavier = try self.records(first: (5, .kg(115)), second: (5, .kg(120)))
        let heaviest = try XCTUnwrap(heavier.first { $0.kind == .heaviestLoad })
        XCTAssertEqual(InsightFormat.recordValue(heaviest, unit: .kilograms).value, "120 kg")
        XCTAssertTrue(InsightFormat.recordValue(heaviest, unit: .pounds).spoken.contains("265 pounds"))
    }

    /// Records the second of two synthetic squat sessions sets.
    private func records(first: (Int, Mass), second: (Int, Mass)) throws -> [PersonalRecord] {
        let start = Date(timeIntervalSince1970: 1_791_223_200)
        let sessions = [(first, 0.0), (second, 3.0)].map { set, days in
            let at = start.addingTimeInterval(days * 86_400)
            return WorkoutSession(name: "Synthetic", startedAt: at, endedAt: at.addingTimeInterval(1800), timeZone: .gmt,
                                  exercises: [PerformedExercise(exerciseID: "back-squat", sets: [
                                      PerformedSet(efforts: [Effort(reps: set.0, load: set.1)], rir: 1, completedAt: at.addingTimeInterval(60)),
                                  ])])
        }
        let history = TrainingHistory(sessions: sessions, library: .bundled)
        return history.records(in: try XCTUnwrap(history.sessions.last))
    }

    func testSetsShowTheirLoadRepsAndEffort() {
        let set = PerformedSet(efforts: [Effort(reps: 5, load: .lb(225))], rir: 1, completedAt: Date())
        XCTAssertEqual(InsightFormat.set(set, unit: .pounds), "225 lb × 5 · RIR 1")
        let failure = PerformedSet(kind: .failure, efforts: [Effort(reps: 8)], completedAt: Date())
        XCTAssertEqual(InsightFormat.set(failure, unit: .kilograms, bodyweight: true), "Bodyweight × 8 · RIR 0")
    }

    func testReportRunsThroughTheAccountsLocalDate() async throws {
        // 01:00 UTC on Oct 1 is still Sep 30 in Los Angeles.
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-01T01:00:00Z"))
        let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let start = now.addingTimeInterval(-3 * 86_400)
        let session = WorkoutSession(name: "Synthetic", startedAt: start, endedAt: start.addingTimeInterval(1800), timeZone: zone,
                                     exercises: [PerformedExercise(exerciseID: "barbell-bench-press",
                                                                   sets: [PerformedSet(efforts: [Effort(reps: 5, load: .kg(100))],
                                                                                       completedAt: start.addingTimeInterval(60))])])
        let model = TrainingInsightsModel()
        await model.refresh(history: TrainingHistory(sessions: [session], library: .bundled), span: .fourWeeks,
                            today: LocalDate(now, in: zone), firstWeekday: .sunday)
        let report = try XCTUnwrap(model.report)
        XCTAssertEqual(report.through, LocalDate("2026-09-30"))
        XCTAssertEqual(report.weeks.last?.start, LocalDate("2026-09-27"))
        XCTAssertEqual(report.sessions, 1)
        XCTAssertEqual(report.lifts.map(\.exerciseID), ["barbell-bench-press"])
    }
}
