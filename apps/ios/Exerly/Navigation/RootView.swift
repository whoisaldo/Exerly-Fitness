import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("exerlyAppearance") private var appearance = "dark"
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var sync = SyncEngine.shared
    @StateObject private var account = AppAccountWorkspace()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            #if DEBUG
            if let mode = ProcessInfo.processInfo.environment["EXERLY_TEST_ACCOUNT_CONTROLS"] {
                AccountControlsFixtureView(mode: mode)
            } else { accountContent }
            #else
            accountContent
            #endif
        }
        .tint(Color.exPrimary)
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
    }

    private var accountContent: some View {
        Group {
            switch authVM.authState {
            case .loading:
                LoadingStateView(message: "Starting Exerly...")
            case .connectionFailed:
                VStack(spacing: 16) {
                    Text("Connection unavailable").font(.title2)
                    Text(authVM.error ?? "Your session is saved. Try connecting again.")
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await authVM.checkAuth() } }
                        .buttonStyle(.borderedProminent)
                    Button("Sign out") { Task { await account.signOut(auth: authVM) } }
                }.padding()
            case .unauthenticated:
                AuthRouter()
            case .onboarding:
                OnboardingWizard().id(authVM.currentUser?.id)
            case .authenticated:
                if sync.isConfigured(for: authVM.currentUser?.id) {
                    MainTabView().id(authVM.currentUser?.id)
                } else { LoadingStateView(message: "Opening saved entries…") }
            }
        }
        .animation(.easeOut(duration: 0.3), value: authVM.authState == .authenticated)
        .environmentObject(authVM)
        .environmentObject(sync)
        .environmentObject(account)
        .disabled(account.isChangingAccount)
        .overlay {
            if account.isChangingAccount {
                ProgressView("Updating account…").padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .task(id: "\(authVM.currentUser?.id ?? "")-\(authVM.currentUser?.timezone ?? "UTC")") {
            sync.configure(container: modelContext.container, accountID: authVM.currentUser?.id,
                           timeZone: authVM.currentUser?.timezone)
            account.retryCleanup()
        }
        .task(id: "\(authVM.authState)-\(authVM.currentUser?.id ?? "")-\(authVM.sessionID)") {
            await account.configure(authVM.authState == .authenticated ? authVM.accountAPI : nil)
        }
        .task(id: "\(account.training?.identity.uuidString ?? "")-\(scenePhase)") {
            guard scenePhase == .active, let workspace = account.training else { return }
            while !Task.isCancelled {
                await workspace.synchronize()
                do { try await Task.sleep(for: .seconds(120)) }
                catch { return }
            }
        }
        .task(id: "\(authVM.authState)-\(authVM.currentUser?.id ?? "")-\(authVM.currentUser?.preferencesRevision ?? 0)") {
            await NotificationService.shared.refresh(accountID: authVM.authState == .authenticated ? authVM.currentUser?.id : nil)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                sync.refreshCalendarDay()
                Task { await sync.synchronize(force: true) }
                Task { await NotificationService.shared.refresh(accountID: authVM.authState == .authenticated ? authVM.currentUser?.id : nil) }
            }
        }
        .safeAreaInset(edge: .top) {
            if let message = account.cleanupError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(message).font(.callout)
                    Button("Retry cleanup") { account.retryCleanup() }
                }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
            }
            if authVM.isOffline && authVM.currentUser != nil {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Offline. Showing saved account data.").font(.caption)
                    Button("Retry") { Task { await authVM.checkAuth() } }
                }.padding(8).frame(maxWidth: .infinity).background(.thinMaterial)
            }
        }
    }
}
