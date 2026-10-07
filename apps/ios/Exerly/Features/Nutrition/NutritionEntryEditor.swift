import ExerlyCore
import SwiftUI

struct NutritionEntryEditor: View {
    let workspace: TrainingWorkspace
    let timeZone: TimeZone
    let editing: FoodEntry?
    let onSaved: (FoodEntry) -> Void
    @ObservedObject var actions: NutritionDiaryActions
    @StateObject private var draft: NutritionEntryDraft
    @State private var confirmation: Confirmation?
    @FocusState private var typing: Bool
    @AccessibilityFocusState private var errorsFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private enum Confirmation: String, Identifiable {
        case discard, delete
        var id: String { rawValue }
    }

    init(workspace: TrainingWorkspace, food: ExerlyCore.Food, date: LocalDate, meal: String,
         timeZone: TimeZone, actions: NutritionDiaryActions, editing: FoodEntry? = nil,
         onSaved: @escaping (FoodEntry) -> Void) {
        self.workspace = workspace
        self.timeZone = timeZone
        self.actions = actions
        self.editing = editing
        self.onSaved = onSaved
        _draft = StateObject(wrappedValue: NutritionEntryDraft(store: workspace.nutrition, food: food,
                                                              date: date, meal: meal, editing: editing))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                Form {
                    Section {
                        Text(draft.food.name).font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let brand = draft.food.brand { Text(brand).foregroundStyle(.secondary) }
                    }
                    Section("Amount") {
                        NutritionChoice(title: "Measure", value: draft.serving?.name ?? "Grams") {
                            Picker("Measure", selection: $draft.serving) {
                                Text("Grams").tag(Serving?.none)
                                ForEach(draft.food.servings, id: \.self) { serving in
                                    Text("\(serving.name) · \(TrainingFormat.number(serving.grams)) g").tag(Optional(serving))
                                }
                            }
                        }.accessibilityIdentifier("nutrition.measure")
                        .onChange(of: draft.serving) { _, serving in
                            draft.amount = NutritionNumberField(serving == nil ? 100 : 1)
                        }
                        NutritionNumberInput(title: draft.serving == nil ? "Amount (g)" : "Number of servings",
                                             text: $draft.amount.text)
                            .focused($typing).accessibilityIdentifier("nutrition.amount")
                        if let serving = draft.serving {
                            Text("One \(serving.name): \(TrainingFormat.number(serving.grams)) g")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section("Diary") {
                        NutritionChoice(title: "Meal", value: draft.meal) {
                            Picker("Meal", selection: $draft.meal) {
                                ForEach(meals, id: \.self) { Text($0).tag($0) }
                            }
                        }.accessibilityIdentifier("nutrition.meal")
                        DatePicker("Diary date", selection: diaryDate, displayedComponents: .date)
                            .accessibilityIdentifier("nutrition.entryDate")
                        DatePicker("Eaten at", selection: $draft.loggedAt, displayedComponents: [.date, .hourAndMinute])
                            .accessibilityIdentifier("nutrition.eatenAt")
                        Text("Dates and times use \(timeZone.identifier). The diary date controls which day's totals include this food.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("This portion") { portion }
                    Section("Source") {
                        Text(NutritionFormat.source(draft.food.source))
                        if let volume = draft.food.volume {
                            if volume.assumed {
                                Text("Gram amounts use an estimated density of \(TrainingFormat.number(volume.density)) g/ml.")
                            }
                            if let note = volume.note { Text(note).foregroundStyle(.secondary) }
                        }
                        if draft.food.source == .openFoodFacts {
                            Link("Open Food Facts · Open Database License", destination: URL(string: "https://world.openfoodfacts.org/data")!)
                        } else if draft.food.source == .usda {
                            Link("USDA FoodData Central · Public domain", destination: URL(string: "https://fdc.nal.usda.gov/")!)
                        }
                        if editing != nil {
                            Text("This entry keeps the food name and nutrition saved when you logged it.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !draft.errors.isEmpty || actions.error != nil {
                        Section("Could not save") {
                            ForEach(draft.errors, id: \.self) { Text($0).foregroundStyle(Color.exError) }
                            if let error = actions.error { Text(error).foregroundStyle(Color.exError) }
                        }.id("errors").accessibilityFocused($errorsFocused)
                    }
                    if editing != nil {
                        Section {
                            Button("Delete entry", role: .destructive) { typing = false; confirmation = .delete }
                                .accessibilityIdentifier("nutrition.deleteEntry")
                        }
                    }
                }
                .onChange(of: draft.errors) { _, errors in
                    guard !errors.isEmpty else { return }
                    scroll.scrollTo("errors", anchor: .bottom)
                    errorsFocused = true
                }
                .onChange(of: actions.error) { _, error in
                    guard error != nil else { return }
                    scroll.scrollTo("errors", anchor: .bottom)
                    errorsFocused = true
                }
            }
            .navigationTitle(editing == nil ? "Log food" : "Food entry").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { typing = false; if draft.hasChanges { confirmation = .discard } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Log" : "Save") {
                        typing = false
                        if let entry = draft.save() {
                            onSaved(entry)
                            Task { await workspace.synchronize() }
                            dismiss()
                        }
                    }.fontWeight(.semibold).accessibilityIdentifier("nutrition.saveEntry")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } }
            }
        }
        .environment(\.timeZone, timeZone)
        .interactiveDismissDisabled(draft.hasChanges)
        .sheet(item: $confirmation) { kind in
            if kind == .delete, let editing {
                NutritionConfirmation(title: "Delete this entry?",
                                      message: "Remove \(editing.food.name) from \(editing.meal) on \(editing.date)? You can undo this from the diary.",
                                      confirm: "Delete entry", destructive: true) {
                    confirmation = nil
                    if actions.delete(editing) {
                        Task { await workspace.synchronize() }
                        dismiss()
                    }
                } cancel: { confirmation = nil }
            } else {
                NutritionConfirmation(title: "Discard entry changes?", message: "Your unsaved portion, date and meal changes will be discarded.",
                                      confirm: "Discard changes", cancelLabel: "Keep editing", destructive: true) {
                    confirmation = nil
                    dismiss()
                } cancel: { confirmation = nil }
            }
        }
    }

    private var meals: [String] {
        let defaults = NutritionStore.defaultMeals
        return defaults.contains(draft.meal) ? defaults : defaults + [draft.meal]
    }

    private var diaryDate: Binding<Date> {
        Binding(get: { NutritionFormat.pickerDate(draft.date, timeZone: timeZone) },
                set: { draft.date = LocalDate($0, in: timeZone) })
    }

    @ViewBuilder private var portion: some View {
        if let amount = try? draft.preview() {
            Text("\(TrainingFormat.number(amount.grams)) g").monospacedDigit()
            NutritionAmountsView(amounts: amount.nutrients)
            Text("Not reported means the food has no value for that nutrient; it does not mean zero.")
                .font(.footnote).foregroundStyle(.secondary)
        } else {
            Text("Enter a positive amount to preview its nutrition.").foregroundStyle(.secondary)
        }
    }
}
