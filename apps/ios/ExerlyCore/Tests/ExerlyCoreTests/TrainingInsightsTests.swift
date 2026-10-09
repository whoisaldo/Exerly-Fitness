import Foundation
import Testing
@testable import ExerlyCore

@Suite struct TrainingInsightsTests {
    let library = Fixture.library
    /// Wednesday of the fixture week; weeks start on Monday 2026-10-05.
    let wednesday = LocalDate("2026-10-07")!

    func bench(_ kg: Double, sets: Int = 3, reps: Int = 5, rir: Double? = 0) -> (ExerciseID, [PerformedSet]) {
        ("barbell-bench-press", (0..<sets).map { _ in Fixture.set(reps, kg, rir: rir) })
    }

    // MARK: Spans and weeks

    @Test func spansAreWholeCalendarWeeksEndingThisWeek() {
        let first = LocalDate("2026-09-02")!
        #expect(TrainingInsights.Span.fourWeeks.start(through: wednesday, firstSession: first, firstWeekday: .monday) == LocalDate("2026-09-14"))
        #expect(TrainingInsights.Span.threeMonths.start(through: wednesday, firstSession: first, firstWeekday: .monday)
            == LocalDate("2026-10-05")!.adding(days: -84))
        #expect(TrainingInsights.Span.all.start(through: wednesday, firstSession: first, firstWeekday: .monday) == LocalDate("2026-08-31"))
        #expect(TrainingInsights.Span.all.start(through: wednesday, firstSession: nil, firstWeekday: .sunday) == LocalDate("2026-10-04"))
        #expect(TrainingInsights.Span.fourWeeks.start(through: wednesday, firstSession: first, firstWeekday: .sunday) == LocalDate("2026-09-13"))
    }

    @Test func weeksCountSessionsSetsAndTonnageIncludingEmptyWeeks() throws {
        let row: (ExerciseID, [PerformedSet]) = ("one-arm-dumbbell-row", [Fixture.set(10, 30, side: .left), Fixture.set(10, 30, side: .right)])
        let sessions = [
            Fixture.session(days: -21, [bench(100)]),
            Fixture.session(days: -7, [bench(100, sets: 1), row]),
            Fixture.session(days: -6, [("back-squat", [Fixture.set(5, 60, kind: .warmUp), Fixture.set(5, 120)])]),
            Fixture.session(days: 2, [bench(102.5)]),
        ]
        let history = TrainingHistory(sessions: sessions, library: library)
        let weeks = TrainingInsights.weeks(history, from: LocalDate("2026-09-01")!, through: wednesday)
        #expect(weeks.map(\.start.description) == ["2026-09-14", "2026-09-21", "2026-09-28", "2026-10-05"])
        #expect(weeks.map(\.sessions) == [1, 0, 2, 1])
        // A unilateral side counts half; warm-ups count nothing.
        #expect(weeks.map(\.sets) == [3, 0, 3, 3])
        #expect(close(weeks[2].tonnage.total, 500 + 600 + 600))
        #expect(weeks.map(\.isPartial) == [false, false, false, true])
        #expect(weeks[2].duration == 7200)
        // A span that starts later than the first session cuts it off.
        let later = TrainingInsights.weeks(history, from: LocalDate("2026-09-28")!, through: wednesday)
        #expect(later.map(\.sessions) == [2, 1])
        #expect(TrainingInsights.weeks(TrainingHistory(sessions: [], library: library), from: wednesday, through: wednesday).isEmpty)
    }

    @Test func weeksUseEachSessionsOwnLocalDate() {
        // 02:00 UTC Monday is Sunday evening in New York: the previous week.
        let monday = Fixture.instant(days: 0, minutes: -16 * 60)
        let session = WorkoutSession(name: "Late", startedAt: monday, endedAt: monday.addingTimeInterval(1800),
                                     timeZone: Fixture.newYork, exercises: [PerformedExercise(exerciseID: "barbell-bench-press",
                                                                                               sets: [Fixture.set(5, 100)])])
        let history = TrainingHistory(sessions: [session], library: library)
        let weeks = TrainingInsights.weeks(history, from: LocalDate("2026-09-28")!, through: wednesday)
        #expect(weeks.first?.start == LocalDate("2026-09-28"))
        #expect(weeks.first?.sessions == 1)
        #expect(weeks.last?.sessions == 0)
    }

    // MARK: Muscles

    @Test func rangesComeFromProgramGenerationsHypertrophyTargets() {
        #expect(TrainingInsights.weeklySetRange(for: .chest) == 10...18)
        #expect(TrainingInsights.weeklySetRange(for: .calves) == 6...10)
        #expect(TrainingInsights.weeklySetRange(for: .rearDelts) == 6...10)
        #expect(TrainingInsights.weeklySetRange(for: .frontDelts) == nil)
    }

    @Test func musclesAverageCompleteWeeksAndShowThisWeekSeparately() throws {
        let sessions = [
            Fixture.session(days: -14, [bench(100, sets: 4)]),
            Fixture.session(days: -7, [bench(100, sets: 6)]),
            Fixture.session(days: -5, [("triceps-pushdown", [Fixture.set(12, 30), Fixture.set(12, 30)])]),
            Fixture.session(days: 1, [bench(100, sets: 2)]),
        ]
        let history = TrainingHistory(sessions: sessions, library: library)
        let muscles = TrainingInsights.muscles(history, from: LocalDate("2026-09-14")!, through: wednesday)
        let chest = try #require(muscles.first { $0.muscle == .chest })
        #expect(chest.averageSets == 5)
        #expect(chest.thisWeek == 2)
        #expect(chest.range == 10...18)
        #expect(chest.status == .below)
        #expect(chest.contributors.map(\.exerciseID) == ["barbell-bench-press"])
        #expect(chest.contributors.first?.sets == 5)
        // Bench gives triceps half a set each; pushdowns a whole one.
        let triceps = try #require(muscles.first { $0.muscle == .triceps })
        #expect(triceps.averageSets == 3.5)
        #expect(triceps.contributors.map(\.exerciseID) == ["barbell-bench-press", "triceps-pushdown"])
        #expect(triceps.contributors.map(\.sets) == [2.5, 1])
        // Front delts have no range but were trained; neck was not and has none.
        #expect(muscles.first { $0.muscle == .frontDelts }?.status == .noRange)
        #expect(!muscles.contains { $0.muscle == .neck })
        #expect(muscles.first { $0.muscle == .calves }?.averageSets == 0)
        #expect(muscles.map(\.averageSets) == muscles.map(\.averageSets).sorted(by: >))
        // The span reaches back two weeks before the first session; those don't dilute the average.
        let wide = TrainingInsights.muscles(history, from: LocalDate("2026-08-03")!, through: wednesday)
        #expect(wide.first { $0.muscle == .chest }?.averageSets == 5)
    }

    @Test func aFirstWeekStandsInProvisionally() throws {
        let history = TrainingHistory(sessions: [Fixture.session(days: 1, [bench(100, sets: 12)])], library: library)
        let report = TrainingInsights.report(history, span: .fourWeeks, through: wednesday)
        #expect(report.completeWeeks == 0)
        #expect(report.isVolumeProvisional)
        let chest = try #require(report.muscles.first)
        #expect(chest.muscle == .chest)
        #expect(chest.averageSets == 12)
        #expect(chest.status == .within)
    }

    // MARK: Lifts

    @Test func liftsRankBySessionsAndFitTheirTrend() throws {
        let sessions = [
            Fixture.session(days: -14, [bench(100), ("back-squat", [Fixture.set(5, 140, rir: 0)])]),
            Fixture.session(days: -7, [bench(105)]),
            Fixture.session(days: 0, [bench(110, sets: 1), ("back-squat", [Fixture.set(5, 150, rir: 0)])]),
        ]
        let history = TrainingHistory(sessions: sessions, library: library)
        let lifts = TrainingInsights.lifts(history, from: LocalDate("2026-09-14")!, through: wednesday)
        #expect(lifts.map(\.exerciseID) == ["barbell-bench-press", "back-squat"])
        let pressed = try #require(lifts.first)
        #expect(pressed.sessions == 3)
        #expect(pressed.sets == 7)
        #expect(pressed.points.map(\.oneRepMax) == [100.0, 105, 110].map { $0 * 36 / 32 })
        #expect(pressed.best.oneRepMax == pressed.latest.oneRepMax)
        #expect(close(pressed.change, 10.0 * 36 / 32, tolerance: 1e-6))
        #expect(close(pressed.relativeChange, 10.0 / 105, tolerance: 1e-6))
        // Two sessions are too few for a trend.
        #expect(lifts[1].trend == nil)
        #expect(lifts[1].change == nil)
        #expect(close(lifts[1].latest.oneRepMax, 150 * 36 / 32))
    }

    @Test func liftSessionsAndBestSetsComeFromTheRange() throws {
        let sessions = [
            Fixture.session(days: -30, [bench(120)]),
            Fixture.session(days: -7, [("barbell-bench-press", [Fixture.set(8, 90, rir: 2), Fixture.set(3, 105, rir: 1)])]),
            Fixture.session(days: 0, [("barbell-bench-press", [Fixture.set(5, 100, rir: 1), Fixture.set(5, 100, rir: 1)])]),
        ]
        let history = TrainingHistory(sessions: sessions, library: library)
        let from = LocalDate("2026-09-21")!
        let rows = TrainingInsights.sessions(of: "barbell-bench-press", in: history, from: from, through: wednesday)
        #expect(rows.count == 2)
        #expect(rows[0].statistics.totalSets == 2)
        #expect(rows[0].statistics.heaviestLoad == .kg(105))
        // 90 x 8 at RIR 2 (10 to failure, 120) beats 105 x 3 at RIR 1 (4 to failure, about 114.5).
        #expect(rows[0].bestSet?.primary.load == .kg(90))
        #expect(close(rows[0].bestSetOneRepMax, 120))
        // 100 x 5 at RIR 1 (6 to failure, about 116.1) ranks above the heavier triple.
        let best = TrainingInsights.bestSets(of: "barbell-bench-press", in: history, from: from, through: wednesday, limit: 4)
        #expect(best.map(\.record.set.primary.load) == [.kg(90), .kg(100), .kg(100), .kg(105)])
        // Equal sets: the earlier one ranks first.
        let ties = TrainingInsights.bestSets(of: "barbell-bench-press", in: history, from: LocalDate("2026-10-05")!, through: wednesday)
        #expect(ties.count == 2)
        #expect(ties[0].record.set.id == sessions[2].exercises[0].sets[0].id)
    }

    // MARK: Records

    @Test func recordsInTheRangeAreDatedAndNewestFirst() throws {
        let sessions = [
            Fixture.session(days: -21, [bench(100)]),
            Fixture.session(days: -14, [bench(105)]),
            Fixture.session(days: 0, [bench(110)]),
        ]
        let history = TrainingHistory(sessions: sessions, library: library)
        let records = TrainingInsights.records(history, from: LocalDate("2026-09-21")!, through: wednesday)
        #expect(Set(records.map(\.date)) == [LocalDate("2026-09-21")!, LocalDate("2026-10-05")!])
        #expect(records.first?.date == LocalDate("2026-10-05"))
        #expect(records.allSatisfy { $0.sessionName == "Session" })
        let e1rm = records.filter { $0.record.kind == .oneRepMax }
        #expect(e1rm.map(\.record.value) == [110.0 * 36 / 32, 105.0 * 36 / 32])
        #expect(e1rm.first?.record.previous == 105.0 * 36 / 32)
        // The first session of an exercise sets no record, even inside the range.
        #expect(TrainingInsights.records(history, from: LocalDate("2026-09-14")!, through: LocalDate("2026-09-20")!).isEmpty)
    }

    // MARK: Signals

    @Test func stallSignalCarriesTheTrendInKilograms() throws {
        let sessions = (0..<6).map { index in Fixture.session(days: Double(-index * 5), [bench(100, sets: 1, rir: nil)]) }
        let history = TrainingHistory(sessions: sessions, library: library)
        let signals = TrainingInsights.signals(history, through: wednesday)
        let stall = try #require(signals.first)
        #expect(signals.count == 1)
        #expect(stall.diagnosis.kind == .stall)
        let lift = try #require(stall.lifts.first)
        #expect(lift.exerciseID == "barbell-bench-press")
        #expect(lift.points.count == 6)
        #expect(close(lift.trend?.meanOneRepMax, 100 * 36 / 32))
        #expect(close(lift.trend?.slopePerWeek, 0, tolerance: 1e-9))
        #expect(stall.caveats.contains { $0.contains("RIR not recorded") })
        #expect(Set(stall.caveats).count == stall.caveats.count)
        #expect(stall.caveats.allSatisfy { !$0.contains(" kg") })
    }

    @Test func deloadSignalComparesRecentAndBaselineMeans() throws {
        let sessions = [30, 24, 18, 13, 6, 2].map { days in
            Fixture.session(days: Double(2 - days), [("deadlift", [Fixture.set(5, days < 10 ? 170 : 200, rir: 0)]),
                                                     bench(days < 10 ? 85 : 100, sets: 1)])
        }
        let history = TrainingHistory(sessions: sessions, library: library)
        let signals = TrainingInsights.signals(history, through: wednesday)
        let deload = try #require(signals.first)
        #expect(deload.diagnosis.kind == .deload)
        #expect(Set(deload.lifts.map(\.exerciseID)) == ["deadlift", "barbell-bench-press"])
        let pressed = try #require(deload.lifts.first { $0.exerciseID == "barbell-bench-press" })
        #expect(close(pressed.baseline, 100.0 * 36 / 32))
        #expect(close(pressed.recent, 85.0 * 36 / 32))
        #expect(close(pressed.recentChange, -0.15, tolerance: 1e-9))
        #expect(pressed.points.count == 6)
    }

    // MARK: Report

    @Test func reportPutsTheSpanTogether() throws {
        let sessions = [
            Fixture.session(days: -14, [bench(100)]),
            Fixture.session(days: -7, [bench(105)]),
            Fixture.session(days: 0, [bench(110)]),
        ]
        let history = TrainingHistory(sessions: sessions, library: library)
        let report = TrainingInsights.report(history, span: .threeMonths, through: wednesday)
        #expect(report.from == LocalDate("2026-07-13"))
        #expect(report.firstSession == LocalDate("2026-09-21"))
        #expect(report.weeks.count == 3)
        #expect(report.completeWeeks == 2)
        #expect(!report.isVolumeProvisional)
        #expect(report.sessions == 3)
        #expect(report.sets == 9)
        #expect(close(report.tonnage.total, 1500 + 1575 + 1650))
        #expect(report.lifts.map(\.exerciseID) == ["barbell-bench-press"])
        #expect(report.records.count >= 2)
        #expect(report.signals.isEmpty)
        let empty = TrainingInsights.report(TrainingHistory(sessions: [], library: library), span: .all, through: wednesday)
        #expect(empty.weeks.isEmpty && empty.muscles.isEmpty && empty.lifts.isEmpty && empty.sessions == 0)
    }
}
