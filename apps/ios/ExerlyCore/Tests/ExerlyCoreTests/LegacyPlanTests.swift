import Foundation
import Testing
@testable import ExerlyCore

/// The plan the server writes from legacy targets, in
/// docs/api/golden/legacy-plan-v1.json, which apps/api/tests/api.legacy-plans.test.js asserts.
@Suite struct LegacyPlanTests {
    static let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/api/golden/legacy-plan-v1.json")

    @Test func theServersLegacyPlanIsAValidManualPlanWithTheSavedNumbers() throws {
        let plan = try ExerlyJSON.decoder.decode(NutritionPlan.self, from: Data(contentsOf: Self.url))
        #expect(plan.validationErrors.isEmpty, "\(plan.validationErrors)")
        #expect(plan.mode == .manual && plan.basis == nil && plan.diet == .lowCarb && plan.protein == .high)
        #expect(plan.goal.direction == .lose && plan.goal.weeklyRate == 0.0059 && plan.goal.goalWeight == .kg(78))
        #expect(plan.targets(on: LocalDate("2026-10-07")!) == DailyTargets(energy: 2150, protein: 170, fat: 80, carbohydrate: 190))
        #expect(plan.goal(for: .fiber, on: LocalDate("2026-10-07")!) == NutrientGoal(target: 30))
        #expect(try ExerlyJSON.decoder.decode(NutritionPlan.self, from: ExerlyJSON.canonical(plan)) == plan)
    }

    @Test func theAppAsksOnceAndLearnsHowManyWereMade() async throws {
        let store = InMemoryCredentialStore()
        let start = Date.milliseconds(1_791_223_200_000)
        try store.save(Credentials(accessToken: "t", refreshToken: "r", accessExpiresAt: start.addingTimeInterval(600),
                                   sessionID: "s", accountID: "a"))
        var calls = 0
        let transport = FakeTransport { request in
            #expect(request.method == "POST" && request.path == "/v1/nutrition/plans/from-legacy")
            calls += 1
            return calls == 1 ? (201, ["created": 1, "reason": "adopted", "plans": []])
                : (200, ["created": 0, "reason": "has_plan", "plans": []])
        }
        let account = try await ExerlyAPI(baseURL: URL(string: "https://api.exerly.test")!, transport: transport, credentials: store,
                                          now: { start }).account()
        #expect(try await account.adoptLegacyTargets() == 1)
        #expect(try await account.adoptLegacyTargets() == 0)
    }
}
