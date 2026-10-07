import ExerlyCore
import SwiftUI

struct NutritionFoodPicker: View {
    let workspace: TrainingWorkspace
    let api: AccountAPI
    let date: LocalDate
    let meal: String
    let timeZone: TimeZone
    @ObservedObject var actions: NutritionDiaryActions
    let onLogged: () -> Void
    @StateObject private var search: NutritionSearchModel
    @State private var query = ""
    @State private var selectedFood: ExerlyCore.Food?
    @State private var createdFood: ExerlyCore.Food?
    @State private var creating = false
    @State private var didLog = false
    @Environment(\.dismiss) private var dismiss

    init(workspace: TrainingWorkspace, api: AccountAPI, date: LocalDate, meal: String,
         timeZone: TimeZone, actions: NutritionDiaryActions, onLogged: @escaping () -> Void) {
        self.workspace = workspace
        self.api = api
        self.date = date
        self.meal = meal
        self.timeZone = timeZone
        self.actions = actions
        self.onLogged = onLogged
        _search = StateObject(wrappedValue: NutritionSearchModel(api: api))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Enter a food label", systemImage: "square.and.pencil") { creating = true }
                        .accessibilityIdentifier("nutrition.createFood")
                    NavigationLink {
                        NutritionBarcodeView(workspace: workspace, api: api, date: date, meal: meal,
                                             timeZone: timeZone, actions: actions) {
                            onLogged()
                            dismiss()
                        }
                    } label: { Label("Scan or enter a barcode", systemImage: "barcode.viewfinder") }
                    .accessibilityIdentifier("nutrition.barcode")
                } footer: {
                    Text("Adding to \(meal) · \(date.description). Saved foods work offline.")
                }
                if !favorites.isEmpty {
                    Section("Favorites") { ForEach(favorites) { foodRow($0) } }
                }
                if !recents.isEmpty {
                    Section("Recently logged") { ForEach(recents) { foodRow($0) } }
                }
                if !otherSaved.isEmpty {
                    Section("Saved foods") { ForEach(otherSaved) { foodRow($0) } }
                }
                databaseResults
                if query.isEmpty && favorites.isEmpty && recents.isEmpty && otherSaved.isEmpty {
                    Section {
                        Text("Your food library is empty. Enter a label, scan a barcode, or search the food database.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Color.exBackground)
            .navigationTitle("Add food").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search food database")
            .onSubmit(of: .search) { Task { await search.search(query) } }
            .onChange(of: query) { _, _ in search.clear() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { search.close(); dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Search") { hideKeyboard(); Task { await search.search(query) } }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $creating, onDismiss: {
                if let createdFood { selectedFood = createdFood; self.createdFood = nil }
            }, content: {
                NutritionFoodEditor(workspace: workspace) { createdFood = $0 }
            })
            .sheet(item: $selectedFood, onDismiss: {
                if didLog { didLog = false; onLogged(); dismiss() }
            }, content: { food in
                NutritionEntryEditor(workspace: workspace, food: food, date: date, meal: meal,
                                     timeZone: timeZone, actions: actions) { _ in didLog = true }
            })
        }
        .onDisappear { search.clear() }
    }

    @ViewBuilder private var databaseResults: some View {
        if search.isLoading {
            Section("Food database") { ProgressView("Searching…") }
        } else if let error = search.error {
            Section("Food database") {
                Text(error).foregroundStyle(Color.exError)
                Button("Try search again") { Task { await search.search(query) } }
            }
        } else if let request = search.request {
            Section("Food database") {
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
            Section {
                Button("Search the food database") { hideKeyboard(); Task { await search.search(query) } }
                Text("Submit a search to look beyond saved foods.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func foodRow(_ food: ExerlyCore.Food) -> some View {
        Button {
            hideKeyboard()
            selectedFood = food
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(food.name).font(.headline).foregroundStyle(Color.exTextPrimary)
                if let brand = food.brand { Text(brand).foregroundStyle(Color.exTextSecondary) }
                Text(NutritionFormat.source(food.source)).font(.caption).foregroundStyle(Color.exTextSecondary)
            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityIdentifier("nutrition.food.\(food.id)")
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
            guard !favoriteIDs.contains(snapshot.foodID) else { return nil }
            let saved = workspace.nutrition.food(snapshot.foodID)
            guard saved?.archivedAt == nil else { return nil }
            let last = workspace.nutrition.entries.last { $0.food.foodID == snapshot.foodID }
            let food = saved ?? ExerlyCore.Food(id: snapshot.foodID, name: snapshot.name, brand: snapshot.brand,
                source: snapshot.source, per100g: snapshot.per100g, servings: last?.serving.map { [$0] } ?? [])
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
