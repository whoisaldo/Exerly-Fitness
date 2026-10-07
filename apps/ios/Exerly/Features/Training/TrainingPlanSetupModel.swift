import Combine
import ExerlyCore
import Foundation

/// These are form answers. Exercise selection, volume and targets belong to Core.
struct TrainingPlanAnswers: Equatable {
    var days: Int? = 3
    var goal: ProgramGeneration.Goal = .general
    var experience: ProgramGeneration.Experience = .beginner
    var minutes = 60
    var fullGym = false
    var equipment: Set<ExerlyCore.Equipment> = [.bodyweight]
    var emphasis: Set<Muscle> = []
    var savedDaysOutsideBuilder: Int?

    mutating func apply(_ snapshot: PreferencesSnapshot) {
        if case .string(let raw) = snapshot.value("experienceLevel"),
           let value = ProgramGeneration.Experience(rawValue: raw) { experience = value }
        if case .number(let value) = snapshot.value("workoutDaysPerWeek"),
           value.isFinite, (0...7).contains(value), value.rounded() == value {
            let count = Int(value)
            days = (2...6).contains(count) ? count : nil
            savedDaysOutsideBuilder = days == nil ? count : nil
        }
        fullGym = snapshot.value("equipmentAccess") == .string("full_gym")
        if case .array(let values) = snapshot.value("equipment") {
            equipment = Set(values.compactMap { value in
                guard case .string(let raw) = value else { return nil }
                return Self.profileEquipment(raw)
            }).union([.bodyweight])
        }
    }

    mutating func apply(_ gym: GymProfile) {
        fullGym = Set(gym.equipment) == Set(ExerlyCore.Equipment.allCases)
        equipment = Set(gym.equipment).union([.bodyweight])
    }

    var request: ProgramGeneration.Request {
        .init(daysPerWeek: days ?? 0, goal: goal, experience: experience,
              emphasis: Muscle.allCases.filter(emphasis.contains), minutes: minutes)
    }

    func gym(unit: MassUnit, active: GymProfile?) -> GymProfile {
        var profile = active ?? GymProfile(name: "Available equipment",
                                          bars: [unit == .pounds ? .lb(45) : .kg(20)],
                                          plates: unit == .pounds ? PlateStock.standardPounds : PlateStock.standardKilograms)
        profile.equipment = fullGym ? ExerlyCore.Equipment.allCases : ExerlyCore.Equipment.allCases.filter(equipment.contains)
        return profile
    }

    static func profileEquipment(_ raw: String) -> ExerlyCore.Equipment? {
        switch raw {
        case "dumbbells": .dumbbell
        case "pull_up_bar": .pullUpBar
        case "resistance_bands": .resistanceBand
        case "bench": .flatBench
        case "cables": .cable
        default: ExerlyCore.Equipment(rawValue: raw)
        }
    }
}

struct TrainingPlanCandidate {
    let proposal: Proposal
    let program: Program
    let answers: TrainingPlanAnswers
    let equipmentSummary: String
}

@MainActor
final class TrainingPlanSetupModel: ObservableObject {
    @Published var answers = TrainingPlanAnswers() {
        didSet { if !applyingSavedAnswers { edited = true }; candidate = nil; error = nil }
    }
    @Published private(set) var candidate: TrainingPlanCandidate?
    @Published private(set) var error: String?
    @Published private(set) var preferenceMessage = "Choose a starting point. Your existing programs stay saved."
    @Published private(set) var loadingPreferences = false
    private var applyingSavedAnswers = false
    private var edited = false
    private var loaded = false
    private var filedID: UUID?
    private let workspace: TrainingWorkspace
    private let unit: MassUnit
    private let ownerIsActive: () -> Bool

    init(workspace: TrainingWorkspace, unit: MassUnit, ownerIsActive: @escaping () -> Bool = { true }) {
        self.workspace = workspace
        self.unit = unit
        self.ownerIsActive = ownerIsActive
        // A local gym remains available even when the first preferences
        // request cannot connect. It must not fall back to bodyweight only.
        if let gym = workspace.gyms.active {
            applyingSavedAnswers = true
            answers.apply(gym)
            applyingSavedAnswers = false
        }
    }

    func loadPreferences(_ preferences: PreferencesStore) async {
        guard !loaded, preferences.accountID == workspace.accountID, ownerIsActive() else { return }
        loaded = true
        loadingPreferences = true
        defer { loadingPreferences = false }
        let cached = preferences.accepted ?? preferences.draft?.base
        if let cached { seed(cached) }
        do { seed(try await preferences.savedSnapshot()) } catch {
            guard ownerIsActive(), !Task.isCancelled else { return }
            if cached == nil { preferenceMessage = "Saved setup couldn't load. You can choose your answers here, including offline." }
        }
    }

    private func seed(_ snapshot: PreferencesSnapshot) {
        guard ownerIsActive(), !Task.isCancelled, !edited, candidate == nil,
              snapshot.accountID == workspace.accountID else { return }
        applyingSavedAnswers = true
        answers.apply(snapshot)
        if let active = workspace.gyms.active {
            answers.apply(active)
            preferenceMessage = "Your saved setup and \(active.name) are filled in. Adjust anything for this plan."
        } else { preferenceMessage = "Your saved setup is filled in. Adjust anything for this plan." }
        applyingSavedAnswers = false
    }

    func prepare() {
        guard ownerIsActive(), filedID == nil else { return }
        do {
            let gym = answers.gym(unit: unit, active: workspace.gyms.active)
            let proposal = try ProgramGeneration.proposal(for: answers.request, library: workspace.store.library, gym: gym)
            guard let change = proposal.changes.first(where: { $0.kind == "program" }),
                  let program = try change.after?.decode(Program.self) else {
                error = "The plan couldn't be prepared. Your answers are still here."
                return
            }
            candidate = TrainingPlanCandidate(proposal: proposal, program: program, answers: answers,
                                              equipmentSummary: answers.fullGym ? "Full gym" :
                                                answers.equipment.map(TrainingPlanFormat.equipment).sorted().joined(separator: ", "))
            error = nil
        } catch ProgramStore.StoreError.invalid(let problems) { error = problems.joined(separator: ". ") } catch { self.error = "The plan couldn't be prepared. Your answers are still here. Try again." }
    }

    func revise() {
        guard filedID == nil else { return }
        candidate = nil
        error = nil
    }

    func accept() {
        guard ownerIsActive(), let candidate, !accepted else { return }
        do {
            if filedID == nil {
                try workspace.agent.file(candidate.proposal)
                filedID = candidate.proposal.id
            }
            let id = candidate.proposal.id
            if workspace.agent.proposal(id)?.status == .pending { try workspace.agent.accept(id) }
            guard workspace.agent.proposal(id)?.status == .accepted else {
                error = "This suggestion changed. Open Suggestions in Training to review its current status."
                return
            }
            error = nil
        } catch {
            self.error = "The plan couldn't be saved. Your preview is kept. Try again; it will not create a second plan."
        }
    }

    var canRevise: Bool { filedID == nil }
    var decisionStatus: ProposalStatus? { candidate.flatMap { workspace.agent.proposal($0.proposal.id)?.status } }
    var accepted: Bool { decisionStatus == .accepted }
    var canSave: Bool { decisionStatus == nil || decisionStatus == .pending }
}

enum TrainingPlanFormat {
    static func goal(_ goal: ProgramGeneration.Goal) -> String {
        switch goal {
        case .hypertrophy: "Build muscle"
        case .strength: "Get stronger"
        case .general: "Build a balanced routine"
        }
    }
    static func experience(_ value: ProgramGeneration.Experience) -> String {
        switch value {
        case .beginner: "New or starting again"
        case .intermediate: "Training regularly"
        case .advanced: "Experienced with structured plans"
        }
    }
    static func equipment(_ value: ExerlyCore.Equipment) -> String {
        switch value {
        case .bodyweight: "Bodyweight"
        case .dumbbell: "Dumbbells"
        case .cable: "Cables"
        case .resistanceBand: "Resistance bands"
        case .ezBar: "EZ bar"
        default: TrainingFormat.words(value.rawValue)
        }
    }
}
