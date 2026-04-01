import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var showImagePicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                avatarSection
                statsRow
                settingsSections
                logoutButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.exBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            Button { showImagePicker = true } label: {
                ZStack {
                    Circle()
                        .fill(Color.exSurface2)
                        .frame(width: 90, height: 90)
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.exTextMuted)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.exPrimary)
                        .clipShape(Circle())
                        .offset(x: 30, y: 30)
                }
            }

            Text(authVM.currentUser?.name ?? "Athlete")
                .font(.exH2)
                .foregroundStyle(.exTextPrimary)
            Text(authVM.currentUser?.email ?? "")
                .font(.exCaption)
                .foregroundStyle(.exTextSecondary)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            profileStat("Age", value: "\(authVM.currentUser?.age ?? 0)")
            profileStat("Weight", value: String(format: "%.0f kg", authVM.currentUser?.weight ?? 0))
            profileStat("Height", value: String(format: "%.0f cm", authVM.currentUser?.height ?? 0))
        }
    }

    private func profileStat(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.exStatSmall)
                .foregroundStyle(.exPrimary)
            Text(label)
                .font(.exSmall)
                .foregroundStyle(.exTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 12)
    }

    private var settingsSections: some View {
        VStack(spacing: 16) {
            settingsGroup("Account") {
                settingsRow(icon: "person.circle", title: "Edit Profile")
                settingsRow(icon: "lock.shield", title: "Change Password")
                settingsRow(icon: "envelope", title: "Email Preferences")
            }
            settingsGroup("Notifications") {
                settingsRow(icon: "bell", title: "Push Notifications")
                settingsRow(icon: "clock", title: "Reminder Schedule")
            }
            settingsGroup("Integrations") {
                NavigationLink(destination: HealthKitSettingsView()) {
                    settingsRowContent(icon: "heart.circle", title: "Apple Health")
                }
            }
            settingsGroup("Data") {
                settingsRow(icon: "square.and.arrow.up", title: "Export Data")
                settingsRow(icon: "trash", title: "Delete Account", isDestructive: true)
            }
        }
    }

    private func settingsGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)
            VStack(spacing: 0) {
                content()
            }
            .glassCard(cornerRadius: 14)
        }
    }

    private func settingsRow(icon: String, title: String, isDestructive: Bool = false) -> some View {
        Button {} label: {
            settingsRowContent(icon: icon, title: title, isDestructive: isDestructive)
        }
    }

    private func settingsRowContent(icon: String, title: String, isDestructive: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isDestructive ? .exError : .exPrimary)
                .frame(width: 28)
            Text(title)
                .font(.exBody)
                .foregroundStyle(isDestructive ? .exError : .exTextPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.exTextMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var logoutButton: some View {
        ActionButton(title: "Log Out", variant: .ghost) {
            authVM.logout()
        }
    }
}

// MARK: - HealthKit Settings

struct HealthKitSettingsView: View {
    @State private var syncEnabled = false

    var body: some View {
        VStack(spacing: 20) {
            GlassCard {
                HStack {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health")
                            .font(.exBodyMedium)
                            .foregroundStyle(.exTextPrimary)
                        Text("Sync steps, calories, and workouts")
                            .font(.exCaption)
                            .foregroundStyle(.exTextSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $syncEnabled)
                        .tint(.exPrimary)
                        .labelsHidden()
                }
            }

            if syncEnabled {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Syncing")
                            .font(.exLabel)
                            .foregroundStyle(.exTextSecondary)
                        syncRow("Steps", icon: "figure.walk")
                        syncRow("Active Calories", icon: "flame")
                        syncRow("Workouts", icon: "figure.run")
                        syncRow("Sleep", icon: "bed.double")
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Color.exBackground)
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: syncEnabled) { _, enabled in
            if enabled {
                Task { await HealthKitService.shared.requestAuthorization() }
            }
        }
    }

    private func syncRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.exPrimary)
                .frame(width: 24)
            Text(title)
                .font(.exBody)
                .foregroundStyle(.exTextPrimary)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.exSuccess)
        }
    }
}
