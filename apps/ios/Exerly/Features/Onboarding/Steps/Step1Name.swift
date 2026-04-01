import SwiftUI

struct Step1Name: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("What's your name?")
                    .font(.exH2)
                    .foregroundStyle(.exTextPrimary)
                Text("We'll use this to personalize your experience")
                    .font(.exBody)
                    .foregroundStyle(.exTextSecondary)
            }

            FloatingLabelTextField(label: "Your name", text: $state.name)

            Spacer()

            ActionButton(title: "Continue", isDisabled: state.name.isEmpty) {
                state.nextStep()
            }
        }
        .padding(24)
        .padding(.top, 24)
    }
}
