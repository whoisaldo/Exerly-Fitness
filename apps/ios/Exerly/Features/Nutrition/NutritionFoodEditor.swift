import ExerlyCore
import SwiftUI

struct NutritionFoodEditor: View {
    let workspace: TrainingWorkspace
    let onSaved: (ExerlyCore.Food) -> Void
    @StateObject private var draft: NutritionFoodDraft
    @State private var discarding = false
    @FocusState private var typing: Bool
    @AccessibilityFocusState private var errorsFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(workspace: TrainingWorkspace, editing: ExerlyCore.Food? = nil, onSaved: @escaping (ExerlyCore.Food) -> Void) {
        self.workspace = workspace
        self.onSaved = onSaved
        _draft = StateObject(wrappedValue: NutritionFoodDraft(store: workspace.nutrition, editing: editing))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ExScreen {
                    ExCard {
                        ExEyebrow("Food label", color: .exPrimary)
                        TextField("Food name", text: $draft.name, axis: .vertical).font(.exH2)
                            .focused($typing).accessibilityIdentifier("nutrition.foodName")
                        TextField("Brand, optional", text: $draft.brand, axis: .vertical).focused($typing)
                        Toggle("Favorite", isOn: $draft.favorite)
                    }
                    VStack(alignment: .leading, spacing: ExSpacing.item) {
                        ExChoiceChips(values: NutritionFoodDraft.Basis.allCases, selection: $draft.basis) { $0.rawValue }
                            .accessibilityIdentifier("nutrition.labelBasis")
                        if draft.basis == .perServing {
                            NutritionNumberInput(title: "Label serving weight (g)", text: $draft.labelGrams.text)
                                .focused($typing).accessibilityIdentifier("nutrition.labelGrams")
                        }
                        Text("Blank means unknown. Use 0 only when the label says zero.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: ExSpacing.item) {
                        ExSectionHeading("Energy & macros")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), alignment: .top)], alignment: .leading, spacing: ExSpacing.content) {
                            ForEach([Nutrient.energy, .protein, .carbohydrate, .fat], id: \.self) { nutrientField($0) }
                        }
                    }
                    ExCard {
                        ExSectionHeading("More nutrients")
                        ForEach(Nutrient.Group.allCases.filter { $0 != .energy && $0 != .macros }, id: \.self) { group in
                            DisclosureGroup(NutritionFormat.group(group)) {
                                ForEach(Nutrient.allCases.filter { $0.group == group }, id: \.self) { nutrientField($0) }
                            }.accessibilityIdentifier("nutrition.group.\(group.rawValue)")
                        }
                    }
                    ExCard {
                        ExSectionHeading("Named servings")
                        ForEach($draft.servings) { $serving in
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Serving name", text: $serving.name, axis: .vertical).focused($typing)
                                NutritionNumberInput(title: "Serving weight (g)", text: $serving.grams.text).focused($typing)
                                Button("Remove serving", role: .destructive) { draft.servings.removeAll { $0.id == serving.id } }
                            }
                        }
                        Button("Add named serving", systemImage: "plus") { draft.servings.append(NutritionServingFields()) }
                            .accessibilityIdentifier("nutrition.addServing")

                        Text("For example, a cup weighing 80 g. You can always log by grams without a named serving.")
                    }
                    Text("Label edits apply to future entries. Previously logged food stays unchanged.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    if !draft.errors.isEmpty {
                        ExCard {
                            ForEach(draft.errors, id: \.self) { Text($0).foregroundStyle(Color.exError) }
                        }.id("errors").accessibilityFocused($errorsFocused)
                    }
                }
                .onChange(of: draft.errors) { _, errors in
                    guard !errors.isEmpty else { return }
                    scroll.scrollTo("errors", anchor: .bottom)
                    errorsFocused = true
                }
            }
            .scrollContentBackground(.hidden).background(Color.exBackground)
            .navigationTitle("Food label").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { typing = false; if draft.hasChanges { discarding = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        typing = false
                        if let food = draft.save() {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onSaved(food)
                            Task { await workspace.synchronize() }
                            dismiss()
                        }
                    }.fontWeight(.semibold).accessibilityIdentifier("nutrition.saveFood")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { typing = false } }
            }
        }
        .interactiveDismissDisabled(draft.hasChanges)
        .sheet(isPresented: $discarding) {
            NutritionConfirmation(title: "Discard food changes?", message: "Your unsaved label and serving changes will be discarded.",
                                  confirm: "Discard changes", cancelLabel: "Keep editing", destructive: true) {
                discarding = false
                dismiss()
            } cancel: { discarding = false }
        }
    }

    private func nutrientField(_ nutrient: Nutrient) -> some View {
        NutritionNumberInput(title: "\(nutrient.name) (\(nutrient.unit.rawValue))", text: Binding(
            get: { draft.nutrients[nutrient]?.text ?? "" },
            set: { draft.nutrients[nutrient]?.text = $0 }
        ))
        .focused($typing).accessibilityIdentifier("nutrition.nutrient.\(nutrient.rawValue)")
    }
}
