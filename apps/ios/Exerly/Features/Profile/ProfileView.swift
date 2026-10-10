import ExerlyCore
import HealthKit
import SwiftUI

/// The Profile tab: who you are and your body numbers, your plan, then
/// everything else grouped by what you'd come here to do.
struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var account: AppAccountWorkspace
    @EnvironmentObject private var dailySync: SyncEngine
    @AppStorage("exerlyAppearance") private var appearance = "dark"
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showEditProfile = false
    @State private var showChangePassword = false
    @State private var changingUnits = false
    @State private var unitsError: String?

    private var user: UserDTO? { authVM.currentUser }
    private var accountID: String { user?.id ?? "" }
    private var unit: MassUnit { user?.unitSystem == "metric" ? .kilograms : .pounds }
    private var timeZone: TimeZone { TimeZone(identifier: user?.timezone ?? "UTC") ?? .gmt }
    private var workspace: TrainingWorkspace? {
        guard let workspace = account.training, workspace.accountID == user?.id else { return nil }
        return workspace
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ExSpacing.section) {
                ProfileIdentityCard(name: user?.name?.isEmpty == false ? user?.name ?? "" : "Your profile",
                                    email: user?.email ?? "", workspace: workspace, user: user, unit: unit,
                                    timeZone: timeZone) { showEditProfile = true }
                NavigationLink {
                    TargetsHostView(accountID: accountID, unit: unit, timeZone: timeZone)
                } label: {
                    ProfilePlanCard(workspace: workspace, unit: unit, timeZone: timeZone)
                }
                .buttonStyle(TodayPressStyle())
                .accessibilityLabel("Your plan")
                .accessibilityHint("Opens your calorie and macro targets")
                .accessibilityIdentifier("profile.targets")
                food
                connections
                preferences
                data
                signOut
                footer
            }
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, ExSpacing.page)
            .padding(.top, ExSpacing.small)
            .padding(.bottom, ExSpacing.major)
        }
        .scrollIndicators(.hidden)
        .exScrollEdges()
        .background(Color.exBackground)
        .accessibilityIdentifier("profile.screen")
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView().environmentObject(authVM)
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView()
        }
    }

    // MARK: Groups

    private var food: some View {
        ProfileSection(title: "Food") {
            NavigationLink {
                NutritionLibraryHostView(accountID: accountID, timeZone: timeZone, unit: unit)
            } label: {
                ProfileRow(title: "Foods & recipes", icon: "fork.knife", subtitle: foodsSummary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.foods")
        }
    }

    private var connections: some View {
        ProfileSection(title: "Connections") {
            NavigationLink(destination: HealthKitSettingsView(accountID: authVM.currentUser?.id ?? "")) {
                ProfileRow(title: "Apple Health", icon: "heart.fill", tint: .exAccent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Apple Health")
            if let api = authVM.accountAPI {
                NavigationLink {
                    AgentConnectionsView(api: api).id(api.accountID)
                } label: {
                    ProfileRow(title: "Connected agents", icon: "key.fill", subtitle: "Let an AI assistant read and propose changes")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.agents")
            }
        }
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            ProfileSection(title: "Preferences") {
                ProfileControlRow(title: "Units", icon: "ruler") {
                    HStack(spacing: ExSpacing.small) {
                        if changingUnits { ProgressView().controlSize(.small) }
                        ExSegmentedControl(values: ["imperial", "metric"], selection: Binding(
                            get: { user?.unitSystem == "metric" ? "metric" : "imperial" },
                            set: setUnits
                        )) { $0 == "metric" ? "Metric" : "U.S." }
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 190)
                        .disabled(changingUnits || user == nil)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Units")
                    .accessibilityIdentifier("profile.units")
                }
                ProfileControlRow(title: "Appearance", icon: "circle.lefthalf.filled") {
                    ExSegmentedControl(values: ["dark", "light", "system"], selection: $appearance) { $0.capitalized }
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 240)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Appearance")
                        .accessibilityIdentifier("profile.appearance")
                }
                Button { showEditProfile = true } label: {
                    ProfileRow(title: "Details & reminders", icon: "person.text.rectangle",
                               subtitle: "Name, body, training, food and reminders")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.details")
            }
            if let unitsError {
                Label(unitsError, systemImage: "exclamationmark.triangle").font(.exCaption).foregroundStyle(Color.exError)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, ExSpacing.tight)
                    .accessibilityIdentifier("profile.unitsError")
            }
        }
    }

    private var data: some View {
        ProfileSection(title: "Account & data") {
            if let workspace {
                NavigationLink {
                    AccountSyncView(workspace: workspace)
                } label: {
                    ProfileRow(title: "Sync", icon: "arrow.triangle.2.circlepath", value: syncStatus(workspace))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.sync")
            }
            if let workspace {
                NavigationLink {
                    MacroFactorImportView(workspace: workspace, unit: unit, timeZone: timeZone)
                } label: {
                    ProfileRow(title: "Import from MacroFactor", icon: "square.and.arrow.down",
                               subtitle: "Food log, weigh-ins and workouts")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.macroFactorImport")
            }
            if let id = user?.id {
                NavigationLink {
                    AccountManagementView(accountID: id, email: user?.email ?? "",
                                          actions: account.actions(auth: authVM, accountID: id))
                } label: {
                    ProfileRow(title: "Account", icon: "person.crop.circle", subtitle: "Sign-in, export your data, delete account")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.account")
            }
            if authVM.signInMethods?.password != false {
                Button { showChangePassword = true } label: {
                    ProfileRow(title: "Change password", icon: "lock.fill")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.password")
            }
            if user?.isAdmin == true {
                NavigationLink(destination: AdminView().environmentObject(authVM)) {
                    ProfileRow(title: "Admin", icon: "shield.checkered", subtitle: "Accounts and usage")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var signOut: some View {
        Button(role: .destructive) { Task { await account.signOut(auth: authVM) } } label: {
            Text("Sign Out").font(.exBodyMedium).foregroundStyle(Color.exError)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous)
                        .strokeBorder(Color.exBorder.opacity(0.5), lineWidth: 0.5)
                }
        }
        .buttonStyle(TodayPressStyle())
        .disabled(account.isChangingAccount)
        .accessibilityIdentifier("profile.logout")
    }

    private var footer: some View {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        return Text("Exerly \(version) · © Sideband")
            .font(.exCaption).foregroundStyle(Color.exTextMuted)
            .frame(maxWidth: .infinity)
    }

    // MARK: Values

    private var foodsSummary: String {
        guard let foods = workspace?.nutrition.foods, !foods.isEmpty else { return "Save foods and recipes you eat often" }
        return foods.count == 1 ? "1 saved food" : "\(foods.count) saved foods"
    }

    private func syncStatus(_ workspace: TrainingWorkspace) -> String {
        if dailySync.attentionCount > 0 { return "Needs review" }
        if dailySync.isSyncing { return "Syncing…" }
        switch workspace.sync?.state {
        case .syncing: return "Syncing…"
        case .offline: return "Saved on this iPhone"
        case .failed: return "Needs attention"
        default: break
        }
        if dailySync.isOffline || dailySync.pendingCount > 0 { return "Saved on this iPhone" }
        return workspace.sync?.lastSyncedAt == nil ? "" : "Up to date"
    }

    private func setUnits(_ system: String) {
        guard system != user?.unitSystem, !changingUnits, let user else { return }
        changingUnits = true
        unitsError = nil
        Task {
            defer { changingUnits = false }
            do {
                try await authVM.updateSettings(timezone: user.timezone ?? TimeZone.current.identifier, unitSystem: system)
                UISelectionFeedbackGenerator().selectionChanged()
            } catch is CancellationError {
            } catch {
                unitsError = "Units didn't change. Connect to the internet and try again."
            }
        }
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
