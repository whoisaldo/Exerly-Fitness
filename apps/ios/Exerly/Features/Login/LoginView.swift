import SwiftUI

struct LoginView: View {
    let onBack: () -> Void
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var shakeAttempts: CGFloat = 0

    var body: some View {
        ZStack {
            Color.exBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    inputFields
                    errorMessage
                    loginButton
                    socialPlaceholders
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
        }
        .overlay(alignment: .topLeading) { backButton }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Welcome back")
                .font(.exH1)
                .foregroundStyle(.exTextPrimary)
            Text("Log in to continue your journey")
                .font(.exBody)
                .foregroundStyle(.exTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputFields: some View {
        VStack(spacing: 16) {
            FloatingLabelTextField(label: "Email", text: $email, keyboardType: .emailAddress)
            FloatingLabelTextField(label: "Password", text: $password, isSecure: true)
        }
        .modifier(ShakeEffect(animatableData: shakeAttempts))
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let error = authVM.error {
            Text(error)
                .font(.exCaption)
                .foregroundStyle(.exError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var loginButton: some View {
        ActionButton(
            title: "Log In",
            isLoading: authVM.isSubmitting,
            isDisabled: email.isEmpty || password.isEmpty
        ) {
            Task {
                await authVM.login(email: email, password: password)
                if authVM.error != nil {
                    withAnimation(.spring(response: 0.3)) {
                        shakeAttempts += 1
                    }
                }
            }
        }
    }

    private var socialPlaceholders: some View {
        VStack(spacing: 12) {
            divider
            ActionButton(title: "Continue with Apple", variant: .secondary, icon: "apple.logo") {}
                .disabled(true)
                .opacity(0.5)
            ActionButton(title: "Continue with Google", variant: .secondary, icon: "globe") {}
                .disabled(true)
                .opacity(0.5)
        }
    }

    private var divider: some View {
        HStack {
            Rectangle().fill(Color.exBorder).frame(height: 1)
            Text("or").font(.exCaption).foregroundStyle(.exTextMuted)
            Rectangle().fill(Color.exBorder).frame(height: 1)
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.exTextPrimary)
                .frame(width: 44, height: 44)
        }
        .padding(.leading, 12)
        .padding(.top, 8)
    }
}
