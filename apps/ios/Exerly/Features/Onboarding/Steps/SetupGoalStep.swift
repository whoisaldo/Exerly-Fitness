import ExerlyCore
import SwiftUI

/// The goal, the weight it points to, and what calories aim for when that
/// differs from the training goal.
struct SetupGoalStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        SetupPage(title: "What's your goal?",
                  detail: "Pick what matters most right now. Training and calories can aim at different things.",
                  action: "Continue", perform: state.nextStep) {
            VStack(spacing: ExSpacing.small) {
                ForEach(FitnessGoal.allCases) { goal in
                    let selected = !state.unansweredFields.contains("goal") && state.goal == goal
                    SetupChoiceRow(title: goal.label, detail: Self.detail(goal), selected: selected) {
                        state.goal = goal
                        state.suggestTargetWeight()
                    } leading: {
                        SetupSymbol(name: goal.icon, selected: selected)
                    }
                }
            }
            SetupLabel("Calories")
            SetupRows {
                SetupRow(title: "Aim to") {
                    Picker("Nutrition goal", selection: Binding(
                        get: { state.nutritionGoal },
                        set: { state.nutritionGoalChoice = $0; state.suggestTargetWeight() }
                    )) {
                        Text("Lose weight").tag("lose")
                        Text("Maintain weight").tag("maintain")
                        Text("Gain weight").tag("gain")
                    }
                    .pickerStyle(.menu).tint(Color.exPrimaryText).frame(minHeight: 44)
                    .accessibilityIdentifier("setup.nutritionGoal")
                }
                if state.nutritionGoal != "maintain" {
                    SetupRow(title: "Goal weight") {
                        SetupNumberField(label: "Target weight", unit: state.useMetric ? "kg" : "lb",
                                         value: Mass.kg(state.targetWeightKg).value(in: state.useMetric ? .kilograms : .pounds),
                                         digits: 1, width: 120) { value in
                            guard let value else { state.targetWeightKg = 0; return }
                            state.targetWeightKg = state.useMetric ? value : Mass.lb(value).kilograms
                        }
                    }
                }
            }
            Text(state.nutritionGoalChoice == nil
                 ? "Follows your goal. Change it to eat for something else, like keeping your weight while you build muscle."
                 : "Set separately from your training goal.")
                .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    static func detail(_ goal: FitnessGoal) -> String {
        switch goal {
        case .loseWeight: "Lose fat at a pace you can keep"
        case .maintain: "Stay at your current weight"
        case .gainMuscle: "Build muscle with a small surplus"
        case .improveEndurance: "Train for stamina and eat to fuel it"
        case .generalHealth: "Eat well and move more"
        }
    }
}
