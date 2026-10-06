import Foundation
import Testing
@testable import ExerlyCore

@Suite struct ExerciseLibraryTests {
    let library = ExerciseLibrary.bundled

    @Test func bundledLibraryIsLargeAndValid() {
        #expect(library.exercises.count >= 100)
        for exercise in library.exercises {
            #expect(exercise.validationErrors.isEmpty, "\(exercise.id): \(exercise.validationErrors)")
        }
    }

    @Test func idsAreStableKebabCaseAndUnique() {
        let ids = library.exercises.map(\.id.rawValue)
        #expect(Set(ids).count == ids.count)
        for id in ids {
            #expect(id.range(of: "^[a-z0-9]+(-[a-z0-9]+)*$", options: .regularExpression) != nil, "\(id)")
            #expect(!ExerciseID(id).isCustom)
        }
    }

    @Test func namesAndAliasesNeverPointAtTwoExercises() {
        var owner: [String: ExerciseID] = [:]
        for exercise in library.exercises {
            for label in [exercise.name] + exercise.aliases {
                let key = ExerciseLibrary.normalize(label)
                if let existing = owner[key], existing != exercise.id {
                    Issue.record("\(label) names both \(existing) and \(exercise.id)")
                }
                owner[key] = exercise.id
            }
        }
    }

    @Test func everyMuscleIsTrainedByTheLibrary() {
        for muscle in Muscle.allCases {
            #expect(library.exercises.contains { $0.muscles[muscle] == 1 }, "\(muscle) has no target exercise")
        }
    }

    @Test func coversMetricsLateralityAndCardio() {
        for metric in TrackingMetric.allCases where metric != .weightDuration {
            #expect(library.exercises.contains { $0.metric == metric }, "\(metric)")
        }
        #expect(library.exercises.contains { $0.laterality == .unilateral })
        #expect(library.exercises.contains { $0.laterality == .alternating })
        #expect(library.exercises.contains { $0.category == .cardio })
    }

    @Test func looksUpById() throws {
        let bench = try #require(library.exercise("barbell-bench-press"))
        #expect(bench.name == "Barbell Bench Press")
        #expect(bench.targetMuscles == [.chest])
        #expect(bench.synergistMuscles == [.frontDelts, .triceps])
        #expect(library.exercise("no-such-exercise") == nil)
    }

    @Test func searchRanksExactThenPrefixThenWordMatches() {
        #expect(library.search("bench press").first?.id == "barbell-bench-press")
        #expect(library.search("Deadlift").first?.id == "deadlift")
        #expect(library.search("rdl").first?.id == "romanian-deadlift")
        #expect(library.search("ohp").first?.id == "overhead-press")
        #expect(library.search("pull").map(\.id).prefix(2).contains("pull-up"))
        #expect(library.search("xyzzy").isEmpty)
    }

    @Test func searchIgnoresCaseDiacriticsPunctuationAndExpandsAbbreviations() {
        #expect(library.search("PUSHUP").first?.id == "push-up")
        #expect(library.search("push up").first?.id == "push-up")
        #expect(library.search("farmers").first?.id == "farmers-carry")
        #expect(library.search("db row").first?.id == "one-arm-dumbbell-row")
        #expect(library.search("bb curl").first?.id == "barbell-curl")
        #expect(library.search("kb swing").first?.id == "kettlebell-swing")
        #expect(library.search("crunch").map(\.id).contains("cable-crunch"))
        #expect(library.search("Lâteral").first?.id == "dumbbell-lateral-raise")
    }

    @Test func emptySearchReturnsEverythingAlphabetically() {
        let all = library.search("")
        #expect(all.count == library.exercises.count)
        #expect(all.map(\.name) == all.map(\.name).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    @Test func filtersByMuscleAndAvailableEquipment() {
        let chest = library.search("", muscle: .chest)
        #expect(!chest.isEmpty && chest.allSatisfy { $0.muscles[.chest] == 1 })

        let homeGym: Set<Equipment> = [.bodyweight, .dumbbell, .flatBench, .pullUpBar]
        let home = library.search("", available: homeGym)
        #expect(home.contains { $0.id == "dumbbell-bench-press" })
        #expect(home.contains { $0.id == "pull-up" })
        #expect(home.contains { $0.id == "running" })
        #expect(!home.contains { $0.id == "barbell-bench-press" })
        #expect(!home.contains { $0.id == "incline-dumbbell-curl" })
    }

    @Test func customExercisesJoinTheLibraryAndMustBeValid() throws {
        let custom = Exercise(
            id: .custom(), name: "Meadows Row", metric: .weightReps, laterality: .unilateral,
            mechanics: .compound, region: .upper, muscles: [.lats: 1, .midBack: 1, .biceps: 0.5],
            equipment: [.barbell, .landmine]
        )
        let extended = try library.adding(custom)
        #expect(extended.exercise(custom.id) == custom)
        #expect(extended.search("meadows").first?.id == custom.id)

        var broken = custom
        broken.muscles = [:]
        #expect(throws: ExerciseLibrary.Error.self) { try library.adding(broken) }
        #expect(throws: ExerciseLibrary.Error.self) { try extended.adding(custom) }
    }

    @Test func roundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(library.exercises)
        let decoded = try JSONDecoder().decode([Exercise].self, from: data)
        #expect(decoded == library.exercises)
    }

    @Test func rejectsUnknownMusclesInJSON() {
        let json = #"{"id":"x","name":"X","metric":"weightReps","mechanics":"isolation","region":"upper","muscles":{"pecs":1},"equipment":["cable"]}"#
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Exercise.self, from: Data(json.utf8)) }
    }
}
