import ExerlyCore
import SwiftUI

struct Step4Goals: View {
    @ObservedObject var state: OnboardingState
    @State private var targetWeightText = ""
    @State private var inputError: String?
    @FocusState private var editingWeight: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("What's your goal?")
                        .font(.exH2)
                        .foregroundStyle(.exTextPrimary)
                    Text("Start with what matters most to you. Your food and training goals can be different.")
                        .font(.exBody)
                        .foregroundStyle(.exTextSecondary)
                }

                goalCards
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition goal").font(.headline)
                        Picker("Nutrition goal", selection: Binding(
                            get: { state.nutritionGoal },
                            set: { state.nutritionGoalChoice = $0 }
                        )) {
                            Text("Lose weight").tag("lose")
                            Text("Maintain weight").tag("maintain")
                            Text("Gain weight").tag("gain")
                        }.pickerStyle(.menu).tint(.exTextPrimary).frame(minHeight: 44)
                            .accessibilityIdentifier("setup.nutritionGoal")
                        Text("Your nutrition goal can differ from your training goal.")
                            .font(.callout).foregroundStyle(.exTextSecondary)
                    }
                }
                targetWeightSection

                Spacer(minLength: 24)

                if let inputError { Text(inputError).foregroundStyle(Color.exError) }
                ActionButton(title: "Continue") {
                    if state.nutritionGoal != "maintain" {
                        guard let value = UserEnteredNumber.parse(targetWeightText) else {
                            inputError = "Enter a valid target weight."
                            return
                        }
                        state.targetWeightKg = state.useMetric ? value : Mass.lb(value).kilograms
                    }
                    inputError = nil
                    state.nextStep()
                }
            }
            .padding(24)
            .padding(.top, 16)
        }
        .onAppear { refreshWeightText() }
        .onChange(of: state.useMetric) { _, _ in refreshWeightText() }
        .onChange(of: state.targetWeightKg) { _, _ in
            if !editingWeight { refreshWeightText() }
        }
    }

    private var goalCards: some View {
        VStack(spacing: 10) {
            ForEach(FitnessGoal.allCases) { goal in
                SelectionCard(
                    title: goal.label,
                    icon: goal.icon,
                    isSelected: !state.unansweredFields.contains("goal") && state.goal == goal
                ) {
                    state.goal = goal
                }
            }
        }
    }

    @ViewBuilder
    private var targetWeightSection: some View {
        if state.nutritionGoal != "maintain" {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Target weight, \(state.useMetric ? "kg" : "lb")").font(.headline)
                    TextField("Target weight", text: $targetWeightText)
                        .keyboardType(.decimalPad).font(.exStatSmall).foregroundStyle(Color.exTextPrimary)
                        .padding(ExSpacing.item)
                        .background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                        .focused($editingWeight)
                        .frame(minHeight: 44).accessibilityLabel("Target weight")
                        .onChange(of: targetWeightText) { _, text in
                            if let value = UserEnteredNumber.parse(text) {
                                state.targetWeightKg = state.useMetric ? value : Mass.lb(value).kilograms
                            }
                        }
                    Text("Your initial targets will be shown for review. You can adjust your goal in Program.")
                        .font(.callout).foregroundStyle(.exTextSecondary)
                }
            }
        }
    }

    private func refreshWeightText() {
        let value = Mass.kg(state.targetWeightKg).value(in: state.useMetric ? .kilograms : .pounds)
        targetWeightText = value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }
}
