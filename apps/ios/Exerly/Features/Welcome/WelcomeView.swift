import SwiftUI

struct WelcomeView: View {
    let onLogin: () -> Void
    let onSignup: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            AnimatedOrbBackground()

            VStack(spacing: 0) {
                Spacer()
                logoSection
                Spacer()
                ctaSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { showContent = true }
        }
    }

    private var logoSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(.exPrimary)
                .primaryGlow(radius: 24, opacity: 0.6)

            Text("Exerly")
                .font(.exDisplay)
                .foregroundStyle(.exTextPrimary)

            Text("Your AI-powered fitness companion")
                .font(.exBody)
                .foregroundStyle(.exTextSecondary)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }

    private var ctaSection: some View {
        VStack(spacing: 14) {
            ActionButton(title: "Get Started", variant: .primary) {
                onSignup()
            }

            ActionButton(title: "I already have an account", variant: .ghost) {
                onLogin()
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.easeOut(duration: 0.8).delay(0.3), value: showContent)
    }
}
