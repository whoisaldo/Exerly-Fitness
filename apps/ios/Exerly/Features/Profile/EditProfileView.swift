import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var age: String = ""
    @State private var weight: String = ""
    @State private var height: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    GlassCard {
                        VStack(spacing: 16) {
                            field("Name", text: $name, keyboard: .default)
                            field("Age", text: $age, keyboard: .numberPad)
                            field("Weight (kg)", text: $weight, keyboard: .decimalPad)
                            field("Height (cm)", text: $height, keyboard: .decimalPad)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.exCaption)
                            .foregroundStyle(.exError)
                    }

                    ActionButton(title: isSaving ? "Saving..." : "Save Changes", variant: .primary) {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
                .padding(20)
            }
            .background(Color.exBackground)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.exTextSecondary)
                }
            }
            .onAppear { loadCurrent() }
        }
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)
            TextField(label, text: text)
                .font(.exBody)
                .foregroundStyle(.exTextPrimary)
                .keyboardType(keyboard)
                .padding(12)
                .background(Color.exSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func loadCurrent() {
        let user = authVM.currentUser
        name = user?.name ?? ""
        age = user?.age != nil ? "\(user!.age!)" : ""
        weight = user?.weight != nil ? String(format: "%.0f", user!.weight!) : ""
        height = user?.height != nil ? String(format: "%.0f", user!.height!) : ""
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            let data = ProfileUpdateRequest(
                name: name.isEmpty ? nil : name,
                age: Int(age),
                height: Double(height),
                weight: Double(weight)
            )
            let updated = try await APIClient.shared.updateProfile(data)
            await MainActor.run {
                authVM.currentUser = updated
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
