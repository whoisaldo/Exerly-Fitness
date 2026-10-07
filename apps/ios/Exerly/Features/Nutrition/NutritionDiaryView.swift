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
                    Button("Try again") { Task { await account.configure(auth.accountAPI) } }.buttonStyle(.borderedProminent).tint(Color.exActionFill)
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
    @StateObject private var savedDay = DiaryViewModel()
    @EnvironmentObject private var dailySync: SyncEngine
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
            ExScreen {
                dateNavigation
                VStack(spacing: ExSpacing.tight) {
                ExCard(accent: true) {
                    NutritionDailySummary(amounts: store.summary(on: date).totals, targets: displayTargets, showHeading: false)
                }
                HStack(spacing: ExSpacing.item) {
                    dayStatus
                    Spacer(minLength: 0)
                    Menu {
                        Button(store.day(date).notes.isEmpty ? "Add a note" : "Edit note", systemImage: "square.and.pencil") {
                            destination = .notes(date)
                        }.accessibilityIdentifier("nutrition.editNote")
                        Button("Copy day", systemImage: "doc.on.doc") { destination = .copy(date, nil) }
                            .disabled(store.entries(on: date).isEmpty).accessibilityIdentifier("nutrition.copyDay")
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    }.accessibilityLabel("Diary actions").accessibilityIdentifier("nutrition.dayActions")
                }
                }
                if !store.day(date).notes.isEmpty {
                    Button { destination = .notes(date) } label: {
                        Label(store.day(date).notes, systemImage: "text.alignleft")
                            .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain).accessibilityLabel("Edit note, \(store.day(date).notes)")
                }
                if dailySync.attentionCount > 0 {
                    NavigationLink { SyncIssuesView() } label: {
                        ExNavigationLabel(title: "Review changes", icon: "arrow.triangle.2.circlepath",
                                          detail: "Activity or body measurements changed on another device")
                    }.accessibilityLabel("Review changes")
                }
                if let error = actions.error {
                    ExCard {
                        Text(error).foregroundStyle(Color.exError).accessibilityFocused($errorFocused)
                        Button("Dismiss message") { actions.clearError() }
                    }.id("errors")
                }
                if let deleted = actions.deleted {
                    ExCard {
                        Label("Removed \(deleted.food.name)", systemImage: "trash")
                        Button("Undo food deletion") {
                            if actions.undoDeletion() { Task { await workspace.synchronize() } }
                        }.accessibilityIdentifier("nutrition.undoDelete").buttonStyle(ExActionStyle(secondary: true))
                    }
                }
                if store.entries(on: date).isEmpty {
                    ExEmptyState(icon: "fork.knife", title: "Your day starts here",
                                 message: "Find a food, scan a label, or log one of your own.", action: "Add your first food") {
                        destination = .add(date, "Breakfast")
                    }
                } else {
                    VStack(alignment: .leading, spacing: ExSpacing.item) {
                        ExSectionHeading("Meals", detail: "\(store.entries(on: date).count) logged")
                        ForEach(meals, id: \.self) { meal in
                            if !store.entries(on: date).filter({ $0.meal == meal }).isEmpty { mealSection(meal) }
                        }
                    }
                }
            if let engine = workspace.sync {
                switch engine.state {
                case .offline:
                    Label("Saved on this device · Offline", systemImage: "wifi.slash").font(.exCaption)
                case .failed:
                    NavigationLink("Some changes could not sync") { AccountSyncView(workspace: workspace) }.font(.exCaption)
                case .syncing: ProgressView("Syncing…").font(.exCaption)
                case .idle: EmptyView()
                }
            }
                ExCard {
                    DisclosureGroup("All nutrients") {
                        NutritionAmountsView(amounts: store.summary(on: date).totals)
                        Text("Totals use reported nutrients. Missing values do not mean zero.")
                            .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    }.font(.exBodyMedium)
                    if let calendarDate = CalendarDay(rawValue: date.description) {
                        NavigationLink {
                            HomeView(refreshToken: 0, initialDate: calendarDate, healthOnly: true)
                        } label: { ExNavigationLabel(title: "Activity, sleep & water", icon: "heart.text.clipboard") }
                            .accessibilityIdentifier("nutrition.dailyHealth")
                    }
                    NavigationLink { AgentReviewView(workspace: workspace, unit: unit) } label: {
                        ExNavigationLabel(title: "Food & meal suggestions", icon: "tray")
                    }
                }
            }
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
        .task(id: date.description) {
            if let day = CalendarDay(rawValue: date.description) { await savedDay.load(for: day) }
        }
    }

    private var displayTargets: DailyTargets? {
        NutritionFormat.displayTargets(current: store.targets(on: date), saved: savedDay.summary?.targets,
                                       savedDate: savedDay.summary?.date, on: date)
    }

    private var store: NutritionStore { workspace.nutrition }

    private var dateNavigation: some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            HStack(spacing: ExSpacing.tight) {
                Button { date = date.adding(days: -1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }.accessibilityLabel("Previous day")
                Spacer(minLength: 0)
                Button { destination = .date } label: {
                    VStack(spacing: 2) {
                        Text(date == LocalDate(Date(), in: timeZone) ? "Today" : NutritionFormat.day(date, timeZone: timeZone))
                            .font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                        if date == LocalDate(Date(), in: timeZone) {
                            Text(NutritionFormat.day(date, timeZone: timeZone)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                        }
                    }.fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
                }.accessibilityLabel("Diary date, \(NutritionFormat.day(date, timeZone: timeZone))")
                    .accessibilityIdentifier("diary.selected-day").accessibilityValue(date.description)
                Spacer(minLength: 0)
                Button { date = date.adding(days: 1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }.accessibilityLabel("Next day")
            }.buttonStyle(.plain).foregroundStyle(Color.exPrimaryText)
            if date != LocalDate(Date(), in: timeZone) {
                Button("Back to today") { date = LocalDate(Date(), in: timeZone) }.font(.exCaption).frame(minHeight: 44)
            }

        }
    }

    private var dayStatus: some View {
        Menu {
            ForEach(DayStatus.allCases, id: \.self) { status in
                Button(NutritionFormat.status(status)) {
                    actions.clearError()
                    destination = .status(StatusReview(desired: status, day: store.day(date), entries: store.entries(on: date)))
                }.accessibilityIdentifier("nutrition.status.\(status.rawValue)")
            }
        } label: {
            HStack(spacing: ExSpacing.item) {
                Image(systemName: store.day(date).status == .complete ? "checkmark.circle.fill" : "circle.dotted")
                    .foregroundStyle(Color.exPrimaryText)
                Text(NutritionFormat.status(store.day(date).status)).font(.exLabel).foregroundStyle(Color.exTextSecondary)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(Color.exTextMuted)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.accessibilityIdentifier("nutrition.dayStatus")
    }

    private var meals: [String] {
        let defaults = NutritionStore.defaultMeals
        let extra = Set(store.entries(on: date).map(\.meal)).subtracting(defaults).sorted()
        return defaults + extra
    }

    private func mealSection(_ meal: String) -> some View {
        let entries = store.entries(on: date).filter { $0.meal == meal }
        return ExCard {
            HStack {
                ExEyebrow(meal, color: .exPrimaryText)
                Spacer()
                Menu {
                    Button("Copy \(meal)", systemImage: "doc.on.doc") { destination = .copy(date, meal) }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    .accessibilityLabel("\(meal) actions")
            }
            ForEach(entries) { entry in
                Button { actions.clearError(); destination = .edit(entry) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: ExSpacing.item) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.food.name).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                            Text(NutritionFormat.portion(entry)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.nutrients[.energy].map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—")
                                .font(.exStatSmall).foregroundStyle(Color.exTextPrimary)
                            Text("kcal").font(.exSmall).foregroundStyle(Color.exTextSecondary)
                        }
                    }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("nutrition.entry.\(entry.id.uuidString)")
            }
            Button("Add food to \(meal)", systemImage: "plus") {
                actions.clearError()
                destination = .add(date, meal)
            }.font(.exLabel).frame(minHeight: 44).accessibilityIdentifier("nutrition.add.\(meal.lowercased())")
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
                food: entry.food.foodForLogging(serving: entry.serving),
                date: entry.date, meal: entry.meal, timeZone: timeZone, actions: actions, editing: entry) { _ in }
        case .notes(let date): NutritionDayNotesView(workspace: workspace, date: date, timeZone: timeZone)
        case .copy(let date, let meal): NutritionCopyView(workspace: workspace, source: date, meal: meal, timeZone: timeZone)
        case .status(let review):
            NutritionConfirmation(title: "Mark this day as \(NutritionFormat.status(review.desired).lowercased())?",
                                  message: "\(NutritionFormat.day(review.day.date, timeZone: timeZone)) has \(review.entries.count) food \(review.entries.count == 1 ? "entry" : "entries"). \(NutritionFormat.statusDescription(review.desired)) Logged foods stay unchanged.",
                                  confirm: "Set logging status") {
                self.destination = nil
                if actions.setStatus(review.desired, reviewed: review.day, entries: review.entries) {
                    Task { await workspace.synchronize() }
                }
            } cancel: { self.destination = nil }
        }
    }
}
