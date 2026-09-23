import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @AppStorage("unitSystem") private var unitSystem = "metric"
    @State private var showEditProfile = false
    @State private var showChangePassword = false

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
        .sheet(isPresented: $showEditProfile) {
            EditProfileView().environmentObject(authVM)
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView()
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.exTextMuted)
                .accessibilityHidden(true)

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
            profileStat("Age", value: authVM.currentUser?.age.map(String.init) ?? "Not set")
            profileStat("Weight", value: displayWeight(authVM.currentUser?.weight))
            profileStat("Height", value: displayHeight(authVM.currentUser?.height))
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
            settingsGroup("Nutrition") {
                NavigationLink(destination: ProgramView()) {
                    settingsRowContent(icon: "target", title: "Nutrition Program")
                }
            }
            settingsGroup("Preferences") {
                Button { showEditProfile = true } label: {
                    settingsRowContent(icon: "slider.horizontal.3", title: "Profile and Preferences")
                }
                .accessibilityIdentifier("profile.preferences")
            }
            settingsGroup("Account") {
                Button { showChangePassword = true } label: {
                    settingsRowContent(icon: "lock.shield", title: "Change Password")
                }
            }
            settingsGroup("Integrations") {
                NavigationLink(destination: HealthKitSettingsView()) {
                    settingsRowContent(icon: "heart.circle", title: "Apple Health")
                }
            }
            if authVM.currentUser?.isAdmin == true {
                settingsGroup("Admin") {
                    NavigationLink(destination: AdminView().environmentObject(authVM)) {
                        settingsRowContent(icon: "shield.checkered", title: "Admin Panel")
                    }
                }
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

    private func displayWeight(_ kilograms: Double?) -> String {
        guard let kilograms else { return "—" }
        if unitSystem == "imperial" {
            return "\((kilograms * 2.20462262).formatted(.number.precision(.fractionLength(0)))) lb"
        }
        return "\(kilograms.formatted(.number.precision(.fractionLength(0)))) kg"
    }

    private func displayHeight(_ centimeters: Double?) -> String {
        guard let centimeters else { return "—" }
        guard unitSystem == "imperial" else {
            return "\(centimeters.formatted(.number.precision(.fractionLength(0)))) cm"
        }
        let totalInches = Int((centimeters / 2.54).rounded())
        return "\(totalInches / 12)′ \(totalInches % 12)″"
    }
}

// MARK: - HealthKit Settings

struct HealthKitSettingsView: View {
    @State private var syncEnabled = UserDefaults.standard.bool(forKey: "healthKitSync")
    @State private var todaySteps: Int?
    @State private var todayCalories: Int?

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
                        Text("Today's Data")
                            .font(.exLabel)
                            .foregroundStyle(.exTextSecondary)
                        syncRow("Steps", icon: "figure.walk", value: todaySteps.map { "\($0)" })
                        syncRow("Active Calories", icon: "flame", value: todayCalories.map { "\($0) kcal" })
                        syncRow("Workouts", icon: "figure.run", value: nil)
                        syncRow("Sleep", icon: "bed.double", value: nil)
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
            UserDefaults.standard.set(enabled, forKey: "healthKitSync")
            if enabled {
                Task {
                    _ = await HealthKitService.shared.requestAuthorization()
                    await fetchHealthData()
                }
            }
        }
        .task {
            if syncEnabled {
                await fetchHealthData()
            }
        }
    }

    private func fetchHealthData() async {
        let steps = await HealthKitService.shared.fetchStepsToday()
        let calories = await HealthKitService.shared.fetchActiveCaloriesToday()
        await MainActor.run {
            todaySteps = steps
            todayCalories = calories
        }
    }

    private func syncRow(_ title: String, icon: String, value: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.exPrimary)
                .frame(width: 24)
            Text(title)
                .font(.exBody)
                .foregroundStyle(.exTextPrimary)
            Spacer()
            if let value {
                Text(value)
                    .font(.exCaption)
                    .foregroundStyle(.exTextSecondary)
            }
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.exSuccess)
        }
    }
}
