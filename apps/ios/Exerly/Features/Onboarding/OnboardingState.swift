import Foundation
import SwiftUI

@MainActor
final class OnboardingState: ObservableObject {
    @Published var step = 0
    @Published var direction: Edge = .trailing

    // Step 1: Name
    @Published var name = ""

    // Step 2: Age & Gender
    @Published var age = 25
    @Published var gender: Gender = .male

    // Step 3: Height/Weight
    @Published var useMetric = true
    @Published var heightCm: Double = 170
    @Published var weightKg: Double = 70
    @Published var heightFeet = 5
    @Published var heightInches = 7
    @Published var weightLbs: Double = 154

    // Step 4: Goal
    @Published var goal: FitnessGoal = .maintain
    @Published var targetWeightKg: Double = 70
    @Published var timelineWeeks = 12

    // Step 5: Activity Level
    @Published var activityLevel: ActivityLevel = .moderate

    // Step 6: Activity Types
    @Published var activityTypes: Set<ActivityType> = []

    // Step 7: Diet
    @Published var dietaryStyle: DietaryStyle = .standard
    @Published var allergies: Set<Allergy> = []
    @Published var mealsPerDay = 3

    // Step 8: Sleep
    @Published var sleepHours: Double = 8
    @Published var wakeHour = 7
    @Published var wakeMinute = 0

    // Step 9: Equipment
    @Published var equipment: Set<Equipment> = [.bodyweight]
    @Published var hasGymAccess = false

    // Step 10: Results
    @Published var results: WizardResults?

    // Step 11: Notifications
    @Published var notifyWorkouts = true
    @Published var notifyMeals = true
    @Published var notifySleep = true
    @Published var showConfetti = false

    var totalSteps: Int { 12 } // 0-11

    var heightDisplay: Double {
        useMetric ? heightCm : WizardService.ftInToCm(feet: heightFeet, inches: heightInches)
    }

    var weightDisplay: Double {
        useMetric ? weightKg : WizardService.lbsToKg(weightLbs)
    }

    var bmiPreview: Double {
        WizardService.calculateBMI(weightKg: weightDisplay, heightCm: heightDisplay)
    }

    var weightRateSafety: WeightRateSafety {
        WizardService.assessWeightRate(
            currentKg: weightDisplay,
            targetKg: targetWeightKg,
            weeks: timelineWeeks
        )
    }

    func nextStep() {
        guard step < totalSteps - 1 else { return }
        direction = .trailing
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            step += 1
        }
        saveCheckpoint()
    }

    func prevStep() {
        guard step > 0 else { return }
        direction = .leading
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            step -= 1
        }
    }

    func computeResults() {
        let daysPerWeek = activityLevel == .sedentary ? 3 :
            activityLevel == .light ? 3 :
            activityLevel == .moderate ? 4 :
            activityLevel == .active ? 5 : 6

        results = WizardService.computeResults(
            name: name, age: age, gender: gender,
            heightCm: heightDisplay, weightKg: weightDisplay,
            goal: goal, targetWeightKg: targetWeightKg,
            activityLevel: activityLevel,
            activityTypes: activityTypes,
            equipment: equipment,
            hasGymAccess: hasGymAccess,
            sleepHours: sleepHours,
            wakeHour: wakeHour, wakeMinute: wakeMinute,
            daysPerWeek: daysPerWeek
        )
    }

    func saveCheckpoint() {
        UserDefaults.standard.set(step, forKey: "onboarding_step")
    }

    func restoreCheckpoint() {
        step = UserDefaults.standard.integer(forKey: "onboarding_step")
    }
}
