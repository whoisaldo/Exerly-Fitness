import Foundation

private extension KeyedDecodingContainer {
    func decodeString(forKeys keys: [K]) -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return String(value)
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return String(value)
            }
        }
        return nil
    }

    func decodeInt(forKeys keys: [K]) -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(value)
            }
            if let str = try? decodeIfPresent(String.self, forKey: key),
               let value = Int(str) {
                return value
            }
        }
        return nil
    }

    func decodeDouble(forKeys keys: [K]) -> Double? {
        for key in keys {
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let str = try? decodeIfPresent(String.self, forKey: key),
               let value = Double(str) {
                return value
            }
        }
        return nil
    }

    func decodeBool(forKeys keys: [K]) -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value != 0
            }
        }
        return nil
    }
}

// MARK: - Auth

struct AuthRequest: Encodable {
    let email: String
    let password: String
    var name: String?
}

struct AuthResponse: Decodable {
    let token: String
    let user: UserDTO?
}

struct UserDTO: Decodable, Identifiable {
    let id: String?
    let email: String
    let name: String?
    let isAdmin: Bool?
    let onboardingCompleted: Bool?
    let age: Int?
    let gender: String?
    let height: Double?
    let weight: Double?
    let activityLevel: String?
    let goal: String?
    let targetWeight: Double?
    let aiCreditsRemaining: Int?
    let dailyAiCreditsUsed: Int?
    let hourlyAiCreditsUsed: Int?

    init(
        id: String? = nil,
        email: String,
        name: String? = nil,
        isAdmin: Bool? = nil,
        onboardingCompleted: Bool? = nil,
        age: Int? = nil,
        gender: String? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        activityLevel: String? = nil,
        goal: String? = nil,
        targetWeight: Double? = nil,
        aiCreditsRemaining: Int? = nil,
        dailyAiCreditsUsed: Int? = nil,
        hourlyAiCreditsUsed: Int? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.isAdmin = isAdmin
        self.onboardingCompleted = onboardingCompleted
        self.age = age
        self.gender = gender
        self.height = height
        self.weight = weight
        self.activityLevel = activityLevel
        self.goal = goal
        self.targetWeight = targetWeight
        self.aiCreditsRemaining = aiCreditsRemaining
        self.dailyAiCreditsUsed = dailyAiCreditsUsed
        self.hourlyAiCreditsUsed = hourlyAiCreditsUsed
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case legacyId = "id"
        case email, name
        case isAdmin
        case legacyIsAdmin = "is_admin"
        case onboardingCompleted
        case age, gender, height, weight, goal
        case activityLevel
        case legacyActivityLevel = "activity_level"
        case targetWeight
        case legacyTargetWeight = "target_weight"
        case aiCreditsRemaining
        case dailyAiCreditsUsed
        case legacyDailyAiCreditsUsed = "aiDailyCreditsUsed"
        case hourlyAiCreditsUsed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: container.decodeString(forKeys: [.id, .legacyId]),
            email: container.decodeString(forKeys: [.email]) ?? "",
            name: container.decodeString(forKeys: [.name]),
            isAdmin: container.decodeBool(forKeys: [.isAdmin, .legacyIsAdmin]),
            onboardingCompleted: container.decodeBool(forKeys: [.onboardingCompleted]),
            age: container.decodeInt(forKeys: [.age]),
            gender: container.decodeString(forKeys: [.gender]),
            height: container.decodeDouble(forKeys: [.height]),
            weight: container.decodeDouble(forKeys: [.weight]),
            activityLevel: container.decodeString(forKeys: [.activityLevel, .legacyActivityLevel]),
            goal: container.decodeString(forKeys: [.goal]),
            targetWeight: container.decodeDouble(forKeys: [.targetWeight, .legacyTargetWeight]),
            aiCreditsRemaining: container.decodeInt(forKeys: [.aiCreditsRemaining]),
            dailyAiCreditsUsed: container.decodeInt(forKeys: [.dailyAiCreditsUsed, .legacyDailyAiCreditsUsed]),
            hourlyAiCreditsUsed: container.decodeInt(forKeys: [.hourlyAiCreditsUsed])
        )
    }
}

// MARK: - Onboarding

struct OnboardingRequest: Encodable {
    let age: Int
    let gender: String
    let height: Double
    let weight: Double
    let activityLevel: String
    let goal: String
    let targetWeight: Double?
}

struct OnboardingResponse: Decodable {
    let message: String
    let maintenance: Double?
}

// MARK: - Activity

struct ActivityDTO: Decodable, Identifiable {
    let id: String?
    let type: String
    let duration: Int
    let calories: Int
    let intensity: String?
    let date: String?

    init(
        id: String? = nil,
        type: String,
        duration: Int,
        calories: Int,
        intensity: String? = nil,
        date: String? = nil
    ) {
        self.id = id
        self.type = type
        self.duration = duration
        self.calories = calories
        self.intensity = intensity
        self.date = date
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case legacyId = "id"
        case type
        case activity
        case duration
        case legacyDuration = "duration_min"
        case calories, intensity, date
        case legacyDate = "entry_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: container.decodeString(forKeys: [.id, .legacyId]),
            type: container.decodeString(forKeys: [.activity, .type]) ?? "Activity",
            duration: container.decodeInt(forKeys: [.duration, .legacyDuration]) ?? 0,
            calories: container.decodeInt(forKeys: [.calories]) ?? 0,
            intensity: container.decodeString(forKeys: [.intensity]),
            date: container.decodeString(forKeys: [.date, .legacyDate])
        )
    }
}

struct ActivityRequest: Encodable {
    let type: String
    let duration: Int
    let calories: Int
    let intensity: String

    enum CodingKeys: String, CodingKey {
        case activity, durationMin = "duration_min", calories, intensity, type
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .activity)
        try container.encode(duration, forKey: .durationMin)
        try container.encode(calories, forKey: .calories)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(type, forKey: .type)
    }
}

// MARK: - Food

struct FoodDTO: Decodable, Identifiable {
    let id: String?
    let name: String
    let calories: Int
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let sugar: Double?
    let servingSize: String?
    let date: String?

    init(
        id: String? = nil,
        name: String,
        calories: Int,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        sugar: Double? = nil,
        servingSize: String? = nil,
        date: String? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.sugar = sugar
        self.servingSize = servingSize
        self.date = date
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case legacyId = "id"
        case name, calories, protein, carbs, fat, sugar
        case servingSize
        case mealType = "meal_type"
        case date
        case legacyDate = "entry_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: container.decodeString(forKeys: [.id, .legacyId]),
            name: container.decodeString(forKeys: [.name]) ?? "Food",
            calories: container.decodeInt(forKeys: [.calories]) ?? 0,
            protein: container.decodeDouble(forKeys: [.protein]),
            carbs: container.decodeDouble(forKeys: [.carbs]),
            fat: container.decodeDouble(forKeys: [.fat]),
            sugar: container.decodeDouble(forKeys: [.sugar]),
            servingSize: container.decodeString(forKeys: [.servingSize, .mealType]),
            date: container.decodeString(forKeys: [.date, .legacyDate])
        )
    }
}

struct FoodRequest: Encodable {
    let name: String
    let calories: Int
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let sugar: Double?
    let servingSize: String?

    enum CodingKeys: String, CodingKey {
        case name, calories, protein, carbs, fat, sugar, mealType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein ?? 0, forKey: .protein)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(fat, forKey: .fat)
        try container.encode(sugar ?? 0, forKey: .sugar)
        try container.encode(servingSize, forKey: .mealType)
    }
}

// MARK: - Sleep

struct SleepDTO: Decodable, Identifiable {
    let id: String?
    let hours: Double
    let quality: Int?
    let bedtime: String?
    let wakeTime: String?
    let date: String?

    init(
        id: String? = nil,
        hours: Double,
        quality: Int? = nil,
        bedtime: String? = nil,
        wakeTime: String? = nil,
        date: String? = nil
    ) {
        self.id = id
        self.hours = hours
        self.quality = quality
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.date = date
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case legacyId = "id"
        case hours, quality, bedtime, wakeTime, date
        case legacyWakeTime = "wake_time"
        case legacyDate = "entry_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let qualityValue = container.decodeInt(forKeys: [.quality])
            ?? SleepRequest.score(for: container.decodeString(forKeys: [.quality]))
        self.init(
            id: container.decodeString(forKeys: [.id, .legacyId]),
            hours: container.decodeDouble(forKeys: [.hours]) ?? 0,
            quality: qualityValue,
            bedtime: container.decodeString(forKeys: [.bedtime]),
            wakeTime: container.decodeString(forKeys: [.wakeTime, .legacyWakeTime]),
            date: container.decodeString(forKeys: [.date, .legacyDate])
        )
    }
}

struct SleepRequest: Encodable {
    let hours: Double
    let quality: Int
    let bedtime: String?
    let wakeTime: String?

    enum CodingKeys: String, CodingKey {
        case hours, quality, bedtime, wakeTime
    }

    static func label(for score: Int) -> String {
        switch score {
        case ..<2: return "poor"
        case 2: return "fair"
        case 3: return "good"
        case 4: return "great"
        default: return "excellent"
        }
    }

    static func score(for label: String?) -> Int? {
        switch label?.lowercased() {
        case "poor": return 1
        case "fair": return 2
        case "good": return 3
        case "great": return 4
        case "excellent": return 5
        default: return nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hours, forKey: .hours)
        try container.encode(Self.label(for: quality), forKey: .quality)
        try container.encode(bedtime, forKey: .bedtime)
        try container.encode(wakeTime, forKey: .wakeTime)
    }
}

// MARK: - Goals

struct GoalsDTO: Codable {
    let id: String?
    let dailyCalories: Int?
    let weeklyWorkouts: Int?
    let dailySteps: Int?
    let targetWeight: Double?
    let sleepHours: Double?
    let waterGlasses: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case legacyId = "id"
        case dailyCalories
        case dailyCaloriesSnake = "daily_calories"
        case weeklyWorkouts
        case weeklyWorkoutsSnake = "weekly_workouts"
        case dailySteps
        case dailyStepsSnake = "daily_steps"
        case targetWeight
        case weeklyWeight = "weekly_weight"
        case sleepHours
        case sleepHoursSnake = "sleep_hours"
        case waterGlasses
        case waterIntake = "water_intake"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = container.decodeString(forKeys: [.id, .legacyId])
        self.dailyCalories = container.decodeInt(forKeys: [.dailyCalories, .dailyCaloriesSnake])
        self.weeklyWorkouts = container.decodeInt(forKeys: [.weeklyWorkouts, .weeklyWorkoutsSnake])
        self.dailySteps = container.decodeInt(forKeys: [.dailySteps, .dailyStepsSnake])
        self.targetWeight = container.decodeDouble(forKeys: [.targetWeight, .weeklyWeight])
        self.sleepHours = container.decodeDouble(forKeys: [.sleepHours, .sleepHoursSnake])
        self.waterGlasses = container.decodeInt(forKeys: [.waterGlasses, .waterIntake])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(dailyCalories, forKey: .dailyCalories)
        try container.encodeIfPresent(weeklyWorkouts, forKey: .weeklyWorkouts)
        try container.encodeIfPresent(dailySteps, forKey: .dailySteps)
        try container.encodeIfPresent(targetWeight, forKey: .weeklyWeight)
        try container.encodeIfPresent(sleepHours, forKey: .sleepHours)
        try container.encodeIfPresent(waterGlasses, forKey: .waterIntake)
    }
}

// MARK: - Dashboard

struct DashboardData: Decodable {
    let calories: DashboardCalories?
    let workouts: DashboardWorkouts?
    let sleep: DashboardSleep?
    let maintenance: Double?
}

struct DashboardCalories: Decodable {
    let consumed: Int
    let target: Int
}

struct DashboardWorkouts: Decodable {
    let completed: Int
    let target: Int
}

struct DashboardSleep: Decodable {
    let hours: Double
    let target: Double
}

// MARK: - Recent

struct RecentData: Decodable {
    let activities: [ActivityDTO]?
    let food: [FoodDTO]?
    let sleep: [SleepDTO]?
}

// MARK: - Profile

struct ProfileUpdateRequest: Encodable {
    var name: String?
    var age: Int?
    var gender: String?
    var height: Double?
    var weight: Double?
    var activityLevel: String?
    var goal: String?
    var targetWeight: Double?
}

// MARK: - AI

struct AIPlanDTO: Decodable, Identifiable {
    let id: String?
    let type: String
    let content: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case legacyId = "id"
        case type, content, response, plan, createdAt, created_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = container.decodeString(forKeys: [.id, .legacyId])
        self.type = container.decodeString(forKeys: [.type]) ?? "plan"
        self.content = container.decodeString(forKeys: [.content, .response, .plan]) ?? ""
        self.createdAt = container.decodeString(forKeys: [.createdAt, .created_at])
    }
}

struct AICreditsDTO: Decodable {
    let creditsRemaining: Int
    let hourlyCreditsUsed: Int
    let dailyCreditsUsed: Int
    let maxHourly: Int
    let maxDaily: Int
    let timeUntilHourlyReset: String?
    let hoursUntilMidnight: Int?

    enum CodingKeys: String, CodingKey {
        case creditsRemaining, hourlyCreditsUsed, dailyCreditsUsed
        case maxHourly, maxDaily, timeUntilHourlyReset, hoursUntilMidnight
        case hourly, daily
    }

    enum NestedCreditKeys: String, CodingKey {
        case remaining, used, limit, resetTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.hourly) || container.contains(.daily) {
            let hourly = try container.nestedContainer(keyedBy: NestedCreditKeys.self, forKey: .hourly)
            let daily = try container.nestedContainer(keyedBy: NestedCreditKeys.self, forKey: .daily)
            self.creditsRemaining = hourly.decodeInt(forKeys: [.remaining]) ?? 0
            self.hourlyCreditsUsed = max(0, (hourly.decodeInt(forKeys: [.limit]) ?? 0) - creditsRemaining)
            self.dailyCreditsUsed = daily.decodeInt(forKeys: [.used]) ?? 0
            self.maxHourly = hourly.decodeInt(forKeys: [.limit]) ?? 0
            self.maxDaily = daily.decodeInt(forKeys: [.limit]) ?? 0
            self.timeUntilHourlyReset = hourly.decodeString(forKeys: [.resetTime])
            let dailyReset = daily.decodeString(forKeys: [.resetTime])
            self.hoursUntilMidnight = dailyReset.flatMap { Int($0) }
        } else {
            self.creditsRemaining = container.decodeInt(forKeys: [.creditsRemaining]) ?? 0
            self.hourlyCreditsUsed = container.decodeInt(forKeys: [.hourlyCreditsUsed]) ?? 0
            self.dailyCreditsUsed = container.decodeInt(forKeys: [.dailyCreditsUsed]) ?? 0
            self.maxHourly = container.decodeInt(forKeys: [.maxHourly]) ?? 0
            self.maxDaily = container.decodeInt(forKeys: [.maxDaily]) ?? 0
            self.timeUntilHourlyReset = container.decodeString(forKeys: [.timeUntilHourlyReset])
            self.hoursUntilMidnight = container.decodeInt(forKeys: [.hoursUntilMidnight])
        }
    }
}
