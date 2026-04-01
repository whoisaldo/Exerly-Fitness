import SwiftUI

struct Step9Equipment: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Your Equipment")
                        .font(.exH2)
                        .foregroundStyle(.exTextPrimary)
                    Text("Select what you have access to")
                        .font(.exBody)
                        .foregroundStyle(.exTextSecondary)
                }

                gymToggle

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(Equipment.allCases) { eq in
                        equipmentTile(eq)
                    }
                }

                Spacer(minLength: 24)

                ActionButton(title: "See My Plan") {
                    state.computeResults()
                    state.nextStep()
                }
            }
            .padding(24)
            .padding(.top, 16)
        }
    }

    private var gymToggle: some View {
        GlassCard {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.exPrimary)
                Text("Gym Access")
                    .font(.exBodyMedium)
                    .foregroundStyle(.exTextPrimary)
                Spacer()
                Toggle("", isOn: $state.hasGymAccess)
                    .tint(.exPrimary)
                    .labelsHidden()
            }
        }
    }

    private func equipmentTile(_ eq: Equipment) -> some View {
        let selected = state.equipment.contains(eq)
        return Button {
            withAnimation(.spring(response: 0.3)) {
                if selected { state.equipment.remove(eq) }
                else { state.equipment.insert(eq) }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: eq.icon)
                    .font(.system(size: 24))
                Text(eq.label)
                    .font(.exCaption)
            }
            .foregroundStyle(selected ? .exPrimary : .exTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(selected ? Color.exPrimary.opacity(0.1) : Color.exGlassBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.exPrimary.opacity(0.4) : Color.exGlassBorder, lineWidth: 1)
            )
        }
    }
}
