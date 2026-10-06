import Foundation
import Testing
@testable import ExerlyCore

/// Synthetic exports with the real Hevy and Strong headers.
@MainActor
@Suite struct WorkoutImportTests {
    let library = ExerciseLibrary.bundled

    static let hevy = #"""
    "title","start_time","end_time","description","exercise_title","superset_id","exercise_notes","set_index","set_type","weight_kg","reps","distance_km","duration_seconds","rpe"
    "Push day","5 Oct 2026, 18:00","5 Oct 2026, 19:05","Felt strong, ""finally""","Bench Press (Barbell)",,"Pause reps",0,"warmup",60,10,,,
    "Push day","5 Oct 2026, 18:00","5 Oct 2026, 19:05","Felt strong, ""finally""","Bench Press (Barbell)",,"",1,"normal",100,5,,,8
    "Push day","5 Oct 2026, 18:00","5 Oct 2026, 19:05","Felt strong, ""finally""","Bench Press (Barbell)",,"",2,"normal",100,5,,,8.5
    "Push day","5 Oct 2026, 18:00","5 Oct 2026, 19:05","Felt strong, ""finally""","Lateral Raise (Dumbbell)",0,"",0,"normal",10,15,,,
    "Push day","5 Oct 2026, 18:00","5 Oct 2026, 19:05","Felt strong, ""finally""","Triceps Pushdown (Cable)",0,"",0,"dropset",30,12,,,
    "Push day","5 Oct 2026, 18:00","5 Oct 2026, 19:05","Felt strong, ""finally""","Plank",,"",0,"normal",,,,60,
    "Push day","5 Oct 2026, 18:00","5 Oct 2026, 19:05","Felt strong, ""finally""","Synthetic Mystery Press",,"",0,"normal",50,10,,,
    "Pull day","7 Oct 2026, 07:30","7 Oct 2026, 08:20","","Pull Up",,"",0,"normal",,8,,,9
    "Pull day","7 Oct 2026, 07:30","7 Oct 2026, 08:20","","Pull Up (Assisted)",,"",0,"normal",20,8,,,
    "Pull day","7 Oct 2026, 07:30","7 Oct 2026, 08:20","","Lat Pulldown (Cable)",,"",0,"normal",,10,,,
    "Pull day","7 Oct 2026, 07:30","7 Oct 2026, 08:20","","Running",,"",0,"normal",,,5,1500,

    """#

    @Test func aHevyExportBecomesSessionsWithTheirSetsSupersetsAndNotes() throws {
        let result = try WorkoutImport.parse(Self.hevy, timeZone: Fixture.newYork, unit: .kilograms, library: library)
        #expect(result.source == .hevy && result.sessions.count == 2)
        let push = result.sessions[0]
        #expect(push.name == "Push day" && push.notes == #"Felt strong, "finally""#)
        #expect(push.startedAt == Date(timeIntervalSince1970: 1_791_237_600), "18:00 in New York")
        #expect(push.endedAt == push.startedAt.addingTimeInterval(65 * 60) && push.timeZoneID == "America/New_York")
        #expect(push.exercises.map(\.exerciseID) == ["barbell-bench-press", "dumbbell-lateral-raise", "triceps-pushdown", "plank"])
        let bench = push.exercises[0]
        #expect(bench.notes == "Pause reps" && bench.sets.map(\.kind) == [.warmUp, .standard, .standard])
        #expect(bench.sets[1].primary == Effort(reps: 5, load: .kg(100)) && bench.sets[1].rir == 2 && bench.sets[2].rir == 1.5)
        #expect(push.exercises[1].supersetID != nil && push.exercises[1].supersetID == push.exercises[2].supersetID)
        #expect(push.exercises[2].sets[0].kind == .drop && push.exercises[3].sets[0].primary.duration == 60)
        #expect(push.exercises.flatMap(\.sets).allSatisfy { $0.isCompleted && $0.completedAt! <= push.endedAt! })
        #expect(result.unmatched == ["Synthetic Mystery Press": 1])

        let pull = result.sessions[1]
        #expect(pull.exercises.map(\.exerciseID) == ["pull-up", "assisted-pull-up", "running"])
        #expect(pull.exercises[0].sets[0].primary == Effort(reps: 8) && pull.exercises[0].sets[0].rir == 1)
        #expect(pull.exercises[1].sets[0].primary.load == .kg(20), "Assistance")
        #expect(pull.exercises[2].sets[0].primary == Effort(duration: 1500, distance: 5000))
        #expect(result.skipped == ["Lat Pulldown (Cable) on 2026-10-07: a set without what Lat Pulldown records"])
        for session in result.sessions { try session.validate(library: library) }
    }

    @Test func importingTheSameFileTwiceAddsNothingAndAMappingFillsTheGap() throws {
        let training = try TrainingStore(persistence: InMemoryTrainingPersistence())
        let first = try WorkoutImport.parse(Self.hevy, timeZone: Fixture.newYork, unit: .kilograms, library: library)
        #expect(try training.importSessions(first.sessions) == 2)
        let again = try WorkoutImport.parse(Self.hevy, timeZone: Fixture.newYork, unit: .kilograms, library: library)
        #expect(again.sessions == first.sessions)
        #expect(try training.importSessions(again.sessions) == 0 && training.history.sessions.count == 2)
        let mapped = try WorkoutImport.parse(Self.hevy, timeZone: Fixture.newYork, unit: .kilograms, library: library,
                                             mapping: ["Synthetic Mystery Press": "machine-chest-press"])
        #expect(mapped.unmatched.isEmpty && mapped.matched["Synthetic Mystery Press"] == "machine-chest-press")
        #expect(mapped.sessions[0].exercises.last?.exerciseID == "machine-chest-press")
        #expect(training.history.sets(of: "barbell-bench-press").count == 2, "Two working sets, once")
    }

    @Test func bothStrongFormatsReadWithTheirUnitsOrSayWhatWasAssumed() throws {
        let newer = #"""
        "Workout #";"Date";"Workout Name";"Duration (sec)";"Exercise Name";"Set Order";"Weight (kg)";"Reps";"RPE";"Distance (meters)";"Seconds";"Notes";"Workout Notes"
        "1";"2026-10-01 12:00:00";"Legs";"3600";"Squat (Barbell)";"W";"60.0";"5";"";"";"";"";"Synthetic"
        "1";"2026-10-01 12:00:00";"Legs";"3600";"Squat (Barbell)";"1";"140.0";"5";"8";"";"";"Belt";"Synthetic"
        "1";"2026-10-01 12:00:00";"Legs";"3600";"Squat (Barbell)";"Rest Timer";"";"";"";"";"120";"";"Synthetic"
        "1";"2026-10-01 12:00:00";"Legs";"3600";"Leg Press";"1";"200";"10";"";"";"";"";"Synthetic"
        "2";"2026-10-03 07:00:00";"Cardio";"1800";"Running";"1";"";"";"";"5000";"1500";"";""
        """#
        let strong = try WorkoutImport.parse(newer, timeZone: Fixture.utc, unit: .pounds, library: library)
        #expect(strong.source == .strong && strong.assumptions.isEmpty && strong.unmatched.isEmpty)
        #expect(strong.sessions.map(\.name) == ["Legs", "Cardio"] && strong.sessions[0].notes == "Synthetic")
        let squat = strong.sessions[0].exercises[0]
        #expect(squat.exerciseID == "back-squat" && squat.notes == "" && squat.sets.map(\.kind) == [.warmUp, .standard])
        #expect(squat.sets[1].primary == Effort(reps: 5, load: .kg(140)), "The header's unit, not the person's")
        #expect(strong.sessions[0].endedAt == strong.sessions[0].startedAt.addingTimeInterval(3600))
        #expect(strong.sessions[1].exercises[0].sets[0].primary == Effort(duration: 1500, distance: 5000))

        let older = #"""
        Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE
        2026-09-20 18:00:00,Upper,1h 5m,Overhead Press (Barbell),1,95,8,,,,"Line one
        line two",
        2026-09-20 18:00:00,Upper,1h 5m,Running,1,,,3,1200,,,
        """#
        let old = try WorkoutImport.parse(older, timeZone: Fixture.utc, unit: .pounds, library: library)
        #expect(old.assumptions == ["Weights have no unit in this file, so they were read in lb.",
                                    "Distances have no unit in this file, so they were read in miles."])
        let upper = try #require(old.sessions.first)
        #expect(upper.notes == "Line one\nline two" && upper.endedAt == upper.startedAt.addingTimeInterval(65 * 60))
        #expect(upper.exercises[0].sets[0].primary == Effort(reps: 8, load: .lb(95)))
        #expect(close(upper.exercises[1].sets[0].primary.distance, 3 * 1609.344))
    }

    @Test func otherFilesAndNamesAreRefusedRatherThanGuessed() {
        #expect(throws: WorkoutImport.ImportError.unrecognized(["date", "weight"])) {
            try WorkoutImport.parse("date,weight\n2026-10-01,80\n", timeZone: Fixture.utc, unit: .kilograms, library: library)
        }
        #expect(WorkoutImport.match("Bench Press (Dumbbell)", library: library) == "dumbbell-bench-press")
        #expect(WorkoutImport.match("Leg Press (Machine)", library: library) == "leg-press")
        #expect(WorkoutImport.match("Leg Press (Barbell)", library: library) == nil, "Wrong equipment")
        #expect(WorkoutImport.match("Bench", library: library) == nil, "Not a whole name")
    }
}
