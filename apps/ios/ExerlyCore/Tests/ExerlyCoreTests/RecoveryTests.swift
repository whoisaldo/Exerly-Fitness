import Foundation
import Testing
@testable import ExerlyCore

@Suite struct RecoveryTests {
    let start = LocalDate("2026-01-01")!

    /// A synthetic person: AR(1) day-to-day noise around 55 ms HRV (15 %),
    /// 58 bpm resting (2.5 bpm) and 7.2 h of sleep (0.8 h), each value missing
    /// one day in ten, with a 5-day strain from `episode` when given.
    func person(_ random: inout TrainingSimulator.Random, episode: Int?, hrvDrop: Double = 1.5, rhrRise: Double = 1.5,
                sleepDrop: Double = 0.5) -> [RecoveryDay] {
        var h = 0.0, r = 0.0, s = 0.0
        var days: [RecoveryDay] = []
        for offset in 0..<120 {
            let n = { (random: inout TrainingSimulator.Random) in random.normal() * 2.0.squareRoot() }
            h = 0.5 * h + 0.75.squareRoot() * n(&random)
            r = 0.6 * r + 0.64.squareRoot() * n(&random)
            s = 0.2 * s + 0.96.squareRoot() * n(&random)
            let strained = episode.map { (($0)..<($0 + 5)).contains(offset) } ?? false
            days.append(RecoveryDay(date: start.adding(days: offset),
                                    sleepHours: random.chance(0.1) ? nil : 7.2 + 0.8 * (s - (strained ? sleepDrop : 0)),
                                    hrv: random.chance(0.1) ? nil : 55 * exp(0.15 * (h - (strained ? hrvDrop : 0))),
                                    restingHeartRate: random.chance(0.1) ? nil : 58 + 2.5 * (r + (strained ? rhrRise : 0))))
        }
        return days
    }

    @Test func aStrainShowsUpWithinTheEpisodeAndQuietDaysRarelyRaiseIt() {
        var random = TrainingSimulator.Random(state: 11)
        var falseDays = 0, quietDays = 0, detected = 0
        for _ in 0..<200 {
            let episode = 60 + random.int(0...20)
            let days = person(&random, episode: episode)
            var found = false
            for offset in 31..<120 {
                let strained = RecoveryStatus.assess(days, on: start.adding(days: offset)).state == .strained
                if offset < episode || offset >= episode + 5 + RecoveryStatus.window + 3 {
                    quietDays += 1
                    if strained { falseDays += 1 }
                }
                if (episode..<(episode + 5)).contains(offset), strained { found = true }
            }
            if found { detected += 1 }
        }
        // Measured (seed 11): 3.3 % of quiet days, and 83 % of 1.5 SD strains. See design 020.
        #expect(Double(falseDays) / Double(quietDays) < 0.05)
        #expect(Double(detected) / 200 > 0.75)
    }

    @Test func statusNeedsABaselineAndSaysWhatIsWorse() throws {
        var random = TrainingSimulator.Random(state: 3)
        let days = person(&random, episode: 40, hrvDrop: 3, rhrRise: 3, sleepDrop: 0)
        #expect(RecoveryStatus.assess(days, on: start.adding(days: 10)).state == .notEnoughData)
        let strained = RecoveryStatus.assess(days, on: start.adding(days: 43))
        #expect(strained.state == .strained && strained.readings.count == 3)
        let hrv = try #require(strained.readings.first { $0.signal == .hrv })
        #expect(hrv.adverse && hrv.score < -1 && hrv.recent < hrv.baseline)
        #expect(strained.summary.contains("HRV") && strained.summary.contains("resting heart rate"))
        // One signal alone is not enough, against a steady baseline.
        func steady(_ offset: Int) -> RecoveryDay {
            RecoveryDay(date: start.adding(days: offset), sleepHours: 7.2 + (offset % 2 == 0 ? 0.3 : -0.3),
                        hrv: 55 + (offset % 2 == 0 ? 3 : -3), restingHeartRate: 58 + (offset % 2 == 0 ? 1 : -1))
        }
        var calm = (0..<40).map(steady)
        for offset in 37..<40 { calm[offset].sleepHours = 4 }
        #expect(RecoveryStatus.assess(calm, on: start.adding(days: 39)).state == .normal)
        for offset in 37..<40 { calm[offset].hrv = 40 }
        let short = RecoveryStatus.assess(calm, on: start.adding(days: 39))
        #expect(short.state == .strained && short.summary == "sleep 4.0 h against a usual 7.2 h, HRV 40 ms against a usual 55 ms")
    }

    @Test func aLighterPlanKeepsTwoThirdsOfTheWorkAtOneMoreRepInReserve() {
        let set = PlannedSet(kind: .standard, effort: Effort(reps: 8, load: .kg(100)), rir: 2)
        let warmUp = PlannedSet(kind: .warmUp, effort: Effort(reps: 5, load: .kg(60)), rir: 5)
        let exercise = PlannedExercise(slotID: nil, exerciseID: "back-squat", notes: "", supersetID: nil,
                                       target: SlotTarget(sets: 4, minReps: 6, maxReps: 8, rir: 2),
                                       recommendation: Recommendation(sets: [warmUp] + Array(repeating: set, count: 4), reason: .progress,
                                                                      oneRepMax: nil, basisSetID: nil, outsideRange: false))
        let plan = WorkoutPlan(name: "Lower", program: nil, isDeload: false, exercises: [exercise]).lightened()
        let sets = plan.exercises[0].recommendation.sets
        #expect(sets.map(\.kind) == [.warmUp, .standard, .standard, .standard])
        #expect(sets.dropFirst().allSatisfy { $0.rir == 3 && $0.effort == set.effort } && sets[0].rir == 5)
        #expect(plan.exercises[0].target.sets == 3 && plan.exercises[0].target.rir == 3)
    }
}
