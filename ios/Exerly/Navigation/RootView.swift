import SwiftUI

struct RootView: View {
    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        Group {
            switch authVM.authState {
            case .loading:
                LoadingStateView(message: "Starting Exerly...")
            case .unauthenticated:
                AuthRouter()
            case .onboarding:
                OnboardingWizard()
            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeOut(duration: 0.3), value: authVM.authState == .authenticated)
        .environmentObject(authVM)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Auth State Equatable conformance for animation

extension AuthState: Equatable {}
