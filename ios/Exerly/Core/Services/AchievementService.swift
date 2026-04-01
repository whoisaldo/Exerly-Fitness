import Foundation
import SwiftData

struct AchievementDefinition {
    let id: String
    let title: String
    let desc: String
    let icon: String
}

@MainActor
final class AchievementService {
    static let shared = AchievementService()
    private init() {}

    static let definitions: [AchievementDefinition] = [
        .init(id: "first_workout", title: "First Step", desc: "Complete your first workout", icon: "figure.run"),
        .init(id: "streak_3", title: "On Fire", desc: "3-day activity streak", icon: "flame"),
        .init(id: "streak_7", title: "Week Warrior", desc: "7-day activity streak", icon: "flame.fill"),
        .init(id: "streak_30", title: "Monthly Master", desc: "30-day activity streak", icon: "star.fill"),
        .init(id: "calories_1000", title: "Calorie Counter", desc: "Log 1,000 calories in a day", icon: "fork.knife"),
        .init(id: "protein_100", title: "Protein Pro", desc: "Hit 100g protein in a day", icon: "bolt.fill"),
        .init(id: "workouts_10", title: "Dedicated", desc: "Complete 10 workouts", icon: "trophy"),
        .init(id: "workouts_50", title: "Committed", desc: "Complete 50 workouts", icon: "trophy.fill"),
        .init(id: "workouts_100", title: "Centurion", desc: "Complete 100 workouts", icon: "medal"),
        .init(id: "sleep_8", title: "Well Rested", desc: "Log 8+ hours of sleep", icon: "moon.fill"),
        .init(id: "sleep_week", title: "Sleep Champion", desc: "Hit sleep goal 7 days in a row", icon: "moon.stars"),
        .init(id: "weight_goal", title: "Goal Crusher", desc: "Reach your target weight", icon: "target"),
        .init(id: "food_log_7", title: "Nutrition Tracker", desc: "Log food for 7 days straight", icon: "leaf"),
        .init(id: "first_photo", title: "Snapshot", desc: "Take your first progress photo", icon: "camera"),
        .init(id: "barcode_scan", title: "Scanner", desc: "Scan your first barcode", icon: "barcode.viewfinder"),
        .init(id: "custom_food", title: "Chef", desc: "Create a custom food item", icon: "frying.pan"),
        .init(id: "social_friend", title: "Social", desc: "Add your first friend", icon: "person.2"),
        .init(id: "challenge_join", title: "Challenger", desc: "Join a challenge", icon: "flag"),
        .init(id: "challenge_win", title: "Champion", desc: "Win a challenge", icon: "crown"),
        .init(id: "ai_plan", title: "AI Powered", desc: "Generate your first AI plan", icon: "brain.head.profile"),
    ]

    func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Achievement>()
        let existing = (try? context.fetch(descriptor))?.count ?? 0
        guard existing == 0 else { return }

        for def in Self.definitions {
            let a = Achievement(
                achievementId: def.id, title: def.title,
                desc: def.desc, icon: def.icon
            )
            context.insert(a)
        }
    }

    func checkAndUnlock(
        id: String, context: ModelContext
    ) -> Bool {
        let targetId = id
        let predicate = #Predicate<Achievement> { $0.achievementId == targetId }
        let descriptor = FetchDescriptor<Achievement>(predicate: predicate)
        guard let achievement = try? context.fetch(descriptor).first,
              !achievement.isUnlocked else { return false }

        achievement.isUnlocked = true
        achievement.unlockedAt = Date()
        achievement.progress = 1.0
        return true
    }

    func updateProgress(
        id: String, progress: Double, context: ModelContext
    ) {
        let targetId = id
        let predicate = #Predicate<Achievement> { $0.achievementId == targetId }
        let descriptor = FetchDescriptor<Achievement>(predicate: predicate)
        guard let achievement = try? context.fetch(descriptor).first,
              !achievement.isUnlocked else { return }

        achievement.progress = min(progress, 1.0)
        if progress >= 1.0 {
            achievement.isUnlocked = true
            achievement.unlockedAt = Date()
        }
    }
}
