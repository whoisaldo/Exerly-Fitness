import Foundation
import Testing
@testable import ExerlyCore

@Suite struct EntryErrorDetectorTests {
    struct Score: CustomStringConvertible {
        var sessions = 0
        var injected: [EntryErrorDetector.Finding.Kind: Int] = [:]
        var found: [EntryErrorDetector.Finding.Kind: Int] = [:]
        /// Findings on clean sets, or with the wrong correction.
        var falseFindings = 0

        func recall(_ kind: EntryErrorDetector.Finding.Kind) -> Double {
            Double(found[kind] ?? 0) / Double(max(1, injected[kind] ?? 0))
        }
        var precision: Double {
            let right = found.values.reduce(0, +)
            return Double(right) / Double(max(1, right + falseFindings))
        }
        var falsePer100Sessions: Double { Double(falseFindings) * 100 / Double(max(1, sessions)) }
        var description: String {
            let kinds: [EntryErrorDetector.Finding.Kind] = [.loadDigit, .unitSwap, .repsDigit]
            return kinds.map { "\($0.rawValue) \(found[$0] ?? 0)/\(injected[$0] ?? 0)" }.joined(separator: ", ")
                + ", false \(falseFindings) in \(sessions) sessions, precision \(precision)"
        }
    }

    /// Runs the detector on every session of every lifter, in order, against
    /// the log as it stood (earlier mistakes left uncorrected).
    static func score(_ profiles: [TrainingSimulator.Profile]) -> Score {
        var score = Score()
        for profile in profiles {
            let result = TrainingSimulator.run(profile)
            let truth = Dictionary(uniqueKeysWithValues: result.injections.map { ($0.setID, $0) })
            for injection in result.injections { score.injected[injection.kind, default: 0] += 1 }
            for (index, session) in result.sessions.enumerated() {
                score.sessions += 1
                let history = TrainingHistory(sessions: Array(result.sessions[..<index]), library: .bundled)
                for finding in EntryErrorDetector.findings(in: session, history: history) {
                    if let injected = truth[finding.setID], injected.truth == finding.corrected {
                        score.found[injected.kind, default: 0] += 1
                    } else {
                        score.falseFindings += 1
                    }
                }
            }
        }
        return score
    }

    static func lifters(errorRate: Double, count: Int = 40) -> [TrainingSimulator.Profile] {
        let gains: [Double] = [0.002, 0.006, 0.012]
        let noises: [Double] = [0.015, 0.025, 0.04]
        return (0..<count).map { (index: Int) -> TrainingSimulator.Profile in
            var profile = TrainingSimulator.Profile(seed: UInt64(1000 + index))
            profile.unit = index % 3 == 0 ? .pounds : .kilograms
            profile.weeklyGain = gains[index % 3]
            profile.noise = noises[index % 3]
            profile.errorRate = errorRate
            profile.plateauFromWeek = index % 4 == 0 ? 8 : nil
            profile.fatigueWeeks = index % 5 == 0 ? 10...11 : nil
            return profile
        }
    }

    /// Lifters the detector was never tuned on: other seeds, beginners gaining
    /// 3 % a week, noisier days and more mistakes.
    static func holdout(errorRate: Double) -> [TrainingSimulator.Profile] {
        (0..<40).map { (index: Int) -> TrainingSimulator.Profile in
            var profile = TrainingSimulator.Profile(seed: UInt64(50_000 + index * 7))
            profile.unit = index % 2 == 0 ? .pounds : .kilograms
            profile.weeklyGain = index % 4 == 0 ? 0.03 : 0.004
            profile.noise = index % 3 == 0 ? 0.06 : 0.02
            profile.errorRate = errorRate
            profile.fatigueWeeks = index % 6 == 0 ? 5...6 : nil
            profile.bodyweight = 60 + Double(index % 5) * 10
            return profile
        }
    }

    /// The rates recorded in docs/design/005-training-detectors.md, with a
    /// little room for the simulator's randomness. A drop means a regression.
    @Test func meetsTheRecordedRatesOnSimulatedLifters() {
        let clean = Self.score(Self.lifters(errorRate: 0))
        let mistyped = Self.score(Self.lifters(errorRate: 0.03))
        let holdoutClean = Self.score(Self.holdout(errorRate: 0))
        let holdout = Self.score(Self.holdout(errorRate: 0.05))
        print("Entry check, clean logs: \(clean)")
        print("Entry check, 3 % mistyped: \(mistyped)")
        print("Entry check, holdout clean: \(holdoutClean)")
        print("Entry check, holdout 5 % mistyped: \(holdout)")
        #expect(clean.sessions == 1920 && holdoutClean.sessions == 1920)
        #expect(clean.falseFindings == 0 && holdoutClean.falseFindings <= 1)
        for score in [mistyped, holdout] {
            #expect(score.precision >= 0.98)
            #expect(score.recall(.loadDigit) >= 0.93)
            #expect(score.recall(.unitSwap) >= 0.80)
            #expect(score.recall(.repsDigit) >= 0.90)
        }
    }

    // MARK: Cases

    static let monday = Fixture.instant()

    /// Four earlier bench sessions around 100 kg, then `sets` in a new one.
    func history(_ sets: [PerformedSet], unit: MassUnit = .kilograms) -> (TrainingHistory, WorkoutSession) {
        func load(_ kilograms: Double) -> Mass {
            unit == .kilograms ? .kg(kilograms) : .lb((kilograms / 0.453_592_37 / 5).rounded() * 5)
        }
        func earlier(_ week: Int) -> WorkoutSession {
            let day = Double(week * 7)
            let top = load(97.5 + Double(week) * 2.5)
            let sets = [
                PerformedSet(efforts: [Effort(reps: 5, load: top)], rir: 2, completedAt: Fixture.instant(days: day)),
                PerformedSet(efforts: [Effort(reps: 5, load: top)], rir: 1, completedAt: Fixture.instant(days: day)),
                PerformedSet(efforts: [Effort(reps: 8, load: load(85))], rir: 2, completedAt: Fixture.instant(days: day)),
            ]
            return Fixture.session(days: day, [("barbell-bench-press", sets)])
        }
        var sessions = (0..<4).map(earlier)
        let today = Fixture.session(days: 28, [("barbell-bench-press", sets)])
        sessions.append(today)
        return (TrainingHistory(sessions: sessions, library: .bundled), today)
    }

    func set(_ reps: Int, _ load: Mass) -> PerformedSet {
        PerformedSet(efforts: [Effort(reps: reps, load: load)], rir: 2, completedAt: Fixture.instant(days: 28))
    }

    @Test func aStrayZeroBecomesAProposalThePhoneCanApply() throws {
        let (log, today) = history([set(5, .kg(105)), set(5, .kg(1050)), set(8, .kg(85))])
        let found = EntryErrorDetector.findings(in: today, history: log)
        #expect(found.map(\.kind) == [.loadDigit])
        #expect(found.first?.corrected.load == .kg(105))
        #expect(found.first?.confidence == .high)

        let proposal = try #require(try EntryErrorDetector.proposal(for: today, history: log, existing: [], now: Self.monday))
        #expect(proposal.title == "Did you mean 105 kg?")
        #expect(proposal.author == EntryErrorDetector.author)
        #expect(proposal.falsifier == "You really did 1050 kg for 5 reps.")
        #expect(proposal.evidence.first?.level == .personalData)
        #expect(try JSONValue.diff(proposal.changes[0].before, proposal.changes[0].after).map(\.path)
            == ["exercises[0].sets[1].efforts[0].load.value"])
        // Never twice for the same session, whatever the person decided.
        #expect(try EntryErrorDetector.proposal(for: today, history: log, existing: [proposal], now: Self.monday) == nil)
    }

    @Test func aRealRecordAndALightDayAreLeftAlone() {
        let (record, recordDay) = history([set(3, .kg(117.5)), set(3, .kg(117.5))])
        #expect(EntryErrorDetector.findings(in: recordDay, history: record).isEmpty)
        let (light, lightDay) = history([set(10, .kg(60)), set(10, .kg(60)), set(10, .kg(60))])
        #expect(EntryErrorDetector.findings(in: lightDay, history: light).isEmpty)
        let (pounds, poundsLight) = history([set(10, .lb(135)), set(10, .lb(135))], unit: .pounds)
        #expect(EntryErrorDetector.findings(in: poundsLight, history: pounds).isEmpty)
    }

    @Test func theWrongUnitIsProposedInTheUsualOne() {
        let (kilograms, today) = history([set(5, .kg(105)), set(5, .lb(105)), set(8, .kg(85))])
        let found = EntryErrorDetector.findings(in: today, history: kilograms)
        #expect(found.map(\.kind) == [.unitSwap])
        #expect(found.first?.corrected.load == .kg(105))
        let (poundsHistory, poundsDay) = history([set(5, .lb(230)), set(5, .kg(230))], unit: .pounds)
        #expect(EntryErrorDetector.findings(in: poundsDay, history: poundsHistory).first?.corrected.load == .lb(230))
    }

    @Test func aDoubledRepDigitIsProposedAsOneDigit() {
        let (log, today) = history([set(5, .kg(105)), set(55, .kg(105)), set(8, .kg(85))])
        let found = EntryErrorDetector.findings(in: today, history: log)
        #expect(found.map(\.kind) == [.repsDigit])
        #expect(found.first?.corrected.reps == 5)
    }

    @Test func aFirstSessionNeedsThreeConsistentSets() {
        let first = Fixture.session([("barbell-bench-press", [set(5, .kg(100)), set(5, .kg(1000))])])
        #expect(EntryErrorDetector.findings(in: first, history: TrainingHistory(sessions: [first], library: .bundled)).isEmpty)
        let three = Fixture.session([("barbell-bench-press", [set(5, .kg(100)), set(5, .kg(1000)), set(5, .kg(100))])])
        #expect(EntryErrorDetector.findings(in: three, history: TrainingHistory(sessions: [three], library: .bundled))
            .first?.confidence == .medium)
    }
}
