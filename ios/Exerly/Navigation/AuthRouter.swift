import SwiftUI

enum AuthRoute {
    case welcome, login, signup
}

struct AuthRouter: View {
    @State private var route: AuthRoute = .welcome

    var body: some View {
        Group {
            switch route {
            case .welcome:
                WelcomeView(
                    onLogin: { route = .login },
                    onSignup: { route = .signup }
                )
                .transition(.opacity)
            case .login:
                LoginView(onBack: { route = .welcome })
                    .transition(.slideFromEdge(.trailing))
            case .signup:
                SignupView(
                    onBack: { route = .welcome },
                    onSwitchToLogin: { route = .login }
                )
                .transition(.slideFromEdge(.trailing))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: route)
    }
}

extension AuthRoute: Equatable {}
