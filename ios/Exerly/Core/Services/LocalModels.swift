import Foundation
import SwiftData

@Model
final class CachedFoodItem {
    @Attribute(.unique) var barcode: String?
    var name: String
    var brand: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var sugar: Double
    var fiber: Double
    var servingSize: String
    var isFavorite: Bool
    var isCustom: Bool
    var lastUsed: Date
    var createdAt: Date

    init(
        barcode: String? = nil, name: String, brand: String? = nil,
        calories: Int, protein: Double = 0, carbs: Double = 0,
        fat: Double = 0, sugar: Double = 0, fiber: Double = 0,
        servingSize: String = "100g", isFavorite: Bool = false,
        isCustom: Bool = false
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.sugar = sugar
        self.fiber = fiber
        self.servingSize = servingSize
        self.isFavorite = isFavorite
        self.isCustom = isCustom
        self.lastUsed = Date()
        self.createdAt = Date()
    }
}

@Model
final class DailyFoodLog {
    var foodName: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var servingSize: String
    var servingCount: Double
    var mealType: String
    var date: Date

    init(
        foodName: String, calories: Int, protein: Double = 0,
        carbs: Double = 0, fat: Double = 0, servingSize: String = "1 serving",
        servingCount: Double = 1, mealType: String = "snack", date: Date = .now
    ) {
        self.foodName = foodName
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingSize = servingSize
        self.servingCount = servingCount
        self.mealType = mealType
        self.date = date
    }
}

@Model
final class Measurement {
    var type: String
    var value: Double
    var unit: String
    var date: Date

    init(type: String, value: Double, unit: String, date: Date = .now) {
        self.type = type
        self.value = value
        self.unit = unit
        self.date = date
    }
}

@Model
final class ProgressPhoto {
    @Attribute(.externalStorage) var imageData: Data?
    var note: String?
    var date: Date

    init(imageData: Data? = nil, note: String? = nil, date: Date = .now) {
        self.imageData = imageData
        self.note = note
        self.date = date
    }
}

@Model
final class Achievement {
    @Attribute(.unique) var achievementId: String
    var title: String
    var desc: String
    var icon: String
    var isUnlocked: Bool
    var unlockedAt: Date?
    var progress: Double

    init(
        achievementId: String, title: String, desc: String,
        icon: String, isUnlocked: Bool = false, progress: Double = 0
    ) {
        self.achievementId = achievementId
        self.title = title
        self.desc = desc
        self.icon = icon
        self.isUnlocked = isUnlocked
        self.progress = progress
    }
}

@Model
final class OfflineAction {
    var endpoint: String
    var method: String
    var bodyData: Data?
    var createdAt: Date

    init(endpoint: String, method: String, bodyData: Data? = nil) {
        self.endpoint = endpoint
        self.method = method
        self.bodyData = bodyData
        self.createdAt = Date()
    }
}
