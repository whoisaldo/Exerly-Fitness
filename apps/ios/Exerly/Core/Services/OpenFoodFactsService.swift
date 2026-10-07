import Foundation

struct OpenFoodItem: Identifiable, Codable {
    var id: String { barcode ?? "\(name)|\(brand ?? "")|\(servingSize)" }
    let barcode: String?
    let name: String
    let brand: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    let servingSize: String
    var source: String? = nil
    var missingNutrients: [String] = []
    var nutritionBasis: NutritionBasis? = nil
    var sodium: Double? = nil
    var saturatedFat: Double? = nil
    var preciseCalories: Double? = nil

    func scaled(by factor: Double) -> OpenFoodItem {
        OpenFoodItem(
            barcode: barcode, name: name, brand: brand,
            calories: Int(((preciseCalories ?? Double(calories)) * factor).rounded()),
            protein: protein * factor, carbs: carbs * factor,
            fat: fat * factor, fiber: fiber * factor,
            sugar: sugar * factor, servingSize: servingSize,
            source: source, missingNutrients: missingNutrients, nutritionBasis: nutritionBasis,
            sodium: sodium.map { $0 * factor }, saturatedFat: saturatedFat.map { $0 * factor },
            preciseCalories: (preciseCalories ?? Double(calories)) * factor
        )
    }
}

struct NutritionBasis: Codable {
    let amount: Double
    let unit: String
}

extension FoodDTO {
    var perServingItem: OpenFoodItem {
        let quantity = max(servings, 0.01)
        let p = nutritionSnapshot != nil ? nutritionSnapshot?.protein : protein.map { $0 / quantity }
        let c = nutritionSnapshot != nil ? nutritionSnapshot?.carbs : carbs.map { $0 / quantity }
        let f = nutritionSnapshot != nil ? nutritionSnapshot?.fat : fat.map { $0 / quantity }
        let fi = nutritionSnapshot != nil ? nutritionSnapshot?.fiber : fiber.map { $0 / quantity }
        let s = nutritionSnapshot != nil ? nutritionSnapshot?.sugar : sugar.map { $0 / quantity }
        let missing = [("protein", p), ("carbs", c), ("fat", f), ("fiber", fi), ("sugar", s)].compactMap { $0.1 == nil ? $0.0 : nil }
        return OpenFoodItem(barcode: barcode, name: name, brand: brand,
            calories: Int((nutritionSnapshot?.calories ?? Double(calories) / quantity).rounded()),
            protein: p ?? 0, carbs: c ?? 0, fat: f ?? 0, fiber: fi ?? 0, sugar: s ?? 0,
            servingSize: servingSize ?? "1 serving", source: source, missingNutrients: missing,
            nutritionBasis: nutritionBasis,
            sodium: nutritionSnapshot != nil ? nutritionSnapshot?.sodium : sodium.map { $0 / quantity },
            saturatedFat: nutritionSnapshot != nil ? nutritionSnapshot?.saturated_fat : saturatedFat.map { $0 / quantity },
            preciseCalories: nutritionSnapshot?.calories ?? Double(calories) / quantity)
    }
}
