import SwiftUI
import SwiftData

struct CreateFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var brand = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var servingSize = "100g"

    private var caloriesInt: Int { Int(calories) ?? 0 }
    private var proteinD: Double { Double(protein) ?? 0 }
    private var carbsD: Double { Double(carbs) ?? 0 }
    private var fatD: Double { Double(fat) ?? 0 }

    private var macroCalories: Int {
        Int(proteinD * 4 + carbsD * 4 + fatD * 9)
    }

    private var hasSanityWarning: Bool {
        caloriesInt > 0 && macroCalories > 0 && abs(caloriesInt - macroCalories) > 50
    }

    private var isValid: Bool {
        !name.isEmpty && caloriesInt > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                FloatingLabelTextField(label: "Food Name", text: $name)
                FloatingLabelTextField(label: "Brand (optional)", text: $brand)
                FloatingLabelTextField(label: "Serving Size", text: $servingSize)

                macroInputs
                sanityWarning
                previewCard

                ActionButton(title: "Create Food", isDisabled: !isValid) {
                    save()
                }
            }
            .padding(20)
        }
        .background(Color.exBackground)
        .navigationTitle("Create Food")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var macroInputs: some View {
        VStack(spacing: 12) {
            FloatingLabelTextField(label: "Calories", text: $calories, keyboardType: .numberPad)
            HStack(spacing: 12) {
                FloatingLabelTextField(label: "Protein (g)", text: $protein, keyboardType: .decimalPad)
                FloatingLabelTextField(label: "Carbs (g)", text: $carbs, keyboardType: .decimalPad)
                FloatingLabelTextField(label: "Fat (g)", text: $fat, keyboardType: .decimalPad)
            }
        }
    }

    @ViewBuilder
    private var sanityWarning: some View {
        if hasSanityWarning {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.exWarning)
                Text("Macros total ~\(macroCalories) kcal, but you entered \(caloriesInt) kcal")
                    .font(.exCaption)
                    .foregroundStyle(.exWarning)
            }
            .padding(12)
            .glassCard(cornerRadius: 10)
        }
    }

    private var previewCard: some View {
        GlassCard {
            VStack(spacing: 8) {
                Text("Preview")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.isEmpty ? "Food Name" : name)
                            .font(.exBodyMedium)
                            .foregroundStyle(.exTextPrimary)
                        Text(servingSize)
                            .font(.exCaption)
                            .foregroundStyle(.exTextMuted)
                    }
                    Spacer()
                    Text("\(caloriesInt) kcal")
                        .font(.exStatSmall)
                        .foregroundStyle(.exPrimary)
                }
            }
        }
    }

    private func save() {
        let item = CachedFoodItem(
            name: name,
            brand: brand.isEmpty ? nil : brand,
            calories: caloriesInt,
            protein: proteinD,
            carbs: carbsD,
            fat: fatD,
            servingSize: servingSize,
            isCustom: true
        )
        modelContext.insert(item)
        dismiss()
    }
}
