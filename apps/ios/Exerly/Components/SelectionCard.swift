import SwiftUI

struct SelectionCard: View {
    let title: String
    var subtitle: String?
    var icon: String?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? .exPrimary : .exTextSecondary)
                        .frame(width: 40, height: 40)
                        .background(
                            isSelected
                                ? Color.exPrimary.opacity(0.15)
                                : Color.exSurface2
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ExRadius.control))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.exBodyMedium)
                        .foregroundStyle(.exTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.exCaption)
                            .foregroundStyle(.exTextSecondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .exPrimary : .exTextMuted)
                    .font(.system(size: 22))
            }
            .padding(ExSpacing.content)
            .background(isSelected ? Color.exPrimary.opacity(0.08) : Color.exGlassBg)
            .clipShape(RoundedRectangle(cornerRadius: ExRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: ExRadius.card)
                    .stroke(
                        isSelected ? Color.exPrimary.opacity(0.4) : Color.exGlassBorder,
                        lineWidth: 1
                    )
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isSelected)
    }
}
