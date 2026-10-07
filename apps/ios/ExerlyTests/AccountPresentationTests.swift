import XCTest
@testable import Exerly

@MainActor
final class AccountPresentationTests: XCTestCase {
    func testAppleResponseMustMatchTheRequestAndContainAUTF8Token() throws {
        let attempt = AppleAuthorizationAttempt()
        let nextAttempt = AppleAuthorizationAttempt()
        XCTAssertNotEqual(attempt.state, nextAttempt.state)
        XCTAssertNotEqual(attempt.nonce.raw, nextAttempt.nonce.raw)
        let token = Data("synthetic-identity-token".utf8)
        XCTAssertThrowsError(try attempt.result(identityToken: token, authorizationCode: nil,
                                                state: nextAttempt.state, name: nil))
        XCTAssertThrowsError(try attempt.result(identityToken: nil, authorizationCode: nil,
                                                state: attempt.state, name: nil))
        XCTAssertThrowsError(try attempt.result(identityToken: Data([0xff]), authorizationCode: nil,
                                                state: attempt.state, name: nil))
        let result = try attempt.result(identityToken: token, authorizationCode: Data("synthetic-code".utf8),
                                        state: attempt.state, name: "  Morgan Example  ")
        XCTAssertEqual(result.rawNonce, attempt.nonce.raw)
        XCTAssertEqual(result.identityToken, "synthetic-identity-token")
        XCTAssertEqual(result.authorizationCode, "synthetic-code")
        XCTAssertEqual(result.name, "Morgan Example")
    }

    func testExportPreservesJSONBytesAndCleansOnlyItsOwnTemporaryDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = Data(#"{"account":{"name":"Synthetic"},"weight":72.2531,"missing":null}"#.utf8)
        let first = try AccountExportFile(data: data, directory: directory)
        let second = try AccountExportFile(data: data, directory: directory)
        XCTAssertNotEqual(first.url, second.url)
        XCTAssertEqual(try Data(contentsOf: first.url), data)
        first.remove()
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertEqual(try Data(contentsOf: second.url), data)
        second.remove()
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testMalformedExportNeverCreatesAShareFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertThrowsError(try AccountExportFile(data: Data("<html>server error</html>".utf8), directory: directory))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }
}
