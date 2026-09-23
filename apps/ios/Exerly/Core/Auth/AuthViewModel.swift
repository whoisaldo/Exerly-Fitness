import Foundation
import SwiftUI
import CryptoKit

enum AuthState: Equatable {
    case loading, unauthenticated, onboarding, authenticated, connectionFailed
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var currentUser: UserDTO? {
        didSet {
            if let unitSystem = currentUser?.unitSystem {
                defaults.set(unitSystem, forKey: "unitSystem")
            }
        }
    }
    @Published var error: String?
    @Published var isSubmitting = false
    @Published var isOffline = false
    @Published private(set) var setupStatus: SetupStatus?

    private let api: APIClient
    private let keychain: any SessionCredentials
    private let defaults: UserDefaults
    private let onSessionInvalidated: @MainActor () -> Void
    private var expiryObserver: NSObjectProtocol?
    private var sessionGeneration = UUID()
    var sessionID: UUID { sessionGeneration }

    init(api: APIClient = .shared, keychain: any SessionCredentials = KeychainService.shared,
         defaults: UserDefaults = .standard, automaticallyCheck: Bool = true,
         onSessionInvalidated: @escaping @MainActor () -> Void = { NotificationService.shared.configure(accountID: nil) }) {
        self.api = api
        self.keychain = keychain
        self.defaults = defaults
        self.onSessionInvalidated = onSessionInvalidated
        expiryObserver = NotificationCenter.default.addObserver(
            forName: .exerlySessionExpired, object: nil, queue: .main
        ) { [weak self] notification in
            guard let token = notification.object as? String else { return }
            Task { @MainActor in
                guard let self, self.keychain.getToken() == token else { return }
                self.invalidateSession()
            }
        }
        if automaticallyCheck { Task { await checkAuth() } }
    }

    deinit {
        if let expiryObserver { NotificationCenter.default.removeObserver(expiryObserver) }
    }

    private func cacheKey(_ token: String) -> String {
        APIClient.accountCacheKey(token)
    }

    private func accept(_ user: UserDTO, setupComplete: Bool? = nil) {
        currentUser = user
        authState = (setupComplete ?? (user.onboardingCompleted == true)) ? .authenticated : .onboarding
        isOffline = false
        error = nil
        if let token = keychain.getToken(), let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: cacheKey(token))
            defaults.set(authState == .authenticated, forKey: cacheKey(token) + ".complete")
        }
    }

    private func invalidateSession() {
        sessionGeneration = UUID()
        onSessionInvalidated()
        if let token = keychain.getToken() {
            defaults.removeObject(forKey: cacheKey(token))
            defaults.removeObject(forKey: cacheKey(token) + ".complete")
        }
        keychain.deleteToken()
        currentUser = nil
        setupStatus = nil
        authState = .unauthenticated
        isOffline = false
    }

    private func finalizeAuthenticatedSession(_ response: AuthResponse) throws {
        try APIClient.validateSession(response)
        guard let user = response.user else { throw APIError.invalidSessionResponse }
        guard keychain.saveSession(token: response.token, refreshToken: response.refreshToken) else { throw APIError.sessionStorage }
        sessionGeneration = UUID()
        currentUser = user
        authState = .loading
        isOffline = false
    }

    func checkAuth(useCached: Bool = true) async {
        guard let token = keychain.getToken() else {
            authState = .unauthenticated
            return
        }
        let generation = sessionGeneration
        if useCached, let data = defaults.data(forKey: cacheKey(token)),
           let cached = try? JSONDecoder().decode(UserDTO.self, from: data),
           cached.id != nil, APIClient.accountID(in: token).map({ $0 == cached.id }) ?? true {
            currentUser = cached
            let completeKey = cacheKey(token) + ".complete"
            let complete = defaults.object(forKey: completeKey) == nil ? cached.onboardingCompleted == true : defaults.bool(forKey: completeKey)
            authState = complete ? .authenticated : .onboarding
        }
        do {
            let bootstrap: BootstrapResponse = try await api.get("/api/bootstrap")
            guard generation == sessionGeneration else { return }
            guard let owner = APIClient.accountID(in: keychain.getToken()),
                  bootstrap.account_id == owner, bootstrap.account.id == owner,
                  bootstrap.onboarding.user.id == owner else { throw APIError.invalidSessionResponse }
            setupStatus = bootstrap.onboarding
            accept(bootstrap.account, setupComplete: bootstrap.onboarding.complete)
        } catch is CancellationError {
            if generation == sessionGeneration && authState == .loading {
                authState = .connectionFailed
                self.error = "Your session changed while connecting. Try again."
            }
            return
        } catch APIError.unauthorized {
            guard generation == sessionGeneration else { return }
            invalidateSession()
        } catch {
            guard generation == sessionGeneration else { return }
            self.error = error.localizedDescription
            isOffline = true
            if currentUser == nil || authState == .loading { authState = .connectionFailed }
        }
    }

    func login(email: String, password: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        let generation = sessionGeneration
        defer { isSubmitting = false }
        do {
            let response = try await api.login(email: email, password: password)
            guard generation == sessionGeneration else { return }
            try finalizeAuthenticatedSession(response)
            await checkAuth(useCached: false)
        } catch { if generation == sessionGeneration { self.error = error.localizedDescription } }
    }

    func signup(email: String, password: String, name: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        let generation = sessionGeneration
        defer { isSubmitting = false }
        do {
            let response = try await api.signup(email: email, password: password, name: name)
            guard generation == sessionGeneration else { return }
            try finalizeAuthenticatedSession(response)
            if let user = currentUser { accept(user, setupComplete: false) }
        } catch { if generation == sessionGeneration { self.error = error.localizedDescription } }
    }

    @discardableResult
    func completeOnboarding(_ data: OnboardingRequest, operationID: String) async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        error = nil
        let generation = sessionGeneration
        defer { isSubmitting = false }
        do {
            let result = try await api.completeOnboarding(data, operationID: operationID)
            guard generation == sessionGeneration, result.complete, result.targets != nil else { return false }
            guard result.user.id == APIClient.accountID(in: keychain.getToken()) else { throw APIError.invalidSessionResponse }
            accept(result.user, setupComplete: true)
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard generation == sessionGeneration else { return false }
            // A committed setup with a lost or malformed acknowledgement is
            // resolved by status. A second completion request is unnecessary.
            if let status: SetupStatus = try? await api.get("/api/onboarding/status"),
               generation == sessionGeneration, status.complete, status.targets != nil,
               status.user.id == APIClient.accountID(in: keychain.getToken()) {
                accept(status.user, setupComplete: true)
                return true
            }
            self.error = error.localizedDescription
            return false
        }
    }

    func logout() {
        let api = self.api
        let token = keychain.getToken()
        invalidateSession()
        if let token { Task { await api.revokeSession(accessToken: token) } }
    }
    func refreshUser() async { await checkAuth() }

    func updateSettings(timezone: String, unitSystem: String) async throws {
        let generation = sessionGeneration
        let accountID = currentUser?.id
        let response = try await api.updateSettings(SettingsRequest(timezone: timezone, unitSystem: unitSystem))
        guard generation == sessionGeneration, response.user.id == accountID else { throw CancellationError() }
        acceptPreferences(response.user, accountID: accountID, sessionID: generation)
    }

    func acceptPreferences(_ user: UserDTO, accountID: String?, sessionID: UUID) {
        guard sessionID == sessionGeneration, let accountID,
              currentUser?.id == accountID, user.id == accountID,
              APIClient.accountID(in: keychain.getToken()) == accountID,
              (user.preferencesRevision ?? 0) >= (currentUser?.preferencesRevision ?? 0) else { return }
        accept(user)
    }
}
