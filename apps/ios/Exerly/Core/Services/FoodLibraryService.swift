import Foundation
import SwiftData

@MainActor
final class FoodLibraryService {
    static let shared = FoodLibraryService()
    private init() {}

    func addToRecents(_ food: OpenFoodItem, context: ModelContext) {
        let predicate = #Predicate<CachedFoodItem> { $0.name == food.name }
        let descriptor = FetchDescriptor<CachedFoodItem>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            existing.lastUsed = Date()
        } else {
            let item = CachedFoodItem(
                barcode: food.barcode,
                name: food.name,
                brand: food.brand,
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat,
                sugar: food.sugar,
                fiber: food.fiber,
                servingSize: food.servingSize
            )
            context.insert(item)
        }
    }

    func toggleFavorite(_ item: CachedFoodItem) {
        item.isFavorite.toggle()
    }

    func logFood(
        _ food: OpenFoodItem,
        servings: Double,
        mealType: String,
        context: ModelContext
    ) {
        let log = DailyFoodLog(
            foodName: food.name,
            calories: Int(Double(food.calories) * servings),
            protein: food.protein * servings,
            carbs: food.carbs * servings,
            fat: food.fat * servings,
            servingSize: food.servingSize,
            servingCount: servings,
            mealType: mealType
        )
        context.insert(log)
        addToRecents(food, context: context)
    }
}
