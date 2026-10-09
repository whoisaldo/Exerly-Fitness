import ExerlyCore
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
    @EnvironmentObject private var account: AppAccountWorkspace
    @EnvironmentObject private var auth: AuthViewModel

    /// The signed-in account's ExerlyCore data, where weigh-ins live.
    private var workspace: TrainingWorkspace? {
        guard let workspace = account.training, workspace.accountID == auth.currentUser?.id else { return nil }
        return workspace
    }
    private var unit: MassUnit { auth.currentUser?.unitSystem == "metric" ? .kilograms : .pounds }
    private var timeZone: TimeZone { TimeZone(identifier: auth.currentUser?.timezone ?? "UTC") ?? .gmt }

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
        case .measurements:
            MeasurementsTab(initialDate: initialDate, workspace: workspace, unit: unit, timeZone: timeZone,
                            openingError: account.openingError)
        case .photos: PhotosTab()
        case .achievements: AchievementsTab { selectedTab = .measurements }
        }
    }
}
