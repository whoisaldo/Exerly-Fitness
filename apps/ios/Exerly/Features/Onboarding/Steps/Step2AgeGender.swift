import SwiftUI

struct Step2AgeGender: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Age & Gender")
                        .font(.exH2)
                        .foregroundStyle(.exTextPrimary)
                    Text("Helps us calculate your nutrition needs")
                        .font(.exBody)
                        .foregroundStyle(.exTextSecondary)
                }

                agePicker
                genderCards

                Spacer(minLength: 24)

                ActionButton(title: "Continue") { state.nextStep() }
            }
            .padding(24)
            .padding(.top, 16)
        }
    }

    private var agePicker: some View {
        GlassCard {
            VStack(spacing: 8) {
                Text("Age")
                    .font(.exLabel)
                    .foregroundStyle(.exTextSecondary)
                Picker("Age", selection: $state.age) {
                    ForEach(13...100, id: \.self) { age in
                        Text("\(age)").tag(age)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }
        }
    }

    private var genderCards: some View {
        VStack(spacing: 8) {
            Text("Gender")
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(Gender.allCases) { g in
                    genderCard(g)
                }
            }
        }
    }

    private func genderCard(_ g: Gender) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { state.gender = g }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: g.icon)
                    .font(.system(size: 28))
                Text(g.label)
                    .font(.exLabel)
            }
            .foregroundStyle(state.gender == g ? .exPrimary : .exTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(state.gender == g ? Color.exPrimary.opacity(0.1) : Color.exGlassBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(state.gender == g ? Color.exPrimary.opacity(0.4) : Color.exGlassBorder, lineWidth: 1)
            )
        }
    }
}
