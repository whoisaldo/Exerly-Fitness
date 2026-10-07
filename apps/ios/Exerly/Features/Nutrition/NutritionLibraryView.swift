import ExerlyCore
import SwiftUI

struct NutritionLibraryHostView: View {
    let accountID: String
    let timeZone: TimeZone
    @EnvironmentObject private var account: AppAccountWorkspace
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            if let workspace = account.training, workspace.accountID == accountID {
                NutritionLibraryView(workspace: workspace, timeZone: timeZone).id(workspace.identity)
            } else if account.openingError != nil {
                ContentUnavailableView {
                    Label("Food library could not open", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved data is still on this device. Keep Exerly installed and try again.")
                } actions: {
                    Button("Try again") { Task { await account.configure(auth.accountAPI) } }.buttonStyle(.borderedProminent)
                }
            } else { ProgressView("Opening food library…") }
        }
    }
}

struct NutritionLibraryView: View {
    @ObservedObject var workspace: TrainingWorkspace
    let timeZone: TimeZone
    @State private var query = ""
    @State private var creating = false
    @State private var showArchived = false

    var body: some View {
        List {
            Section {
                Text("Your saved labels and favorites work offline. Earlier diary entries keep the label you logged.")
                    .font(.footnote).foregroundStyle(.secondary)
                Toggle("Show archived foods", isOn: $showArchived)
                    .accessibilityIdentifier("nutrition.showArchived")
            }
            if visibleFoods.isEmpty {
                ContentUnavailableView(query.isEmpty ? "No saved foods" : "No matching foods", systemImage: "book.closed",
                                       description: Text("Create a food label, or save a favorite when adding food to your diary."))
            } else {
                Section(showArchived ? "Archived foods" : "Saved foods") {
                    ForEach(visibleFoods) { food in
                        NavigationLink {
                            NutritionLibraryDetail(workspace: workspace, foodID: food.id, timeZone: timeZone)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(food.name).font(.headline).foregroundStyle(Color.exTextPrimary)
                                if let brand = food.brand { Text(brand).foregroundStyle(Color.exTextSecondary) }
                                HStack {
                                    Text(NutritionFormat.source(food.source))
                                    if food.favorite { Label("Favorite", systemImage: "star.fill") }
                                }.font(.caption).foregroundStyle(Color.exTextSecondary)
                            }.fixedSize(horizontal: false, vertical: true)
                        }.accessibilityIdentifier("nutrition.libraryFood.\(food.id)")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).background(Color.exBackground)
        .navigationTitle("Food library").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Find a saved food")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Create food", systemImage: "plus") { creating = true }
                    .accessibilityIdentifier("nutrition.libraryCreate")
            }
        }
        .sheet(isPresented: $creating) { NutritionFoodEditor(workspace: workspace) { _ in } }
    }

    private var visibleFoods: [ExerlyCore.Food] {
        workspace.nutrition.foods.filter {
            ($0.archivedAt != nil) == showArchived &&
                (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || ($0.brand?.localizedCaseInsensitiveContains(query) ?? false))
        }.sorted {
            if $0.favorite != $1.favorite { return $0.favorite }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

private struct NutritionLibraryDetail: View {
    @ObservedObject var workspace: TrainingWorkspace
    let foodID: String
    let timeZone: TimeZone
    @StateObject private var actions: NutritionLibraryActions
    @StateObject private var diaryActions: NutritionDiaryActions
    @State private var destination: Destination?
    @State private var logged: FoodEntry?
    @AccessibilityFocusState private var errorFocused: Bool

    private enum Destination: Identifiable {
        case edit(ExerlyCore.Food), log(ExerlyCore.Food), archive(ExerlyCore.Food)
        var id: String {
            switch self {
            case .edit(let food): "edit-\(food.id)"
            case .log(let food): "log-\(food.id)"
            case .archive(let food): "archive-\(food.id)"
            }
        }
    }

    init(workspace: TrainingWorkspace, foodID: String, timeZone: TimeZone) {
        self.workspace = workspace
        self.foodID = foodID
        self.timeZone = timeZone
        _actions = StateObject(wrappedValue: NutritionLibraryActions(store: workspace.nutrition))
        _diaryActions = StateObject(wrappedValue: NutritionDiaryActions(store: workspace.nutrition))
    }

    var body: some View {
        List {
            if let food = workspace.nutrition.food(foodID) {
                Section {
                    Text(food.name).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    if let brand = food.brand { Text(brand).foregroundStyle(.secondary) }
                    Text(NutritionFormat.source(food.source)).foregroundStyle(.secondary)
                    if food.archivedAt != nil { Label("Archived", systemImage: "archivebox") }
                }
                if let error = actions.error {
                    Section { Text(error).foregroundStyle(Color.exError).accessibilityFocused($errorFocused) }
                }
                if let logged {
                    Section {
                        Text("Logged \(NutritionFormat.portion(logged)) to \(logged.meal), \(logged.date.description).")
                            .accessibilityIdentifier("nutrition.libraryLogged")
                    }
                }
                Section {
                    if food.archivedAt == nil {
                        Button("Log this food", systemImage: "plus") { destination = .log(food) }
                            .accessibilityIdentifier("nutrition.libraryLog")
                        Button(food.favorite ? "Remove from favorites" : "Add to favorites", systemImage: food.favorite ? "star.slash" : "star") {
                            if actions.setFavorite(!food.favorite, reviewed: food) { sync() }
                        }.accessibilityIdentifier("nutrition.libraryFavorite")
                        if food.source == .custom || food.source == .imported {
                            Button("Edit food label", systemImage: "square.and.pencil") { destination = .edit(food) }
                                .accessibilityIdentifier("nutrition.libraryEdit")
                        }
                    }
                    Button(food.archivedAt == nil ? "Archive food" : "Restore food", systemImage: "archivebox") {
                        actions.clearError()
                        destination = .archive(food)
                    }.accessibilityIdentifier("nutrition.libraryArchive")
                }
                Section("Per 100 g") { NutritionAmountsView(amounts: food.per100g) }
                if !food.servings.isEmpty {
                    Section("Named servings") {
                        ForEach(food.servings, id: \.self) { Text("\($0.name) · \(TrainingFormat.number($0.grams)) g") }
                    }
                }
                if let volume = food.volume {
                    Section("Volume label") {
                        Text("Density: \(TrainingFormat.number(volume.density)) g/ml\(volume.assumed ? " (estimated)" : "")")
                        if let note = volume.note { Text(note).foregroundStyle(.secondary) }
                    }
                }
                if food.source == .openFoodFacts {
                    Section { Link("Open Food Facts · Open Database License", destination: URL(string: "https://world.openfoodfacts.org/data")!) }
                } else if food.source == .usda {
                    Section { Link("USDA FoodData Central · Public domain", destination: URL(string: "https://fdc.nal.usda.gov/")!) }
                }
            } else {
                ContentUnavailableView("Food is no longer available", systemImage: "book.closed")
            }
        }
        .scrollContentBackground(.hidden).background(Color.exBackground)
        .navigationTitle("Saved food").navigationBarTitleDisplayMode(.inline)
        .onChange(of: actions.error) { _, error in errorFocused = error != nil }
        .sheet(item: $destination) { destination in
            switch destination {
            case .edit(let food): NutritionFoodEditor(workspace: workspace, editing: food) { _ in }
            case .log(let food):
                NutritionEntryEditor(workspace: workspace, food: food, date: LocalDate(Date(), in: timeZone),
                                     meal: workspace.nutrition.entries.last?.meal ?? "Snacks", timeZone: timeZone,
                                     actions: diaryActions) { logged = $0 }
            case .archive(let food):
                let restoring = food.archivedAt != nil
                NutritionConfirmation(title: "\(restoring ? "Restore" : "Archive") \(food.name)?",
                    message: restoring ? "This food will return to your saved foods. Existing diary entries stay unchanged." :
                        "This food will be hidden from your saved foods and diary picker. Existing diary entries stay unchanged. You can restore it later.",
                    confirm: restoring ? "Restore food" : "Archive food") {
                    self.destination = nil
                    if restoring ? actions.restore(reviewed: food) : actions.archive(reviewed: food) { sync() }
                } cancel: { self.destination = nil }
            }
        }
    }

    private func sync() { Task { await workspace.synchronize() } }
}
