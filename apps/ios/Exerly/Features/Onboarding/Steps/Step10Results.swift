import SwiftUI

struct Step10Results: View {
    @ObservedObject var state: OnboardingState
    var onComplete: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Review your targets").font(.exH2)
                Text(state.manualTargetMode ? "These are the targets you entered." : "These initial estimates use your measurements and activity level. You can review and change them in Program.")
                    .font(.body).foregroundStyle(.exTextSecondary)
                if let preview = state.serverPreview {
                    GlassCard {
                        VStack(spacing: 16) {
                            targetRow("Calories", value: preview.targets.calories, unit: "kcal")
                            targetRow("Protein", value: preview.targets.protein_g, unit: "g")
                            targetRow("Carbohydrate", value: preview.targets.carbs_g, unit: "g")
                            targetRow("Fat", value: preview.targets.fat_g, unit: "g")
                        }
                    }
                    Text("The same targets will appear in Today, Program, and your web diary.")
                        .font(.callout).foregroundStyle(.exTextSecondary)
                    ActionButton(title: "Finish setup", isLoading: state.isSubmitting) {
                        onComplete?()
                    }
                } else if let error = state.previewError {
                    Text(error).foregroundStyle(.exError)
                    Button("Retry target calculation") { Task { await state.loadPreview() } }
                        .buttonStyle(.borderedProminent).frame(minHeight: 44)
                    Text("Your answers are saved on this device.").font(.callout)
                } else {
                    ProgressView("Calculating targets")
                }
            }.padding(24)
        }
        .task(id: state.previewIdentity) { await state.loadPreview() }
    }

    private func targetRow(_ title: String, value: Double, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value, format: .number.precision(.fractionLength(0))) \(unit)")
                .monospacedDigit().fontWeight(.semibold)
        }.accessibilityElement(children: .combine)
    }
}
