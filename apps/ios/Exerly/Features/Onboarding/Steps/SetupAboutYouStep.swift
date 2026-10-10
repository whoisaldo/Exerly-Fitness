import ExerlyCore
import SwiftUI

/// The first page: name, units, and the measurements the calorie estimate
/// needs, on one screen like a health details form.
struct SetupAboutYouStep: View {
    @ObservedObject var state: OnboardingState
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Fixed when the page opens, so the question stays while it's answered.
    @State private var asksGender = false

    private var asksName: Bool { state.visibleSteps.contains(0) }

    var body: some View {
        SetupPage(title: "About you",
                  detail: "These set your starting calories. You can change any of them later in Profile.",
                  action: "Continue", perform: state.continueFromAboutYou) {
            if asksName {
                SetupRows {
                    SetupRow(title: "Name") {
                        TextField("Your name", text: $state.name, prompt: Text("Your name").foregroundColor(.exTextMuted))
                            .font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                            .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                            .textContentType(.name).textInputAutocapitalization(.words).autocorrectionDisabled()
                            .submitLabel(.done)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Your name")
                    }
                }
            }
            SetupLabel("Units")
            ExSegmentedControl(values: [false, true], selection: $state.useMetric) { $0 ? "Metric" : "U.S." }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Units")
            Text(state.useMetric ? "Kilograms and centimeters. Food energy in kcal."
                 : "Pounds, feet and inches. Food energy in kcal.")
                .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            SetupLabel("Your body")
            SetupRows {
                SetupRow(title: "Sex") {
                    ExSegmentedControl(values: ["female", "male"], selection: $state.physiologicalSex) { $0.capitalized }
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 200)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Sex, for the calorie estimate")
                        .accessibilityIdentifier("setup.formula")
                }
                SetupRow(title: "Age") {
                    SetupStepper(label: "Age", value: state.age, range: 18...120) { state.age = $0 }
                }
                SetupRow(title: "Height") { height }
                SetupRow(title: "Weight") {
                    SetupNumberField(label: state.useMetric ? "Weight, kg" : "Weight, lb",
                                     unit: state.useMetric ? "kg" : "lb",
                                     value: state.useMetric ? state.weightKg : state.weightLbs, digits: 2, width: 120) { value in
                        if state.useMetric { state.weightKg = value ?? 0 } else { state.weightLbs = value ?? 0 }
                    }
                }
            }
            Text("Sex sets the calorie equation. Your weight becomes your first weigh-in.")
                .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if asksGender { genderIdentity }
        }
        .onAppear { asksGender = asksGender || state.unansweredFields.contains("gender") }
    }

    @ViewBuilder private var height: some View {
        if state.useMetric {
            SetupNumberField(label: "Height, cm", unit: "cm", value: state.heightCm, digits: 1, width: 120) { value in
                state.heightCm = value ?? 0
            }
        } else {
            HStack(spacing: ExSpacing.small) {
                SetupNumberField(label: "Height, feet", unit: "ft", value: Double(state.heightFeet), integer: true, width: 76) { value in
                    state.heightFeet = Int(value ?? 0)
                }
                SetupNumberField(label: "Height, inches", unit: "in", value: Double(state.heightInches), integer: true, width: 76) { value in
                    state.heightInches = Int(value ?? 0)
                }
            }
        }
    }

    /// Asked only when repairing an account saved without one.
    private var genderIdentity: some View {
        SetupRows {
            SetupRow(title: "Gender identity") {
                Picker("Gender identity", selection: Binding(
                    get: { state.unansweredFields.contains("gender") ? "" : state.gender.rawValue },
                    set: { if let value = Gender(rawValue: $0) { state.gender = value } }
                )) {
                    Text("Choose").tag("")
                    ForEach(Gender.allCases) { gender in
                        Text(gender == .other ? "Other or prefer not to say" : gender.label).tag(gender.rawValue)
                    }
                }
                .pickerStyle(.menu).tint(Color.exPrimaryText).frame(minHeight: 44)
            }
        }
    }
}
