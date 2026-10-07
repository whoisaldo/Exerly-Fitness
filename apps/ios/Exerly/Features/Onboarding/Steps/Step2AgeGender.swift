import SwiftUI

struct Step2AgeGender: View {
    @ObservedObject var state: OnboardingState
    @State private var genderExpanded = false

    var body: some View {
        ExScreen {
            VStack(alignment: .leading, spacing: ExSpacing.item) {
                Text("Your starting measurements").font(.exH2).accessibilityAddTraits(.isHeader)
                Text("These help estimate your daily Calories. Use your current measurements; you can update them later.")
                    .font(.exBody).foregroundStyle(Color.exTextSecondary)
            }
            MeasurementFields(state: state)
            ExCard {
                Text("Age").font(.exBodyMedium)
                TextField("Age", value: $state.age, format: .number)
                    .keyboardType(.numberPad).font(.exStatSmall)
                    .padding(ExSpacing.item).frame(minHeight: 52)
                    .background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
                Text("Exerly currently supports adults aged 18 and over.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            ExCard {
                ExSectionHeading("Starting Calorie estimate")
                Text("The initial equation uses a male or female parameter, separate from gender identity. Or you can enter targets you already follow.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                Toggle("Use my own targets", isOn: $state.manualTargetMode).font(.exBodyMedium)
                if state.manualTargetMode {
                    targetField("Calories", unit: "kcal", value: $state.manualTargets.calories)
                    targetField("Protein", unit: "g", value: $state.manualTargets.protein_g)
                    targetField("Carbs", unit: "g", value: $state.manualTargets.carbs_g)
                    targetField("Fat", unit: "g", value: $state.manualTargets.fat_g)
                } else {
                    ExChoiceChips(values: ["male", "female"], selection: $state.physiologicalSex) { $0 == "male" ? "Male parameter" : "Female parameter" }
                        .accessibilityIdentifier("setup.formula")
                }
            }
            DisclosureGroup("Gender identity, optional", isExpanded: $genderExpanded) {
                Picker("Gender identity", selection: Binding(
                    get: { state.unansweredFields.contains("gender") ? "" : state.gender.rawValue },
                    set: { if let value = Gender(rawValue: $0) { state.gender = value } }
                )) {
                    Text("Choose").tag("")
                    ForEach(Gender.allCases) { gender in
                        Text(gender == .other ? "Other / prefer not to say" : gender.label).tag(gender.rawValue)
                    }
                }.frame(minHeight: 44)
                Text("This is saved to your profile and does not choose the Calorie equation.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }.font(.exLabel)
            Button("Continue") { state.nextStep() }.buttonStyle(ExActionStyle())
        }.scrollDismissesKeyboard(.interactively)
            .onAppear { genderExpanded = state.unansweredFields.contains("gender") }
    }

    private func targetField(_ title: String, unit: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            Text(title).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            HStack(alignment: .firstTextBaseline, spacing: ExSpacing.small) {
                TextField(title, value: value, format: .number).keyboardType(.decimalPad).font(.exStatSmall)
                Text(unit).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }.padding(ExSpacing.item).frame(minHeight: 52)
                .background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control))
        }
    }
}
