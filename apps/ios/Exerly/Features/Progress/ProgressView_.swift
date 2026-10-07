import SwiftUI

enum ProgressTab: String, CaseIterable {
    case measurements = "Measurements"
    case photos = "Photos"
    case achievements = "Achievements"

    var title: String {
        switch self {
        case .measurements: "Body"
        case .photos: "Photos"
        case .achievements: "Milestones"
        }
    }
}

struct ProgressView_: View {
    let initialDate: CalendarDay
    @State private var selectedTab: ProgressTab = .measurements

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            tabContent
        }
        .background(Color.exBackground)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tabPicker: some View {
        ExSegmentedControl(values: ProgressTab.allCases, selection: $selectedTab) { $0.title }
            .padding(.horizontal, ExSpacing.page).padding(.vertical, ExSpacing.small)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .measurements: MeasurementsTab(initialDate: initialDate)
        case .photos: PhotosTab()
        case .achievements: AchievementsTab { selectedTab = .measurements }
        }
    }
}
