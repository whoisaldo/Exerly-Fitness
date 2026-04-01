import Foundation

struct Exercise: Identifiable {
    let id = UUID()
    let name: String
    let muscleGroup: MuscleGroup
    let equipment: Set<Equipment>
    let isCompound: Bool
    let defaultSets: Int
    let defaultReps: String
    let caloriesPerMinute: Double
}

enum MuscleGroup: String, CaseIterable {
    case chest, back, shoulders, biceps, triceps
    case quads, hamstrings, glutes, calves, core, fullBody

    var label: String { rawValue.capitalized }
}

enum WorkoutSplit: String {
    case fullBody, upperLower, pushPullLegs, bro

    static func forDays(_ days: Int) -> WorkoutSplit {
        switch days {
        case 1...3: return .fullBody
        case 4: return .upperLower
        case 5...6: return .pushPullLegs
        default: return .fullBody
        }
    }
}

struct ExerciseLibrary {

    static let all: [Exercise] = [
        // Chest
        Exercise(name: "Barbell Bench Press", muscleGroup: .chest, equipment: [.barbell, .bench], isCompound: true, defaultSets: 4, defaultReps: "8-10", caloriesPerMinute: 7),
        Exercise(name: "Dumbbell Bench Press", muscleGroup: .chest, equipment: [.dumbbells, .bench], isCompound: true, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 6),
        Exercise(name: "Push-Ups", muscleGroup: .chest, equipment: [.bodyweight], isCompound: true, defaultSets: 3, defaultReps: "12-15", caloriesPerMinute: 5),
        Exercise(name: "Incline Dumbbell Press", muscleGroup: .chest, equipment: [.dumbbells, .bench], isCompound: true, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 6),
        Exercise(name: "Cable Flyes", muscleGroup: .chest, equipment: [.cables], isCompound: false, defaultSets: 3, defaultReps: "12-15", caloriesPerMinute: 4),

        // Back
        Exercise(name: "Pull-Ups", muscleGroup: .back, equipment: [.pullUpBar], isCompound: true, defaultSets: 4, defaultReps: "6-10", caloriesPerMinute: 8),
        Exercise(name: "Barbell Row", muscleGroup: .back, equipment: [.barbell], isCompound: true, defaultSets: 4, defaultReps: "8-10", caloriesPerMinute: 7),
        Exercise(name: "Dumbbell Row", muscleGroup: .back, equipment: [.dumbbells], isCompound: true, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 6),
        Exercise(name: "Lat Pulldown", muscleGroup: .back, equipment: [.cables], isCompound: true, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 5),
        Exercise(name: "Band Pull-Apart", muscleGroup: .back, equipment: [.resistanceBands], isCompound: false, defaultSets: 3, defaultReps: "15-20", caloriesPerMinute: 3),

        // Shoulders
        Exercise(name: "Overhead Press", muscleGroup: .shoulders, equipment: [.barbell], isCompound: true, defaultSets: 4, defaultReps: "8-10", caloriesPerMinute: 6),
        Exercise(name: "Dumbbell Shoulder Press", muscleGroup: .shoulders, equipment: [.dumbbells], isCompound: true, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 5),
        Exercise(name: "Lateral Raises", muscleGroup: .shoulders, equipment: [.dumbbells], isCompound: false, defaultSets: 3, defaultReps: "12-15", caloriesPerMinute: 3),
        Exercise(name: "Pike Push-Ups", muscleGroup: .shoulders, equipment: [.bodyweight], isCompound: true, defaultSets: 3, defaultReps: "8-12", caloriesPerMinute: 5),

        // Biceps
        Exercise(name: "Barbell Curl", muscleGroup: .biceps, equipment: [.barbell], isCompound: false, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 4),
        Exercise(name: "Dumbbell Curl", muscleGroup: .biceps, equipment: [.dumbbells], isCompound: false, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 4),
        Exercise(name: "Hammer Curl", muscleGroup: .biceps, equipment: [.dumbbells], isCompound: false, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 4),
        Exercise(name: "Band Curl", muscleGroup: .biceps, equipment: [.resistanceBands], isCompound: false, defaultSets: 3, defaultReps: "12-15", caloriesPerMinute: 3),

        // Triceps
        Exercise(name: "Tricep Dips", muscleGroup: .triceps, equipment: [.bodyweight], isCompound: true, defaultSets: 3, defaultReps: "8-12", caloriesPerMinute: 5),
        Exercise(name: "Skull Crushers", muscleGroup: .triceps, equipment: [.barbell, .bench], isCompound: false, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 4),
        Exercise(name: "Tricep Pushdown", muscleGroup: .triceps, equipment: [.cables], isCompound: false, defaultSets: 3, defaultReps: "12-15", caloriesPerMinute: 3),
        Exercise(name: "Diamond Push-Ups", muscleGroup: .triceps, equipment: [.bodyweight], isCompound: true, defaultSets: 3, defaultReps: "10-15", caloriesPerMinute: 5),

        // Quads
        Exercise(name: "Barbell Squat", muscleGroup: .quads, equipment: [.barbell], isCompound: true, defaultSets: 4, defaultReps: "8-10", caloriesPerMinute: 9),
        Exercise(name: "Goblet Squat", muscleGroup: .quads, equipment: [.dumbbells], isCompound: true, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 7),
        Exercise(name: "Bulgarian Split Squat", muscleGroup: .quads, equipment: [.dumbbells], isCompound: true, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 7),
        Exercise(name: "Bodyweight Squat", muscleGroup: .quads, equipment: [.bodyweight], isCompound: true, defaultSets: 3, defaultReps: "15-20", caloriesPerMinute: 6),
        Exercise(name: "Kettlebell Swing", muscleGroup: .quads, equipment: [.kettlebell], isCompound: true, defaultSets: 3, defaultReps: "15-20", caloriesPerMinute: 8),

        // Hamstrings
        Exercise(name: "Romanian Deadlift", muscleGroup: .hamstrings, equipment: [.barbell], isCompound: true, defaultSets: 4, defaultReps: "8-10", caloriesPerMinute: 8),
        Exercise(name: "Dumbbell RDL", muscleGroup: .hamstrings, equipment: [.dumbbells], isCompound: true, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 6),
        Exercise(name: "Glute Bridge", muscleGroup: .hamstrings, equipment: [.bodyweight], isCompound: true, defaultSets: 3, defaultReps: "12-15", caloriesPerMinute: 4),
        Exercise(name: "Band Leg Curl", muscleGroup: .hamstrings, equipment: [.resistanceBands], isCompound: false, defaultSets: 3, defaultReps: "12-15", caloriesPerMinute: 3),

        // Glutes
        Exercise(name: "Hip Thrust", muscleGroup: .glutes, equipment: [.barbell, .bench], isCompound: true, defaultSets: 4, defaultReps: "10-12", caloriesPerMinute: 7),
        Exercise(name: "Sumo Deadlift", muscleGroup: .glutes, equipment: [.barbell], isCompound: true, defaultSets: 4, defaultReps: "8-10", caloriesPerMinute: 9),
        Exercise(name: "Cable Kickback", muscleGroup: .glutes, equipment: [.cables], isCompound: false, defaultSets: 3, defaultReps: "12-15", caloriesPerMinute: 3),

        // Core
        Exercise(name: "Plank", muscleGroup: .core, equipment: [.bodyweight], isCompound: true, defaultSets: 3, defaultReps: "30-60s", caloriesPerMinute: 4),
        Exercise(name: "Hanging Leg Raise", muscleGroup: .core, equipment: [.pullUpBar], isCompound: true, defaultSets: 3, defaultReps: "10-15", caloriesPerMinute: 5),
        Exercise(name: "Russian Twist", muscleGroup: .core, equipment: [.bodyweight], isCompound: false, defaultSets: 3, defaultReps: "20", caloriesPerMinute: 4),
        Exercise(name: "Ab Rollout", muscleGroup: .core, equipment: [.bodyweight], isCompound: true, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 5),
        Exercise(name: "Dead Bug", muscleGroup: .core, equipment: [.bodyweight], isCompound: false, defaultSets: 3, defaultReps: "12-15", caloriesPerMinute: 3),
        Exercise(name: "Mountain Climbers", muscleGroup: .core, equipment: [.bodyweight], isCompound: true, defaultSets: 3, defaultReps: "20", caloriesPerMinute: 8),

        // Full Body
        Exercise(name: "Burpees", muscleGroup: .fullBody, equipment: [.bodyweight], isCompound: true, defaultSets: 3, defaultReps: "10-15", caloriesPerMinute: 10),
        Exercise(name: "Turkish Get-Up", muscleGroup: .fullBody, equipment: [.kettlebell], isCompound: true, defaultSets: 3, defaultReps: "5 each", caloriesPerMinute: 7),
        Exercise(name: "Clean and Press", muscleGroup: .fullBody, equipment: [.barbell], isCompound: true, defaultSets: 4, defaultReps: "6-8", caloriesPerMinute: 9),
        Exercise(name: "Thruster", muscleGroup: .fullBody, equipment: [.dumbbells], isCompound: true, defaultSets: 3, defaultReps: "10-12", caloriesPerMinute: 9),
    ]

    // MARK: - Plan Generation

    static func generateWeeklyPlan(
        goal: FitnessGoal, daysPerWeek: Int,
        activityTypes: Set<ActivityType>,
        equipment: Set<Equipment>,
        hasGymAccess: Bool
    ) -> [DayPlan] {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let split = WorkoutSplit.forDays(daysPerWeek)
        let available = availableEquipment(equipment, hasGymAccess: hasGymAccess)
        let filtered = all.filter { ex in
            ex.equipment.isEmpty || !ex.equipment.isDisjoint(with: available)
        }

        var plans: [DayPlan] = []
        let schedule = workoutDayIndices(daysPerWeek: daysPerWeek)

        for (i, dayName) in dayNames.enumerated() {
            guard let workoutIndex = schedule.firstIndex(of: i) else {
                plans.append(DayPlan(day: dayName, isRestDay: true, workoutType: nil, exercises: [], durationMinutes: 0))
                continue
            }

            let (type, groups) = muscleGroupsForDay(split: split, dayIndex: workoutIndex, daysPerWeek: daysPerWeek)
            let exercises = pickExercises(from: filtered, groups: groups, goal: goal)
            let duration = exercises.reduce(0) { $0 + $1.sets * 2 } + 10

            plans.append(DayPlan(
                day: dayName, isRestDay: false, workoutType: type,
                exercises: exercises, durationMinutes: duration
            ))
        }

        return plans
    }

    private static func availableEquipment(
        _ owned: Set<Equipment>, hasGymAccess: Bool
    ) -> Set<Equipment> {
        var result = owned
        result.insert(.bodyweight)
        if hasGymAccess {
            result.formUnion(Equipment.allCases)
        }
        return result
    }

    private static func workoutDayIndices(daysPerWeek: Int) -> [Int] {
        switch daysPerWeek {
        case 1: return [2]
        case 2: return [1, 4]
        case 3: return [0, 2, 4]
        case 4: return [0, 1, 3, 4]
        case 5: return [0, 1, 2, 3, 4]
        case 6: return [0, 1, 2, 3, 4, 5]
        default: return [0, 2, 4]
        }
    }

    private static func muscleGroupsForDay(
        split: WorkoutSplit, dayIndex: Int, daysPerWeek: Int
    ) -> (String, [MuscleGroup]) {
        switch split {
        case .fullBody:
            return ("Full Body", [.chest, .back, .quads, .shoulders, .core])
        case .upperLower:
            return dayIndex % 2 == 0
                ? ("Upper Body", [.chest, .back, .shoulders, .biceps, .triceps])
                : ("Lower Body", [.quads, .hamstrings, .glutes, .calves, .core])
        case .pushPullLegs:
            switch dayIndex % 3 {
            case 0: return ("Push", [.chest, .shoulders, .triceps])
            case 1: return ("Pull", [.back, .biceps, .core])
            default: return ("Legs", [.quads, .hamstrings, .glutes, .calves])
            }
        case .bro:
            let days: [(String, [MuscleGroup])] = [
                ("Chest", [.chest]), ("Back", [.back]),
                ("Shoulders", [.shoulders]), ("Legs", [.quads, .hamstrings, .glutes]),
                ("Arms", [.biceps, .triceps]),
            ]
            return days[dayIndex % days.count]
        }
    }

    private static func pickExercises(
        from pool: [Exercise], groups: [MuscleGroup], goal: FitnessGoal
    ) -> [PlannedExercise] {
        let exercisesPerGroup = goal == .gainMuscle ? 2 : 1
        var result: [PlannedExercise] = []

        for group in groups {
            let matching = pool.filter { $0.muscleGroup == group }
                .sorted { $0.isCompound && !$1.isCompound }
            let picked = Array(matching.prefix(exercisesPerGroup))
            for ex in picked {
                result.append(PlannedExercise(
                    name: ex.name, sets: ex.defaultSets,
                    reps: ex.defaultReps, muscleGroup: group.label
                ))
            }
        }

        return result
    }
}
