import SwiftUI

struct Step2AgeGender: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your measurements").font(.exH2)
                Text("Exerly supports adults aged 18 and over.")
                    .font(.body).foregroundStyle(.exTextSecondary)
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Age")
                            TextField("Age", value: $state.age, format: .number)
                                .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing).frame(minHeight: 44)
                        }
                        Picker("Gender identity", selection: Binding(
                            get: { state.unansweredFields.contains("gender") ? "" : state.gender.rawValue },
                            set: { if let value = Gender(rawValue: $0) { state.gender = value } }
                        )) {
                            Text("Choose").tag("")
                            ForEach(Gender.allCases) { gender in
                                Text(gender == .other ? "Other / prefer not to say" : gender.label).tag(gender.rawValue)
                            }
                        }.frame(minHeight: 44)
                    }
                }
                MeasurementFields(state: state)
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition calculation").font(.headline)
                        Text("The initial formula uses a physiological sex parameter, separate from gender identity. You can use your own targets instead.")
                            .font(.callout).foregroundStyle(.exTextSecondary)
                        Toggle("Use my own targets", isOn: $state.manualTargetMode)
                        if state.manualTargetMode {
                            targetField("Calories", value: $state.manualTargets.calories)
                            targetField("Protein, g", value: $state.manualTargets.protein_g)
                            targetField("Carbohydrate, g", value: $state.manualTargets.carbs_g)
                            targetField("Fat, g", value: $state.manualTargets.fat_g)
                        } else {
                            Picker("Formula parameter", selection: $state.physiologicalSex) {
                                Text("Choose").tag("")
                                Text("Male parameter").tag("male")
                                Text("Female parameter").tag("female")
                            }.pickerStyle(.menu).frame(minHeight: 44)
                        }
                    }
                }
                ActionButton(title: "Continue") { state.nextStep() }
            }.padding(24)
        }.scrollDismissesKeyboard(.interactively)
    }

    private func targetField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder).frame(minHeight: 44)
        }
    }
}
