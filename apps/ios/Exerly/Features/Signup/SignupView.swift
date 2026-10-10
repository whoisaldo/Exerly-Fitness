import SwiftUI

struct SignupView: View {
    let onBack: () -> Void
    var onSwitchToLogin: (() -> Void)?
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var agreedToTerms = false
    @State private var shakeAttempts: CGFloat = 0
    @State private var emailAlreadyExists = false
    @FocusState private var focus: Field?
    @AccessibilityFocusState private var errorFocused: Bool

    enum Field { case name, email, password }

    private var longEnough: Bool { password.count >= 8 }

    /// 0 to 1, from length, case and digits. A hint, not a rule.
    private var strength: Double {
        var score = 0.0
        if password.count >= 8 { score += 0.25 }
        if password.count >= 12 { score += 0.25 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil && password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 0.25 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil || password.rangeOfCharacter(from: .punctuationCharacters) != nil { score += 0.25 }
        return score
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && email.contains("@") && longEnough && agreedToTerms
    }

    var body: some View {
        AuthPage(title: "Create your account", detail: "Then a few quick questions to set your targets.", onBack: onBack) {
            VStack(spacing: ExSpacing.small) {
                AuthField(title: "Name", kind: .name, text: $name, field: Field.name, focus: $focus) { focus = .email }
                AuthField(title: "Email", kind: .email, text: $email, field: Field.email, focus: $focus) { focus = .password }
                    .onChange(of: email) { _, _ in emailAlreadyExists = false; authVM.error = nil }
                AuthField(title: "Password", kind: .newPassword, text: $password, field: Field.password, focus: $focus,
                          submitLabel: .done) { focus = nil }
            }
            .modifier(ShakeEffect(animatableData: shakeAttempts))
            passwordHint
            terms
            errorMessage
            Button(action: submit) {
                HStack(spacing: ExSpacing.small) {
                    if authVM.isSubmitting { ProgressView().tint(.white) }
                    Text("Create Account")
                }
            }
            .buttonStyle(ExActionStyle())
            .disabled(!isValid || authVM.isSubmitting)
            AuthDivider().padding(.vertical, ExSpacing.tight)
            AppleAuthorizationButton(label: .signUp) { payload in
                await authVM.signInWithApple(identityToken: payload.identityToken, rawNonce: payload.rawNonce, name: payload.name)
                if authVM.error != nil { errorFocused = true }
            }
            .disabled(!agreedToTerms || authVM.isSubmitting)
            .opacity(agreedToTerms ? 1 : 0.5)
            if !agreedToTerms {
                Text("Agree to the terms to sign up with Apple.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            if let onSwitchToLogin {
                AuthSwitchLink(question: "Already have an account?", action: "Log in") {
                    authVM.error = nil
                    onSwitchToLogin()
                }
                .padding(.top, ExSpacing.small)
            }
        }
        .onAppear { authVM.error = nil }
    }

    private var passwordHint: some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            if !password.isEmpty {
                GeometryReader { geometry in
                    Capsule().fill(Color.exSurface2)
                        .overlay(alignment: .leading) {
                            Capsule().fill(strength < 0.5 ? Color.exWarning : Color.exSuccess)
                                .frame(width: geometry.size.width * max(strength, 0.08))
                        }
                }
                .frame(height: 4)
                .animation(.snappy, value: strength)
                .accessibilityHidden(true)
            }
            Label("At least 8 characters", systemImage: longEnough ? "checkmark.circle.fill" : "circle")
                .font(.exCaption)
                .foregroundStyle(longEnough ? Color.exSuccess : Color.exTextSecondary)
                .accessibilityLabel(longEnough ? "Password has at least 8 characters" : "Use at least 8 characters")
        }
        .padding(.horizontal, ExSpacing.tight)
    }

    private var terms: some View {
        Button {
            agreedToTerms.toggle()
        } label: {
            HStack(alignment: .top, spacing: ExSpacing.item) {
                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(agreedToTerms ? Color.exPrimaryText : Color.exTextMuted)
                    .accessibilityHidden(true)
                Text("I agree to the Terms of Service & Privacy Policy")
                    .font(.exLabel).foregroundStyle(Color.exTextSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("I agree to the Terms of Service & Privacy Policy")
        .accessibilityAddTraits(agreedToTerms ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: agreedToTerms)
    }

    @ViewBuilder
    private var errorMessage: some View {
        if emailAlreadyExists {
            VStack(alignment: .leading, spacing: ExSpacing.tight) {
                Label("An account with this email already exists.", systemImage: "exclamationmark.circle.fill")
                    .font(.exLabel).foregroundStyle(Color.exError)
                    .accessibilityFocused($errorFocused)
                Button("Log in instead") {
                    authVM.error = nil
                    emailAlreadyExists = false
                    if let onSwitchToLogin { onSwitchToLogin() } else { onBack() }
                }
                .font(.exLabel.weight(.semibold)).foregroundStyle(Color.exPrimaryText).frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let error = authVM.error {
            Label(error, systemImage: "exclamationmark.circle.fill")
                .font(.exLabel).foregroundStyle(Color.exError)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityFocused($errorFocused)
        }
    }

    private func submit() {
        focus = nil
        Task {
            emailAlreadyExists = false
            await authVM.signup(email: email.trimmingCharacters(in: .whitespaces), password: password,
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            if let err = authVM.error {
                emailAlreadyExists = err.lowercased().contains("already exists") || err.lowercased().contains("409")
                errorFocused = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(.spring(response: 0.3)) { shakeAttempts += 1 }
            }
        }
    }
}
