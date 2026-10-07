import ExerlyCore
import SwiftUI

struct Step5ActivityLevel: View {
    @ObservedObject var state: OnboardingState
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ExScreen {
            if state.repairSteps != nil || state.planningPage == 0 { activity }
            else if state.planningPage == 1 { training }
            else if state.planningPage == 2 { equipment }
            else { nutrition }
        }
        .id(state.planningPage)
        .safeAreaInset(edge: .bottom) {
            Button(state.repairSteps != nil || state.planningPage == 3 ? "Review my plan" : "Continue") { state.nextStep() }
                .buttonStyle(ExActionStyle()).accessibilityIdentifier("setup.continueWeek")
                .padding(ExSpacing.page).background(Color.exBackground)
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: ExSpacing.section) {
            heading("Your everyday activity", detail: "Think about a usual week, including work, walking and exercise. This helps estimate your starting Calories.")
            VStack(spacing: ExSpacing.item) {
                ForEach(ActivityLevel.allCases) { level in
                    SelectionCard(title: level.label, subtitle: level.subtitle,
                                  isSelected: !state.unansweredFields.contains("activityLevel") && state.activityLevel == level) {
                        state.activityLevel = level
                    }
                }
            }
            Text("Choose the closest fit. Your logs give you a better picture over time.")
                .font(.exCaption).foregroundStyle(Color.exTextSecondary)
        }
    }

    private var training: some View {
        VStack(alignment: .leading, spacing: ExSpacing.section) {
            heading("A week you can stick to", detail: "Start with the time you have. Save your training experience and weekly goal now; review exercises in Train.")
            ExCard {
                ExSectionHeading("Workouts per week")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: ExSpacing.small), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: ExSpacing.small) {
                    ForEach(0...7, id: \.self) { days in
                        Button {
                            state.workoutDaysPerWeek = days
                            state.workoutDays = []
                        } label: {
                            Text(String(days)).font(.exStatSmall).frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(state.workoutDaysPerWeek == days ? Color.white : Color.exTextPrimary)
                                .background(state.workoutDaysPerWeek == days ? Color.exActionFill : Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                        }.buttonStyle(.plain).accessibilityLabel("\(days) workouts per week")
                            .accessibilityAddTraits(state.workoutDaysPerWeek == days ? .isSelected : [])
                            .accessibilityIdentifier("setup.workouts.\(days)")
                    }
                }
                Text(state.workoutDaysPerWeek == 0 ? "Just nutrition for now. You can add training later." : "Choose a realistic starting week. Rest days are part of the plan.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            VStack(alignment: .leading, spacing: ExSpacing.item) {
                ExSectionHeading("Your training experience")
                SelectionCard(title: "I'm new or starting again", subtitle: "Learning the movements and building a routine.", isSelected: state.experienceLevel == "beginner") { state.experienceLevel = "beginner" }
                SelectionCard(title: "I train regularly", subtitle: "Comfortable with the main lifts and tracking sets.", isSelected: state.experienceLevel == "intermediate") { state.experienceLevel = "intermediate" }
                SelectionCard(title: "I've trained for years", subtitle: "Experienced with structured programs and progression.", isSelected: state.experienceLevel == "advanced") { state.experienceLevel = "advanced" }
            }
        }
    }

    private var equipment: some View {
        VStack(alignment: .leading, spacing: ExSpacing.section) {
            heading("Where will you train?", detail: "Save the equipment you can use. You can change this when you build a workout.")
            SelectionCard(title: "A full gym", subtitle: "Barbells, dumbbells, cables and machines.", icon: "building.2", isSelected: state.hasGymAccess) { state.hasGymAccess = true }
            SelectionCard(title: "At home or with limited equipment", subtitle: "Choose what you have below.", icon: "house", isSelected: !state.hasGymAccess) { state.hasGymAccess = false }
            if !state.hasGymAccess {
                MultiSelectGrid(items: Equipment.allCases, selected: $state.equipment, label: { $0.label }, icon: { $0.icon })
            }
        }
    }

    private var nutrition: some View {
        VStack(alignment: .leading, spacing: ExSpacing.section) {
            heading("Nutrition that fits your day", detail: state.manualTargetMode ? "Your own Calorie and macro targets stay in place." : "Choose how your Calorie target is split between protein, carbs and fat. You can change this later.")
            if !state.manualTargetMode {
                VStack(spacing: ExSpacing.item) {
                    SelectionCard(title: "Balanced", subtitle: "A flexible starting point with room for carbs and fats.", isSelected: (state.dietType ?? "balanced") == "balanced") { state.dietType = "balanced" }
                    SelectionCard(title: "More carbs", subtitle: "More of your Calories from carbs, less from fat.", isSelected: state.dietType == "low_fat") { state.dietType = "low_fat" }
                    SelectionCard(title: "Fewer carbs", subtitle: "More of your Calories from fat, less from carbs.", isSelected: state.dietType == "low_carb") { state.dietType = "low_carb" }
                }
            }
            if !state.manualTargetMode {
                DisclosureGroup("More macro styles") {
                    VStack(spacing: ExSpacing.item) {
                        SelectionCard(title: "Keto", subtitle: "A very low-carb split.", isSelected: (state.dietType ?? (state.dietaryStyle == .keto ? "keto" : "balanced")) == "keto") { state.dietType = "keto" }
                        SelectionCard(title: "Higher protein", subtitle: "A larger share of Calories from protein.", isSelected: state.dietType == "high_protein") { state.dietType = "high_protein" }
                    }.padding(.top, ExSpacing.item)
                }.font(.exLabel)
            }
            ExCard {
                ExSectionHeading("Meals in a typical day")
                ExChoiceChips(values: Array(2...6), selection: $state.mealsPerDay) { String($0) }
                Text("A preference, not a rule. Log whenever you eat.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            DisclosureGroup("Food preferences, optional") {
                VStack(spacing: ExSpacing.item) {
                    ForEach(DietaryStyle.allCases) { style in
                        SelectionCard(title: style == .standard ? "No particular eating style" : style.label,
                                      isSelected: state.dietaryStyle == style) {
                            if state.dietType == nil { state.dietType = state.dietaryStyle == .keto ? "keto" : "balanced" }
                            state.dietaryStyle = style
                        }
                    }
                    Text("Saved to your profile. These preferences do not change the macro split above or filter the food database.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }.padding(.top, ExSpacing.item)
            }.font(.exLabel)
        }
    }

    private func heading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            Text(title).font(.exH2).accessibilityAddTraits(.isHeader)
            Text(detail).font(.exBody).foregroundStyle(Color.exTextSecondary)
        }
    }
}
