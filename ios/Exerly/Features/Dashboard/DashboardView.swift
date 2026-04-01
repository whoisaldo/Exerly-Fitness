import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                bentoGrid
                weeklyChart
                macroSummary
                goalRings
                aiCoachTeaser
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.exBackground)
        .task { await vm.load() }
    }

    private var header: some View {
        Text("Dashboard")
            .font(.exH1)
            .foregroundStyle(.exTextPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bentoGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            BentoCard(icon: "flame.fill", title: "Calories",
                      value: "\(vm.caloriesConsumed)", unit: "kcal",
                      color: .exAccent)
            BentoCard(icon: "figure.run", title: "Workouts",
                      value: "\(vm.workoutsCompleted)", unit: "sessions",
                      color: .exSuccess)
            BentoCard(icon: "moon.fill", title: "Sleep",
                      value: String(format: "%.1f", vm.sleepHours), unit: "hours",
                      color: .exInfo)
            BentoCard(icon: "drop.fill", title: "Water",
                      value: "0", unit: "glasses",
                      color: .exPrimary)
        }
    }

    private var weeklyChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("7-Day Activity")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)

                Chart {
                    ForEach(sampleWeekData, id: \.day) { item in
                        BarMark(
                            x: .value("Day", item.day),
                            y: .value("Calories", item.calories)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.exPrimary, .exSecondary],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.exTextMuted)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.exTextMuted)
                    }
                }
                .frame(height: 160)
            }
        }
    }

    private var macroSummary: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Macros")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                HStack(spacing: 16) {
                    MacroPill(label: "Protein", grams: 0, color: .exPrimary)
                    MacroPill(label: "Carbs", grams: 0, color: .exSuccess)
                    MacroPill(label: "Fat", grams: 0, color: .exAccent)
                }
            }
        }
    }

    private var goalRings: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Goal Progress")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                HStack(spacing: 20) {
                    MiniRing(progress: Double(vm.caloriesConsumed) / max(Double(vm.caloriesTarget), 1),
                             color: .exAccent, label: "Cal")
                    MiniRing(progress: Double(vm.workoutsCompleted) / max(Double(vm.workoutsTarget), 1),
                             color: .exSuccess, label: "Move")
                    MiniRing(progress: vm.sleepHours / max(vm.sleepTarget, 1),
                             color: .exInfo, label: "Sleep")
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var aiCoachTeaser: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundStyle(.exSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Coach")
                        .font(.exBodyMedium)
                        .foregroundStyle(.exTextPrimary)
                    Text("Get personalized advice and plans")
                        .font(.exCaption)
                        .foregroundStyle(.exTextSecondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.exPrimary)
            }
        }
    }

    private var sampleWeekData: [(day: String, calories: Int)] {
        [("Mon", 320), ("Tue", 450), ("Wed", 280), ("Thu", 520),
         ("Fri", 380), ("Sat", 200), ("Sun", 0)]
    }
}

// MARK: - Subviews

struct BentoCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Spacer()
            Text(value)
                .font(.exStatMedium)
                .foregroundStyle(.exTextPrimary)
            Text(unit)
                .font(.exSmall)
                .foregroundStyle(.exTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110)
        .padding(14)
        .glassCard(cornerRadius: 16)
    }
}

struct MacroPill: View {
    let label: String
    let grams: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(grams)g")
                .font(.exStatSmall)
                .foregroundStyle(color)
            Text(label)
                .font(.exSmall)
                .foregroundStyle(.exTextMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MiniRing: View {
    let progress: Double
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(min(progress, 1) * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.exTextPrimary)
            }
            .frame(width: 50, height: 50)
            Text(label)
                .font(.exSmall)
                .foregroundStyle(.exTextMuted)
        }
    }
}
