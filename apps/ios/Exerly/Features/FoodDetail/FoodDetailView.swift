import SwiftUI

struct FoodDetailView: View {
    let food: OpenFoodItem
    @State private var servingCount: Double = 1
    @State private var selectedMealType = "Snack"
    @State private var isLogging = false
    @Environment(\.dismiss) private var dismiss
    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]

    private var scaled: OpenFoodItem {
        food.scaled(by: servingCount)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                servingSelector
                mealTypePicker
                nutritionFacts
                logButton
            }
            .padding(20)
        }
        .background(Color.exBackground)
        .navigationTitle("Food Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(food.name)
                .font(.exH2)
                .foregroundStyle(.exTextPrimary)
            if let brand = food.brand {
                Text(brand)
                    .font(.exBody)
                    .foregroundStyle(.exTextSecondary)
            }
            Text("\(scaled.calories) kcal")
                .font(.exStat)
                .foregroundStyle(.exPrimary)
        }
    }

    private var servingSelector: some View {
        GlassCard {
            HStack {
                Text("Servings")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        if servingCount > 0.5 {
                            servingCount -= 0.5
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.exPrimary)
                            .font(.system(size: 24))
                    }
                    Text(String(format: "%.1f", servingCount))
                        .font(.exStatSmall)
                        .foregroundStyle(.exTextPrimary)
                        .frame(width: 50)
                    Button { servingCount += 0.5 } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.exPrimary)
                            .font(.system(size: 24))
                    }
                }
                Text(food.servingSize)
                    .font(.exCaption)
                    .foregroundStyle(.exTextMuted)
            }
        }
    }

    private var mealTypePicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Meal Type")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                HStack(spacing: 8) {
                    ForEach(mealTypes, id: \.self) { type in
                        Button {
                            selectedMealType = type
                        } label: {
                            Text(type)
                                .font(.exSmall)
                                .fontWeight(selectedMealType == type ? .semibold : .regular)
                                .foregroundStyle(selectedMealType == type ? .white : .exTextSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedMealType == type ? Color.exPrimary : Color.exSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    private var nutritionFacts: some View {
        GlassCard {
            VStack(spacing: 12) {
                Text("Nutrition Facts")
                    .font(.exH3)
                    .foregroundStyle(.exTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().overlay(Color.exBorder)

                nutrientRow("Calories", value: "\(scaled.calories)", unit: "kcal", bold: true)
                nutrientRow("Protein", value: String(format: "%.1f", scaled.protein), unit: "g")
                nutrientRow("Carbohydrates", value: String(format: "%.1f", scaled.carbs), unit: "g")
                nutrientRow("Fat", value: String(format: "%.1f", scaled.fat), unit: "g")
                nutrientRow("Fiber", value: String(format: "%.1f", scaled.fiber), unit: "g")
                nutrientRow("Sugar", value: String(format: "%.1f", scaled.sugar), unit: "g")
            }
        }
    }

    private func nutrientRow(_ name: String, value: String, unit: String, bold: Bool = false) -> some View {
        HStack {
            Text(name)
                .font(bold ? .exBodyMedium : .exBody)
                .foregroundStyle(.exTextPrimary)
            Spacer()
            Text("\(value) \(unit)")
                .font(bold ? .exStatSmall : .exMono)
                .foregroundStyle(bold ? .exPrimary : .exTextSecondary)
        }
    }

    private var logButton: some View {
        ActionButton(title: "Log Food", isLoading: isLogging) {
            Task { await logFood() }
        }
    }

    private func logFood() async {
        isLogging = true
        let req = FoodRequest(
            name: scaled.name, calories: scaled.calories,
            protein: scaled.protein, carbs: scaled.carbs,
            fat: scaled.fat, sugar: scaled.sugar,
            mealType: selectedMealType,
            barcode: food.barcode,
            brand: food.brand,
            fiber: scaled.fiber,
            servingSize: food.servingSize
        )
        do {
            let _: FoodDTO = try await APIClient.shared.createFoodLog(req)
            dismiss()
        } catch {
            isLogging = false
        }
    }
}
