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
                    VStack(alignment: .leading, spacing: ExSpacing.small) {
                        Text("Height").font(.exBodyMedium)
                        HStack(spacing: ExSpacing.item) {
                            heightField("Feet", value: $state.heightFeet)
                            heightField("Inches", value: $state.heightInches)
                        }
                    }
                    numberField("Weight, lb", value: $state.weightLbs)
                }
            }
        }
    }

    private func heightField(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            Text(label).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            TextField(label, value: value, format: .number)
                .keyboardType(.numberPad)
                .padding(ExSpacing.item).background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                .frame(minHeight: 44).font(.exStatSmall).accessibilityLabel("Height, \(label.lowercased())")
        }
    }

    private func numberField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.headline)
            TextField(label, value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .padding(ExSpacing.item).background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                .frame(minHeight: 44).font(.exStatSmall).accessibilityLabel(label)
        }
    }
}
