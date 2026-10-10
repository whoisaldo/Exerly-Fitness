import ExerlyCore
import SwiftUI

/// Step 3: everyday activity, then how and where the person trains. A
/// repair asks only for the activity.
struct SetupWeekStep: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        Group {
            if state.repairSteps != nil || state.planningPage == 0 { SetupActivityPage(state: state) }
            else { SetupTrainingPage(state: state) }
        }
        .id(state.planningPage)
    }
}

private struct SetupActivityPage: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        SetupPage(title: "Your everyday activity",
                  detail: "Think of a usual week, including work, walking and exercise.",
                  action: state.repairSteps != nil ? "Review my plan" : "Continue", perform: state.nextStep) {
            VStack(spacing: ExSpacing.small) {
                ForEach(Array(ActivityLevel.allCases.enumerated()), id: \.element) { index, level in
                    let selected = !state.unansweredFields.contains("activityLevel") && state.activityLevel == level
                    SetupChoiceRow(title: level.label, detail: level.subtitle, selected: selected) {
                        state.activityLevel = level
                    } leading: {
                        ActivityBars(level: index + 1, selected: selected)
                    }
                }
            }
            Text("Pick the closest fit. Your logs refine it over time.")
                .font(.exCaption).foregroundStyle(Color.exTextSecondary)
        }
    }
}

/// One to five rising bars: how much a level moves.
private struct ActivityBars: View {
    let level: Int
    let selected: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...5, id: \.self) { bar in
                Capsule()
                    .fill(bar <= level ? (selected ? Color.white : Color.exPrimaryText) : Color.exPrimary.opacity(selected ? 0.45 : 0.18))
                    .frame(width: 4, height: CGFloat(6 + bar * 4))
            }
        }
        .frame(width: 40, height: 40)
        .background(selected ? Color.exActionFill : Color.exPrimary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct SetupTrainingPage: View {
    @ObservedObject var state: OnboardingState
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        SetupPage(title: "Your training",
                  detail: "Train builds your workouts from this. Change it whenever your week changes.",
                  action: "Review my plan", perform: state.nextStep) {
            SetupLabel("Workouts a week")
            workoutsPerWeek
            Text(state.workoutDaysPerWeek == 0 ? "Nutrition only for now. Add training whenever you like."
                 : "A week you can keep beats an ambitious one. Rest days count.")
                .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if state.workoutDaysPerWeek > 0 {
                SetupLabel("Experience")
                VStack(spacing: ExSpacing.small) {
                    experience("beginner", title: "I'm new or starting again", detail: "Learning the movements")
                    experience("intermediate", title: "I train regularly", detail: "Comfortable with the main lifts")
                    experience("advanced", title: "I've trained for years", detail: "Used to structured programs")
                }
                SetupLabel("Where you train")
                VStack(spacing: ExSpacing.small) {
                    SetupChoiceRow(title: "A full gym", detail: "Barbells, dumbbells, cables and machines",
                                   selected: state.hasGymAccess) { state.hasGymAccess = true } leading: {
                        SetupSymbol(name: "building.2", selected: state.hasGymAccess)
                    }
                    SetupChoiceRow(title: "At home or with limited equipment", detail: "Choose what you have",
                                   selected: !state.hasGymAccess) { state.hasGymAccess = false } leading: {
                        SetupSymbol(name: "house", selected: !state.hasGymAccess)
                    }
                }
                if !state.hasGymAccess {
                    SetupToggleChips(items: Equipment.allCases, isOn: { state.equipment.contains($0) },
                                     title: \.label) { item in
                        if state.equipment.contains(item) { state.equipment.remove(item) } else { state.equipment.insert(item) }
                    }
                    .accessibilityLabel("Equipment you have")
                }
            }
        }
        .animation(.snappy, value: state.workoutDaysPerWeek == 0)
        .animation(.snappy, value: state.hasGymAccess)
    }

    private var workoutsPerWeek: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: ExSpacing.small), count: typeSize.isAccessibilitySize ? 2 : 4)
        return LazyVGrid(columns: columns, spacing: ExSpacing.small) {
            ForEach(0...7, id: \.self) { days in
                let selected = state.workoutDaysPerWeek == days
                Button {
                    state.workoutDaysPerWeek = days
                    state.workoutDays = []
                } label: {
                    Text(String(days)).font(.exStatMedium).monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(selected ? Color.white : Color.exTextPrimary)
                        .background(selected ? Color.exActionFill : Color.exSurface1,
                                    in: RoundedRectangle(cornerRadius: ExRadius.control, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: ExRadius.control, style: .continuous)
                                .strokeBorder(Color.exBorder.opacity(selected ? 0 : 0.5), lineWidth: 0.5)
                        }
                }
                .buttonStyle(TodayPressStyle())
                .accessibilityLabel("\(days) workouts per week")
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("setup.workouts.\(days)")
                .sensoryFeedback(.selection, trigger: selected) { _, new in new }
            }
        }
    }

    private func experience(_ value: String, title: String, detail: String) -> some View {
        SetupChoiceRow(title: title, detail: detail, selected: state.experienceLevel == value) {
            state.experienceLevel = value
        }
    }
}
