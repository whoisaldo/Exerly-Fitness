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
    var label: String { rawValue.capitalized }
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

// MARK: - Weight Rate Safety

enum WeightRateSafety: String {
    case safe, aggressive, dangerous

    var label: String {
        switch self {
        case .safe: return "Safe & Sustainable"
        case .aggressive: return "Aggressive"
        case .dangerous: return "Not Recommended"
        }
    }

    var color: String {
        switch self {
        case .safe: return "exSuccess"
        case .aggressive: return "exWarning"
        case .dangerous: return "exError"
        }
    }
}

// MARK: - Wizard Results

struct WizardResults {
    let bmr: Double
    let tdee: Double
    let calorieTarget: Int
    let proteinGrams: Int
    let fatGrams: Int
    let carbGrams: Int
    let bmi: Double
    let bodyFatEstimate: Double
    let healthyWeightRange: ClosedRange<Double>
    let weeklyPlan: [DayPlan]
    let sleepSchedule: SleepSchedule
}

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

struct SleepSchedule {
    let bedtime: String
    let wakeTime: String
    let durationHours: Double
}

// MARK: - WizardService

struct WizardService {

    // MARK: BMR — Mifflin-St Jeor

    static func calculateBMR(
        weightKg: Double, heightCm: Double,
        age: Int, gender: Gender
    ) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch gender {
        case .male: return base + 5
        case .female: return base - 161
        case .other: return base - 78
        }
    }

    // MARK: TDEE

    static func calculateTDEE(bmr: Double, activityLevel: ActivityLevel) -> Double {
        bmr * activityLevel.palMultiplier
    }

    // MARK: Calorie Target

    static func calculateCalorieTarget(
        tdee: Double, goal: FitnessGoal, bmr: Double
    ) -> Int {
        let raw: Double
        switch goal {
        case .loseWeight: raw = tdee - 500
        case .maintain, .generalHealth: raw = tdee
        case .gainMuscle: raw = tdee + 300
        case .improveEndurance: raw = tdee + 150
        }
        let floor = bmr * 1.1
        return Int(max(raw, floor))
    }

    // MARK: Macros — Protein-First (MacroFactor Method)

    static func calculateMacros(
        calorieTarget: Int, weightKg: Double,
        bodyFatPct: Double, goal: FitnessGoal
    ) -> (protein: Int, fat: Int, carbs: Int) {
        let leanMass = weightKg * (1 - bodyFatPct / 100)

        // Protein: 2.0–2.5g per kg lean mass
        let proteinMultiplier: Double = goal == .gainMuscle ? 2.5 : 2.0
        let proteinG = leanMass * proteinMultiplier

        // Fat: min 0.7g/kg, 25-35% of calories
        let fatMin = weightKg * 0.7
        let fatFromPct = Double(calorieTarget) * 0.30 / 9.0
        let fatG = max(fatMin, fatFromPct)

        // Carbs: remainder
        let usedCals = proteinG * 4 + fatG * 9
        let carbG = max(0, (Double(calorieTarget) - usedCals) / 4.0)

        return (Int(proteinG), Int(fatG), Int(carbG))
    }

    // MARK: BMI

    static func calculateBMI(weightKg: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100
        return weightKg / (heightM * heightM)
    }

    // MARK: Body Fat Estimate (Deurenberg)

    static func estimateBodyFat(
        bmi: Double, age: Int, gender: Gender
    ) -> Double {
        let sexFactor: Double = gender == .male ? 1 : 0
        return 1.20 * bmi + 0.23 * Double(age) - 10.8 * sexFactor - 5.4
    }

    // MARK: Healthy Weight Range

    static func healthyWeightRange(heightCm: Double) -> ClosedRange<Double> {
        let heightM = heightCm / 100
        let low = 18.5 * heightM * heightM
        let high = 24.9 * heightM * heightM
        return low...high
    }

    // MARK: Weight Rate Safety

    static func assessWeightRate(
        currentKg: Double, targetKg: Double, weeks: Int
    ) -> WeightRateSafety {
        guard weeks > 0 else { return .dangerous }
        let ratePerWeek = abs(currentKg - targetKg) / Double(weeks)
        if ratePerWeek <= 0.5 { return .safe }
        if ratePerWeek <= 1.0 { return .aggressive }
        return .dangerous
    }

    // MARK: Sleep Schedule

    static func calculateSleepSchedule(
        durationHours: Double, wakeHour: Int, wakeMinute: Int
    ) -> SleepSchedule {
        let totalWakeMinutes = wakeHour * 60 + wakeMinute
        let sleepMinutes = Int(durationHours * 60)
        var bedMinutes = totalWakeMinutes - sleepMinutes
        if bedMinutes < 0 { bedMinutes += 1440 }
        let bedH = bedMinutes / 60
        let bedM = bedMinutes % 60
        return SleepSchedule(
            bedtime: String(format: "%d:%02d %@", bedH > 12 ? bedH - 12 : bedH, bedM, bedH >= 12 ? "PM" : "AM"),
            wakeTime: String(format: "%d:%02d %@", wakeHour > 12 ? wakeHour - 12 : wakeHour, wakeMinute, wakeHour >= 12 ? "PM" : "AM"),
            durationHours: durationHours
        )
    }

    // MARK: Compute All Results

    static func computeResults(
        name: String, age: Int, gender: Gender,
        heightCm: Double, weightKg: Double,
        goal: FitnessGoal, targetWeightKg: Double?,
        activityLevel: ActivityLevel,
        activityTypes: Set<ActivityType>,
        equipment: Set<Equipment>,
        hasGymAccess: Bool,
        sleepHours: Double, wakeHour: Int, wakeMinute: Int,
        daysPerWeek: Int
    ) -> WizardResults {
        let bmr = calculateBMR(weightKg: weightKg, heightCm: heightCm, age: age, gender: gender)
        let tdee = calculateTDEE(bmr: bmr, activityLevel: activityLevel)
        let target = calculateCalorieTarget(tdee: tdee, goal: goal, bmr: bmr)
        let bmi = calculateBMI(weightKg: weightKg, heightCm: heightCm)
        let bf = estimateBodyFat(bmi: bmi, age: age, gender: gender)
        let macros = calculateMacros(calorieTarget: target, weightKg: weightKg, bodyFatPct: bf, goal: goal)
        let hwRange = healthyWeightRange(heightCm: heightCm)
        let sleep = calculateSleepSchedule(durationHours: sleepHours, wakeHour: wakeHour, wakeMinute: wakeMinute)
        let plan = ExerciseLibrary.generateWeeklyPlan(
            goal: goal, daysPerWeek: daysPerWeek,
            activityTypes: activityTypes, equipment: equipment,
            hasGymAccess: hasGymAccess
        )

        return WizardResults(
            bmr: bmr, tdee: tdee, calorieTarget: target,
            proteinGrams: macros.protein, fatGrams: macros.fat, carbGrams: macros.carbs,
            bmi: bmi, bodyFatEstimate: bf, healthyWeightRange: hwRange,
            weeklyPlan: plan, sleepSchedule: sleep
        )
    }

    // MARK: Unit Conversions

    static func lbsToKg(_ lbs: Double) -> Double { lbs * 0.453592 }
    static func kgToLbs(_ kg: Double) -> Double { kg / 0.453592 }
    static func ftInToCm(feet: Int, inches: Int) -> Double {
        Double(feet * 12 + inches) * 2.54
    }
    static func cmToFtIn(_ cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = cm / 2.54
        return (Int(totalInches) / 12, Int(totalInches) % 12)
    }
}
