import SwiftUI

struct Step1Name: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ExSpacing.section) {
                VStack(spacing: 8) {
                    Text("Your profile")
                        .font(.exH2)
                        .foregroundStyle(.exTextPrimary)
                }

                FloatingLabelTextField(label: "Your name", text: $state.name)
                ExCard {
                    ExEyebrow("Measurements")
                    ExSegmentedControl(values: [false, true], selection: $state.useMetric) { $0 ? "Metric" : "U.S." }
                    Text(state.useMetric ? "Kilograms and centimeters" : "Pounds, feet and inches")
                        .font(.exCaption).foregroundStyle(.exTextSecondary)
                }

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
