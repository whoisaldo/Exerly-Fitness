import ExerlyCore
import SwiftUI

struct NutritionHostView: View {
    let accountID: String
    let unit: MassUnit
    let timeZone: TimeZone
    @EnvironmentObject private var account: AppAccountWorkspace
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            if let workspace = account.training, workspace.accountID == accountID,
               let api = auth.accountAPI, api.accountID == accountID {
                NutritionDiaryView(workspace: workspace, api: api, unit: unit, timeZone: timeZone).id(workspace.identity)
            } else if account.openingError != nil {
                ContentUnavailableView {
                    Label("Diary could not open", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved data is still on this device. Keep Exerly installed and try again.")
                } actions: {
                    Button("Try again") { Task { await account.configure(auth.accountAPI) } }.buttonStyle(.borderedProminent)
                }
            } else { ProgressView("Opening diary…") }
        }
    }
}

struct NutritionDiaryView: View {
    @ObservedObject var workspace: TrainingWorkspace
    let api: AccountAPI
    let unit: MassUnit
    let timeZone: TimeZone
    @State private var date: LocalDate
    @State private var destination: Destination?
    @StateObject private var actions: NutritionDiaryActions
    @AccessibilityFocusState private var errorFocused: Bool

    private struct StatusReview {
        let desired: DayStatus
        let day: NutritionDay
        let entries: [FoodEntry]
    }

    private enum Destination: Identifiable {
        case date, add(LocalDate, String), edit(FoodEntry), notes(LocalDate), copy(LocalDate, String?), status(StatusReview)
        var id: String {
            switch self {
            case .date: "date"
            case .add(let date, let meal): "add-\(date)-\(meal)"
            case .edit(let entry): "edit-\(entry.id)"
            case .notes(let date): "notes-\(date)"
            case .copy(let date, let meal): "copy-\(date)-\(meal ?? "all")"
            case .status(let review): "status-\(review.day.date)-\(review.desired.rawValue)"
            }
        }
    }

    init(workspace: TrainingWorkspace, api: AccountAPI, unit: MassUnit, timeZone: TimeZone) {
        self.workspace = workspace
        self.api = api
        self.unit = unit
        self.timeZone = timeZone
        _date = State(initialValue: LocalDate(Date(), in: timeZone))
        _actions = StateObject(wrappedValue: NutritionDiaryActions(store: workspace.nutrition))
    }

    var body: some View {
        ScrollViewReader { scroll in
            List {
                Section { dateNavigation }
                if let error = actions.error {
                    Section {
                        Text(error).foregroundStyle(Color.exError).accessibilityFocused($errorFocused)
                        Button("Dismiss message") { actions.clearError() }
                    }.id("errors")
                }
                if let deleted = actions.deleted {
                    Section {
                        Text("Removed \(deleted.food.name) from \(deleted.meal), \(deleted.date.description).")
                        Button("Undo food deletion") {
                            if actions.undoDeletion() { Task { await workspace.synchronize() } }
                        }.accessibilityIdentifier("nutrition.undoDelete")
                    }
                }
                Section("Logged nutrition") {
                    NutritionDailySummary(amounts: store.summary(on: date).totals, targets: store.targets(on: date))
                    DisclosureGroup("All nutrients") { NutritionAmountsView(amounts: store.summary(on: date).totals) }
                    Text("Totals include only nutrients reported by each food. A missing value does not mean zero.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Logging status") {
                    Menu {
                        ForEach(DayStatus.allCases, id: \.self) { status in
                            Button(NutritionFormat.status(status)) {
                                actions.clearError()
                                destination = .status(StatusReview(desired: status, day: store.day(date), entries: store.entries(on: date)))
                            }.accessibilityIdentifier("nutrition.status.\(status.rawValue)")
                        }
                    } label: {
                        Label(NutritionFormat.status(store.day(date).status), systemImage: "checklist")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }.accessibilityIdentifier("nutrition.dayStatus")
                    Text(NutritionFormat.statusDescription(store.day(date).status)).font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(meals, id: \.self) { mealSection($0) }
                Section("Day note") {
                    if !store.day(date).notes.isEmpty { Text(store.day(date).notes).fixedSize(horizontal: false, vertical: true) }
                    Button(store.day(date).notes.isEmpty ? "Add a note" : "Edit note") { destination = .notes(date) }
                        .accessibilityIdentifier("nutrition.editNote")
                }
                Section {
                    Button("Copy this day's food log", systemImage: "doc.on.doc") { destination = .copy(date, nil) }
                        .disabled(store.entries(on: date).isEmpty).accessibilityIdentifier("nutrition.copyDay")
                    NavigationLink("Food and meal suggestions") { AgentReviewView(workspace: workspace, unit: unit) }
                    NavigationLink("Backup and sync") { AccountSyncView(workspace: workspace) }
                    if let calendarDate = CalendarDay(rawValue: date.description) {
                        NavigationLink("Activity, sleep and water") {
                            HomeView(refreshToken: 0, initialDate: calendarDate, healthOnly: true)
                        }.accessibilityIdentifier("nutrition.dailyHealth")
                    }
                }
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Color.exBackground)
            .navigationTitle("Diary").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add food", systemImage: "plus") {
                        actions.clearError()
                        destination = .add(date, store.entries.last?.meal ?? "Snacks")
                    }.accessibilityIdentifier("nutrition.addFood")
                }
            }
            .refreshable { await workspace.synchronize() }
            .onChange(of: actions.error) { _, error in
                guard error != nil else { return }
                scroll.scrollTo("errors", anchor: .top)
                errorFocused = true
            }
        }
        .sheet(item: $destination) { destination in sheet(destination) }
        .task { await workspace.synchronize() }
    }

    private var store: NutritionStore { workspace.nutrition }

    private var dateNavigation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { destination = .date } label: {
                Text(NutritionFormat.day(date, timeZone: timeZone)).font(.headline)
                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
            }.accessibilityLabel("Diary date, \(NutritionFormat.day(date, timeZone: timeZone))")
            HStack {
                Button { date = date.adding(days: -1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }.accessibilityLabel("Previous day")
                Spacer()
                Button("Today") { date = LocalDate(Date(), in: timeZone) }.frame(minHeight: 44)
                Spacer()
                Button { date = date.adding(days: 1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }.accessibilityLabel("Next day")
            }.buttonStyle(.borderless)
            if let engine = workspace.sync {
                switch engine.state {
                case .offline:
                    Label("Offline. Food is saved on this device.", systemImage: "wifi.slash").font(.footnote)
                case .failed:
                    NavigationLink("Some changes could not sync") { AccountSyncView(workspace: workspace) }
                        .font(.footnote)
                case .syncing: ProgressView("Syncing…").font(.footnote)
                case .idle: EmptyView()
                }
            }
        }
    }

    private var meals: [String] {
        let defaults = NutritionStore.defaultMeals
        let extra = Set(store.entries(on: date).map(\.meal)).subtracting(defaults).sorted()
        return defaults + extra
    }

    private func mealSection(_ meal: String) -> some View {
        let entries = store.entries(on: date).filter { $0.meal == meal }
        return Section(meal) {
            if entries.isEmpty { Text("Nothing logged").foregroundStyle(.secondary) }
            ForEach(entries) { entry in
                Button { actions.clearError(); destination = .edit(entry) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.food.name).font(.headline).foregroundStyle(Color.exTextPrimary)
                        if let brand = entry.food.brand { Text(brand).foregroundStyle(Color.exTextSecondary) }
                        Text(NutritionFormat.portion(entry)).foregroundStyle(Color.exTextSecondary)
                        Text(entry.nutrients[.energy].map { "\(TrainingFormat.number($0)) kcal" } ?? "Energy not reported")
                            .monospacedDigit().foregroundStyle(Color.exPrimary)
                    }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                }.accessibilityIdentifier("nutrition.entry.\(entry.id.uuidString)")
            }
            Button("Add food to \(meal)", systemImage: "plus") {
                actions.clearError()
                destination = .add(date, meal)
            }.accessibilityIdentifier("nutrition.add.\(meal.lowercased())")
            if !entries.isEmpty {
                Button("Copy \(meal)", systemImage: "doc.on.doc") { destination = .copy(date, meal) }
            }
        }
    }

    @ViewBuilder private func sheet(_ destination: Destination) -> some View {
        switch destination {
        case .date: NutritionDateView(date: $date, timeZone: timeZone)
        case .add(let date, let meal):
            NutritionFoodPicker(workspace: workspace, api: api, date: date, meal: meal,
                                timeZone: timeZone, actions: actions) {}
        case .edit(let entry):
            NutritionEntryEditor(workspace: workspace,
                food: ExerlyCore.Food(id: entry.food.foodID, name: entry.food.name, source: entry.food.source, per100g: entry.food.per100g),
                date: entry.date, meal: entry.meal, timeZone: timeZone, actions: actions, editing: entry) { _ in }
        case .notes(let date): NutritionDayNotesView(workspace: workspace, date: date)
        case .copy(let date, let meal): NutritionCopyView(workspace: workspace, source: date, meal: meal, timeZone: timeZone)
        case .status(let review):
            NutritionConfirmation(title: "Mark this day as \(NutritionFormat.status(review.desired).lowercased())?",
                                  message: "\(review.day.date) has \(review.entries.count) food entries. \(NutritionFormat.statusDescription(review.desired)) Logged foods stay unchanged.",
                                  confirm: "Set logging status") {
                self.destination = nil
                if actions.setStatus(review.desired, reviewed: review.day, entries: review.entries) {
                    Task { await workspace.synchronize() }
                }
            } cancel: { self.destination = nil }
        }
    }
}
