import SwiftUI

enum ActionButtonVariant {
    case primary, secondary, ghost
}

struct ActionButton: View {
    let title: String
    var variant: ActionButtonVariant = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var icon: String? = nil
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
                    }
                    Text(title)
                        .font(.exBodyMedium)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(textColor)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(borderOverlay)
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
        .modifier(GlowModifier(variant: variant))
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            LinearGradient.exPrimaryGradient
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
        case .ghost: return .exPrimary
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch variant {
        case .secondary:
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.exBorder, lineWidth: 1)
        case .ghost:
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.exPrimary.opacity(0.3), lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

private struct GlowModifier: ViewModifier {
    let variant: ActionButtonVariant

    func body(content: Content) -> some View {
        if variant == .primary {
            content.primaryGlow(radius: 16, opacity: 0.3)
        } else {
            content
        }
    }
}
