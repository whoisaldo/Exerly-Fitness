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
    @Environment(\.dynamicTypeSize) private var typeSize

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
        Group {
            if typeSize.isAccessibilitySize {
                Menu {
                    Picker("Progress view", selection: $selectedTab) {
                        ForEach(ProgressTab.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } label: {
                    HStack {
                        Text(selectedTab.title).font(.exBodyMedium)
                        Spacer()
                        Image(systemName: "chevron.down").font(.exCaption)
                    }.foregroundStyle(Color.exTextPrimary).padding(ExSpacing.item)
                        .background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                }.accessibilityLabel("Progress view, \(selectedTab.title)").accessibilityIdentifier("progress.section")
            } else {
                ExSegmentedControl(values: ProgressTab.allCases, selection: $selectedTab) { $0.title }
            }
        }.padding(.horizontal, ExSpacing.page).padding(.vertical, ExSpacing.small)
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
