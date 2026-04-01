import SwiftUI

struct Step3HeightWeight: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Height & Weight")
                        .font(.exH2)
                        .foregroundStyle(.exTextPrimary)
                    Text("Used for accurate calorie calculations")
                        .font(.exBody)
                        .foregroundStyle(.exTextSecondary)
                }

                unitToggle
                heightSection
                weightSection
                bmiPreview

                Spacer(minLength: 24)

                ActionButton(title: "Continue") { state.nextStep() }
            }
            .padding(24)
            .padding(.top, 16)
        }
    }

    private var unitToggle: some View {
        HStack(spacing: 0) {
            unitButton("Metric", isSelected: state.useMetric) { state.useMetric = true }
            unitButton("Imperial", isSelected: !state.useMetric) { state.useMetric = false }
        }
        .background(Color.exSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func unitButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.spring(response: 0.3)) { action() } }) {
            Text(title)
                .font(.exLabel)
                .foregroundStyle(isSelected ? .white : .exTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isSelected ? Color.exPrimary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(2)
    }

    private var heightSection: some View {
        GlassCard {
            VStack(spacing: 8) {
                Text("Height")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                if state.useMetric {
                    HStack {
                        Slider(value: $state.heightCm, in: 120...220, step: 1)
                            .tint(.exPrimary)
                        Text("\(Int(state.heightCm)) cm")
                            .font(.exStatSmall)
                            .foregroundStyle(.exTextPrimary)
                            .frame(width: 70)
                    }
                } else {
                    HStack(spacing: 16) {
                        Picker("Feet", selection: $state.heightFeet) {
                            ForEach(4...7, id: \.self) { Text("\($0) ft").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                        Picker("Inches", selection: $state.heightInches) {
                            ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 100)
                    }
                }
            }
        }
    }

    private var weightSection: some View {
        GlassCard {
            VStack(spacing: 8) {
                Text("Weight")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                if state.useMetric {
                    HStack {
                        Slider(value: $state.weightKg, in: 30...200, step: 0.5)
                            .tint(.exPrimary)
                        Text(String(format: "%.1f kg", state.weightKg))
                            .font(.exStatSmall)
                            .foregroundStyle(.exTextPrimary)
                            .frame(width: 80)
                    }
                } else {
                    HStack {
                        Slider(value: $state.weightLbs, in: 66...440, step: 1)
                            .tint(.exPrimary)
                        Text(String(format: "%.0f lbs", state.weightLbs))
                            .font(.exStatSmall)
                            .foregroundStyle(.exTextPrimary)
                            .frame(width: 80)
                    }
                }
            }
        }
    }

    private var bmiPreview: some View {
        GlassCard {
            HStack {
                Text("BMI Preview")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                Spacer()
                Text(String(format: "%.1f", state.bmiPreview))
                    .font(.exStatSmall)
                    .foregroundStyle(bmiColor)
            }
        }
    }

    private var bmiColor: Color {
        let bmi = state.bmiPreview
        if bmi < 18.5 { return .exWarning }
        if bmi < 25 { return .exSuccess }
        if bmi < 30 { return .exWarning }
        return .exError
    }
}
