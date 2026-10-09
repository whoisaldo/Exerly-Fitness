import XCTest

/// A synthetic week of logging for realistic screens and usability runs.
extension ExerlyUITestCase {
    struct SeedFood {
        let id = UUID().uuidString
        let name: String
        let per100g: [String: Double]
    }

    /// A week of synthetic logging: breakfast at this time of day on four
    /// days (a habit), plus lunches and dinners on earlier days. Foods get
    /// fresh IDs for every account.
    func seedWeek(token: String) async throws {
        let yogurt = SeedFood(name: "Greek yogurt, plain", per100g: ["energy": 73, "protein": 10, "carbohydrate": 3.9, "fat": 1.9])
        let berries = SeedFood(name: "Blueberries", per100g: ["energy": 57, "protein": 0.7, "carbohydrate": 14.5, "fat": 0.3])
        let oats = SeedFood(name: "Rolled oats", per100g: ["energy": 380, "protein": 13, "carbohydrate": 67, "fat": 7])
        let chicken = SeedFood(name: "Chicken breast, grilled", per100g: ["energy": 165, "protein": 31, "carbohydrate": 0, "fat": 3.6])
        let rice = SeedFood(name: "Jasmine rice, cooked", per100g: ["energy": 130, "protein": 2.7, "carbohydrate": 28, "fat": 0.3])
        let salmon = SeedFood(name: "Salmon fillet", per100g: ["energy": 208, "protein": 20, "carbohydrate": 0, "fat": 13])
        let potato = SeedFood(name: "Roasted potatoes", per100g: ["energy": 149, "protein": 2.5, "carbohydrate": 24, "fat": 4.8])
        for food in [yogurt, berries, oats, chicken, rice, salmon, potato] {
            let payload: [String: Any] = ["id": food.id, "name": food.name, "source": "custom", "per100g": food.per100g,
                                          "servings": [], "favorite": false, "createdAt": "2026-10-01T12:00:00.000Z"]
            _ = try await request("PUT", "/v1/documents/saved_food/\(food.id)", body: ["base_revision": 0, "payload": payload], token: token)
        }
        for day in 1...4 {
            try await seedEntry(yogurt, grams: 170, daysAgo: day, meal: "Breakfast", token: token)
            try await seedEntry(berries, grams: 80, daysAgo: day, meal: "Breakfast", token: token)
            if day % 2 == 0 { try await seedEntry(oats, grams: 50, daysAgo: day, meal: "Breakfast", token: token) }
        }
        try await seedEntry(chicken, grams: 180, daysAgo: 1, meal: "Lunch", minutes: 240, token: token)
        try await seedEntry(rice, grams: 200, daysAgo: 1, meal: "Lunch", minutes: 240, token: token)
        try await seedEntry(salmon, grams: 150, daysAgo: 1, meal: "Dinner", minutes: 480, token: token)
        try await seedEntry(potato, grams: 220, daysAgo: 1, meal: "Dinner", minutes: 480, token: token)
        try await seedEntry(chicken, grams: 150, daysAgo: 3, meal: "Dinner", minutes: 480, token: token)
    }

    /// Logs an entry `daysAgo` days back, `minutes` before now's time of day.
    func seedEntry(_ food: SeedFood, grams: Double, daysAgo: Int, meal: String, minutes: Int = 15, token: String) async throws {
        let id = UUID().uuidString
        let at = Date().addingTimeInterval(Double(-daysAgo * 86_400 - minutes * 60))
        let day = DateFormatter()
        day.calendar = Calendar(identifier: .gregorian)
        day.timeZone = TimeZone(identifier: "America/New_York")!
        day.dateFormat = "yyyy-MM-dd"
        let instant = ISO8601DateFormatter()
        instant.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let entry: [String: Any] = ["id": id, "date": day.string(from: at), "meal": meal, "loggedAt": instant.string(from: at),
                                    "food": ["foodID": food.id, "name": food.name, "source": "custom", "per100g": food.per100g],
                                    "grams": grams]
        _ = try await request("PUT", "/v1/documents/food_entry/\(id)", body: ["base_revision": 0, "payload": entry], token: token)
    }

    func signedInWithWeek(prefix: String) async throws -> XCUIApplication {
        try await control([:])
        let person = try await createAccount(prefix: prefix, units: "imperial")
        try await seedWeek(token: person.token)
        _ = try await seedProgram(name: "Strength foundations", activated: "2026-10-01T12:00:00.000Z", token: person.token)
        _ = try await seedTrainingWorkout(name: "Full body", loads: [60, 65, 65], daysAgo: 2,
                                           exercises: ["deadlift", "barbell-bench-press"], token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        return app
    }
}
