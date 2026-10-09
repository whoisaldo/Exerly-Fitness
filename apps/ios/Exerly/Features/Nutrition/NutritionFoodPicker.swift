import ExerlyCore
import SwiftUI

/// How the food picker is shown. As a sheet it closes after a portion is
/// logged; as the root of the search tab it stays and confirms each log.
enum FoodPickerPresentation { case sheet, tab }

struct NutritionFoodPicker: View {
    let workspace: TrainingWorkspace
    let api: AccountAPI
    let date: LocalDate
    let timeZone: TimeZone
    let unit: MassUnit
    @ObservedObject var actions: NutritionDiaryActions
    let onLogged: () -> Void
    let onPick: ((ExerlyCore.Food) -> Int?)?
    let pickError: () -> String?
    let presentation: FoodPickerPresentation
    @StateObject private var search: NutritionSearchModel
    @State private var meal: String
    @State private var query = ""
    @State private var scope = FoodListScope.recent
    @State private var shelf = FoodShelf()
    @State private var selectedFood: ExerlyCore.Food?
    @State private var createdFood: ExerlyCore.Food?
    @State private var creating = false
    @State private var scanningLabel = false
    @State private var quickAdding = false
    @State private var buildingMeal = false
    @State private var showingBarcode: Bool
    @State private var pickedCount: Int
    @State private var addedIDs: Set<String>
    @State private var selectionError: String?
    @State private var sheetLogged: [FoodEntry]?
    @State private var confirmation: LoggedConfirmation?
    @State private var justLogged: Set<String> = []
    @State private var logError: String?
    @State private var loggedCount = 0
    @State private var openedOnce = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    init(workspace: TrainingWorkspace, api: AccountAPI, date: LocalDate, meal: String,
         timeZone: TimeZone, unit: MassUnit, actions: NutritionDiaryActions, onLogged: @escaping () -> Void,
         startsWithBarcode: Bool = false, pickedCount: Int = 0, pickedFoodIDs: Set<String> = [], onPick: ((ExerlyCore.Food) -> Int?)? = nil,
         pickError: @escaping () -> String? = { nil }, presentation: FoodPickerPresentation = .sheet) {
        self.workspace = workspace
        self.api = api
        self.date = date
        self.timeZone = timeZone
        self.unit = unit
        self.actions = actions
        self.onLogged = onLogged
        self.onPick = onPick
        self.pickError = pickError
        self.presentation = presentation
        _meal = State(initialValue: presentation == .tab ? workspace.nutrition.suggestedMeal(at: .now, timeZone: timeZone) : meal)
        _showingBarcode = State(initialValue: startsWithBarcode)
        _pickedCount = State(initialValue: pickedCount)
        _addedIDs = State(initialValue: pickedFoodIDs)
        _search = StateObject(wrappedValue: NutritionSearchModel(api: api))
    }

    var body: some View {
        NavigationStack {
            ExScreen {
                header
                if trimmedQuery.isEmpty { browsing } else { searching }
            }
            .scrollDismissesKeyboard(.immediately)
            .overlay(alignment: .bottom) { toast }
            .safeAreaInset(edge: .bottom) {
                if picking {
                    Button(pickedCount == 0 ? "Back to meal" : "Review meal · \(pickedCount) \(pickedCount == 1 ? "food" : "foods")") { dismiss() }
                        .buttonStyle(ExActionStyle()).accessibilityIdentifier("nutrition.reviewPlate")
                        .padding(ExSpacing.page).background(Color.exBackground)
                }
            }
            .navigationTitle(picking ? "Choose foods" : "Add food").navigationBarTitleDisplayMode(.inline)
            .modifier(FoodSearchField(text: $query, presentation: presentation))
            .onSubmit(of: .search) { Task { await search.search(query) } }
            .onChange(of: query) { _, text in search.type(text) }
            .toolbar { toolbar }
            .sensoryFeedback(.success, trigger: loggedCount)
            .navigationDestination(isPresented: $showingBarcode) {
                NutritionBarcodeView(workspace: workspace, api: api, date: date, meal: meal,
                                     timeZone: timeZone, unit: unit, actions: actions,
                                     onPicked: picking ? { select($0) } : nil) { entry in
                    showingBarcode = false
                    finish([entry])
                }
            }
            .sheet(isPresented: $creating, onDismiss: openCreatedFood) {
                NutritionFoodEditor(workspace: workspace) { createdFood = $0 }
            }
            .sheet(isPresented: $scanningLabel, onDismiss: openCreatedFood) {
                NutritionLabelCaptureView(workspace: workspace) { createdFood = $0 }
            }
            .sheet(isPresented: $buildingMeal, onDismiss: finishSheet) {
                NutritionPlateView(workspace: workspace, api: api, date: date, meal: meal,
                                   timeZone: timeZone, unit: unit, actions: actions, onLogged: {}) { sheetLogged = $0 }
            }
            .sheet(isPresented: $quickAdding, onDismiss: finishSheet) {
                NutritionQuickAddView(workspace: workspace, date: date, meal: meal, timeZone: timeZone, onLogged: {}) {
                    sheetLogged = [$0]
                }
            }
            .sheet(item: $selectedFood, onDismiss: finishSheet) { food in
                NutritionEntryEditor(workspace: workspace, food: food, date: date, meal: meal,
                                     timeZone: timeZone, unit: unit, actions: actions) { sheetLogged = [$0] }
            }
        }
        .onAppear(perform: refresh)
        .onDisappear { search.clear() }
    }

    // MARK: Layout

    private var picking: Bool { onPick != nil }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var store: NutritionStore { workspace.nutrition }

    @ViewBuilder private var header: some View {
        if picking {
            VStack(alignment: .leading, spacing: ExSpacing.small) {
                Text("Tap foods to add them, then review portions.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                if let selectionError { Text(selectionError).font(.exCaption).foregroundStyle(Color.exError) }
            }
        } else {
            VStack(alignment: .leading, spacing: ExSpacing.tight) {
                if date != LocalDate(.now, in: timeZone) {
                    Label("Logging to \(NutritionFormat.day(date, timeZone: timeZone))", systemImage: "calendar")
                        .font(.exCaption.weight(.medium)).foregroundStyle(Color.exPrimaryText)
                        .accessibilityIdentifier("nutrition.pickerDate")
                }
                FoodMealSelector(meals: meals, selection: $meal)
            }
        }
        if let logError {
            Text(logError).font(.exCaption).foregroundStyle(Color.exError).accessibilityIdentifier("nutrition.logError")
        }
    }

    @ViewBuilder private var browsing: some View {
        if typeSize.isAccessibilitySize {
            // At the largest sizes the foods come first: Barcode and a compact
            // list choice above them, the other tools below.
            barcodeButton(prominent: true)
            scopeMenu
        } else {
            HStack(spacing: ExSpacing.small) { toolButtons(compact: false) }
            ExSegmentedControl(values: FoodListScope.allCases, selection: $scope) { $0.title }
                .accessibilityElement(children: .contain).accessibilityIdentifier("nutrition.listScope")
        }
        scopeContent
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: ExSpacing.small) {
                ExEyebrow("More ways to log")
                otherTools
            }.padding(.top, ExSpacing.small)
        }
    }

    private var scopeMenu: some View {
        Menu {
            Picker("Show", selection: $scope) {
                ForEach(FoodListScope.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        } label: {
            HStack {
                Text("Showing \(scope.title)").font(.exBodyMedium).multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.exCaption)
            }.foregroundStyle(Color.exPrimaryText).frame(minHeight: 44).contentShape(Rectangle())
        }.accessibilityIdentifier("nutrition.listScope")
    }

    @ViewBuilder private var scopeContent: some View {
        switch scope {
        case .recent:
            if shelf.suggested.isEmpty && shelf.recent.isEmpty {
                emptyMessage("Your foods come back here", "Search, scan or quick add your first food. Next time it's one tap away, with the amount you had.")
            } else {
                if !shelf.suggested.isEmpty { group(suggestedTitle, shelf.suggested, id: "suggested") }
                if !shelf.recent.isEmpty { group("Recent", shelf.recent, id: "recent") }
            }
        case .favorites:
            let favorites = savedItems { $0.favorite }
            if favorites.isEmpty {
                emptyMessage("No favorites yet", "Open any food and tap the star to keep it here.")
            } else { group("Favorites", favorites, id: "favorites") }
        case .mine:
            let mine = savedItems { _ in true }
            Button { creating = true } label: {
                Label("Create a food", systemImage: "plus").font(.exLabel)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(Color.exPrimaryText).accessibilityIdentifier("nutrition.createFoodRow")
            if mine.isEmpty {
                emptyMessage("Nothing saved yet", "Foods you create, recipes, and foods you star are kept here, ready offline.")
            } else { group("Saved foods", mine, id: "mine") }
        }
    }

    @ViewBuilder private var searching: some View {
        let local = localMatches
        if !local.isEmpty { group("Your foods", local, id: "local") }
        databaseSection(excluding: Set(local.map(\.id)))
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            ExEyebrow("Can't find it?")
            if typeSize.isAccessibilitySize {
                barcodeButton(prominent: false)
                otherTools
            } else {
                HStack(spacing: ExSpacing.small) { toolButtons(compact: true) }
            }
        }.padding(.top, ExSpacing.small)
    }

    @ViewBuilder private func toolButtons(compact: Bool) -> some View {
        barcodeButton(prominent: !compact)
        otherTools
    }

    private func barcodeButton(prominent: Bool) -> some View {
        FoodToolButton(title: typeSize.isAccessibilitySize ? "Scan barcode" : "Barcode", icon: "barcode.viewfinder", prominent: prominent,
                       identifier: picking ? "nutrition.plateBarcode" : "nutrition.barcode") {
            hideKeyboard(); showingBarcode = true
        }.accessibilityLabel("Scan barcode")
    }

    @ViewBuilder private var otherTools: some View {
        FoodToolButton(title: "Label", icon: "text.viewfinder", identifier: "nutrition.scanLabel") {
            hideKeyboard(); scanningLabel = true
        }.accessibilityLabel("Scan nutrition label")
        if !picking {
            FoodToolButton(title: "Quick add", icon: "bolt.fill", identifier: "nutrition.quickAdd") {
                hideKeyboard(); quickAdding = true
            }.accessibilityLabel("Quick add calories and macros")
        }
        FoodToolButton(title: "New food", icon: "square.and.pencil", identifier: "nutrition.createFood") {
            hideKeyboard(); creating = true
        }.accessibilityLabel("Enter a food manually")
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if presentation == .sheet {
            ToolbarItem(placement: .cancellationAction) {
                Button(confirmation != nil || loggedCount > 0 ? "Done" : "Cancel") { search.close(); dismiss() }
                    .accessibilityIdentifier("nutrition.closePicker")
            }
        }
        if !picking {
            ToolbarItem(placement: .primaryAction) {
                Menu("More ways to log", systemImage: "ellipsis") {
                    Button("Build a meal from several foods", systemImage: "plus.rectangle.on.rectangle") { buildingMeal = true }
                        .accessibilityIdentifier("nutrition.buildMeal")
                }.accessibilityIdentifier("nutrition.moreFoodOptions")
            }
        }
    }

    @ViewBuilder private func databaseSection(excluding local: Set<String>) -> some View {
        let foods = (search.result?.foods ?? []).filter { !local.contains($0.id) }
        let items = foods.compactMap { food in store.quickPortion(for: food, unit: unit).map { FoodPickerItem(portion: $0, food: food) } }
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            HStack(spacing: ExSpacing.small) {
                ExEyebrow("Food database")
                if search.isLoading { ProgressView().controlSize(.small).accessibilityLabel("Searching the food database") }
                Spacer(minLength: 0)
            }
            if let error = search.error {
                ExCard {
                    Text(error).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    Button("Try again") { Task { await search.search(query) } }.font(.exLabel).frame(minHeight: 44)
                        .accessibilityIdentifier("nutrition.retrySearch")
                }
            } else if !items.isEmpty {
                ExCard { rows(items) }.accessibilityElement(children: .contain).accessibilityIdentifier("nutrition.databaseResults")
                if let attribution = search.result?.attribution {
                    Text(attribution).font(.exSmall).foregroundStyle(Color.exTextMuted)
                }
                Link("Open Food Facts · Open Database License", destination: URL(string: "https://world.openfoodfacts.org/data")!)
                    .font(.exSmall)
            } else if search.shownQuery == trimmedQuery, !search.isLoading {
                Text("No database foods matched “\(trimmedQuery)”. Try another name, or scan the package.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            } else if trimmedQuery.count < NutritionSearchModel.typeAheadMinimum, !search.isLoading {
                Text("Keep typing to search the food database.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
        }
    }

    private func group(_ title: String, _ items: [FoodPickerItem], id: String) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            ExEyebrow(title).accessibilityAddTraits(.isHeader)
            ExCard { rows(items) }.accessibilityElement(children: .contain).accessibilityIdentifier("nutrition.group.\(id)")
        }
    }

    @ViewBuilder private func rows(_ items: [FoodPickerItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                row(item)
                if item.id != items.last?.id { Divider().overlay(Color.exBorder.opacity(0.35)) }
            }
        }.padding(.vertical, -6)
    }

    private func row(_ item: FoodPickerItem) -> some View {
        let portion = FoodFormat.portion(item.portion, unit: unit)
        let detail = [portion, FoodFormat.origin(of: item.portion.food)].compactMap { $0 }.joined(separator: " · ")
        let done = picking ? addedIDs.contains(item.id) : justLogged.contains(item.id)
        return FoodQuickRow(name: item.portion.food.name, detail: detail, amounts: item.portion.nutrients,
                            openHint: picking ? "Adds a portion. You can adjust it in the meal review." : "Opens the portion to adjust it",
                            openIdentifier: "nutrition.\(picking ? "platePick" : "food").\(item.id)",
                            open: { hideKeyboard(); if picking { select(item.food) } else { selectedFood = item.food } },
                            add: FoodAddButton(done: done,
                                               label: picking ? "Add \(item.portion.food.name) to the meal" : "Log \(portion) of \(item.portion.food.name) to \(meal)",
                                               identifier: "nutrition.\(picking ? "plateAdd" : "quickLog").\(item.id)") {
                                if picking { select(item.food) } else { quickLog(item) }
                            })
    }

    private func emptyMessage(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            Text(title).font(.exH3).foregroundStyle(Color.exTextPrimary)
            Text(message).font(.exBody).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.top, ExSpacing.small).accessibilityElement(children: .combine)
    }

    @ViewBuilder private var toast: some View {
        if let confirmation {
            FoodLoggedToast(title: confirmation.title, detail: confirmation.detail) { undo(confirmation) }
                .padding(.bottom, ExSpacing.small)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(confirmation.id)
                .task(id: confirmation.id) {
                    // VoiceOver users get the confirmation until they move on.
                    guard !UIAccessibility.isVoiceOverRunning else { return }
                    try? await Task.sleep(for: .seconds(8))
                    guard !Task.isCancelled else { return }
                    withAnimation(.snappy) { if self.confirmation?.id == confirmation.id { self.confirmation = nil } }
                }
        }
    }

    // MARK: Lists

    private var meals: [String] {
        NutritionStore.defaultMeals.contains(meal) ? NutritionStore.defaultMeals : NutritionStore.defaultMeals + [meal]
    }

    private var suggestedTitle: String {
        "Usual around \(Date.now.formatted(Date.FormatStyle(timeZone: timeZone).hour()))"
    }

    /// Recent and suggested foods are fixed when the screen opens, so rows
    /// don't move under a finger as foods are logged.
    private func refresh() {
        if presentation == .tab { meal = store.suggestedMeal(at: .now, timeZone: timeZone) }
        let suggested = store.suggestions(at: .now, timeZone: timeZone, limit: 5)
            .filter { $0.food.unweighed != true }
            .map { suggestion in
                FoodPickerItem(portion: QuickPortion(suggestion),
                               food: store.food(suggestion.food.foodID) ?? suggestion.food.foodForLogging(serving: suggestion.serving))
            }
        let suggestedIDs = Set(suggested.map(\.id))
        let recent = store.recentPortions(limit: 30).filter { !suggestedIDs.contains($0.id) }.map(item)
        shelf = FoodShelf(suggested: suggested, recent: recent)
        // With nothing logged yet, open on the foods already saved.
        if !openedOnce {
            openedOnce = true
            if suggested.isEmpty && recent.isEmpty && store.foods.contains(where: { $0.archivedAt == nil }) { scope = .mine }
        }
        // Results are dropped while the screen is away; bring back the ones
        // for a search still typed (from the cache when they were fetched).
        if !trimmedQuery.isEmpty { search.type(query) }
    }

    private func item(_ portion: QuickPortion) -> FoodPickerItem {
        FoodPickerItem(portion: portion, food: store.food(portion.id) ?? portion.food.foodForLogging(serving: portion.serving))
    }

    private func savedItems(_ include: (ExerlyCore.Food) -> Bool) -> [FoodPickerItem] {
        store.foods.filter { $0.archivedAt == nil && include($0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .compactMap { food in store.quickPortion(for: food, unit: unit).map { FoodPickerItem(portion: $0, food: food) } }
    }

    /// Foods already on this device that match the search: history first,
    /// then saved foods. They need no connection.
    private var localMatches: [FoodPickerItem] {
        let term = trimmedQuery
        func matches(_ name: String, _ brand: String?) -> Bool {
            name.localizedCaseInsensitiveContains(term) || (brand?.localizedCaseInsensitiveContains(term) ?? false)
        }
        var seen = Set<String>()
        let history = store.recentPortions(limit: 200).filter { matches($0.food.name, $0.food.brand) }.map(item)
        let saved = savedItems { matches($0.name, $0.brand) }
        return (history + saved).filter { seen.insert($0.id).inserted }.prefix(12).map { $0 }
    }

    // MARK: Actions

    private func quickLog(_ item: FoodPickerItem) {
        logError = nil
        do {
            let entry = try store.log(item.portion, on: date, meal: meal)
            withAnimation(.snappy) { _ = justLogged.insert(item.id) }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.snappy) { _ = justLogged.remove(item.id) }
            }
            confirm([entry])
            onLogged()
            Task { await workspace.synchronize() }
        } catch {
            logError = "Couldn't log \(item.portion.food.name). Nothing was saved. Open it to check the portion."
        }
    }

    /// Shows "Logged · Undo". The haptic is skipped when the sheet that
    /// logged the food already gave one.
    private func confirm(_ entries: [FoodEntry], haptic: Bool = true) {
        guard let first = entries.first else { return }
        let energy = entries.reduce(0) { $0 + $1.nutrients.energy }
        var detail = "\(FoodFormat.kcal(energy)) kcal · \(first.meal)"
        if first.date != LocalDate(.now, in: timeZone) { detail += ", \(NutritionFormat.day(first.date, timeZone: timeZone))" }
        if let left = store.progress(on: first.date).energy.remaining { detail += " · \(FoodFormat.kcal(left)) left" }
        let title = entries.count == 1 ? "Logged \(first.food.name)" : "Logged \(entries.count) foods"
        if haptic { loggedCount += 1 }
        withAnimation(.snappy) { confirmation = LoggedConfirmation(entries: entries, title: title, detail: detail) }
    }

    private func undo(_ logged: LoggedConfirmation) {
        logError = nil
        let current = logged.entries.filter { entry in store.entries.first { $0.id == entry.id } == entry }
        do {
            for entry in current { try store.deleteEntry(entry.id) }
            if current.count < logged.entries.count {
                logError = "Some of these entries changed after logging. Review them in today's log."
            }
        } catch {
            logError = "Couldn't undo. The food is still logged; remove it from today's log."
        }
        withAnimation(.snappy) { confirmation = nil; justLogged.subtract(logged.entries.map(\.food.foodID)) }
        Task { await workspace.synchronize() }
    }

    /// A portion, quick add or meal was logged in a sheet: a sheet picker
    /// closes, the search tab stays and confirms.
    private func finishSheet() {
        guard let entries = sheetLogged else { return }
        sheetLogged = nil
        finish(entries)
    }

    private func finish(_ entries: [FoodEntry]) {
        onLogged()
        if presentation == .sheet {
            search.close()
            dismiss()
        } else {
            confirm(entries, haptic: false)
        }
    }

    private func openCreatedFood() {
        guard let createdFood else { return }
        self.createdFood = nil
        select(createdFood)
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

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

enum FoodListScope: String, CaseIterable, Hashable {
    case recent, favorites, mine
    var title: String {
        switch self {
        case .recent: "Recent"
        case .favorites: "Favorites"
        case .mine: "My foods"
        }
    }
}

struct FoodPickerItem: Identifiable {
    let portion: QuickPortion
    /// The food the portion sheet opens with.
    let food: ExerlyCore.Food
    var id: String { portion.id }
}

private struct FoodShelf {
    var suggested: [FoodPickerItem] = []
    var recent: [FoodPickerItem] = []
}

private struct LoggedConfirmation: Identifiable {
    let id = UUID()
    let entries: [FoodEntry]
    let title: String
    let detail: String
}

/// As a sheet the search field stays under the title; in the search tab,
/// iOS places it in the tab bar.
private struct FoodSearchField: ViewModifier {
    @Binding var text: String
    let presentation: FoodPickerPresentation

    func body(content: Content) -> some View {
        switch presentation {
        case .sheet:
            content.searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
        case .tab:
            content.searchable(text: $text, prompt: "Search foods")
        }
    }
}
