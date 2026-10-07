import Foundation
import Testing
@testable import ExerlyCore

@Suite struct ProgramGenerationTests {
    typealias Generation = ProgramGeneration
    let library = ExerciseLibrary.bundled
    let gyms: [GymProfile?] = [nil, GymProfile(name: "Home", equipment: [.dumbbell, .flatBench, .inclineBench, .pullUpBar]),
                               GymProfile(name: "Bodyweight", equipment: [.pullUpBar])]

    @Test func everyCombinationIsValidFitsTheGymAndTheSessionAndOwnsUpToItsGaps() throws {
        for gym in gyms {
            for days in 2...6 {
                for goal in Generation.Goal.allCases {
                    for level in Generation.Experience.allCases {
                        for minutes in [60, 90] {
                            let request = Generation.Request(daysPerWeek: days, goal: goal, experience: level, minutes: minutes)
                            let result = try Generation.generate(request, library: library, gym: gym)
                            let label = "\(gym?.name ?? "Full") \(days) \(goal) \(level) \(minutes)"
                            let program = result.program
                            #expect(program.validationErrors(library: library).isEmpty, "\(label)")
                            #expect(program.trainingDays.count == days, "\(label)")
                            #expect(program.deload == (level == .beginner ? .none : .last), "\(label)")
                            for day in program.days {
                                #expect(day.slots.reduce(0) { $0 + $1.target.sets } <= minutes / 3, "\(label) \(day.name)")
                                #expect((day.slots.first?.target.sets ?? 0) >= 3, "\(label) \(day.name) main lift")
                                #expect(day.slots.allSatisfy { slot in gym?.allows(library.exercise(slot.exerciseID)!) ?? true }, "\(label)")
                            }
                            let under = Set(result.targets.filter { (result.weeklySets[$0.key] ?? 0) < 0.8 * $0.value }.keys)
                            #expect(Set(result.shortfalls) == under, "\(label): every gap is reported")
                        }
                    }
                }
            }
        }
    }

    @Test func aFullGymWithEnoughTimeCoversEveryLargerMuscleTwiceAWeek() throws {
        for days in 4...6 {
            for goal in Generation.Goal.allCases {
                for level in Generation.Experience.allCases where !(goal == .hypertrophy && level == .advanced) {
                    let result = try Generation.generate(.init(daysPerWeek: days, goal: goal, experience: level, minutes: 90), library: library)
                    for muscle in Generation.larger {
                        let ratio = (result.weeklySets[muscle] ?? 0) / result.targets[muscle]!
                        #expect((0.8...1.5).contains(ratio), "\(days) \(goal) \(level) \(muscle): \(ratio)")
                        let trained = result.program.days.filter { day in
                            day.slots.contains { library.exercise($0.exerciseID)?.muscles[muscle] == 1 }
                        }
                        #expect(trained.count >= 2, "\(days) \(goal) \(level) \(muscle) is trained on \(trained.count) days")
                    }
                }
            }
        }
    }

    @Test func aProgramLooksLikeOneACoachWouldWrite() throws {
        let strength = try Generation.generate(.init(daysPerWeek: 4, goal: .strength, experience: .intermediate), library: library).program
        #expect(strength.name == "4-day Upper/Lower")
        #expect(strength.days.map(\.name) == ["Upper A", "Lower A", "Upper B", "Lower B"])
        #expect(strength.days[1].slots.first?.exerciseID == "back-squat" && strength.days[3].slots.first?.exerciseID == "deadlift")
        #expect(strength.days[1].slots.first?.target == SlotTarget(sets: strength.days[1].slots[0].target.sets, minReps: 3, maxReps: 5, rir: 2))
        // One hinge and one squat pattern a day, not three deadlifts.
        let hinges: Set<ExerciseID> = ["deadlift", "romanian-deadlift", "trap-bar-deadlift", "sumo-deadlift"]
        for day in strength.days { #expect(day.slots.filter { hinges.contains($0.exerciseID) }.count <= 1, "\(day.name)") }

        let home = try Generation.generate(.init(daysPerWeek: 3, goal: .general, experience: .beginner), library: library, gym: gyms[2])
        #expect(home.shortfalls.contains(.calves), "Nothing in a bodyweight gym with a pull-up bar trains calves")
        #expect(home.program.days.allSatisfy { $0.slots.count >= 3 }, "Missing equipment falls back to other patterns")
        #expect(!home.program.days.flatMap(\.slots).contains { ["pistol-squat", "handstand-push-up"].contains($0.exerciseID) },
                "No skilled moves for a beginner")
    }

    @Test func emphasisAndBadRequests() throws {
        let plain = Generation.targets(for: .init(daysPerWeek: 4, goal: .hypertrophy, experience: .intermediate))
        let emphasised = Generation.targets(for: .init(daysPerWeek: 4, goal: .hypertrophy, experience: .intermediate, emphasis: [.sideDelts]))
        #expect(plain[.sideDelts] == 14 && emphasised[.sideDelts] == 18 && plain[.frontDelts] == nil)
        #expect(throws: ProgramStore.StoreError.invalid(["Choose 2 to 6 training days a week", "Sessions must be 30 to 150 minutes"])) {
            _ = try Generation.generate(.init(daysPerWeek: 7, goal: .general, experience: .beginner, minutes: 10), library: library)
        }
    }

    @MainActor
    @Test func itArrivesAsAProposalThatAddsTheProgramWhenAccepted() throws {
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let programs = try ProgramStore(persistence: persistence, training: training)
        let agent = try AgentStore(persistence: persistence, hosts: [training, programs])
        let proposal = try Generation.proposal(for: .init(daysPerWeek: 3, goal: .hypertrophy, experience: .intermediate),
                                               library: library, now: Fixture.instant())
        #expect(proposal.title == "New program: 3-day Full body")
        #expect(proposal.summary.hasPrefix("3 training days a cycle for hypertrophy, 6 cycles, the last a deload. Under 80 % of the weekly target: "))
        #expect(proposal.summary.hasSuffix("More days or longer sessions would cover more."))
        #expect(proposal.changes.count == 1 && proposal.changes[0].before == nil)
        #expect(proposal.evidence.allSatisfy { $0.level == .humanRCT && $0.source != nil })
        try agent.file(proposal)
        try agent.accept(proposal.id)
        #expect(programs.programs.map(\.name) == ["3-day Full body"])
        try agent.undo(proposal.id)
        #expect(programs.programs.isEmpty)
    }
}
