import SwiftUI
import SwiftData

struct AchievementsTab: View {
    @Query private var achievements: [Achievement]
    let onReviewMeasurements: () -> Void

    private var sorted: [Achievement] {
        achievements.sorted { ($0.isUnlocked ? 0 : 1) < ($1.isUnlocked ? 0 : 1) }
    }

    var body: some View {
        ExScreen {
            if sorted.isEmpty {
                ExEmptyState(icon: "chart.line.uptrend.xyaxis", title: "Progress takes a little history",
                             message: "Your recorded milestones will appear here. Start with a measurement you want to follow.",
                             action: "Review measurements", perform: onReviewMeasurements)
            } else {
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    ExEyebrow("Your record", color: .exPrimary)
                    Text("Milestones").font(.exH1)
                    Text("\(sorted.filter(\.isUnlocked).count) recorded").font(.exBody).foregroundStyle(Color.exTextSecondary)
                }
                ForEach(sorted) { achievement in
                    ExCard {
                        HStack(alignment: .top, spacing: ExSpacing.content) {
                            Image(systemName: achievement.icon).font(.title2)
                                .foregroundStyle(achievement.isUnlocked ? Color.exPrimary : Color.exTextSecondary)
                                .frame(width: 44, height: 44).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: ExSpacing.small) {
                                Text(achievement.title).font(.exH3)
                                Text(achievement.desc).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                            }.fixedSize(horizontal: false, vertical: true)
                        }
                        if !achievement.isUnlocked && achievement.progress > 0 {
                            ExProgressBar(value: achievement.progress, total: 1)
                        }
                    }
                }
            }
        }
    }
}
