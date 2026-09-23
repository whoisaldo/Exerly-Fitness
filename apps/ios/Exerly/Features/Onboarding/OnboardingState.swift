import Foundation
import SwiftUI

struct OnboardingDraft: Codable {
    var schemaVersion = 2
    var accountID: String
    var step: Int
    var answers: OnboardingRequest
    var operationID: String
    var submittedPayload: Data?
    var serverRevision: Int?
    var cloudBaseline: Data?
    var pendingCloudSave: SetupDraftSave?
    var repairSteps: [Int]?
}

struct SetupDraftContent: Codable {
    var schema_version = 2
    var last_valid_step: Int
    var answers: OnboardingRequest
}

struct SetupCloudDraft: Decodable {
    let account_id: String
    let schema_version: Int
    let last_valid_step: Int
    let answers: OnboardingRequest
    let revision: Int
    var content: SetupDraftContent {
        SetupDraftContent(schema_version: schema_version, last_valid_step: last_valid_step, answers: answers)
    }
}

struct SetupDraftEnvelope: Decodable { let draft: SetupCloudDraft? }
struct SetupDraftSave: Codable {
    let revision: Int
    let schema_version: Int
    let last_valid_step: Int
    let answers: OnboardingRequest
    let operationID: String
    var content: SetupDraftContent {
        SetupDraftContent(schema_version: schema_version, last_valid_step: last_valid_step, answers: answers)
    }
    enum CodingKeys: String, CodingKey {
        case revision, schema_version, last_valid_step, answers, operationID
    }
}

@MainActor
final class OnboardingState: ObservableObject {
    @Published var step = 0 { didSet { saveCheckpoint() } }
    @Published var direction: Edge = .trailing
    @Published var name = "" { didSet { saveCheckpoint() } }
    @Published var age = 25 { didSet { saveCheckpoint() } }
    @Published var gender: Gender = .male {
        didSet {
            if !restoring { preservedGender = nil }
            answered("gender"); saveCheckpoint()
        }
    }
    @Published var physiologicalSex = "" { didSet { saveCheckpoint() } }
    @Published var manualTargetMode = false { didSet { saveCheckpoint() } }
    @Published var manualTargets = SetupTargets(calories: 2200, protein_g: 140, carbs_g: 250, fat_g: 70) { didSet { saveCheckpoint() } }
    @Published var useMetric = Locale.current.measurementSystem == .metric { didSet { saveCheckpoint() } }
    @Published var heightCm: Double = 170 { didSet { saveCheckpoint() } }
    @Published var weightKg: Double = 70 { didSet { saveCheckpoint() } }
    @Published var goal: FitnessGoal = .maintain { didSet { answered("goal"); saveCheckpoint() } }
    @Published var nutritionGoalChoice: String? { didSet { saveCheckpoint() } }
    @Published var targetWeightKg: Double = 70 { didSet { saveCheckpoint() } }
    @Published var timelineWeeks = 12 { didSet { saveCheckpoint() } }
    @Published var activityLevel: ActivityLevel = .moderate { didSet { answered("activityLevel"); saveCheckpoint() } }
    @Published var activityTypes: Set<ActivityType> = [] { didSet { saveCheckpoint() } }
    @Published var dietaryStyle: DietaryStyle = .standard {
        didSet { if !restoring { dietaryStyleEdited = true }; saveCheckpoint() }
    }
    @Published var allergies: Set<Allergy> = [] { didSet { saveCheckpoint() } }
    @Published var mealsPerDay = 3 { didSet { saveCheckpoint() } }
    @Published var sleepHours: Double = 8 {
        didSet { if !restoring { sleepPreferencesEdited = true }; saveCheckpoint() }
    }
    @Published var wakeHour = 7 {
        didSet { if !restoring { sleepPreferencesEdited = true }; saveCheckpoint() }
    }
    @Published var wakeMinute = 0 {
        didSet { if !restoring { sleepPreferencesEdited = true }; saveCheckpoint() }
    }
    @Published var equipment: Set<Equipment> = [.bodyweight] { didSet { saveCheckpoint() } }
    @Published var hasGymAccess = false {
        didSet { if !restoring { equipmentAccessEdited = true }; saveCheckpoint() }
    }
    @Published var notifyWorkouts = false { didSet { saveCheckpoint() } }
    @Published var notifyMeals = false { didSet { saveCheckpoint() } }
    @Published var notifySleep = false { didSet { saveCheckpoint() } }
    @Published var results: WizardResults?
    @Published var serverPreview: SetupPreview?
    @Published var previewError: String?
    @Published var validationError: String?
    @Published var showConfetti = false
    @Published var isSubmitting = false
    @Published private(set) var cloudConflict: SetupCloudDraft?
    @Published private(set) var cloudMessage: String?
    @Published private(set) var isSyncingDraft = false
    @Published private(set) var repairSteps: [Int]?
    @Published private(set) var repairUnavailable = false
    @Published private(set) var unansweredFields: Set<String> = []
    private(set) var operationID = UUID().uuidString
    private var submittedPayload: Data?
    private var accountID: String?
    private var restoring = false
    private let defaults: UserDefaults
    private let api: APIClient
    private let automaticallySync: Bool
    private var serverRevision: Int?
    private var cloudBaseline: Data?
    private var pendingCloudSave: SetupDraftSave?
    private var scheduledSync: Task<Void, Never>?
    private var activeSync: Task<Bool, Never>?
    private var preservedAnswers: OnboardingRequest?
    private var preservedGender: String?
    private var dietaryStyleEdited = false
    private var sleepPreferencesEdited = false
    private var equipmentAccessEdited = false

    init(defaults: UserDefaults = .standard, api: APIClient = .shared, automaticallySync: Bool = false) {
        self.defaults = defaults
        self.api = api
        self.automaticallySync = automaticallySync
    }
    var totalSteps: Int { 5 }
    var visibleSteps: [Int] { repairSteps ?? Array(0..<totalSteps) }
    var previewIdentity: Data? { signature(content()) }
    private func checkpointKey(_ accountID: String) -> String {
        "onboarding.draft.v2.\(api.storageNamespace).\(accountID)"
    }

    private func answered(_ field: String) {
        if !restoring { unansweredFields.remove(field) }
    }
    var heightDisplay: Double { heightCm }
    var weightDisplay: Double { weightKg }
    var weightLbs: Double {
        get { weightKg / 0.45359237 }
        set { weightKg = newValue * 0.45359237 }
    }
    var heightFeet: Int {
        get { Int((heightCm / 2.54).rounded()) / 12 }
        set { heightCm = Double(newValue * 12 + heightInches) * 2.54 }
    }
    var heightInches: Int {
        get { Int((heightCm / 2.54).rounded()) % 12 }
        set { heightCm = Double(heightFeet * 12 + newValue) * 2.54 }
    }
    var bmiPreview: Double { WizardService.calculateBMI(weightKg: weightKg, heightCm: heightCm) }
    var weightRateSafety: WeightRateSafety {
        WizardService.assessWeightRate(currentKg: weightKg, targetKg: targetWeightKg, weeks: timelineWeeks)
    }
    var nutritionGoal: String {
        if let nutritionGoalChoice { return nutritionGoalChoice }
        switch goal {
        case .loseWeight: return "lose"
        case .gainMuscle: return "gain"
        default: return "maintain"
        }
    }

    func errorForStep(_ index: Int) -> String? {
        switch index {
        case 0: return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter your name." : nil
        case 1:
            if unansweredFields.contains("gender") { return "Choose a gender identity, or prefer not to say." }
            if !(18...120).contains(age) { return "Exerly currently supports adults aged 18 or older." }
            if !manualTargetMode && !["male", "female"].contains(physiologicalSex) {
                return "Choose a calculation parameter or enter your own targets."
            }
            if manualTargetMode && (!(800...10000).contains(manualTargets.calories) ||
                !(0...500).contains(manualTargets.protein_g) || !(0...1500).contains(manualTargets.carbs_g) ||
                !(0...500).contains(manualTargets.fat_g)) {
                return "Enter valid calorie and nutrient targets."
            }
            return (50...280).contains(heightCm) && (20...500).contains(weightKg) ? nil : "Enter a valid height and weight."
        case 2:
            if unansweredFields.contains("goal") { return "Choose your fitness goal." }
            if !["lose", "maintain", "gain"].contains(nutritionGoal) { return "Choose your nutrition goal." }
            if nutritionGoal != "maintain" && !(20...500).contains(targetWeightKg) { return "Enter a valid target weight." }
            if nutritionGoal == "lose" && targetWeightKg > weightKg { return "Your target weight must be below your current weight." }
            if nutritionGoal == "gain" && targetWeightKg < weightKg { return "Your target weight must be above your current weight." }
            return nil
        case 3: return unansweredFields.contains("activityLevel") ? "Choose your usual activity level." : nil
        default: return nil
        }
    }

    func nextStep() {
        guard !isSubmitting else { return }
        validationError = errorForStep(step)
        guard validationError == nil, let next = visibleSteps.first(where: { $0 > step }) else { return }
        direction = .trailing
        step = next
    }
    func prevStep() {
        guard !isSubmitting, let previous = visibleSteps.last(where: { $0 < step }) else { return }
        validationError = nil
        direction = .leading
        step = previous
    }

    func request() -> OnboardingRequest {
        var answer = OnboardingRequest(age: age, gender: unansweredFields.contains("gender") ? "" : (preservedGender ?? gender.rawValue), height: heightCm,
            weight: weightKg, activityLevel: unansweredFields.contains("activityLevel") ? "" : activityLevel.rawValue,
            goal: unansweredFields.contains("goal") ? "" : goal.rawValue,
            targetWeight: nutritionGoal == "maintain" ? nil : targetWeightKg)
        if let preservedAnswers {
            answer.timezone = preservedAnswers.timezone
            answer.experienceLevel = preservedAnswers.experienceLevel
            answer.workoutDaysPerWeek = preservedAnswers.workoutDaysPerWeek
            answer.workoutDays = preservedAnswers.workoutDays
            answer.rateKgPerWeek = preservedAnswers.rateKgPerWeek
            answer.dietType = preservedAnswers.dietType
        }
        answer.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        answer.sex = physiologicalSex.isEmpty ? nil : physiologicalSex
        answer.nutritionGoal = nutritionGoal
        answer.nutritionGoalFollowsFitness = nutritionGoalChoice == nil
        answer.targetMode = manualTargetMode ? "manual" : "estimated"
        answer.manualTargets = manualTargetMode ? manualTargets : nil
        answer.unitSystem = useMetric ? "metric" : "imperial"
        answer.equipmentAccess = !equipmentAccessEdited ? preservedAnswers?.equipmentAccess ?? (hasGymAccess ? "full_gym" : "home") : (hasGymAccess ? "full_gym" : "home")
        answer.equipment = retainedPreferences(preservedAnswers?.equipment, selected: equipment.map(\.rawValue)) { Equipment(rawValue: $0) != nil }
        answer.activityTypes = retainedPreferences(preservedAnswers?.activityTypes, selected: activityTypes.map(\.rawValue)) { ActivityType(rawValue: $0) != nil }
        answer.dietaryStyle = !dietaryStyleEdited ? preservedAnswers?.dietaryStyle ?? dietaryStyle.rawValue : dietaryStyle.rawValue
        answer.allergies = retainedPreferences(preservedAnswers?.allergies, selected: allergies.map(\.rawValue)) { Allergy(rawValue: $0) != nil }
        answer.mealsPerDay = mealsPerDay
        answer.sleepGoalHours = sleepHours
        if let preservedAnswers, !sleepPreferencesEdited {
            answer.wakeTime = preservedAnswers.wakeTime
            answer.bedtime = preservedAnswers.bedtime
        } else {
            answer.wakeTime = String(format: "%02d:%02d", wakeHour, wakeMinute)
            let bedMinutes = (wakeHour * 60 + wakeMinute - Int(sleepHours * 60) + 1440) % 1440
            answer.bedtime = String(format: "%02d:%02d", bedMinutes / 60, bedMinutes % 60)
        }
        answer.timelineWeeks = timelineWeeks
        answer.reminders = ["workouts": notifyWorkouts, "meals": notifyMeals, "sleep": notifySleep]
        return answer
    }

    private func retainedPreferences(_ saved: [String]?, selected: [String], known: (String) -> Bool) -> [String] {
        let retained = (saved ?? []).filter { !known($0) || selected.contains($0) }
        return retained + selected.sorted().filter { !retained.contains($0) }
    }

    func prepareSubmission() -> OnboardingRequest {
        var answer = request()
        answer.draftRevision = serverRevision
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let payload = try? encoder.encode(answer)
        if let submittedPayload, submittedPayload != payload { operationID = UUID().uuidString }
        submittedPayload = payload
        saveCheckpoint()
        return answer
    }

    func computeResults() {
        // Legacy optional screens still use the local preview. The review and
        // submitted targets use the server calculation below.
        results = WizardService.computeResults(name: name, age: age, gender: gender,
            heightCm: heightCm, weightKg: weightKg, goal: goal, targetWeightKg: targetWeightKg,
            activityLevel: activityLevel, activityTypes: activityTypes, equipment: equipment,
            hasGymAccess: hasGymAccess, sleepHours: sleepHours, wakeHour: wakeHour,
            wakeMinute: wakeMinute, daysPerWeek: 3)
    }

    func loadPreview() async {
        guard !repairUnavailable else { return }
        previewError = nil
        let identity = previewIdentity
        do {
            let preview: SetupPreview = try await api.request("POST", path: "/api/onboarding/preview", body: request(), expectedAccountID: accountID)
            guard identity == previewIdentity else { return }
            serverPreview = preview
        } catch is CancellationError { return }
        catch { if identity == previewIdentity { previewError = error.localizedDescription } }
    }

    func saveCheckpoint(invalidatePreview: Bool = true) {
        guard !restoring, let accountID else { return }
        let draft = OnboardingDraft(accountID: accountID, step: step, answers: request(),
            operationID: operationID, submittedPayload: submittedPayload, serverRevision: serverRevision,
            cloudBaseline: cloudBaseline, pendingCloudSave: pendingCloudSave, repairSteps: repairSteps)
        if let data = try? JSONEncoder().encode(draft) {
            defaults.set(data, forKey: checkpointKey(accountID))
        }
        if invalidatePreview { serverPreview = nil }
        scheduleCloudSync()
    }

    func restoreCheckpoint(accountID: String, name initialName: String? = nil, repair: SetupStatus? = nil) {
        guard self.accountID != accountID else {
            if repair?.needs_repair == true, repairSteps == nil { beginRepair(repair) }
            return
        }
        restoring = true
        defer { restoring = false; saveCheckpoint() }
        self.accountID = accountID
        name = initialName ?? ""
        let legacyKey = "onboarding.draft.v1.\(accountID)"
        let saved = defaults.data(forKey: checkpointKey(accountID)) ??
            (api.permitsLegacyDraftMigration ? defaults.data(forKey: legacyKey) : nil)
        guard let data = saved,
              let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data),
              (1...2).contains(draft.schemaVersion), draft.accountID == accountID else {
            step = 0
            beginRepair(repair)
            cloudBaseline = signature(content())
            return
        }
        serverRevision = draft.serverRevision
        cloudBaseline = draft.cloudBaseline
        pendingCloudSave = draft.pendingCloudSave
        operationID = draft.operationID
        submittedPayload = draft.submittedPayload
        repairSteps = draft.repairSteps
        apply(draft.answers, step: draft.step, schema: draft.schemaVersion)
        // The old app used the production API. A staging build must never
        // adopt those answers merely because its account ID happens to match.
        defaults.set(data, forKey: checkpointKey(accountID))
        if api.permitsLegacyDraftMigration { defaults.removeObject(forKey: legacyKey) }
        if repair?.needs_repair == true, repairSteps == nil {
            repairSteps = (0..<4).filter { errorForStep($0) != nil } + [4]
            step = repairSteps?.first ?? 4
        }
    }

    private func apply(_ a: OnboardingRequest, step savedStep: Int, schema: Int) {
        preservedAnswers = a
        name = a.name ?? name
        age = a.age
        gender = Gender(rawValue: a.gender) ?? .other
        preservedGender = Gender(rawValue: a.gender) == nil && !a.gender.isEmpty ? a.gender : nil
        physiologicalSex = a.sex ?? ""
        manualTargetMode = a.targetMode == "manual"
        if let targets = a.manualTargets { manualTargets = targets }
        heightCm = a.height
        weightKg = a.weight
        useMetric = a.unitSystem == "metric"
        goal = FitnessGoal(rawValue: a.goal) ?? .maintain
        nutritionGoalChoice = a.nutritionGoalFollowsFitness == true ? nil : a.nutritionGoal
        targetWeightKg = a.targetWeight ?? a.weight
        timelineWeeks = a.timelineWeeks
        activityLevel = ActivityLevel(rawValue: a.activityLevel) ?? .moderate
        activityTypes = Set(a.activityTypes.compactMap(ActivityType.init(rawValue:)))
        dietaryStyle = DietaryStyle(rawValue: a.dietaryStyle) ?? .standard
        allergies = Set(a.allergies.compactMap(Allergy.init(rawValue:)))
        mealsPerDay = a.mealsPerDay
        sleepHours = a.sleepGoalHours
        let wake = (a.wakeTime ?? "07:00").split(separator: ":").compactMap { Int($0) }
        wakeHour = wake.first ?? 7
        wakeMinute = wake.last ?? 0
        equipment = Set(a.equipment.compactMap(Equipment.init(rawValue:)))
        hasGymAccess = a.equipmentAccess == "full_gym"
        notifyMeals = a.reminders["meals"] ?? false
        notifyWorkouts = a.reminders["workouts"] ?? false
        notifySleep = a.reminders["sleep"] ?? false
        dietaryStyleEdited = false
        sleepPreferencesEdited = false
        equipmentAccessEdited = false
        unansweredFields = Set([
            a.gender.isEmpty ? "gender" : nil,
            FitnessGoal(rawValue: a.goal) == nil ? "goal" : nil,
            ActivityLevel(rawValue: a.activityLevel) == nil ? "activityLevel" : nil
        ].compactMap { $0 })
        let migratedStep: Int
        if schema == 1 {
            switch savedStep {
            case ...1: migratedStep = 0
            case 2...3: migratedStep = 1
            case 4: migratedStep = 2
            case 5...9: migratedStep = 3
            default: migratedStep = 4
            }
        } else { migratedStep = savedStep }
        step = min(max(migratedStep, 0), totalSteps - 1)
        if let invalid = (0...step).first(where: { errorForStep($0) != nil }) { step = invalid }
        if let repairSteps {
            self.repairSteps = Array(Set(repairSteps + (0..<4).filter { errorForStep($0) != nil } + [4])).sorted()
        }
    }

    private func beginRepair(_ status: SetupStatus?) {
        guard status?.needs_repair == true, let known = status?.repair_answers else { return }
        repairUnavailable = false
        let wasRestoring = restoring
        restoring = true
        defer { restoring = wasRestoring; saveCheckpoint() }
        do {
            let encoder = JSONEncoder()
            var merged = try JSONDecoder().decode([String: JSONValue].self, from: encoder.encode(request()))
            for (key, value) in known {
                if case .null = value { continue }
                merged[key] = value
            }
            // Missing measurements and choices must never turn into defaults
            // that appear to have come from the old account.
            func missing(_ key: String) -> Bool {
                if case .null = known[key] ?? .null { return true }
                return false
            }
            for key in ["age", "height", "weight"] where missing(key) {
                merged[key] = .number(0)
            }
            for key in ["gender", "goal", "activityLevel", "sex"] where missing(key) {
                merged[key] = .string("")
            }
            if case .string(let goal) = merged["goal"] {
                let aliases = ["lose": "lose_weight", "weight_loss": "lose_weight", "gain": "gain_muscle", "muscle_gain": "gain_muscle"]
                merged["goal"] = .string(aliases[goal] ?? goal)
            }
            let answers = try JSONDecoder().decode(OnboardingRequest.self, from: encoder.encode(merged))
            apply(answers, step: 0, schema: 2)
            repairSteps = (0..<4).filter { errorForStep($0) != nil } + [4]
            step = repairSteps?.first ?? 4
        } catch {
            repairUnavailable = true
            validationError = "Your saved profile could not be read. Your existing logs are safe. Reconnect to retry account repair."
        }
    }

    func clearCheckpoint() {
        guard let accountID else { return }
        scheduledSync?.cancel()
        defaults.removeObject(forKey: checkpointKey(accountID))
        self.accountID = nil
    }

    private func content() -> SetupDraftContent {
        SetupDraftContent(last_valid_step: step, answers: request())
    }

    private func signature(_ content: SetupDraftContent) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(content)
    }

    private func scheduleCloudSync() {
        guard automaticallySync, !isSubmitting, activeSync == nil, cloudConflict == nil else { return }
        scheduledSync?.cancel()
        scheduledSync = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
            _ = await self?.syncCloud()
        }
    }

    @discardableResult
    func syncCloud() async -> Bool {
        if let activeSync { return await activeSync.value }
        guard let owner = accountID, cloudConflict == nil else { return false }
        isSyncingDraft = true
        let task = Task { await self.reconcileCloud(owner: owner) }
        activeSync = task
        let success = await task.value
        activeSync = nil
        isSyncingDraft = false
        return success
    }

    private func reconcileCloud(owner: String) async -> Bool {
        do {
            // A persisted mutation is replayed before reading the server. Its
            // key and body survive process death, including a lost response.
            for _ in 0..<12 {
                guard owner == accountID else { return false }
                if let pending = pendingCloudSave {
                    do {
                        let response: SetupDraftEnvelope = try await api.request("PUT", path: "/api/onboarding/draft",
                            body: pending, operationID: pending.operationID, expectedAccountID: owner)
                        guard owner == accountID, let saved = response.draft, saved.account_id == owner else { return false }
                        serverRevision = saved.revision
                        cloudBaseline = signature(saved.content)
                        pendingCloudSave = nil
                        saveCheckpoint(invalidatePreview: false)
                    } catch APIError.serverError(409, _) {
                        pendingCloudSave = nil
                        saveCheckpoint(invalidatePreview: false)
                    }
                }
                let response: SetupDraftEnvelope = try await api.request("GET", path: "/api/onboarding/draft", expectedAccountID: owner)
                guard owner == accountID else { return false }
                let local = content()
                if let remote = response.draft {
                    guard remote.account_id == owner, (1...2).contains(remote.schema_version) else {
                        cloudMessage = "This saved draft needs a newer version of Exerly. Your local answers are safe."
                        return false
                    }
                    if remote.revision != serverRevision {
                        if signature(local) == signature(remote.content) {
                            serverRevision = remote.revision
                            cloudBaseline = signature(remote.content)
                        } else if signature(local) == cloudBaseline {
                            restoring = true
                            apply(remote.answers, step: remote.last_valid_step, schema: remote.schema_version)
                            serverPreview = nil
                            restoring = false
                            serverRevision = remote.revision
                            cloudBaseline = signature(content())
                            saveCheckpoint(invalidatePreview: false)
                        } else {
                            cloudConflict = remote
                            cloudMessage = "Setup changed on another device. Choose which answers to continue with."
                            return false
                        }
                    }
                } else if serverRevision != nil && serverRevision != 0 {
                    cloudMessage = "The saved draft changed. Reconnect to check your account before finishing."
                    return false
                } else { serverRevision = 0 }
                if response.draft != nil && signature(content()) == cloudBaseline {
                    cloudMessage = nil
                    saveCheckpoint(invalidatePreview: false)
                    return true
                }
                let latest = content()
                pendingCloudSave = SetupDraftSave(revision: serverRevision ?? 0, schema_version: 2,
                    last_valid_step: latest.last_valid_step, answers: latest.answers, operationID: UUID().uuidString)
                saveCheckpoint(invalidatePreview: false)
            }
            cloudMessage = "Your answers are saved on this device. Tap Retry to finish syncing."
        } catch is CancellationError { return false }
        catch { cloudMessage = error.localizedDescription }
        return false
    }

    func resolveCloudConflict(useServer: Bool) async {
        guard let remote = cloudConflict else { return }
        if useServer {
            restoring = true
            apply(remote.answers, step: remote.last_valid_step, schema: remote.schema_version)
            serverPreview = nil
            restoring = false
        }
        serverRevision = remote.revision
        cloudBaseline = signature(remote.content)
        pendingCloudSave = nil
        cloudConflict = nil
        cloudMessage = nil
        saveCheckpoint(invalidatePreview: false)
        _ = await syncCloud()
    }
}
