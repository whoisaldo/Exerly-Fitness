import SwiftUI

struct Step5ActivityLevel: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Activity Level")
                        .font(.exH2)
                        .foregroundStyle(.exTextPrimary)
                    Text("How active are you on a typical day?")
                        .font(.exBody)
                        .foregroundStyle(.exTextSecondary)
                }

                VStack(spacing: 10) {
                    ForEach(ActivityLevel.allCases) { level in
                        SelectionCard(
                            title: level.label,
                            subtitle: level.subtitle,
                            isSelected: state.activityLevel == level
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                state.activityLevel = level
                            }
                        }
                    }
                }

                Spacer(minLength: 24)

                ActionButton(title: "Continue") { state.nextStep() }
            }
            .padding(24)
            .padding(.top, 16)
        }
    }
}
