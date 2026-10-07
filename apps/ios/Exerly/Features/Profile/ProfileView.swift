import ExerlyCore
import HealthKit
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var account: AppAccountWorkspace
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("unitSystem") private var unitSystem = "imperial"
    @AppStorage("exerlyAppearance") private var appearance = "dark"
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
            .padding(.bottom, ExSpacing.major)
        }
        .exScrollEdges()
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
        HStack(spacing: ExSpacing.content) {
            if !dynamicTypeSize.isAccessibilitySize {
            Text(String((authVM.currentUser?.name ?? "A").prefix(1)).uppercased())
                .font(.exStat).foregroundStyle(Color.exPrimaryText).frame(width: 64, height: 64)
                .background(Color.exPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(authVM.currentUser?.name ?? "Your profile").font(.exH2).foregroundStyle(Color.exTextPrimary)
                Text(authVM.currentUser?.email ?? "").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    .accessibilityLabel("Email").accessibilityValue(authVM.currentUser?.email ?? "")
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var statsRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            profileStat("Age", value: authVM.currentUser?.age.map(String.init) ?? "Not set")
            profileStat("Weight", value: displayWeight(authVM.currentUser?.weight))
            profileStat("Height", value: displayHeight(authVM.currentUser?.height))
        }
    }

    private func profileStat(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.exStatSmall)
                .foregroundStyle(.exPrimaryText)
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
                VStack(alignment: .leading, spacing: ExSpacing.small) {
                    Text("Appearance").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    ExSegmentedControl(values: ["dark", "light", "system"], selection: $appearance) { $0.capitalized }
                        .accessibilityIdentifier("profile.appearance")
                }.padding(ExSpacing.content)
            }
            settingsGroup("Account") {
                if let id = authVM.currentUser?.id {
                    NavigationLink {
                        AccountManagementView(accountID: id, email: authVM.currentUser?.email ?? "",
                                              actions: account.actions(auth: authVM, accountID: id))
                    } label: {
                        settingsRowContent(icon: "person.badge.key", title: "Account settings")
                    }
                    .accessibilityIdentifier("profile.account")
                }
                if authVM.signInMethods?.password != false {
                    Button { showChangePassword = true } label: {
                        settingsRowContent(icon: "lock.shield", title: "Change Password")
                    }
                }
                if let workspace = account.training, workspace.accountID == authVM.currentUser?.id {
                    NavigationLink {
                        AccountSyncView(workspace: workspace)
                    } label: {
                        settingsRowContent(icon: "arrow.triangle.2.circlepath", title: "Sync")
                    }
                    .accessibilityIdentifier("profile.sync")
                }
            }
            settingsGroup("Integrations") {
                if let api = authVM.accountAPI {
                    NavigationLink {
                        AgentConnectionsView(api: api).id(api.accountID)
                    } label: { settingsRowContent(icon: "key", title: "Connected agents") }
                    .accessibilityIdentifier("profile.agents")
                }
                NavigationLink(destination: HealthKitSettingsView(accountID: authVM.currentUser?.id ?? "")) {
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
            .glassCard()
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
            Task { await account.signOut(auth: authVM) }
        }
        .disabled(account.isChangingAccount)
        .accessibilityIdentifier("profile.logout")
    }

    private func displayWeight(_ kilograms: Double?) -> String {
        guard let kilograms else { return "—" }
        if unitSystem == "imperial" {
            return "\(Mass.kg(kilograms).value(in: .pounds).formatted(.number.precision(.fractionLength(0)))) lb"
        }
        return "\(kilograms.formatted(.number.precision(.fractionLength(0)))) kg"
    }

    private func displayHeight(_ centimeters: Double?) -> String {
        guard let centimeters else { return "—" }
        guard unitSystem == "imperial" else {
            return "\(centimeters.formatted(.number.precision(.fractionLength(0)))) cm"
        }
        let height = USUnits.feetAndInches(centimeters: centimeters)
        return "\(height.feet)′ \(Int(height.inches))″"
    }
}

// MARK: - HealthKit Settings

@MainActor
final class HealthReadModel: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isRequesting = false
    @Published private(set) var steps: Int?
    @Published private(set) var calories: Int?
    @Published private(set) var message: String?
    private let preferenceKey: String
    private let defaults: UserDefaults
    private let available: () -> Bool
    private let request: () async throws -> Void
    private let load: () async -> (steps: Int?, calories: Int?)
    private var generation = UUID()

    init(accountID: String, namespace: String = APIClient.shared.storageNamespace, defaults: UserDefaults = .standard,
         available: @escaping () -> Bool = { HKHealthStore.isHealthDataAvailable() },
         request: @escaping () async throws -> Void = {
             let types: Set<HKObjectType> = [HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned)]
             try await HKHealthStore().requestAuthorization(toShare: [], read: types)
         },
         load: @escaping () async -> (steps: Int?, calories: Int?) = {
             let steps = await HealthKitService.shared.stepsToday()
             let calories = await HealthKitService.shared.activeCaloriesToday()
             return (steps, calories)
         }) {
        preferenceKey = "healthRead.\(namespace).\(accountID)"
        self.defaults = defaults
        self.available = available
        self.request = request
        self.load = load
        isEnabled = !accountID.isEmpty && defaults.bool(forKey: preferenceKey)
    }

    func setEnabled(_ enabled: Bool) async {
        let operation = UUID()
        generation = operation
        message = nil
        steps = nil
        calories = nil
        if !enabled {
            isEnabled = false
            isRequesting = false
            defaults.set(false, forKey: preferenceKey)
            return
        }
        guard available() else {
            message = "Apple Health isn't available on this device."
            return
        }
        isRequesting = true
        defer { if generation == operation { isRequesting = false } }
        do {
            try await request()
            guard generation == operation, !Task.isCancelled else { return }
            // Completing the permission sheet does not prove that read access
            // was granted. Health deliberately does not reveal denied reads.
            isEnabled = true
            defaults.set(true, forKey: preferenceKey)
            await refresh()
        } catch {
            guard generation == operation, !Task.isCancelled else { return }
            isEnabled = false
            defaults.set(false, forKey: preferenceKey)
            message = "Health access couldn't open. Try again."
        }
    }

    func refresh() async {
        guard isEnabled, available() else { return }
        let operation = generation
        let values = await load()
        guard generation == operation, isEnabled, !Task.isCancelled else { return }
        // Nil means no samples are visible. Health does not reveal denied reads.
        steps = values.steps
        calories = values.calories
    }

    func close() { generation = UUID(); isRequesting = false }
}

struct HealthKitSettingsView: View {
    @StateObject private var model: HealthReadModel
    @Environment(\.dynamicTypeSize) private var typeSize

    init(accountID: String) { _model = StateObject(wrappedValue: HealthReadModel(accountID: accountID)) }

    var body: some View {
        ExScreen {
            ExCard(accent: true) {
                Text("Daily activity").font(.exH2).foregroundStyle(Color.exTextPrimary)
                Toggle("Read activity", isOn: Binding(get: { model.isEnabled }, set: { enabled in
                    Task { await model.setEnabled(enabled) }
                })).tint(.exActionFill).disabled(model.isRequesting)
                    .accessibilityIdentifier("health.readActivity")
                Text("Steps and active Calories from Health.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                if model.isRequesting { ProgressView("Opening Health access…") }
                if let message = model.message { Text(message).font(.exCaption).foregroundStyle(Color.exError) }
            }
            if model.isEnabled {
                ExCard {
                    ExSectionHeading("Available from Health")
                    activityRow("Steps", value: model.steps.map { $0.formatted() })
                    Divider()
                    activityRow("Active Calories", value: model.calories.map { "\($0.formatted()) kcal" })
                    Text("No data can mean nothing is recorded or read access is off. Check Exerly's permissions in the Health app.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }
            }
            ExCard {
                ExSectionHeading("You choose what to share")
                Text("This screen reads steps and active Calories. It doesn't add or change Health records.")
                    .font(.exBody).foregroundStyle(Color.exTextSecondary)
                Text("Turning this off stops reading here. Manage permissions in the Health app.")
                    .font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
        }
        .navigationTitle("Apple Health").navigationBarTitleDisplayMode(.inline)
        .task { await model.refresh() }
        .onDisappear { model.close() }
    }

    private func activityRow(_ title: String, value: String?) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.small))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: ExSpacing.item))
        return layout {
            Text(title).font(.exBody).foregroundStyle(Color.exTextPrimary)
            if !typeSize.isAccessibilitySize { Spacer() }
            Text(value ?? "No data available").font(value == nil ? .exCaption : .exStatSmall).foregroundStyle(Color.exTextSecondary)
        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
}
