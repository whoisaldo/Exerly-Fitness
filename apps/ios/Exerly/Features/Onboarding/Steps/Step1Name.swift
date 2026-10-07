import SwiftUI

struct Step1Name: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ExScreen {
            VStack(alignment: .leading, spacing: ExSpacing.item) {
                ExEyebrow("Welcome to Exerly", color: .exPrimaryText)
                Text("Food and training,\nin one place.").font(.exH1).accessibilityAddTraits(.isHeader)
                Text("Let's set a starting point that fits your life. You can change every choice later.")
                    .font(.exBody).foregroundStyle(Color.exTextSecondary)
            }
            ExCard {
                introduction("Log meals quickly", detail: "Scan a barcode, search a food, then choose your portion.", icon: "barcode.viewfinder")
                introduction("Make training a routine", detail: "Save your schedule and equipment, then review workouts in Train.", icon: "dumbbell")
                introduction("Understand your progress", detail: "See food, body measurements and training together.", icon: "chart.xyaxis.line")
            }
            FloatingLabelTextField(label: "Your name", text: $state.name)
            ExCard {
                ExSectionHeading("Your units")
                ExSegmentedControl(values: [false, true], selection: $state.useMetric) { $0 ? "Metric" : "U.S." }
                Text(state.useMetric ? "Kilograms and centimeters. Food energy stays in Calories." : "Pounds, feet and inches. Food energy in Calories, portions in ounces where supported.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            Button("Continue") { state.nextStep() }.buttonStyle(ExActionStyle())
                .disabled(state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.scrollDismissesKeyboard(.interactively)
    }

    private func introduction(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: ExSpacing.item) {
            Image(systemName: icon).font(.exH3).foregroundStyle(Color.exPrimaryText)
                .frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: ExSpacing.tight) {
                Text(title).font(.exBodyMedium)
                Text(detail).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }.fixedSize(horizontal: false, vertical: true)
        }
    }
}
