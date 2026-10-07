import SwiftUI
import ExerlyCore

enum MainTab: Int, CaseIterable {
    case home, training, library, progress, profile

    var icon: String {
        switch self {
        case .home: "house"
        case .training: "dumbbell"
        case .library: "book"
        case .progress: "chart.line.uptrend.xyaxis"
        case .profile: "person.crop.circle"
        }
    }

    var label: String {
        switch self {
        case .home: "Home"
        case .training: "Train"
        case .library: "Library"
        case .progress: "Progress"
        case .profile: "Profile"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var sync: SyncEngine
    @EnvironmentObject private var auth: AuthViewModel
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                if let account = auth.currentUser?.id {
                    NutritionHostView(accountID: account,
                                      unit: auth.currentUser?.unitSystem == "metric" ? .kilograms : .pounds,
                                      timeZone: TimeZone(identifier: auth.currentUser?.timezone ?? "UTC") ?? .gmt)
                }
            }
                .tabItem { Label(MainTab.home.label, systemImage: MainTab.home.icon) }.tag(MainTab.home)
            NavigationStack {
                if let account = auth.currentUser?.id {
                    TrainingHostView(accountID: account,
                                     unit: auth.currentUser?.unitSystem == "metric" ? .kilograms : .pounds,
                                     timeZone: TimeZone(identifier: auth.currentUser?.timezone ?? "UTC") ?? .gmt)
                }
            }
            .tabItem { Label(MainTab.training.label, systemImage: MainTab.training.icon) }.tag(MainTab.training)
            NavigationStack {
                if let account = auth.currentUser?.id {
                    NutritionLibraryHostView(accountID: account,
                        timeZone: TimeZone(identifier: auth.currentUser?.timezone ?? "UTC") ?? .gmt,
                        unit: auth.currentUser?.unitSystem == "metric" ? .kilograms : .pounds)
                }
            }
                .tabItem { Label(MainTab.library.label, systemImage: MainTab.library.icon) }.tag(MainTab.library)
            NavigationStack { ProgressView_(initialDate: sync.today) }
                .tabItem { Label(MainTab.progress.label, systemImage: MainTab.progress.icon) }.tag(MainTab.progress)
            NavigationStack { ProfileView() }
                .tabItem { Label(MainTab.profile.label, systemImage: MainTab.profile.icon) }.tag(MainTab.profile)
        }
        .tint(Color.exPrimaryText)
    }
}
