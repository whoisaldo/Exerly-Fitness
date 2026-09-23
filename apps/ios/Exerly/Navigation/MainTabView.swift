import SwiftUI

enum MainTab: Int, CaseIterable {
    case home, library, fab, progress, profile

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .library: return "book.fill"
        case .fab: return "plus"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .profile: return "person.fill"
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .library: return "Library"
        case .fab: return ""
        case .progress: return "Progress"
        case .profile: return "Profile"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var sync: SyncEngine
    @State private var selectedTab: MainTab = .home
    @State private var showFABMenu = false
    @State private var showLogActivity = false
    @State private var showLogFood = false
    @State private var showLogSleep = false
    @State private var homeRefreshToken = 0

    var body: some View {
        tabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(
                    selectedTab: $selectedTab,
                    showFABMenu: $showFABMenu
                )
            }
            .background(Color.exBackground)
            .overlay { fabOverlay }
            .sheet(isPresented: $showLogActivity, onDismiss: refreshHome) { LogActivityView(initialDate: sync.today) }
            .sheet(isPresented: $showLogFood, onDismiss: refreshHome) { LogFoodView(initialDate: sync.today) }
            .sheet(isPresented: $showLogSleep, onDismiss: refreshHome) { LogSleepView(initialDate: sync.today) }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack { HomeView(refreshToken: homeRefreshToken, initialDate: sync.today) }
        case .library:
            NavigationStack { FoodLibraryView() }
        case .fab:
            EmptyView()
        case .progress:
            NavigationStack { ProgressView_(initialDate: sync.today) }
        case .profile:
            NavigationStack { ProfileView() }
        }
    }

    private func refreshHome() {
        homeRefreshToken += 1
    }

    @ViewBuilder
    private var fabOverlay: some View {
        if showFABMenu {
            FABMenuOverlay(
                onLogActivity: { showFABMenu = false; showLogActivity = true },
                onLogFood: { showFABMenu = false; showLogFood = true },
                onLogSleep: { showFABMenu = false; showLogSleep = true },
                onDismiss: { showFABMenu = false }
            )
        }
    }
}
