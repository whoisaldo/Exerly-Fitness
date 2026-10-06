import XCTest
import ExerlyCore
@testable import Exerly

@MainActor
final class AccountWorkspaceTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var namespace: String!
    private var credentials: MemoryCredentials!
    private var api: APIClient!
    private var auth: AuthViewModel!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        namespace = "exerly.workspace.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: namespace)!
        credentials = MemoryCredentials()
        credentials.saveSession(token: SessionBridgeTests.token("account-a"), refreshToken: "fixture-refresh")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        api = APIClient(baseURL: "https://fixture.exerly.test", session: URLSession(configuration: configuration),
                            keychain: credentials, defaults: defaults)
        auth = AuthViewModel(api: api, keychain: credentials, defaults: defaults,
                             automaticallyCheck: false, onSessionInvalidated: {})
        StubURLProtocol.handler = { _ in (200, SessionBridgeTests.bootstrap("account-a", password: true, apple: false)) }
        await auth.checkAuth(useCached: false)
    }

    override func tearDown() async throws {
        StubURLProtocol.handler = nil
        StubURLProtocol.responseDelay = nil
        defaults.removePersistentDomain(forName: namespace)
        try? FileManager.default.removeItem(at: root)
    }

    private func workspace(purge: @escaping @MainActor (String) throws -> Void = { _ in }) -> AppAccountWorkspace {
        let directory = root!
        return AppAccountWorkspace(open: { try TrainingWorkspace(accountID: $0.accountID, root: directory, api: $0) },
            deleteTraining: { try TrainingWorkspace.deleteStorage(accountID: $0, root: directory) },
            purgeLegacy: purge)
    }

    func testSignOutQuiescesSyncAndKeepsTrainingForTheSameAccount() async throws {
        let owner = workspace()
        await owner.configure(auth.accountAPI)
        let training = try XCTUnwrap(owner.training)
        let originalEngine = try XCTUnwrap(training.sync)
        try training.store.startSession(name: "Saved locally", bodyweight: nil)
        let revoked = expectation(description: "The signed-out session is revoked")
        StubURLProtocol.handler = { _ in
            revoked.fulfill()
            return (200, Data(#"{"ok":true}"#.utf8))
        }
        await owner.signOut(auth: auth)
        await fulfillment(of: [revoked], timeout: 2)
        XCTAssertNil(owner.training)
        XCTAssertEqual(auth.authState, .unauthenticated)
        do { try await originalEngine.sync(); XCTFail("A stopped engine must not run") }
        catch is CancellationError { }
        let restored = try TrainingWorkspace(accountID: "account-a", root: root)
        XCTAssertEqual(restored.store.activeSession?.name, "Saved locally")
        XCTAssertNil(try TrainingWorkspace(accountID: "account-b", root: root).store.activeSession)
    }

    func testFailedDeleteKeepsTheSessionAndStartsAFreshSyncEngine() async throws {
        let owner = workspace()
        await owner.configure(auth.accountAPI)
        let training = try XCTUnwrap(owner.training)
        let oldEngine = try XCTUnwrap(training.sync)
        try training.store.startSession(name: "Keep me", bodyweight: nil)
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        do { try await owner.deleteAccount(auth: auth, authorizationCode: nil); XCTFail("Expected offline error") }
        catch { XCTAssertNotNil(error as? URLError) }
        XCTAssertEqual(auth.authState, .authenticated)
        XCTAssertEqual(owner.training?.store.activeSession?.name, "Keep me")
        XCTAssertFalse(owner.training?.sync === oldEngine)
        XCTAssertTrue(FileManager.default.fileExists(atPath: training.url.path))
        XCTAssertTrue(auth.accountsAwaitingLocalCleanup.isEmpty)
    }

    func testConfirmedDeleteCleansOnlyThatAccountAndRetriesFailedLocalCleanupAfterRelaunch() async throws {
        var attempts = 0
        let owner = workspace { id in
            XCTAssertEqual(id, "account-a")
            attempts += 1
            if attempts == 1 { throw CocoaError(.fileWriteNoPermission) }
        }
        await owner.configure(auth.accountAPI)
        let original = try XCTUnwrap(owner.training)
        try original.store.startSession(name: "Delete me", bodyweight: nil)
        let other = try TrainingWorkspace(accountID: "account-b", root: root)
        try other.store.startSession(name: "Keep other account", bodyweight: nil)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/api/account")
            return (200, Data(#"{"ok":true}"#.utf8))
        }
        try await owner.deleteAccount(auth: auth, authorizationCode: nil)
        XCTAssertEqual(auth.authState, .unauthenticated)
        XCTAssertNil(owner.training)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.url.path))
        XCTAssertEqual(auth.accountsAwaitingLocalCleanup, ["account-a"])
        XCTAssertNotNil(owner.cleanupError)
        let relaunched = workspace { id in XCTAssertEqual(id, "account-a") }
        let relaunchedAuth = AuthViewModel(api: api, keychain: credentials, defaults: defaults,
                                           automaticallyCheck: false, onSessionInvalidated: {})
        XCTAssertEqual(relaunchedAuth.accountsAwaitingLocalCleanup, ["account-a"])
        await relaunched.retryCleanup(auth: relaunchedAuth)
        XCTAssertTrue(relaunchedAuth.accountsAwaitingLocalCleanup.isEmpty)
        XCTAssertNil(relaunched.cleanupError)
        XCTAssertEqual(try TrainingWorkspace(accountID: "account-b", root: root).store.activeSession?.name,
                       "Keep other account")
    }

    func testAppleReauthorizationRestartsSyncWithoutDeletingLocalFiles() async throws {
        let owner = workspace()
        await owner.configure(auth.accountAPI)
        let training = try XCTUnwrap(owner.training)
        let oldEngine = training.sync
        StubURLProtocol.handler = { _ in
            (400, Data(#"{"message":"Confirm with Apple","details":{"code":"apple_reauthorization_required"}}"#.utf8))
        }
        do { try await owner.deleteAccount(auth: auth, authorizationCode: nil); XCTFail("Expected Apple authorization") }
        catch ExerlyCore.APIError.appleReauthorizationRequired { }
        XCTAssertEqual(auth.authState, .authenticated)
        XCTAssertFalse(training.sync === oldEngine)
        XCTAssertTrue(FileManager.default.fileExists(atPath: training.url.path))
        XCTAssertTrue(auth.accountsAwaitingLocalCleanup.isEmpty)
    }

    func testDeletionOnAnotherDeviceStopsThisStoreBeforeCleanup() async throws {
        let owner = workspace()
        await owner.configure(auth.accountAPI)
        let training = try XCTUnwrap(owner.training)
        let engine = try XCTUnwrap(training.sync)
        try training.store.startSession(name: "Removed elsewhere", bodyweight: nil)
        StubURLProtocol.handler = { _ in (401, SessionBridgeTests.deletedBody) }
        await auth.checkAuth(useCached: false)
        XCTAssertEqual(auth.accountsAwaitingLocalCleanup, ["account-a"])
        await owner.retryCleanup(auth: auth)
        XCTAssertNil(owner.training)
        XCTAssertFalse(FileManager.default.fileExists(atPath: training.url.path))
        XCTAssertTrue(auth.accountsAwaitingLocalCleanup.isEmpty)
        do { try await engine.sync(); XCTFail("Deleted stores must stay stopped") }
        catch is CancellationError { }
    }

    func testWorkspaceExportsUnsyncedTrainingOnlineAndLabelsADeviceOnlyExport() async throws {
        let owner = workspace()
        await owner.configure(auth.accountAPI)
        let training = try XCTUnwrap(owner.training)
        try training.store.startSession(name: "Not uploaded", bodyweight: nil)
        let online = try training.export(server: Data(#"{"account":{"name":"Morgan"},"documents":[]}"#.utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: online) as? [String: Any])
        XCTAssertEqual((json["account"] as? [String: Any])?["name"] as? String, "Morgan")
        let document = try XCTUnwrap((json["documents"] as? [[String: Any]])?.first)
        XCTAssertEqual(document["pending_sync"] as? Bool, true)
        XCTAssertEqual((document["payload"] as? [String: Any])?["name"] as? String, "Not uploaded")
        let offline = try XCTUnwrap(JSONSerialization.jsonObject(with: training.export(server: nil)) as? [String: Any])
        XCTAssertEqual(offline["source"] as? String, "device")
        XCTAssertNil(offline["account"])
        XCTAssertNotNil(offline["note"])
    }
}
