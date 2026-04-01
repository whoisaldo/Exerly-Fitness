import SwiftUI

enum ProgressTab: String, CaseIterable {
    case measurements = "Measurements"
    case photos = "Photos"
    case achievements = "Achievements"
}

struct ProgressView_: View {
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
        HStack(spacing: 0) {
            ForEach(ProgressTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.exLabel)
                        .foregroundStyle(selectedTab == tab ? .exPrimary : .exTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.exPrimary)
                                    .frame(height: 2)
                            }
                        }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .measurements: MeasurementsTab()
        case .photos: PhotosTab()
        case .achievements: AchievementsTab()
        }
    }
}
