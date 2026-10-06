import ExerlyCore
import SwiftUI

/// App composition only: Core owns sessions, persistence, sync and server calls.
/// This owner outlives the signed-in screens so confirmed deletion cleanup can
/// finish after AuthViewModel returns the app to sign-in.
@MainActor
final class AppAccountWorkspace: ObservableObject {
    @Published private(set) var training: TrainingWorkspace?
    @Published private(set) var openingError: String?
    @Published private(set) var isChangingAccount = false
    @Published private(set) var cleanupError: String?
    private let defaults: UserDefaults
    private let open: @MainActor (AccountAPI) throws -> TrainingWorkspace
    private let deleteTraining: @MainActor (String) throws -> Void
    private let purgeLegacy: @MainActor (String) throws -> Void
    private var generation = UUID()
    private let cleanupKey = "exerly.confirmedDeletionCleanup"

    init(defaults: UserDefaults = .standard,
         open: @escaping @MainActor (AccountAPI) throws -> TrainingWorkspace = {
             try TrainingWorkspace(accountID: $0.accountID, api: $0)
         },
         deleteTraining: @escaping @MainActor (String) throws -> Void = {
             try TrainingWorkspace.deleteStorage(accountID: $0)
         },
         purgeLegacy: @escaping @MainActor (String) throws -> Void = {
             try SyncEngine.shared.purge(accountID: $0)
         }) {
        self.defaults = defaults
        self.open = open
        self.deleteTraining = deleteTraining
        self.purgeLegacy = purgeLegacy
    }

    var pendingCleanup: [String] { defaults.stringArray(forKey: cleanupKey) ?? [] }

    func configure(_ account: AccountAPI?) async {
        guard !isChangingAccount else { return }
        if let account, training?.accountID == account.accountID { return }
        let request = UUID()
        generation = request
        let previous = training?.sync
        training = nil
        openingError = nil
        await previous?.shutdown()
        guard generation == request, !Task.isCancelled, let account else { return }
        do { training = try open(account) }
        catch { openingError = "Your saved training could not open. Keep Exerly installed and try again." }
    }

    func signOut(auth: AuthViewModel) async {
        guard !isChangingAccount else { return }
        isChangingAccount = true
        generation = UUID()
        await training?.sync?.shutdown()
        training = nil
        auth.logout()
        isChangingAccount = false
    }

    func deleteAccount(auth: AuthViewModel, authorizationCode: String?) async throws {
        guard !isChangingAccount, let account = auth.accountAPI else { throw ExerlyCore.APIError.notSignedIn }
        isChangingAccount = true
        generation = UUID()
        defer { isChangingAccount = false }
        await training?.sync?.shutdown()
        do {
            try Task.checkCancellation()
            let result = try await auth.deleteAccount(appleAuthorizationCode: authorizationCode)
            if result == .appleReauthorizationRequired { throw ExerlyCore.APIError.appleReauthorizationRequired }
            // Persist this work before the signed-in UI disappears. Never put a
            // merely attempted or refused server deletion into this queue.
            defaults.set(Array(Set(pendingCleanup + [account.accountID])).sorted(), forKey: cleanupKey)
            training = nil
            retryCleanup()
        } catch {
            if auth.accountAPI?.accountID == account.accountID {
                training?.resumeSync(api: account)
            } else { training = nil }
            throw error
        }
    }

    func retryCleanup() {
        var remaining: [String] = []
        for accountID in pendingCleanup {
            do {
                try deleteTraining(accountID)
                try purgeLegacy(accountID)
            } catch { remaining.append(accountID) }
        }
        defaults.set(remaining, forKey: cleanupKey)
        cleanupError = remaining.isEmpty ? nil :
            "Your account was deleted. Some saved data on this device still needs to be removed. Retry cleanup."
    }

    func actions(auth: AuthViewModel, accountID: String) -> AccountManagementActions {
        func checkAccount() throws {
            guard auth.accountAPI?.accountID == accountID else { throw ExerlyCore.APIError.accountChanged }
        }
        func methods() async throws -> AccountSignInMethods {
            try checkAccount()
            if auth.signInMethods == nil { await auth.checkAuth() }
            try checkAccount()
            guard let values = auth.signInMethods else {
                throw ExerlyCore.APIError.server(status: 0, message: "Connect to Exerly to load your sign-in methods.")
            }
            return AccountSignInMethods(appleConnected: values.apple, hasPassword: values.password)
        }
        return AccountManagementActions(signInMethods: { try await methods() }, connectApple: { payload in
            try checkAccount()
            try await auth.linkApple(identityToken: payload.identityToken, rawNonce: payload.rawNonce)
            return try await methods()
        }, disconnectApple: {
            try checkAccount()
            try await auth.unlinkApple()
            return try await methods()
        }, exportAccount: {
            try checkAccount()
            return try await auth.exportAccount()
        }, deleteAccount: { code in
            try checkAccount()
            try await self.deleteAccount(auth: auth, authorizationCode: code)
        })
    }
}
