import Foundation
import SwiftUI

enum AuthState {
    case loading
    case unauthenticated
    case onboarding
    case authenticated
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var currentUser: UserDTO?
    @Published var error: String?
    @Published var isSubmitting = false

    private let api = APIClient.shared
    private let keychain = KeychainService.shared

    init() {
        Task { await checkAuth() }
    }

    private func finalizeAuthenticatedSession(token: String, fallbackUser: UserDTO? = nil) async throws {
        keychain.saveToken(token)
        if let resolvedUser = try? await api.getProfile() {
            currentUser = resolvedUser
            authState = resolvedUser.onboardingCompleted == true ? .authenticated : .onboarding
        } else if let fallbackUser {
            currentUser = fallbackUser
            authState = fallbackUser.onboardingCompleted == true ? .authenticated : .onboarding
        } else {
            throw APIError.unknown
        }
    }

    func checkAuth() async {
        guard keychain.getToken() != nil else {
            authState = .unauthenticated
            return
        }
        do {
            let user: UserDTO = try await api.getProfile()
            currentUser = user
            authState = user.onboardingCompleted == true ? .authenticated : .onboarding
        } catch {
            keychain.deleteToken()
            authState = .unauthenticated
        }
    }

    func login(email: String, password: String) async {
        isSubmitting = true
        error = nil
        do {
            let response = try await api.login(email: email, password: password)
            try await finalizeAuthenticatedSession(token: response.token, fallbackUser: response.user)
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isSubmitting = false
    }

    func signup(email: String, password: String, name: String) async {
        isSubmitting = true
        error = nil
        do {
            let response = try await api.signup(
                email: email, password: password, name: name
            )
            try await finalizeAuthenticatedSession(token: response.token, fallbackUser: response.user)
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isSubmitting = false
    }

    func completeOnboarding(_ data: OnboardingRequest) async {
        do {
            _ = try await api.completeOnboarding(data)
            await checkAuth()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func logout() {
        keychain.deleteToken()
        currentUser = nil
        authState = .unauthenticated
    }

    func refreshUser() async {
        do {
            currentUser = try await api.getProfile()
        } catch {
            // Silently fail on refresh
        }
    }
}
