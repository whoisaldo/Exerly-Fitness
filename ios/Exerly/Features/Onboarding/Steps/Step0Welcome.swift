import SwiftUI

struct Step0Welcome: View {
    @ObservedObject var state: OnboardingState
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.exPrimary)
                .primaryGlow()
                .scaleEffect(showContent ? 1 : 0.5)

            VStack(spacing: 12) {
                Text("Let's personalize\nyour experience")
                    .font(.exH1)
                    .foregroundStyle(.exTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Answer a few questions so we can create your perfect fitness plan.")
                    .font(.exBody)
                    .foregroundStyle(.exTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            ActionButton(title: "Let's Go", icon: "arrow.right") {
                state.nextStep()
            }
        }
        .padding(24)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { showContent = true }
        }
    }
}
