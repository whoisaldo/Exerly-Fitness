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
        try await deleteSetupWeight(token: person.token)
        for reading in syntheticReadings(days: 28) {
            let pounds = (reading.kilograms / 0.453_592_37 * 10).rounded() / 10
            try await seedWeighIn(token: person.token, date: reading.date, at: reading.at, value: pounds, unit: "lb")
        }
        _ = try await seedProgram(name: "Strength foundations", activated: "2026-10-01T12:00:00.000Z", token: person.token)
        _ = try await seedTrainingWorkout(name: "Full body", loads: [60, 65, 65], daysAgo: 2,
                                           exercises: ["deadlift", "barbell-bench-press"], token: person.token)
        let app = launch(resetSession: true)
        signIn(app, email: person.email)
        return app
    }

    // MARK: Weigh-ins

    /// Setup records its weight for today through the older API; captures want a clean history.
    func deleteSetupWeight(token: String) async throws {
        let row = try await request("GET", "/api/weight/day", token: token)
        guard let id = row["id"] as? String, let revision = row["revision"] as? Int else { return }
        _ = try await request("DELETE", "/api/weight/\(id)?base_revision=\(revision)", token: token)
    }

    func seedWeighIn(token: String, date: String, at: Date, value: Double, unit: String) async throws {
        let id = UUID().uuidString
        let payload: [String: Any] = ["id": id, "at": Self.iso(at), "date": date, "weight": ["unit": unit, "value": value]]
        _ = try await request("PUT", "/v1/documents/weight_entry/\(id)", body: ["base_revision": 0, "payload": payload], token: token)
    }

    /// Eight weeks of a steady cut, weighed most mornings, with food fully logged on most days.
    func seedHistory(token: String) async throws {
        for reading in syntheticReadings(days: 56) {
            let pounds = (reading.kilograms / 0.453_592_37 * 10).rounded() / 10
            try await seedWeighIn(token: token, date: reading.date, at: reading.at, value: pounds, unit: "lb")
        }
        for back in 1...56 where back % 7 != 3 {
            let day = Self.day(-back)
            let id = UUID().uuidString
            let energy = 2150 + 180 * sin(Double(back) * 2.3)
            let food: [String: Any] = ["foodID": "quick:\(id)", "name": "Logged day", "source": "custom", "unweighed": true,
                                       "per100g": ["energy": energy, "protein": 165, "carbohydrate": 210, "fat": 70]]
            let entry: [String: Any] = ["id": id, "date": day.date, "meal": "Dinner", "loggedAt": Self.iso(day.at), "food": food, "grams": 100]
            _ = try await request("PUT", "/v1/documents/food_entry/\(id)", body: ["base_revision": 0, "payload": entry], token: token)
            let status: [String: Any] = ["id": day.date, "date": day.date, "status": "complete", "notes": "", "tags": [String]()]
            _ = try await request("PUT", "/v1/documents/nutrition_day/\(day.date)", body: ["base_revision": 0, "payload": status], token: token)
        }
    }

    /// The account's live weigh-in documents by ID, from the change feed.
    func weighIns(token: String) async throws -> [String: [String: Any]] {
        var latest: [String: [String: Any]?] = [:]
        var cursor = 0
        while true {
            let page = try await request("GET", "/v1/changes?after=\(cursor)&limit=1000", token: token)
            for change in page["changes"] as? [[String: Any]] ?? [] where change["kind"] as? String == "weight_entry" {
                guard let id = change["id"] as? String else { continue }
                latest[id] = change["payload"] as? [String: Any]
            }
            cursor = page["cursor"] as? Int ?? cursor
            guard page["has_more"] as? Bool == true else { break }
        }
        return latest.compactMapValues { $0 }
    }

    func waitForWeighIn(token: String, timeout: Int = 40, _ matches: @escaping ([String: Any]) -> Bool) async throws -> [String: Any]? {
        for _ in 0..<timeout {
            if let found = try await weighIns(token: token).values.first(where: matches) { return found }
            try await Task.sleep(for: .milliseconds(500))
        }
        XCTFail("No matching weigh-in reached the server")
        return nil
    }

    struct Reading {
        let date: String
        let kilograms: Double
        let at: Date
    }

    static let newYork = TimeZone(identifier: "America/New_York")!

    static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// A local date in New York `offset` days from today, and 07:10 that morning.
    static func day(_ offset: Int) -> (date: String, at: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = newYork
        formatter.dateFormat = "yyyy-MM-dd"
        let at = offset == 0 ? min(Date(), calendar.date(bySettingHour: 7, minute: 10, second: 0, of: date)!)
            : calendar.date(bySettingHour: 7, minute: 10, second: 0, of: date)!
        return (formatter.string(from: date), at)
    }

    /// A steady cut of about 0.45 kg a week with water swings, weighed on most mornings.
    func syntheticReadings(days: Int) -> [Reading] {
        (1...days).reversed().compactMap { back -> Reading? in
            guard back % 9 != 4, back % 13 != 6 else { return nil }
            let day = Double(days - back)
            let water = 0.42 * sin(day * 1.7) + 0.22 * sin(day * 0.53 + 1) + 0.12 * cos(day * 3.1)
            let kilograms = ((84.2 - 0.064 * day + water) * 10).rounded() / 10
            let local = Self.day(-back)
            return Reading(date: local.date, kilograms: kilograms, at: local.at.addingTimeInterval(Double(back % 20) * 60))
        }
    }
}
