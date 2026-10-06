import XCTest
import ExerlyCore
@testable import Exerly

@MainActor
final class AgentConnectionTests: XCTestCase {
    func testDefaultPermissionCreatesProposeOnlyAccessForTheBoundAccount() async throws {
        let transport = TokenTransport()
        let model = AgentConnectionsModel(api: AccountAPI(accountID: "account-a", transport: transport))
        await model.create(name: "  Training assistant  ", permission: .propose, expiresInDays: 30)
        XCTAssertNil(model.error)
        XCTAssertNotNil(model.created)
        let sent = await transport.creation()
        let request = try XCTUnwrap(sent)
        XCTAssertEqual(request.accountID, "account-a")
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(request.body)) as? [String: Any])
        XCTAssertEqual(body["name"] as? String, "Training assistant")
        XCTAssertEqual(body["scopes"] as? [String], ["read", "propose"])
        XCTAssertEqual(body["expires_in_days"] as? Int, 30)
        XCTAssertEqual(model.tokens.map(\.name), ["Training assistant"])
        model.clearSecret()
        XCTAssertNil(model.created)
    }

    func testRevocationRefreshesTheListAndFailureKeepsExistingAccessVisible() async throws {
        let transport = TokenTransport()
        let model = AgentConnectionsModel(api: AccountAPI(accountID: "account-a", transport: transport))
        await model.create(name: "Training assistant", permission: .read, expiresInDays: 7)
        let token = try XCTUnwrap(model.tokens.first)
        await transport.failRevocation()
        await model.revoke(token)
        XCTAssertEqual(model.tokens.map(\.id), [token.id])
        XCTAssertNotNil(model.error)
        await transport.allowRevocation()
        await model.revoke(token)
        XCTAssertTrue(model.tokens.isEmpty)
        XCTAssertNil(model.error)
    }

    func testClosingCreationDoesNotLetALateResponseRevealTheSecret() async throws {
        let began = expectation(description: "Creation began")
        let transport = TokenTransport(onCreation: { began.fulfill() }, holdCreation: true)
        let model = AgentConnectionsModel(api: AccountAPI(accountID: "account-a", transport: transport))
        let task = Task { await model.create(name: "Training assistant", permission: .propose, expiresInDays: 30) }
        await fulfillment(of: [began], timeout: 3)
        model.clearSecret()
        await transport.finishCreation()
        await task.value
        XCTAssertNil(model.created)
        XCTAssertEqual(model.tokens.count, 1)
    }
}

private actor TokenTransport: SessionTransport {
    struct Request: Sendable {
        let accountID: String
        let body: Data?
    }
    private var lastCreation: Request?
    private var hasToken = false
    private var refuseRevoke = false
    private let onCreation: @Sendable () -> Void
    private var holding: Bool
    private var pending: CheckedContinuation<Void, Never>?

    init(onCreation: @escaping @Sendable () -> Void = {}, holdCreation: Bool = false) {
        self.onCreation = onCreation
        holding = holdCreation
    }

    func creation() -> Request? { lastCreation }
    func failRevocation() { refuseRevoke = true }
    func allowRevocation() { refuseRevoke = false }
    func finishCreation() { holding = false; pending?.resume(); pending = nil }

    func send(_ method: String, path: String, body: Data?, headers: [String: String],
              as accountID: String) async throws -> (status: Int, data: Data) {
        let row: [String: Any] = ["id": "synthetic-token", "name": "Training assistant", "prefix": "exr_test",
                                  "scopes": ["read", "propose"], "created_at": "2026-10-06T10:00:00.000Z"]
        if method == "POST" {
            lastCreation = Request(accountID: accountID, body: body)
            onCreation()
            if holding { await withCheckedContinuation { pending = $0 } }
            hasToken = true
            var created = row
            created["token"] = "synthetic-secret-for-test-only"
            return (201, try JSONSerialization.data(withJSONObject: created))
        }
        if method == "DELETE" {
            if refuseRevoke { throw URLError(.notConnectedToInternet) }
            hasToken = false
            return (200, Data("{}".utf8))
        }
        return (200, try JSONSerialization.data(withJSONObject: hasToken ? [row] : []))
    }
}
