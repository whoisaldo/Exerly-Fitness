import SwiftUI

struct WelcomeView: View {
    let onLogin: () -> Void
    let onSignup: () -> Void

    @State private var showContent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            PulseBackground()

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 24)
                        logoSection
                        Spacer(minLength: 32)
                        ctaSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { showContent = true }
        }
    }

    private var logoSection: some View {
        VStack(spacing: 16) {
            Image("ExerlyMark")
                .resizable().scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .accessibilityHidden(true)

            Text("Exerly")
                .font(.exDisplay)
                .foregroundStyle(.exTextPrimary)

            Text("Training and nutrition, on your terms.")
                .font(.exBody)
                .foregroundStyle(.exTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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
        .animation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.3), value: showContent)
    }
}
