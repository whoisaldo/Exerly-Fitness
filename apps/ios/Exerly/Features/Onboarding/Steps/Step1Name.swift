import SwiftUI

struct Step1Name: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ScrollView {
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
                Picker("Display units", selection: $state.useMetric) {
                    Text("Metric").tag(true)
                    Text("Imperial").tag(false)
                }.pickerStyle(.segmented).frame(minHeight: 44)
                Text("You can change units later without changing your measurements.")
                    .font(.callout).foregroundStyle(.exTextSecondary)

                Spacer()

                ActionButton(title: "Continue", isDisabled: state.name.isEmpty) {
                    state.nextStep()
                }
            }
            .padding(24)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
