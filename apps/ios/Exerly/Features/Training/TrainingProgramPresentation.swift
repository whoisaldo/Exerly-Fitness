import Combine
import ExerlyCore
import Foundation

/// Edits a value draft; Core validates the complete program before it is saved.
@MainActor
final class TrainingProgramDraft: ObservableObject {
    @Published var program: Program
    @Published var cycles: String
    @Published private(set) var errors: [String] = []
    private let store: ProgramStore
    private var saved: Program?
    private var initial: Program
    private var initialCycles: String

    init(store: ProgramStore, editing: Program? = nil) {
        self.store = store
        saved = editing
        let draft = editing ?? Program(name: "", days: [], cycles: 4)
        program = draft
        initial = draft
        cycles = String(draft.cycles)
        initialCycles = String(draft.cycles)
    }

    var hasChanges: Bool { program != initial || cycles != initialCycles }

    @discardableResult
    func save() -> Bool {
        errors = []
        guard let count = TrainingInput.reps(cycles) else {
            errors = ["Enter a whole number for cycles."]
            return false
        }
        guard store.program(program.id) == saved else {
            errors = ["This program changed while you were editing. Your draft is still here. Reopen the program to review the latest version."]
            return false
        }
        var value = program
        value.cycles = count
        do {
            try store.save(value)
            program = value
            saved = value
            initial = value
            initialCycles = cycles
            return true
        } catch ProgramStore.StoreError.invalid(let messages) {
            errors = messages.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        } catch {
            errors = ["The program could not be saved. Your draft is still here. Try again."]
        }
        return false
    }
}

/// Text-field syntax and unchanged-value preservation, without target arithmetic.
struct ProgramTargetFields {
    var sets: String
    var minReps: String
    var maxReps: String
    var rir: String
    var rest: String
    var kind: SetKind
    private let original: SlotTarget
    private let initialRIR: String
    private let initialRest: String

    enum InputError: LocalizedError {
        case invalid
        var errorDescription: String? { "Enter whole numbers for sets and reps, and numbers for RIR and rest. Leave rest empty to use your usual timer." }
    }

    init(_ target: SlotTarget) {
        original = target
        sets = String(target.sets)
        minReps = String(target.minReps)
        maxReps = String(target.maxReps)
        rir = TrainingFormat.number(target.rir)
        rest = target.rest.map(TrainingFormat.number) ?? ""
        kind = target.kind
        initialRIR = rir
        initialRest = rest
    }

    func value(locale: Locale = .current) throws -> SlotTarget {
        guard let sets = TrainingInput.reps(sets), let minimum = TrainingInput.reps(minReps),
              let maximum = TrainingInput.reps(maxReps),
              let reserve = rir == initialRIR ? original.rir : TrainingInput.number(rir, locale: locale) else {
            throw InputError.invalid
        }
        let seconds: Double?
        if rest == initialRest {
            seconds = original.rest
        } else if rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            seconds = nil
        } else if let parsed = TrainingInput.number(rest, locale: locale) {
            seconds = parsed
        } else { throw InputError.invalid }
        return SlotTarget(sets: sets, minReps: minimum, maxReps: maximum, rir: reserve, rest: seconds, kind: kind)
    }
}

enum TrainingProgramFormat {
    static func deload(_ placement: DeloadPlacement) -> String {
        switch placement {
        case .none: "No deload cycle"
        case .first: "First cycle"
        case .last: "Last cycle"
        }
    }

    static func target(_ target: SlotTarget, exercise: ExerlyCore.Exercise?) -> String {
        var parts = [target.sets == 1 ? "1 set" : "\(target.sets) sets"]
        if exercise?.metric.tracksReps == true {
            parts.append(target.minReps == target.maxReps ? "\(target.minReps) reps" : "\(target.minReps)–\(target.maxReps) reps")
            parts.append("\(TrainingFormat.number(target.rir)) RIR")
        }
        return parts.joined(separator: " · ")
    }

    static func reason(_ recommendation: Recommendation, exercise: ExerlyCore.Exercise, target: SlotTarget) -> String {
        switch recommendation.reason {
        case .firstSession:
            if !exercise.metric.tracksReps { return "Enter the required values while logging. Later workouts can repeat your last entry." }
            if exercise.metric == .weightReps { return "Choose a load that leaves \(TrainingFormat.number(target.rir)) reps in reserve." }
            return "Choose your reps and any added load while logging."
        case .progress: return "Your recent performance supports progressing to these targets."
        case .hold: return "Keep the current level with these targets."
        case .reduce: return "Recent performance supports a lighter target."
        case .repeatLast: return "Repeat the last logged values for this exercise."
        }
    }
}
