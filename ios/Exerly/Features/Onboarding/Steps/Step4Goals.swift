import SwiftUI

struct Step4Goals: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("What's your goal?")
                        .font(.exH2)
                        .foregroundStyle(.exTextPrimary)
                    Text("We'll build your plan around this")
                        .font(.exBody)
                        .foregroundStyle(.exTextSecondary)
                }

                goalCards
                targetWeightSection
                timelineSection
                safetyBadge

                Spacer(minLength: 24)

                ActionButton(title: "Continue") { state.nextStep() }
            }
            .padding(24)
            .padding(.top, 16)
        }
    }

    private var goalCards: some View {
        VStack(spacing: 10) {
            ForEach(FitnessGoal.allCases) { goal in
                SelectionCard(
                    title: goal.label,
                    icon: goal.icon,
                    isSelected: state.goal == goal
                ) {
                    withAnimation(.spring(response: 0.3)) { state.goal = goal }
                }
            }
        }
    }

    @ViewBuilder
    private var targetWeightSection: some View {
        if state.goal == .loseWeight || state.goal == .gainMuscle {
            GlassCard {
                VStack(spacing: 8) {
                    Text("Target Weight")
                        .font(.exLabel)
                        .foregroundStyle(.exTextSecondary)
                    HStack {
                        Slider(value: $state.targetWeightKg, in: 40...150, step: 0.5)
                            .tint(.exPrimary)
                        Text(String(format: "%.1f kg", state.targetWeightKg))
                            .font(.exStatSmall)
                            .foregroundStyle(.exTextPrimary)
                            .frame(width: 80)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var timelineSection: some View {
        if state.goal == .loseWeight || state.goal == .gainMuscle {
            GlassCard {
                VStack(spacing: 8) {
                    Text("Timeline")
                        .font(.exLabel)
                        .foregroundStyle(.exTextSecondary)
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(state.timelineWeeks) },
                                set: { state.timelineWeeks = Int($0) }
                            ),
                            in: 4...52, step: 1
                        )
                        .tint(.exPrimary)
                        Text("\(state.timelineWeeks) weeks")
                            .font(.exStatSmall)
                            .foregroundStyle(.exTextPrimary)
                            .frame(width: 90)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var safetyBadge: some View {
        if state.goal == .loseWeight || state.goal == .gainMuscle {
            let safety = state.weightRateSafety
            HStack(spacing: 8) {
                Circle()
                    .fill(safetyColor(safety))
                    .frame(width: 10, height: 10)
                Text(safety.label)
                    .font(.exLabel)
                    .foregroundStyle(safetyColor(safety))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: 20)
        }
    }

    private func safetyColor(_ safety: WeightRateSafety) -> Color {
        switch safety {
        case .safe: return .exSuccess
        case .aggressive: return .exWarning
        case .dangerous: return .exError
        }
    }
}
