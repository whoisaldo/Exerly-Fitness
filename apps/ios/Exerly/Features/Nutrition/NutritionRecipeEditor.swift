import ExerlyCore
import SwiftUI

struct NutritionRecipeEditor: View {
    let workspace: TrainingWorkspace
    let timeZone: TimeZone
    let onSaved: (ExerlyCore.Food) -> Void
    private let editing: Bool
    @StateObject private var draft: NutritionRecipeDraft
    @StateObject private var actions: NutritionDiaryActions
    @State private var picking: IngredientPicker?
    @State private var editingPortion: NutritionRecipeDraft.Row?
    @State private var discarding = false
    @State private var openedSession: UUID?
    @AccessibilityFocusState private var errorFocused: Bool
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private enum IngredientPicker: String, Identifiable {
        case barcode, search
        var id: String { rawValue }
    }

    init(workspace: TrainingWorkspace, editing food: ExerlyCore.Food? = nil, timeZone: TimeZone,
         unit: MassUnit, onSaved: @escaping (ExerlyCore.Food) -> Void) {
        self.workspace = workspace
        self.timeZone = timeZone
        self.onSaved = onSaved
        editing = food != nil
        _draft = StateObject(wrappedValue: NutritionRecipeDraft(store: workspace.nutrition, editing: food, unit: unit))
        _actions = StateObject(wrappedValue: NutritionDiaryActions(store: workspace.nutrition))
    }

    var body: some View {
        NavigationStack {
            ExScreen {
                ExCard(accent: true) {
                    ExEyebrow("Your recipe", color: .exPrimaryText)
                    TextField("Name your dish", text: $draft.name).font(.exH1)
                        .textInputAutocapitalization(.words).submitLabel(.done)
                        .accessibilityLabel("Recipe name").accessibilityIdentifier("nutrition.recipe.name")
                    if let summary = draft.summary {
                        ExEyebrow(summary.serving == nil ? "Whole recipe" : "Per serving")
                        NutritionDailySummary(amounts: summary.nutrients, targets: nil, showHeading: false, showTargetNote: false)
                        Text("Totals include the nutrients reported by your ingredients.")
                            .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    } else {
                        Text(draft.rows.isEmpty ? "Save a dish you make often. Next time, log a portion in one step." : "Review the portions below to see nutrition.")
                            .font(.exBody).foregroundStyle(Color.exTextSecondary)
                    }
                }
                ingredients
                ExCard {
                    ExSectionHeading("How much does it make?")
                    ExQuantityControl(title: "Equal servings", text: $draft.servingCount.text, step: 1,
                                      presets: [1, 2, 4, 6], unit: "servings")
                        .accessibilityIdentifier("nutrition.recipe.servings")
                    Text("For meal prep, enter the number of equal portions. Leave this blank if you only log by weight.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    Divider()
                    NutritionNumberInput(title: "Finished weight (\(draft.weightUnit), optional)", text: $draft.cookedWeight.text,
                                         identifier: "nutrition.recipe.weight")
                    Text("Weigh the finished food without its container if you want to log a cooked portion by weight. Cooking can change its weight.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    if draft.cookedWeight.text.isEmpty {
                        Text("No finished weight yet. Weight-based portions will use the ingredient weights; equal servings use a share of the whole dish.")
                            .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    }
                }
                ExCard {
                    DisclosureGroup("Preparation notes") {
                        TextField("How you make it", text: $draft.preparation, axis: .vertical)
                            .lineLimit(4...12).font(.exBody).padding(.top, ExSpacing.item)
                            .accessibilityLabel("Preparation notes").accessibilityIdentifier("nutrition.recipe.preparation")
                    }.font(.exLabel)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    if !draft.errors.isEmpty {
                        Text(draft.errors.joined(separator: ". ")).font(.exCaption).foregroundStyle(Color.exError)
                            .accessibilityFocused($errorFocused).accessibilityIdentifier("nutrition.recipe.error")
                    }
                    Button(editing ? "Save changes" : "Save recipe") {
                        hideKeyboard()
                        let ownerIsActive = auth.currentUser?.id == workspace.accountID && auth.sessionID == openedSession
                        if let food = draft.save(ownerIsActive: ownerIsActive) {
                            onSaved(food)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            Task { await workspace.synchronize() }
                            dismiss()
                        } else { errorFocused = true }
                    }.buttonStyle(ExActionStyle()).disabled(draft.saved != nil)
                        .accessibilityIdentifier("nutrition.recipe.save")
                }.padding(ExSpacing.page).background(Color.exBackground)
            }
            .navigationTitle(editing ? "Edit recipe" : "Create recipe").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { hideKeyboard(); if draft.hasChanges { discarding = true } else { dismiss() } }
                        .accessibilityIdentifier("nutrition.recipe.cancel")
                }
            }
            .sheet(item: $picking) { destination in
                if let api = auth.accountAPI {
                    NutritionFoodPicker(workspace: workspace, api: api, date: date, meal: "Recipe",
                                        timeZone: timeZone, unit: draft.unit, actions: actions, onLogged: {},
                                        startsWithBarcode: destination == .barcode, pickedCount: draft.rows.count,
                                        pickedFoodIDs: Set(draft.rows.map { $0.food.id }), selectionPurpose: .recipe,
                                        onPick: { draft.add($0) ? draft.rows.count : nil },
                                        pickError: { draft.errors.isEmpty ? nil : draft.errors.joined(separator: ". ") })
                }
            }
            .sheet(item: $editingPortion) { row in
                NutritionRecipePortionEditor(workspace: workspace, recipe: draft, row: row, date: date)
            }
            .sheet(isPresented: $discarding) {
                NutritionConfirmation(title: "Discard recipe changes?", message: "Your saved recipe and diary will stay as they were.",
                                      confirm: "Discard changes", cancelLabel: "Keep editing", destructive: true) { dismiss() }
                    cancel: { discarding = false }
            }
        }
        .onAppear { if openedSession == nil { openedSession = auth.sessionID } }
        .interactiveDismissDisabled(draft.hasChanges)
    }

    private var date: LocalDate { LocalDate(.now, in: timeZone) }

    private var ingredients: some View {
        ExCard {
            ExSectionHeading("Ingredients", detail: draft.rows.isEmpty ? nil : "\(draft.rows.count)")
            if draft.rows.isEmpty {
                Text("Start with the food in your dish").font(.exH2)
                Text("Scan a package, or search for foods like oats, chicken or vegetables. Review each amount before saving.")
                    .font(.exBody).foregroundStyle(Color.exTextSecondary)
            }
            ForEach(draft.rows) { row in
                HStack(spacing: ExSpacing.small) {
                    Button { editingPortion = row } label: {
                        VStack(alignment: .leading, spacing: ExSpacing.tight) {
                            Text(row.food.name).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                            Text(NutritionFormat.portion(row.entry(on: date), roundedGrams: true)).font(.exCaption)
                                .foregroundStyle(Color.exTextSecondary)
                            Text("Edit amount").font(.exCaption).foregroundStyle(Color.exPrimaryText)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("nutrition.recipe.ingredient.\(row.food.id)")
                    Menu("Ingredient actions", systemImage: "ellipsis") {
                        Button("Move up", systemImage: "arrow.up") { draft.move(row, by: -1) }
                            .disabled(draft.rows.first?.id == row.id)
                        Button("Move down", systemImage: "arrow.down") { draft.move(row, by: 1) }
                            .disabled(draft.rows.last?.id == row.id)
                        Button("Remove ingredient", systemImage: "minus.circle", role: .destructive) { draft.remove(row) }
                    }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Actions for \(row.food.name)")
                        .accessibilityIdentifier("nutrition.recipe.ingredientActions.\(row.food.id)")
                }
                Divider()
            }
            Button { hideKeyboard(); picking = .barcode } label: { Label("Scan ingredient", systemImage: "barcode.viewfinder") }
                .buttonStyle(ExActionStyle()).accessibilityIdentifier("nutrition.recipe.scan")
            Button { hideKeyboard(); picking = .search } label: {
                Label("Search ingredients", systemImage: "magnifyingglass").font(.exLabel).frame(maxWidth: .infinity, minHeight: 44)
            }.accessibilityIdentifier("nutrition.recipe.search")
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct NutritionRecipePortionEditor: View {
    @ObservedObject var recipe: NutritionRecipeDraft
    let row: NutritionRecipeDraft.Row
    @StateObject private var draft: NutritionEntryDraft
    @State private var choosingMeasure = false
    @State private var discarding = false
    @Environment(\.dismiss) private var dismiss

    init(workspace: TrainingWorkspace, recipe: NutritionRecipeDraft, row: NutritionRecipeDraft.Row, date: LocalDate) {
        self.recipe = recipe
        self.row = row
        _draft = StateObject(wrappedValue: NutritionEntryDraft(store: workspace.nutrition, food: row.food, date: date,
            meal: "Recipe", editing: row.entry(on: date), preferredUnit: recipe.unit))
    }

    var body: some View {
        NavigationStack {
            ExScreen {
                ExCard(accent: true) {
                    ExEyebrow("Recipe ingredient", color: .exPrimaryText)
                    Text(row.food.name).font(.exH2)
                    if let amount = try? draft.preview() {
                        NutritionDailySummary(amounts: amount.nutrients, targets: nil, showHeading: false, showTargetNote: false)
                    }
                }
                ExCard {
                    Button { choosingMeasure = true } label: {
                        ExNavigationLabel(title: draft.measure.title, icon: "scalemass", detail: "Portion measure")
                    }.accessibilityIdentifier("nutrition.measure")
                    ExQuantityControl(title: draft.measure.amountTitle, text: $draft.amount.text, step: draft.measure.step,
                                      presets: draft.measure.presets, unit: draft.measure.symbol)
                        .accessibilityIdentifier("nutrition.recipe.ingredientAmount")
                    if draft.measure == .milliliters || draft.measure == .fluidOunces, row.food.volume?.assumed == true {
                        Text("Estimated weight from volume").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    }
                }
                if !draft.errors.isEmpty || !recipe.errors.isEmpty {
                    Text((draft.errors + recipe.errors).joined(separator: ". ")).font(.exCaption).foregroundStyle(Color.exError)
                        .accessibilityIdentifier("nutrition.recipe.portionError")
                }
            }
            .navigationTitle("Ingredient amount").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if draft.hasChanges { discarding = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if draft.reviewNutrition() != nil, let amount = try? draft.preview(),
                           recipe.stage(row.food, amount: amount, replacing: row) { dismiss() }
                    }.fontWeight(.semibold).accessibilityIdentifier("nutrition.recipe.applyAmount")
                }
            }
            .sheet(isPresented: $choosingMeasure) { NutritionMeasureSelection(draft: draft) }
            .sheet(isPresented: $discarding) {
                NutritionConfirmation(title: "Discard amount changes?", message: "The ingredient will keep its previous amount.",
                                      confirm: "Discard changes", cancelLabel: "Keep editing", destructive: true) { dismiss() }
                    cancel: { discarding = false }
            }
        }
        .interactiveDismissDisabled(draft.hasChanges)
    }
}
