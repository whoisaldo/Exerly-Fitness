import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    GlassCard {
                        VStack(spacing: 16) {
                            secureField("Current Password", text: $currentPassword)
                            secureField("New Password", text: $newPassword)
                            secureField("Confirm New Password", text: $confirmPassword)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.exCaption)
                            .foregroundStyle(.exError)
                    }

                    if showSuccess {
                        Text("Password changed successfully!")
                            .font(.exCaption)
                            .foregroundStyle(.exSuccess)
                    }

                    ActionButton(title: isSaving ? "Changing..." : "Change Password", variant: .primary) {
                        Task { await changePassword() }
                    }
                    .disabled(isSaving || !isValid)
                }
                .padding(20)
            }
            .background(Color.exBackground)
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.exTextSecondary)
                }
            }
        }
    }

    private var isValid: Bool {
        !currentPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)
            SecureField(label, text: text)
                .font(.exBody)
                .foregroundStyle(.exTextPrimary)
                .padding(12)
                .background(Color.exSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func changePassword() async {
        guard isValid else {
            errorMessage = newPassword.count < 6
                ? "New password must be at least 6 characters"
                : "Passwords don't match"
            return
        }

        isSaving = true
        errorMessage = nil
        showSuccess = false

        do {
            let _: APIMessageResponse = try await APIClient.shared.post(
                "/api/change-password",
                body: ChangePasswordRequest(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
            )
            showSuccess = true
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run { dismiss() }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}
