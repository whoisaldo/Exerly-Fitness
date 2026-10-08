import SwiftUI

struct Step10Results: View {
    @ObservedObject var state: OnboardingState
    var onComplete: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ExScreen {
            VStack(alignment: .leading, spacing: ExSpacing.item) {
                Text("Review your targets").font(.exH2).accessibilityAddTraits(.isHeader)
                Text(state.manualTargetMode ? "Your own targets, ready for your diary." : "Your starting estimate. Use your logs to review what works for you.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            if let preview = state.serverPreview {
                ExCard(accent: true) {
                    ExEyebrow("Daily Calories")
                    HStack(alignment: .firstTextBaseline, spacing: ExSpacing.small) {
                        Text(preview.targets.calories, format: .number.precision(.fractionLength(0))).font(.exDisplay)
                        Text("kcal").font(.exBody).foregroundStyle(Color.exTextSecondary)
                    }.accessibilityElement(children: .combine)
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.content))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: ExSpacing.item))
                    layout {
                        nutrient("Protein", value: preview.targets.protein_g, color: .exPrimaryText)
                        nutrient("Carbs", value: preview.targets.carbs_g, color: .exAccent)
                        nutrient("Fat", value: preview.targets.fat_g, color: .exPrimaryText)
                    }
                }
                ExCard {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: ExSpacing.content) {
                            reviewLine("Nutrition goal", value: nutritionGoal)
                            reviewLine("Activity", value: state.activityLevel.label)
                            reviewLine("Macro split", value: macroStyle)
                            Text(state.manualTargetMode ? "Exerly will use the values you entered." : "This estimate is not a measurement of your metabolism. Review targets in Program as you build a history of food and weight logs.")
                                .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                        }.padding(.top, ExSpacing.item)
                    } label: { Text("Why these targets?").font(.exBodyMedium) }
                }
                if state.repairSteps == nil {
                    ExCard {
                        ExSectionHeading("Training")
                        Text(state.workoutDaysPerWeek == 0 ? "Nutrition only for now" : "\(state.workoutDaysPerWeek) workouts per week").font(.exBodyMedium)
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: ExSpacing.content) {
                                reviewLine("Experience", value: experience)
                                reviewLine("Equipment", value: state.hasGymAccess ? "Full gym" : state.equipment.isEmpty ? "No equipment selected" : state.equipment.map(\.label).sorted().joined(separator: ", "))
                            }.padding(.top, ExSpacing.item)
                        } label: { Text("Your training preferences").font(.exCaption) }
                        Text("Open Train to choose and review your workouts.")
                            .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    }
                    VStack(alignment: .leading, spacing: ExSpacing.item) {
                        ExSectionHeading("Your first day")
                        Label("Scan a barcode or search for your first meal.", systemImage: "barcode.viewfinder")
                        Label("Review your training plan before your first workout.", systemImage: "dumbbell")
                    }.font(.exBody)
                }
            } else if let error = state.previewError {
                ExCard {
                    Text("Your answers are saved").font(.exH3)
                    Text(error).font(.exBody).foregroundStyle(Color.exError)
                    Button("Try loading targets again") { Task { await state.loadPreview() } }.buttonStyle(ExActionStyle())
                }
            } else { ProgressView("Preparing your starting targets…").frame(maxWidth: .infinity, minHeight: 120) }
        }
        .safeAreaInset(edge: .bottom) {
            if state.serverPreview != nil {
                VStack(spacing: ExSpacing.small) {
                    if state.isSubmitting { ProgressView("Saving your setup…") }
                    Button("Finish setup") { onComplete?() }.buttonStyle(ExActionStyle())
                        .disabled(state.isSubmitting).accessibilityIdentifier("setup.finish")
                }.padding(ExSpacing.page).background(Color.exBackground)
            }
        }
        .task(id: state.previewIdentity) { await state.loadPreview() }
    }

    private func nutrient(_ title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            Text(title).font(.exCaption).foregroundStyle(color)
            Text("\(value, format: .number.precision(.fractionLength(0))) g").font(.exStatSmall)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }

    private func reviewLine(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.tight) {
            Text(title).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            Text(value).font(.exBodyMedium)
        }.accessibilityElement(children: .combine)
    }

    private var nutritionGoal: String {
        switch state.nutritionGoal {
        case "lose": "Lose weight"
        case "gain": "Gain weight"
        default: "Maintain weight"
        }
    }
    private var experience: String {
        switch state.experienceLevel {
        case "intermediate": "Training regularly"
        case "advanced": "Experienced with structured programs"
        default: "New or starting again"
        }
    }
    private var macroStyle: String {
        if state.manualTargetMode { return "Your own targets" }
        switch state.dietType ?? (state.dietaryStyle == .keto ? "keto" : "balanced") {
        case "low_fat": return "More carbs"
        case "low_carb": return "Fewer carbs"
        case "keto": return "Keto"
        case "high_protein": return "Higher protein"
        default: return "Balanced"
        }
    }
}
