import SwiftUI

struct SignupView: View {
    let onBack: () -> Void
    var onSwitchToLogin: (() -> Void)? = nil
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var agreedToTerms = false
    @State private var shakeAttempts: CGFloat = 0
    @State private var emailAlreadyExists = false

    private var passwordStrength: Double {
        var score = 0.0
        if password.count >= 6 { score += 0.25 }
        if password.count >= 10 { score += 0.25 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 0.25 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 0.25 }
        return score
    }

    private var strengthColor: Color {
        switch passwordStrength {
        case 0..<0.5: return .exError
        case 0.5..<0.75: return .exWarning
        default: return .exSuccess
        }
    }

    private var isValid: Bool {
        !name.isEmpty && !email.isEmpty && password.count >= 6 && agreedToTerms
    }

    var body: some View {
        ZStack {
            Color.exBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    inputFields
                    passwordStrengthBar
                    termsToggle
                    errorMessage
                    signupButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
        }
        .overlay(alignment: .topLeading) { backButton }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Create account")
                .font(.exH1)
                .foregroundStyle(.exTextPrimary)
            Text("Start your fitness journey today")
                .font(.exBody)
                .foregroundStyle(.exTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputFields: some View {
        VStack(spacing: 16) {
            FloatingLabelTextField(label: "Full Name", text: $name)
            FloatingLabelTextField(label: "Email", text: $email, keyboardType: .emailAddress)
                .onChange(of: email) { _, _ in emailAlreadyExists = false; authVM.error = nil }
            FloatingLabelTextField(label: "Password", text: $password, isSecure: true)
        }
        .modifier(ShakeEffect(animatableData: shakeAttempts))
    }

    private var passwordStrengthBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.exSurface2)
                Capsule()
                    .fill(strengthColor)
                    .frame(width: geo.size.width * passwordStrength)
                    .animation(.spring(response: 0.3), value: passwordStrength)
            }
        }
        .frame(height: 4)
        .opacity(password.isEmpty ? 0 : 1)
    }

    private var termsToggle: some View {
        Button {
            agreedToTerms.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                    .foregroundStyle(agreedToTerms ? .exPrimary : .exTextMuted)
                    .font(.system(size: 20))
                Text("I agree to the Terms of Service & Privacy Policy")
                    .font(.exCaption)
                    .foregroundStyle(.exTextSecondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var errorMessage: some View {
        if emailAlreadyExists {
            VStack(alignment: .leading, spacing: 8) {
                Text("An account with this email already exists.")
                    .font(.exCaption)
                    .foregroundStyle(.exError)
                Button {
                    authVM.error = nil
                    emailAlreadyExists = false
                    if let onSwitchToLogin {
                        onSwitchToLogin()
                    } else {
                        onBack()
                    }
                } label: {
                    Text("Log in instead →")
                        .font(.exLabel)
                        .foregroundStyle(.exPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let error = authVM.error {
            Text(error)
                .font(.exCaption)
                .foregroundStyle(.exError)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var signupButton: some View {
        ActionButton(
            title: "Create Account",
            isLoading: authVM.isSubmitting,
            isDisabled: !isValid
        ) {
            Task {
                emailAlreadyExists = false
                await authVM.signup(email: email, password: password, name: name)
                if let err = authVM.error {
                    let isConflict = err.lowercased().contains("already exists")
                        || err.lowercased().contains("409")
                    emailAlreadyExists = isConflict
                    withAnimation(.spring(response: 0.3)) {
                        shakeAttempts += 1
                    }
                }
            }
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
