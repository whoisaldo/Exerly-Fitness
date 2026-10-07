import SwiftUI

enum ActionButtonVariant {
    case primary, secondary, ghost
}

struct ActionButton: View {
    let title: String
    var variant: ActionButtonVariant = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(textColor)
                        .scaleEffect(0.8)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.exBodyMedium)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, ExSpacing.content)
            .padding(.vertical, ExSpacing.item)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .foregroundStyle(textColor)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: ExRadius.control))
            .overlay(borderOverlay)
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "In progress" : "")
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            Color.exActionFill
        case .secondary:
            Color.exSurface2
        case .ghost:
            Color.clear
        }
    }

    private var textColor: Color {
        switch variant {
        case .primary: return .white
        case .secondary: return .exTextPrimary
        case .ghost: return .exPrimaryText
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch variant {
        case .secondary:
            RoundedRectangle(cornerRadius: ExRadius.control)
                .stroke(Color.exBorder, lineWidth: 1)
        case .ghost:
            RoundedRectangle(cornerRadius: ExRadius.control)
                .stroke(Color.exBorder, lineWidth: 1)
        default:
            EmptyView()
        }
    }
}
