import SwiftUI
import ExerlyCore

enum MainTab: Hashable {
    case today, training, progress, profile, search
}

struct MainTabView: View {
    @EnvironmentObject private var sync: SyncEngine
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var account: AppAccountWorkspace
    @State private var selectedTab: MainTab = .today

    private var unit: MassUnit { auth.currentUser?.unitSystem == "metric" ? .kilograms : .pounds }
    private var timeZone: TimeZone { TimeZone(identifier: auth.currentUser?.timezone ?? "UTC") ?? .gmt }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "house", value: .today) {
                NavigationStack {
                    if let id = auth.currentUser?.id {
                        TodayHostView(accountID: id, unit: unit, timeZone: timeZone) { selectedTab = .training }
                    }
                }
            }
            Tab("Train", systemImage: "dumbbell", value: .training) {
                NavigationStack {
                    if let id = auth.currentUser?.id {
                        TrainingHostView(accountID: id, unit: unit, timeZone: timeZone)
                    }
                }
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: .progress) {
                NavigationStack { ProgressView_(initialDate: sync.today) }
            }
            Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
                NavigationStack { ProfileView() }
            }
            Tab("Log food", systemImage: "magnifyingglass", value: .search, role: .search) {
                if let id = auth.currentUser?.id {
                    FoodSearchTab(accountID: id, unit: unit, timeZone: timeZone)
                }
            }
        }
        .tint(Color.exPrimaryText)
    }
}

/// Food search as a tab, so a food is two taps from anywhere.
private struct FoodSearchTab: View {
    let accountID: String
    let unit: MassUnit
    let timeZone: TimeZone
    @EnvironmentObject private var account: AppAccountWorkspace
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        if let workspace = account.training, workspace.accountID == accountID,
           let api = auth.accountAPI, api.accountID == accountID {
            FoodSearchTabContent(workspace: workspace, api: api, unit: unit, timeZone: timeZone)
                .id(workspace.identity)
        } else { ProgressView("Opening foods…") }
    }
}

private struct FoodSearchTabContent: View {
    let workspace: TrainingWorkspace
    let api: AccountAPI
    let unit: MassUnit
    let timeZone: TimeZone
    @StateObject private var actions: NutritionDiaryActions

    init(workspace: TrainingWorkspace, api: AccountAPI, unit: MassUnit, timeZone: TimeZone) {
        self.workspace = workspace
        self.api = api
        self.unit = unit
        self.timeZone = timeZone
        _actions = StateObject(wrappedValue: NutritionDiaryActions(store: workspace.nutrition))
    }

    var body: some View {
        NutritionFoodPicker(workspace: workspace, api: api, date: LocalDate(Date(), in: timeZone),
                            meal: workspace.nutrition.suggestedMeal(at: .now, timeZone: timeZone),
                            timeZone: timeZone, unit: unit, actions: actions) {}
    }
}
