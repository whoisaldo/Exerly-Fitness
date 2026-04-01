import SwiftUI

// MARK: - Glass Card

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(Color.exGlassBg)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.exGlassBorder, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Primary Glow

struct PrimaryGlowModifier: ViewModifier {
    var radius: CGFloat = 20
    var opacity: Double = 0.4

    func body(content: Content) -> some View {
        content
            .shadow(color: Color.exPrimary.opacity(opacity), radius: radius, y: 4)
    }
}

extension View {
    func primaryGlow(radius: CGFloat = 20, opacity: Double = 0.4) -> some View {
        modifier(PrimaryGlowModifier(radius: radius, opacity: opacity))
    }
}

// MARK: - Accent Glow

extension View {
    func accentGlow(radius: CGFloat = 16, opacity: Double = 0.3) -> some View {
        shadow(color: Color.exAccent.opacity(opacity), radius: radius, y: 4)
    }
}

// MARK: - Surface Style

struct SurfaceModifier: ViewModifier {
    var level: Int = 1

    private var bgColor: Color {
        switch level {
        case 1: return .exSurface1
        case 2: return .exSurface2
        case 3: return .exSurface3
        default: return .exSurface1
        }
    }

    func body(content: Content) -> some View {
        content
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func surfaceStyle(level: Int = 1) -> some View {
        modifier(SurfaceModifier(level: level))
    }
}

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Slide Transition

extension AnyTransition {
    static func slideFromEdge(_ edge: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: edge == .leading ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: edge)
                .combined(with: .opacity)
        )
    }
}
