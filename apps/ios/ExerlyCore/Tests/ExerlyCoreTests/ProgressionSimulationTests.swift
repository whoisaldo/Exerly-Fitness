import Foundation
import Testing
@testable import ExerlyCore

/// Simulated lifters who follow a program's recommendations. Their true
/// strength grows, varies from day to day and fades across sets; they do the
/// prescribed reps unless they fail first, and report RIR with error. Scored
/// against the truth (docs/design/006-programs-progression.md).
@MainActor
@Suite struct ProgressionSimulationTests {
    /// How loads are chosen: Exerly's progression, plain double progression
    /// (add load once every set reaches the top of the range, otherwise add a
    /// rep), or an oracle that knows today's true strength.
    enum Method { case exerly, doubleProgression, oracle }

    struct Profile {
        var seed: UInt64
        var method = Method.exerly
        var gain = 0.006
        var noise = 0.025
        var reportNoise = 0.7
        var unit: MassUnit = .kilograms
        var weeks = 16
    }

    struct Score: CustomStringConvertible {
        /// Actual minus target RIR on each exercise's first prescribed set, from the third session on.
        var errors: [Double] = []
        var outsideRange = 0
        var prescriptions = 0
        /// Recommended e1RM against the truth, as a fraction.
        var trackingErrors: [Double] = []

        var meanAbsolute: Double { errors.map(abs).reduce(0, +) / Double(max(1, errors.count)) }
        var bias: Double { errors.reduce(0, +) / Double(max(1, errors.count)) }
        func within(_ reps: Double) -> Double { Double(errors.filter { abs($0) <= reps }.count) / Double(max(1, errors.count)) }
        var tracking: Double { trackingErrors.map(abs).reduce(0, +) / Double(max(1, trackingErrors.count)) }
        var description: String {
            String(format: "RIR error mean |%.2f|, bias %+.2f, within 1 %.0f%%, within 1.5 %.0f%%; e1RM tracking %.1f%%; outside range %d/%d",
                   meanAbsolute, bias, within(1) * 100, within(1.5) * 100, tracking * 100, outsideRange, prescriptions)
        }
        mutating func add(_ other: Score) {
            errors += other.errors
            outsideRange += other.outsideRange
            prescriptions += other.prescriptions
            trackingErrors += other.trackingErrors
        }
    }

    static let program: Program = {
        func slot(_ id: ExerciseID, _ sets: Int, _ low: Int, _ high: Int) -> ProgramSlot {
            ProgramSlot(exerciseID: id, target: SlotTarget(sets: sets, minReps: low, maxReps: high, rir: 2))
        }
        return Program(name: "Simulated", days: [
            ProgramDay(name: "A", slots: [slot("back-squat", 3, 5, 7), slot("barbell-bench-press", 3, 6, 8)]),
            ProgramDay(name: "B", slots: [slot("deadlift", 2, 4, 6), slot("barbell-row", 3, 8, 10)]),
            ProgramDay(name: "C", slots: [slot("overhead-press", 3, 8, 10), slot("pull-up", 3, 6, 8)]),
        ], cycles: 20, createdAt: Fixture.instant())
    }()

    static func run(_ profile: Profile) -> Score {
        var random = TrainingSimulator.Random(state: profile.seed &* 7919 &+ 17)
        let bodyweight = 80.0
        let truth = Dictionary(uniqueKeysWithValues: TrainingSimulator.lifts.map { ($0.id, $0.oneRepMax) })
        var sessions: [WorkoutSession] = []
        var score = Score()
        var seen: [ExerciseID: Int] = [:]
        for index in 0..<(profile.weeks * 3) {
            let history = TrainingHistory(sessions: sessions, library: .bundled)
            guard let position = ProgramSchedule.next(for: program, in: history) else { break }
            let plan = ProgramSchedule.plan(program, at: position, history: history, bodyweight: .kg(bodyweight),
                                            increments: { exercise in
                                                var steps = LoadIncrements.defaults(for: exercise)
                                                if profile.unit == .pounds { steps.minimum = steps.minimum.map { _ in .lb(45) } }
                                                return steps
                                            })
            let week = Double(index / 3)
            let day = 1 + profile.noise * random.normal()
            let start = Fixture.instant(days: Double(index) * 7 / 3)
            var exercises: [PerformedExercise] = []
            for planned in plan.exercises {
                let exercise = ExerciseLibrary.bundled.exercise(planned.exerciseID)!
                let share = exercise.metric == .bodyweightReps ? bodyweight * exercise.bodyweightShare : 0
                let strength = truth[planned.exerciseID]! * (1 + profile.gain * week) * day
                var sets: [PerformedSet] = []
                let step = (profile.unit == .kilograms ? LoadIncrements.defaults(for: exercise).kilograms
                            : LoadIncrements.defaults(for: exercise).pounds)
                var baseline: (load: Mass?, reps: Int)?
                if profile.method == .oracle {
                    let ideal = OneRepMax.load(forReps: planned.target.targetReps.rounded(.down) + planned.target.rir, oneRepMax: strength) - share
                    let value = max(0, (ideal / profile.unit.kilogramsPerUnit / step).rounded(.down) * step)
                    let reps = Int((OneRepMax.repsToFailure(load: value * profile.unit.kilogramsPerUnit + share, oneRepMax: strength)
                        - planned.target.rir).rounded(.down))
                    baseline = (value > 0 ? Mass(value, profile.unit) : nil, min(max(reps, planned.target.minReps), planned.target.maxReps))
                } else if profile.method == .doubleProgression,
                          let last = sessions.last(where: { $0.exercises.contains { $0.exerciseID == planned.exerciseID } })?
                              .exercises.first(where: { $0.exerciseID == planned.exerciseID }) {
                    let top = last.sets[0].primary
                    if last.sets.allSatisfy({ ($0.primary.reps ?? 0) >= planned.target.maxReps }) {
                        baseline = (Mass((top.load?.value ?? 0) + step, top.load?.unit ?? profile.unit), planned.target.minReps)
                    } else {
                        baseline = (top.load, min(planned.target.maxReps, (top.reps ?? planned.target.minReps) + 1))
                    }
                }
                for (setIndex, prescribed) in planned.recommendation.sets.enumerated() {
                    let capacity = strength * (1 - 0.02 * Double(setIndex))
                    var load = baseline.map { $0.load } ?? prescribed.effort.load
                    if planned.recommendation.reason == .firstSession && profile.method != .oracle {
                        // A cautious first pick: a little under what the target needs.
                        let pick = OneRepMax.load(forReps: planned.target.targetReps + planned.target.rir + 1, oneRepMax: strength) - share
                        let step = profile.unit == .kilograms ? 2.5 : 5
                        let value = (pick / profile.unit.kilogramsPerUnit / step).rounded(.down) * step
                        load = value > 0 ? Mass(value, profile.unit) : nil
                    }
                    let effective = (load?.kilograms ?? 0) + share
                    let failure = OneRepMax.repsToFailure(load: effective, oneRepMax: capacity)
                    let planReps = baseline?.reps ?? prescribed.effort.reps ?? Int(planned.target.targetReps)
                    let done = max(1, min(planReps, Int(failure.rounded(.down))))
                    let actual = failure - Double(done)
                    let reported = min(6, max(0, (actual + profile.reportNoise * random.normal()).rounded()))
                    if setIndex == 0 && (seen[planned.exerciseID] ?? 0) >= 2 {
                        score.errors.append(failure - Double(planReps) - prescribed.rir)
                        score.prescriptions += 1
                        if planned.recommendation.outsideRange { score.outsideRange += 1 }
                        if let estimate = planned.recommendation.oneRepMax {
                            score.trackingErrors.append(estimate / strength - 1)
                        }
                    }
                    sets.append(PerformedSet(efforts: [Effort(reps: done, load: load)], rir: reported,
                                             completedAt: start.addingTimeInterval(Double(setIndex) * 180)))
                }
                seen[planned.exerciseID, default: 0] += 1
                exercises.append(PerformedExercise(exerciseID: planned.exerciseID, sets: sets))
            }
            sessions.append(WorkoutSession(name: plan.name, startedAt: start, endedAt: start.addingTimeInterval(3600),
                                           timeZone: Fixture.utc, bodyweight: .kg(bodyweight), exercises: exercises,
                                           program: plan.program))
        }
        return score
    }

    static func population(noise: Double, reportNoise: Double, method: Method = .exerly) -> Score {
        var total = Score()
        for seed in 0..<24 {
            var profile = Profile(seed: UInt64(seed))
            profile.method = method
            profile.noise = noise
            profile.reportNoise = reportNoise
            profile.gain = [0.002, 0.006, 0.012][seed % 3]
            profile.unit = seed % 4 == 0 ? .pounds : .kilograms
            total.add(run(profile))
        }
        return total
    }

    /// The rates recorded in docs/design/006-programs-progression.md, with room
    /// for the simulator's randomness. A drop means a regression.
    @Test func prescriptionsLandNearTheTargetReserve() {
        let bounds: [(noise: Double, report: Double, mean: Double, within: Double)] = [
            (0.015, 0.5, 0.75, 0.75), (0.025, 0.7, 0.95, 0.62), (0.04, 1.0, 1.3, 0.48),
        ]
        for bound in bounds {
            let score = Self.population(noise: bound.noise, reportNoise: bound.report)
            let baseline = Self.population(noise: bound.noise, reportNoise: bound.report, method: .doubleProgression)
            let oracle = Self.population(noise: bound.noise, reportNoise: bound.report, method: .oracle)
            print("Progression, day noise \(bound.noise), RIR report error \(bound.report): \(score)")
            print("  double progression: \(baseline)")
            print("  oracle: \(oracle)")
            #expect(score.errors.count > 1500)
            #expect(score.meanAbsolute <= bound.mean)
            #expect(score.within(1) >= bound.within)
            #expect(score.outsideRange == 0)
            #expect(score.meanAbsolute < baseline.meanAbsolute - 0.4, "Clearly better than double progression")
        }
    }
}
