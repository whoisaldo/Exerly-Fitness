import SwiftUI
import SwiftData

struct AchievementsTab: View {
    @Query private var achievements: [Achievement]
    @State private var newlyUnlocked: Achievement?

    private var sorted: [Achievement] {
        achievements.sorted { ($0.isUnlocked ? 0 : 1) < ($1.isUnlocked ? 0 : 1) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ZStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(sorted) { a in
                        achievementCard(a)
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }

            if newlyUnlocked != nil {
                ConfettiView()
            }
        }
    }

    private func achievementCard(_ a: Achievement) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(a.isUnlocked ? Color.exPrimary.opacity(0.15) : Color.exSurface2)
                    .frame(width: 56, height: 56)
                Image(systemName: a.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(a.isUnlocked ? .exPrimary : .exTextMuted)
            }

            Text(a.title)
                .font(.exLabel)
                .foregroundStyle(a.isUnlocked ? .exTextPrimary : .exTextMuted)
                .multilineTextAlignment(.center)

            Text(a.desc)
                .font(.exSmall)
                .foregroundStyle(.exTextMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if !a.isUnlocked && a.progress > 0 {
                ProgressView(value: a.progress)
                    .tint(.exPrimary)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
        .opacity(a.isUnlocked ? 1 : 0.6)
    }
}
