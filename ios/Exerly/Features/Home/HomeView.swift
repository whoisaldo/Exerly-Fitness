import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                calorieSection
                todayStatsRow
                streakCard
                recentActivitySection
                aiInsightCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.exBackground)
        .refreshable { await vm.load() }
        .task { await vm.load() }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.greeting)
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                Text(authVM.currentUser?.name ?? "Athlete")
                    .font(.exH2)
                    .foregroundStyle(.exTextPrimary)
            }
            Spacer()
            NavigationLink(destination: NotificationsView()) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.exTextSecondary)
                    .frame(width: 44, height: 44)
                    .glassCard(cornerRadius: 12)
            }
        }
    }

    private var calorieSection: some View {
        GlassCard {
            VStack(spacing: 12) {
                CalorieRing(
                    consumed: Double(vm.caloriesConsumed),
                    target: Double(vm.caloriesTarget),
                    size: 140
                )
                Text("Today's Calories")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var todayStatsRow: some View {
        HStack(spacing: 12) {
            StatMiniCard(
                icon: "flame.fill",
                value: "\(vm.caloriesConsumed)",
                label: "Calories",
                color: .exAccent
            )
            StatMiniCard(
                icon: "figure.run",
                value: "\(vm.workoutsCompleted)/\(vm.workoutsTarget)",
                label: "Workouts",
                color: .exSuccess
            )
            StatMiniCard(
                icon: "moon.fill",
                value: String(format: "%.1f", vm.sleepHours),
                label: "Sleep hrs",
                color: .exInfo
            )
        }
    }

    private var streakCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.exWarning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Streak")
                        .font(.exCaption)
                        .foregroundStyle(.exTextSecondary)
                    Text("Keep it going!")
                        .font(.exBodyMedium)
                        .foregroundStyle(.exTextPrimary)
                }
                Spacer()
                Text("🔥")
                    .font(.system(size: 24))
            }
        }
    }

    @ViewBuilder
    private var recentActivitySection: some View {
        if !vm.recentActivities.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.exH3)
                    .foregroundStyle(.exTextPrimary)
                ForEach(vm.recentActivities.prefix(3)) { activity in
                    activityRow(activity)
                }
            }
        }
    }

    private func activityRow(_ a: ActivityDTO) -> some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: "figure.run")
                    .foregroundStyle(.exPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.exPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.type)
                        .font(.exBodyMedium)
                        .foregroundStyle(.exTextPrimary)
                    Text("\(a.duration) min · \(a.calories) kcal")
                        .font(.exCaption)
                        .foregroundStyle(.exTextSecondary)
                }
                Spacer()
            }
        }
    }

    private var aiInsightCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundStyle(.exSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Insight")
                        .font(.exLabel)
                        .foregroundStyle(.exTextSecondary)
                    Text("You're on track today! Keep up the great work.")
                        .font(.exCaption)
                        .foregroundStyle(.exTextPrimary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.exTextMuted)
            }
        }
    }
}
