import SwiftUI

struct FoodDetailView: View {
    @State private var food: OpenFoodItem
    var onLogged: () -> Void = {}
    private var editing: FoodDTO?
    @State private var operationID = UUID().uuidString
    @State private var submittedPayload: Data?
    @State private var showCorrection = false
    @State private var servingCount: Double = 1
    @State private var selectedMealType: String
    @State private var selectedDate: CalendarDay
    @State private var isLogging = false
    @State private var errorMessage: String?
    @EnvironmentObject private var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss
    // Canonical lowercase values, matching what the API stores.
    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    private var scaled: OpenFoodItem {
        food.scaled(by: servingCount)
    }

    init(
        food: OpenFoodItem,
        initialDate: CalendarDay,
        initialMealType: String = "snack",
        editing: FoodDTO? = nil,
        onLogged: @escaping () -> Void = {}
    ) {
        _food = State(initialValue: food)
        self.onLogged = onLogged
        self.editing = editing
        _servingCount = State(initialValue: editing?.servings ?? 1)
        _selectedDate = State(initialValue: editing?.date.flatMap { CalendarDay(rawValue: $0) } ?? initialDate)
        _selectedMealType = State(initialValue: initialMealType)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                servingSelector
                mealTypePicker
                datePicker
                nutritionFacts
                if !food.missingNutrients.isEmpty {
                    Text("Not provided: \(food.missingNutrients.joined(separator: ", ")). Unknown nutrients remain blank in your log.")
                        .font(.callout).foregroundStyle(.exTextSecondary)
                }
                if let source = food.source {
                    Text("Source: \(source == "openfoodfacts" ? "Open Food Facts, ODbL" : source)")
                        .font(.caption).foregroundStyle(.exTextSecondary)
                }
                DisclosureGroup("Correct nutrition per serving", isExpanded: $showCorrection) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Calories, kcal")
                            TextField("Calories", value: Binding(get: { food.preciseCalories ?? Double(food.calories) }, set: { value in
                                guard value.isFinite, (0...30000).contains(value) else { return }
                                food.preciseCalories = value
                                food.calories = Int(value.rounded())
                                food.missingNutrients.removeAll { $0 == "calories" }
                            }), format: .number)
                                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                        }
                        correctionField("Protein, g", key: "protein", value: $food.protein)
                        correctionField("Carbohydrate, g", key: "carbs", value: $food.carbs)
                        correctionField("Fat, g", key: "fat", value: $food.fat)
                        correctionField("Fiber, g", key: "fiber", value: $food.fiber)
                        correctionField("Sugar, g", key: "sugar", value: $food.sugar)
                    }.padding(.top, 12)
                }
                logButton
                if let errorMessage {
                    Text(errorMessage)
                        .font(.exCaption)
                        .foregroundStyle(.exError)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
        }
        .background(Color.exBackground)
        .navigationTitle("Food Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
        .scrollDismissesKeyboard(.interactively)
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
            VStack(alignment: .leading, spacing: 10) {
                Text("Quantity").font(.headline)
                HStack {
                    TextField("Number of servings", value: $servingCount, format: .number.precision(.fractionLength(0...3)))
                        .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                        .frame(minHeight: 44).accessibilityLabel("Number of servings")
                    Text("× \(food.servingSize)").font(.callout)
                }
                if let basis = food.nutritionBasis, basis.amount > 0 {
                    Text("Total: \(servingCount * basis.amount, format: .number.precision(.fractionLength(0...2))) \(basis.unit)")
                        .font(.callout).monospacedDigit()
                }
            }
        }
    }

    private func correctionField(_ title: String, key: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            TextField(title, value: Binding(get: { value.wrappedValue }, set: { number in
                value.wrappedValue = number
                food.missingNutrients.removeAll { $0 == key }
            }), format: .number)
                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(minHeight: 44)
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
                            Text(type.capitalized)
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

    private var datePicker: some View {
        GlassCard {
            CalendarDayPicker("Log date", selection: $selectedDate, today: sync.today,
                              timeZoneIdentifier: sync.calendar.timeZoneIdentifier)
            .font(.exLabel)
            .foregroundStyle(.exTextSecondary)
            .tint(.exPrimary)
            .colorScheme(.dark)
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
            Text(food.missingNutrients.contains(name.lowercased() == "carbohydrates" ? "carbs" : name.lowercased()) ? "Not provided" : "\(value) \(unit)")
                .font(bold ? .exStatSmall : .exMono)
                .foregroundStyle(bold ? .exPrimary : .exTextSecondary)
        }
    }

    private var logButton: some View {
        ActionButton(title: editing == nil ? "Log Food" : "Save changes", isLoading: isLogging, isDisabled: food.missingNutrients.contains("calories") || !(0.01...100).contains(servingCount)) {
            Task { await logFood() }
        }
    }

    private func logFood() async {
        guard !isLogging else { return }
        isLogging = true
        errorMessage = nil
        var req = FoodRequest(
            name: food.name, calories: food.preciseCalories ?? Double(food.calories),
            protein: food.missingNutrients.contains("protein") ? nil : food.protein, carbs: food.missingNutrients.contains("carbs") ? nil : food.carbs,
            fat: food.missingNutrients.contains("fat") ? nil : food.fat, sugar: food.missingNutrients.contains("sugar") ? nil : food.sugar,
            mealType: selectedMealType,
            barcode: food.barcode,
            brand: food.brand,
            fiber: food.missingNutrients.contains("fiber") ? nil : food.fiber,
            servingSize: food.servingSize
        )
        req.nutritionBasis = food.nutritionBasis
        req.sodium = food.sodium
        req.saturatedFat = food.saturatedFat
        req.source = food.source
        req.servings = servingCount
        req.entryDate = selectedDate.rawValue
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let payload = try? encoder.encode(req)
        if let submittedPayload, submittedPayload != payload { operationID = UUID().uuidString }
        submittedPayload = payload
        do {
            try SyncEngine.shared.saveFood(req, editing: editing)
            onLogged()
            dismiss()
        } catch {
            isLogging = false
            errorMessage = error.localizedDescription
        }
    }
}
