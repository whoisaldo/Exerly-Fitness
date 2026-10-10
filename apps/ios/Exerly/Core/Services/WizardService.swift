import Foundation

// MARK: - Enums

enum Gender: String, CaseIterable, Identifiable, Codable {
    case male, female, other
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        case .other: return "figure.wave"
        }
    }
}

enum FitnessGoal: String, CaseIterable, Identifiable, Codable {
    case loseWeight = "lose_weight"
    case maintain
    case gainMuscle = "gain_muscle"
    case improveEndurance = "improve_endurance"
    case generalHealth = "general_health"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .loseWeight: return "Lose Weight"
        case .maintain: return "Maintain"
        case .gainMuscle: return "Gain Muscle"
        case .improveEndurance: return "Improve Endurance"
        case .generalHealth: return "General Health"
        }
    }

    var icon: String {
        switch self {
        case .loseWeight: return "flame.fill"
        case .maintain: return "equal.circle.fill"
        case .gainMuscle: return "dumbbell.fill"
        case .improveEndurance: return "figure.run"
        case .generalHealth: return "heart.fill"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary, light, moderate, active, veryActive = "very_active"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly Active"
        case .moderate: return "Moderately Active"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: return "Desk job, little exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .active: return "Hard exercise 6-7 days/week"
        case .veryActive: return "Athlete / physical job"
        }
    }

    var palMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
}

enum DietaryStyle: String, CaseIterable, Identifiable, Codable {
    case standard, vegetarian, vegan, keto, paleo, mediterranean

    var id: String { rawValue }
    var label: String { self == .standard ? "No special diet" : rawValue.capitalized }
}

enum Allergy: String, CaseIterable, Identifiable, Hashable, Codable {
    case gluten, dairy, nuts, soy, eggs, shellfish, fish

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum Equipment: String, CaseIterable, Identifiable, Hashable, Codable {
    case dumbbells, barbell, kettlebell, pullUpBar = "pull_up_bar"
    case resistanceBands = "resistance_bands", bench, cables, bodyweight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dumbbells: return "Dumbbells"
        case .barbell: return "Barbell"
        case .kettlebell: return "Kettlebell"
        case .pullUpBar: return "Pull-Up Bar"
        case .resistanceBands: return "Bands"
        case .bench: return "Bench"
        case .cables: return "Cables"
        case .bodyweight: return "Bodyweight"
        }
    }

    var icon: String {
        switch self {
        case .dumbbells: return "dumbbell.fill"
        case .barbell: return "figure.strengthtraining.traditional"
        case .kettlebell: return "figure.strengthtraining.functional"
        case .pullUpBar: return "figure.climbing"
        case .resistanceBands: return "figure.flexibility"
        case .bench: return "chair.fill"
        case .cables: return "cable.connector"
        case .bodyweight: return "figure.walk"
        }
    }
}

enum ActivityType: String, CaseIterable, Identifiable, Hashable, Codable {
    case running, walking, cycling, swimming, yoga
    case weightlifting, hiit, pilates, boxing, rowing
    case stretching, hiking, dancing, climbing

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.yoga"
        case .weightlifting: return "dumbbell.fill"
        case .hiit: return "flame.fill"
        case .pilates: return "figure.pilates"
        case .boxing: return "figure.boxing"
        case .rowing: return "figure.rowing"
        case .stretching: return "figure.flexibility"
        case .hiking: return "figure.hiking"
        case .dancing: return "figure.dance"
        case .climbing: return "figure.climbing"
        }
    }
}

// MARK: - Weekly plan

struct DayPlan: Identifiable {
    let id = UUID()
    let day: String
    let isRestDay: Bool
    let workoutType: String?
    let exercises: [PlannedExercise]
    let durationMinutes: Int
}

struct PlannedExercise: Identifiable {
    let id = UUID()
    let name: String
    let sets: Int
    let reps: String
    let muscleGroup: String
}
