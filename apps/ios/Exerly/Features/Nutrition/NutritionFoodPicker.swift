import ExerlyCore
import SwiftUI

struct NutritionFoodPicker: View {
    let workspace: TrainingWorkspace
    let api: AccountAPI
    let date: LocalDate
    let meal: String
    let timeZone: TimeZone
    let unit: MassUnit
    @ObservedObject var actions: NutritionDiaryActions
    let onLogged: () -> Void
    let onPick: ((ExerlyCore.Food) -> Int?)?
    let pickError: () -> String?
    @StateObject private var search: NutritionSearchModel
    @State private var query = ""
    @State private var selectedFood: ExerlyCore.Food?
    @State private var createdFood: ExerlyCore.Food?
    @State private var creating = false
    @State private var scanningLabel = false
    @State private var didLog = false
    @State private var buildingMeal = false
    @State private var pickedCount: Int
    @State private var addedIDs: Set<String> = []
    @State private var selectionError: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    init(workspace: TrainingWorkspace, api: AccountAPI, date: LocalDate, meal: String,
         timeZone: TimeZone, unit: MassUnit, actions: NutritionDiaryActions, onLogged: @escaping () -> Void,
         pickedCount: Int = 0, pickedFoodIDs: Set<String> = [], onPick: ((ExerlyCore.Food) -> Int?)? = nil,
         pickError: @escaping () -> String? = { nil }) {
        self.workspace = workspace
        self.api = api
        self.date = date
        self.meal = meal
        self.timeZone = timeZone
        self.unit = unit
        self.actions = actions
        self.onLogged = onLogged
        self.onPick = onPick
        self.pickError = pickError
        _pickedCount = State(initialValue: pickedCount)
        _addedIDs = State(initialValue: pickedFoodIDs)
        _search = StateObject(wrappedValue: NutritionSearchModel(api: api))
    }

    var body: some View {
        NavigationStack {
            ExScreen {
                if onPick == nil {
                    ExCard {
                        ExEyebrow("\(meal) · \(NutritionFormat.day(date, timeZone: timeZone))", color: .exPrimaryText)
                        Button { buildingMeal = true } label: { ExNavigationLabel(title: "Build a meal", icon: "fork.knife", detail: "Choose several foods, then log together") }
                            .accessibilityIdentifier("nutrition.buildMeal")
                        Button { creating = true } label: { ExNavigationLabel(title: "Create food", icon: "square.and.pencil") }
                            .accessibilityIdentifier("nutrition.createFood")
                        Button { scanningLabel = true } label: { ExNavigationLabel(title: "Scan label", icon: "text.viewfinder") }
                            .accessibilityIdentifier("nutrition.scanLabel")
                        NavigationLink {
                            NutritionBarcodeView(workspace: workspace, api: api, date: date, meal: meal,
                                                 timeZone: timeZone, unit: unit, actions: actions) {
                                onLogged()
                                dismiss()
                            }
                        } label: { ExNavigationLabel(title: "Barcode", icon: "barcode.viewfinder") }
                        .accessibilityIdentifier("nutrition.barcode")
                    }
                } else {
                    VStack(alignment: .leading, spacing: ExSpacing.small) {
                        ExEyebrow("\(meal) · \(NutritionFormat.day(date, timeZone: timeZone))", color: .exPrimaryText)
                        Text("Add foods, then review portions.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                        if let selectionError { Text(selectionError).foregroundStyle(Color.exError) }
                    }
                }
                if !favorites.isEmpty {
                    foodGroup("Favorites", foods: favorites)
                }
                if !recents.isEmpty {
                    foodGroup("Recently logged", foods: recents)
                }
                if !otherSaved.isEmpty {
                    foodGroup("Saved foods", foods: otherSaved)
                }
                databaseResults
                if query.isEmpty && favorites.isEmpty && recents.isEmpty && otherSaved.isEmpty {
                    ExEmptyState(icon: "magnifyingglass", title: "Find your first food",
                                 message: onPick == nil ? "Search above, scan a barcode, or enter the details from a label." : "Search above or enter the details from a label.",
                                 action: "Enter a food label") { creating = true }
                }
            }
            .scrollContentBackground(.hidden).background(Color.exBackground)
            .safeAreaInset(edge: .bottom) {
                if onPick != nil {
                    Button(pickedCount == 0 ? "Back to meal" : "Review meal · \(pickedCount) \(pickedCount == 1 ? "food" : "foods")") { dismiss() }
                        .buttonStyle(ExActionStyle()).accessibilityIdentifier("nutrition.reviewPlate")
                        .padding(ExSpacing.page).background(Color.exBackground)
                }
            }
            .navigationTitle(onPick == nil ? "Add food" : "Choose foods").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search food database")
            .onSubmit(of: .search) { Task { await search.search(query) } }
            .onChange(of: query) { _, _ in search.clear() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { search.close(); dismiss() } }
                if onPick == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Search") { hideKeyboard(); Task { await search.search(query) } }
                            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Create food", systemImage: "square.and.pencil") { creating = true }
                            .labelStyle(.iconOnly).accessibilityIdentifier("nutrition.createFood")
                    }
                }
            }
            .sheet(isPresented: $creating, onDismiss: {
                if let createdFood { select(createdFood); self.createdFood = nil }
            }, content: {
                NutritionFoodEditor(workspace: workspace) { createdFood = $0 }
            })
            .sheet(isPresented: $scanningLabel, onDismiss: {
                if let createdFood { select(createdFood); self.createdFood = nil }
            }, content: {
                NutritionLabelCaptureView(workspace: workspace) { createdFood = $0 }
            })
            .sheet(isPresented: $buildingMeal, onDismiss: {
                if didLog { didLog = false; onLogged(); dismiss() }
            }, content: {
                NutritionPlateView(workspace: workspace, api: api, date: date, meal: meal,
                                   timeZone: timeZone, unit: unit, actions: actions) { didLog = true }
            })
            .sheet(item: $selectedFood, onDismiss: {
                if didLog { didLog = false; onLogged(); dismiss() }
            }, content: { food in
                NutritionEntryEditor(workspace: workspace, food: food, date: date, meal: meal,
                                     timeZone: timeZone, unit: unit, actions: actions) { _ in didLog = true }
            })
        }
        .onDisappear { search.clear() }
    }

    @ViewBuilder private var databaseResults: some View {
        if search.isLoading {
            ExCard {
                ExEyebrow("Food database")
                ProgressView("Searching…")
            }
        } else if let error = search.error {
            ExCard {
                ExEyebrow("Food database")
                Text(error).foregroundStyle(Color.exError)
                Button("Try search again") { Task { await search.search(query) } }
            }
        } else if let request = search.request {
            ExCard {
                ExEyebrow("Food database")
                if let result = search.result, !result.foods.isEmpty {
                    ForEach(result.foods) { foodRow($0) }
                    Text(result.attribution).font(.footnote).foregroundStyle(.secondary)
                    Link("Open Food Facts · Open Database License", destination: URL(string: "https://world.openfoodfacts.org/data")!)
                } else {
                    Text("No database foods matched. Try a different name or enter the food label.")
                }
                if case .search(let term) = request {
                    Text("Results for “\(term)”").font(.footnote).foregroundStyle(.secondary)
                }
            }
        } else if !query.isEmpty {
            ExCard {
                Button("Search the food database") { hideKeyboard(); Task { await search.search(query) } }
                Text("Submit a search to look beyond saved foods.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func foodRow(_ food: ExerlyCore.Food) -> some View {
        Button {
            hideKeyboard()
            select(food)
        } label: {
            HStack(spacing: ExSpacing.item) {
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    NutritionFoodRow(food: food, showsIcon: onPick == nil)
                    if onPick != nil && addedIDs.contains(food.id) {
                        Label("Added · Tap to add another", systemImage: "checkmark")
                            .font(.exCaption).foregroundStyle(Color.exPrimaryText)
                    }
                }
                if onPick != nil && !typeSize.isAccessibilitySize {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.exPrimaryText).accessibilityHidden(true)
                }
            }
        }.accessibilityIdentifier("nutrition.\(onPick == nil ? "food" : "platePick").\(food.id)")
            .accessibilityValue(addedIDs.contains(food.id) ? "Added to meal" : "")
            .accessibilityHint(onPick == nil ? "" : "Adds a portion. You can adjust it in the meal review.")
    }

    private func select(_ food: ExerlyCore.Food) {
        guard let onPick else { selectedFood = food; return }
        if let count = onPick(food) {
            pickedCount = count
            addedIDs.insert(food.id)
            selectionError = nil
            UISelectionFeedbackGenerator().selectionChanged()
        } else { selectionError = pickError() ?? "This food could not be added. Review its saved label and try again." }
    }

    private func foodGroup(_ title: String, foods: [ExerlyCore.Food]) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            ExSectionHeading(title)
            ExCard {
                ForEach(foods) { food in
                    foodRow(food)
                    if food.id != foods.last?.id { Divider().overlay(Color.exBorder.opacity(0.3)) }
                }
            }
        }
    }

    private func matches(_ food: ExerlyCore.Food) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty || food.name.localizedCaseInsensitiveContains(term) || (food.brand?.localizedCaseInsensitiveContains(term) ?? false)
    }

    private var favorites: [ExerlyCore.Food] {
        workspace.nutrition.foods.filter { $0.favorite && $0.archivedAt == nil && matches($0) }
    }

    private var recents: [ExerlyCore.Food] {
        let favoriteIDs = Set(favorites.map(\.id))
        return workspace.nutrition.recentFoods().compactMap { snapshot in
            guard snapshot.unweighed != true, !favoriteIDs.contains(snapshot.foodID) else { return nil }
            let saved = workspace.nutrition.food(snapshot.foodID)
            guard saved?.archivedAt == nil else { return nil }
            let last = workspace.nutrition.entries.last { $0.food.foodID == snapshot.foodID }
            let food = saved ?? snapshot.foodForLogging(serving: last?.serving)
            return matches(food) ? food : nil
        }
    }

    private var otherSaved: [ExerlyCore.Food] {
        let shown = Set((favorites + recents).map(\.id))
        return workspace.nutrition.foods.filter { $0.archivedAt == nil && !shown.contains($0.id) && matches($0) }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
