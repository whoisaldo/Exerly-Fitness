import SwiftUI

struct Step6ActivityTypes: View {
    @ObservedObject var state: OnboardingState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Favorite Activities")
                        .font(.exH2)
                        .foregroundStyle(.exTextPrimary)
                    Text("Select all that interest you")
                        .font(.exBody)
                        .foregroundStyle(.exTextSecondary)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(ActivityType.allCases) { type in
                        activityTile(type)
                    }
                }

                Spacer(minLength: 24)

                ActionButton(
                    title: "Continue",
                    isDisabled: state.activityTypes.isEmpty
                ) {
                    state.nextStep()
                }
            }
            .padding(24)
            .padding(.top, 16)
        }
    }

    private func activityTile(_ type: ActivityType) -> some View {
        let selected = state.activityTypes.contains(type)
        return Button {
            withAnimation(.spring(response: 0.3)) {
                if selected {
                    state.activityTypes.remove(type)
                } else {
                    state.activityTypes.insert(type)
                }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                Text(type.label)
                    .font(.exLabel)
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
