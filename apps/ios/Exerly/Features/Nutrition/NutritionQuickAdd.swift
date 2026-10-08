import Combine
import ExerlyCore
import SwiftUI

@MainActor
final class NutritionQuickAddDraft: ObservableObject {
    static let nutrients: [Nutrient] = [.energy, .protein, .carbohydrate, .fat]
    @Published var fields = Dictionary(uniqueKeysWithValues: NutritionQuickAddDraft.nutrients.map { ($0, NutritionNumberField()) })
    @Published var name = ""
    @Published var meal: String
    @Published private(set) var errors: [String] = []
    @Published private(set) var loggedEntry: FoodEntry?
    let date: LocalDate
    private let store: NutritionStore
    private let initialMeal: String

    init(store: NutritionStore, date: LocalDate, meal: String) {
        self.store = store
        self.date = date
        self.meal = meal
        initialMeal = meal
    }

    var hasChanges: Bool {
        !name.isEmpty || meal != initialMeal || fields.values.contains { !$0.text.isEmpty }
    }

    @discardableResult
    func save(ownerIsActive: Bool, locale: Locale = .current) -> FoodEntry? {
        guard loggedEntry == nil else { return nil }
        guard ownerIsActive else {
            errors = ["Sign in again before logging this entry. Your draft is still here."]
            return nil
        }
        do {
            var amounts = NutrientAmounts()
            for nutrient in Self.nutrients {
                amounts[nutrient] = try fields[nutrient]?.value(named: nutrient == .energy ? "Calories" : nutrient.name, locale: locale)
            }
            let entry = try store.quickAdd(amounts, name: name, on: date, meal: meal)
            loggedEntry = entry
            errors = []
            return entry
        } catch { errors = NutritionDraftError.messages(error).map { $0.prefix(1).uppercased() + $0.dropFirst() } }
        return nil
    }
}

struct NutritionQuickAddView: View {
    let workspace: TrainingWorkspace
    let timeZone: TimeZone
    let onLogged: () -> Void
    @StateObject private var draft: NutritionQuickAddDraft
    @State private var discarding = false
    @State private var openedSession: UUID?
    @FocusState private var naming: Bool
    @AccessibilityFocusState private var errorFocused: Bool
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    init(workspace: TrainingWorkspace, date: LocalDate, meal: String, timeZone: TimeZone, onLogged: @escaping () -> Void) {
        self.workspace = workspace
        self.timeZone = timeZone
        self.onLogged = onLogged
        _draft = StateObject(wrappedValue: NutritionQuickAddDraft(store: workspace.nutrition, date: date, meal: meal))
    }

    var body: some View {
        NavigationStack {
            ExScreen {
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    ExEyebrow("\(draft.meal) · \(NutritionFormat.day(draft.date, timeZone: timeZone))", color: .exPrimaryText)
                    Text("Log the totals").font(.exH1)
                    Text("Enter totals for your meal or snack.")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary)
                }
                ExCard(accent: true) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: typeSize.isAccessibilitySize ? 1 : 2),
                              alignment: .leading, spacing: ExSpacing.content) {
                        ForEach(NutritionQuickAddDraft.nutrients, id: \.self) { nutrient in
                            NutritionNumberInput(title: "\(nutrient == .energy ? "Calories" : nutrient.name) (\(nutrient.unit.rawValue))",
                                                 text: Binding(get: { draft.fields[nutrient]?.text ?? "" },
                                                               set: { draft.fields[nutrient]?.text = $0 }),
                                                 identifier: "nutrition.quick.\(nutrient.rawValue)")
                        }
                    }
                    Text("Enter Calories, macros, or both. Leave unknown values blank; use 0 only for a known zero.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
                VStack(alignment: .leading, spacing: ExSpacing.item) {
                    ExSectionHeading("Log to")
                    ExChoiceChips(values: meals, selection: $draft.meal) { $0 }
                }
                ExCard {
                    Text("Name (optional)").font(.exLabel)
                    TextField("e.g. Restaurant lunch", text: $draft.name)
                        .font(.exBody).focused($naming).submitLabel(.done).onSubmit { naming = false }
                        .padding(ExSpacing.content).background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                        .accessibilityLabel("Entry name, optional").accessibilityIdentifier("nutrition.quick.name")
                    Text("You can edit these totals later from your diary.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    if !draft.errors.isEmpty {
                        Text(draft.errors.joined(separator: ". ")).font(.exCaption).foregroundStyle(Color.exError)
                            .accessibilityIdentifier("nutrition.quick.error").accessibilityFocused($errorFocused)
                    }
                    Button("Log to \(draft.meal)") {
                        hideKeyboard()
                        let ownerIsActive = auth.currentUser?.id == workspace.accountID && auth.sessionID == openedSession
                        if draft.save(ownerIsActive: ownerIsActive) != nil {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onLogged()
                            Task { await workspace.synchronize() }
                            dismiss()
                        } else { errorFocused = true }
                    }.buttonStyle(ExActionStyle()).disabled(draft.loggedEntry != nil)
                        .accessibilityIdentifier("nutrition.quick.save")
                }.padding(ExSpacing.page).background(Color.exBackground)
            }
            .navigationTitle("Quick add").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hideKeyboard()
                        if draft.hasChanges { discarding = true } else { dismiss() }
                    }.accessibilityIdentifier("nutrition.quick.cancel")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Hide keyboard") { hideKeyboard() } }
            }
        }
        .onAppear { if openedSession == nil { openedSession = auth.sessionID } }
        .interactiveDismissDisabled(draft.hasChanges)
        .sheet(isPresented: $discarding) {
            NutritionConfirmation(title: "Discard this entry?", message: "These totals have not been logged.",
                                  confirm: "Discard entry", cancelLabel: "Keep editing", destructive: true) {
                discarding = false
                dismiss()
            } cancel: { discarding = false }
        }
    }

    private var meals: [String] {
        NutritionStore.defaultMeals.contains(draft.meal) ? NutritionStore.defaultMeals : NutritionStore.defaultMeals + [draft.meal]
    }

    private func hideKeyboard() {
        naming = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
