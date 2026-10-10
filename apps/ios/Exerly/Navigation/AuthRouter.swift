import SwiftUI

enum AuthRoute: Equatable {
    case welcome, login, signup
}

struct AuthRouter: View {
    @State private var route: AuthRoute = .welcome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch route {
            case .welcome:
                WelcomeView(onLogin: { route = .login }, onSignup: { route = .signup })
                    .transition(.opacity)
            case .login:
                LoginView(onBack: { route = .welcome }, onSwitchToSignup: { route = .signup })
                    .transition(reduceMotion ? .opacity : .slideFromEdge(.trailing))
            case .signup:
                SignupView(onBack: { route = .welcome }, onSwitchToLogin: { route = .login })
                    .transition(reduceMotion ? .opacity : .slideFromEdge(.trailing))
            }
        }
        .animation(.snappy(duration: 0.35), value: route)
    }
}
