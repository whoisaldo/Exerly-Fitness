import SwiftUI

struct Step3HeightWeight: View {
    @ObservedObject var state: OnboardingState
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Height and weight").font(.exH2)
                MeasurementFields(state: state)
                ActionButton(title: "Continue") { state.nextStep() }
            }.padding(24)
        }.scrollDismissesKeyboard(.interactively)
    }
}

struct MeasurementFields: View {
    @ObservedObject var state: OnboardingState
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                if state.useMetric {
                    numberField("Height, cm", value: $state.heightCm)
                    numberField("Weight, kg", value: $state.weightKg)
                } else {
                    numberField("Height, inches", value: Binding(
                        get: { state.heightCm / 2.54 }, set: { state.heightCm = $0 * 2.54 }))
                    numberField("Weight, lb", value: $state.weightLbs)
                }
            }
        }
    }

    private func numberField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.headline)
            TextField(label, value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                .frame(minHeight: 44).monospacedDigit().accessibilityLabel(label)
        }
    }
}
