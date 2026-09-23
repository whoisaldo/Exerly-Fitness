import SwiftUI
import SwiftData

struct RootView: View {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var sync = SyncEngine.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
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
                    Button("Sign out") { authVM.logout() }
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
        .task(id: "\(authVM.currentUser?.id ?? "")-\(authVM.currentUser?.timezone ?? "UTC")") {
            sync.configure(container: modelContext.container, accountID: authVM.currentUser?.id,
                           timeZone: authVM.currentUser?.timezone)
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
            if authVM.isOffline && authVM.currentUser != nil {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Offline. Showing saved account data.").font(.caption)
                    Button("Retry") { Task { await authVM.checkAuth() } }
                }.padding(8).frame(maxWidth: .infinity).background(.thinMaterial)
            }
        }
        .preferredColorScheme(.dark)
    }
}
