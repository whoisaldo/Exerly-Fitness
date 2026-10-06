import Foundation
import Testing
@testable import ExerlyCore

/// The Swift client and sync engine against the real API. Runs only when
/// EXERLY_LIVE_API is set: `scripts/live-sync.sh` starts the API on a
/// throwaway PostgreSQL database and sets it.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["EXERLY_LIVE_API"] != nil))
struct LiveSyncTests {
    let base = URL(string: ProcessInfo.processInfo.environment["EXERLY_LIVE_API"] ?? "http://127.0.0.1:39102")!

    /// Creates a synthetic account and returns its email and password.
    func signUp() async throws -> (String, String) {
        let email = "live-\(UUID().uuidString.prefix(8).lowercased())@exerly.test"
        let password = "synthetic-password-\(UUID().uuidString.prefix(6))"
        var request = URLRequest(url: base.appendingPathComponent("signup"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": "Live Test", "email": email, "password": password])
        let (_, response) = try await URLSession.shared.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 201)
        return (email, password)
    }

    @MainActor
    final class LiveDevice {
        let api: ExerlyAPI
        let credentials = InMemoryCredentialStore()
        let persistence: InMemoryTrainingPersistence
        let store: TrainingStore
        private(set) var engine: SyncEngine!

        init(base: URL) throws {
            let persistence = InMemoryTrainingPersistence()
            self.persistence = persistence
            api = ExerlyAPI(baseURL: base, credentials: credentials)
            store = try TrainingStore(persistence: persistence)
        }

        /// Signs in, then binds sync to the signed-in account.
        func signIn(email: String, password: String) async throws -> SignInResult {
            let result = try await api.signIn(email: email, password: password)
            engine = SyncEngine(store: store, state: persistence, api: try await api.account())
            return result
        }

        func logSet(reps: Int, kg: Double) throws {
            let performed = store.activeSession!.exercises[0]
            let id = try store.addSet(to: performed.id)
            var set = store.activeSession!.set(id)!.set
            set.primary = Effort(reps: reps, load: .kg(kg))
            try store.updateSet(set, in: performed.id)
            try store.completeSet(id)
        }
    }

    @Test func twoDevicesSyncMergeAndDeleteThroughTheRealAPI() async throws {
        let (email, password) = try await signUp()
        let phone = try LiveDevice(base: base)
        let watch = try LiveDevice(base: base)
        let signedIn = try await phone.signIn(email: email, password: password)
        _ = try await watch.signIn(email: email, password: password)
        #expect(signedIn.account.email == email)

        // A custom exercise and a session, logged on the phone.
        let custom = Exercise(id: .custom(), name: "Synthetic Zercher Squat", metric: .weightReps, mechanics: .compound,
                              region: .lower, muscles: [.quads: 1, .glutes: 1], equipment: [.barbell])
        try phone.store.addCustomExercise(custom)
        try phone.store.startSession(name: "Live session", bodyweight: .kg(80), timeZone: TimeZone(identifier: "America/New_York")!)
        try phone.store.addExercise(custom.id)
        try phone.logSet(reps: 5, kg: 90)
        try await phone.engine.sync()

        try await watch.engine.sync()
        #expect(watch.store.library.exercise(custom.id) == custom)
        #expect(watch.store.activeSession == phone.store.activeSession)

        // Both log offline, then converge.
        try phone.logSet(reps: 5, kg: 95)
        try watch.logSet(reps: 8, kg: 70)
        try watch.store.updateActiveSession { $0.notes = "Logged on the watch" }
        try await phone.engine.sync()
        try await watch.engine.sync()
        try await phone.engine.sync()
        #expect(phone.store.activeSession == watch.store.activeSession)
        let loads = Set(phone.store.activeSession!.exercises[0].sets.filter(\.isCompleted).compactMap(\.primary.load))
        #expect(loads == [.kg(90), .kg(95), .kg(70)])

        // A forced refresh rotates the credential on the real server.
        var expired = try #require(try phone.credentials.load())
        expired.accessExpiresAt = Date(timeIntervalSince1970: 0)
        try phone.credentials.save(expired)
        try phone.store.finishSession()
        try await phone.engine.sync()
        #expect(try phone.credentials.load()?.refreshToken != expired.refreshToken)

        try await watch.engine.sync()
        #expect(watch.store.activeSession == nil)
        #expect(watch.store.history.sessions == phone.store.history.sessions)

        // Deletion reaches the other device.
        try phone.store.deleteSession(phone.store.history.sessions[0].id)
        try await phone.engine.sync()
        try await watch.engine.sync()
        #expect(watch.store.history.sessions.isEmpty)

        // The export holds the synced documents; deleting the account ends both sessions.
        let exported: Data = try await phone.api.account().exportAccount()
        let export = try JSONSerialization.jsonObject(with: exported) as? [String: Any]
        let documents = export?["documents"] as? [[String: Any]]
        #expect(documents?.contains { $0["document_id"] as? String == custom.id.rawValue } == true)
        try await phone.api.deleteAccount(appleAuthorizationCode: nil)
        #expect(await !phone.api.isSignedIn)
        await #expect(throws: APIError.sessionExpired) { _ = try await watch.api.account().changes(after: 0, limit: 10) }
    }
}
