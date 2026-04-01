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
    @State private var selectedTab: MainTab = .home
    @State private var showFABMenu = false
    @State private var showLogActivity = false
    @State private var showLogFood = false
    @State private var showLogSleep = false

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(
                selectedTab: $selectedTab,
                showFABMenu: $showFABMenu
            )
        }
        .background(Color.exBackground)
        .overlay { fabOverlay }
        .sheet(isPresented: $showLogActivity) { LogActivityView() }
        .sheet(isPresented: $showLogFood) { LogFoodView() }
        .sheet(isPresented: $showLogSleep) { LogSleepView() }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack { HomeView() }
        case .library:
            NavigationStack { FoodLibraryView() }
        case .fab:
            EmptyView()
        case .progress:
            NavigationStack { ProgressView_() }
        case .profile:
            NavigationStack { ProfileView() }
        }
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
