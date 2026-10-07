import Combine
import ExerlyCore
import Foundation

@MainActor
final class AgentConnectionsModel: ObservableObject {
    enum Permission: String, CaseIterable {
        case propose = "Read and propose"
        case read = "Read only"
        case write = "Direct write"

        var scopes: Set<AccessToken.Scope> {
            switch self {
            case .read: [.read]
            case .propose: [.read, .propose]
            case .write: [.read, .propose, .write]
            }
        }
    }

    @Published private(set) var tokens: [AccessToken] = []
    @Published private(set) var created: CreatedAccessToken?
    @Published private(set) var error: String?
    @Published private(set) var isBusy = false
    @Published private(set) var isLoading = false
    private let api: AccountAPI
    private var secretGeneration = UUID()
    private var refreshGeneration = UUID()

    init(api: AccountAPI) { self.api = api }

    func refresh() async {
        let request = UUID()
        refreshGeneration = request
        isLoading = true
        defer { if refreshGeneration == request { isLoading = false } }
        do {
            let fresh = try await api.accessTokens()
            guard refreshGeneration == request, !Task.isCancelled else { return }
            tokens = fresh
            error = nil
        } catch {
            guard refreshGeneration == request, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    func create(name: String, permission: Permission, expiresInDays: Int) async {
        guard !isBusy else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "Give this agent a name."; return }
        let request = secretGeneration
        error = nil
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await api.createAccessToken(name: trimmed, scopes: permission.scopes, expiresInDays: expiresInDays)
            if secretGeneration == request, !Task.isCancelled { created = result }
            await refresh()
        } catch {
            guard secretGeneration == request, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    func revoke(_ token: AccessToken) async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            try await api.revokeAccessToken(id: token.id)
            // Reflect confirmed revocation even when the subsequent refresh fails.
            tokens.removeAll { $0.id == token.id }
            if created?.token.id == token.id { clearSecret() }
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearSecret() {
        secretGeneration = UUID()
        created = nil
    }
}
