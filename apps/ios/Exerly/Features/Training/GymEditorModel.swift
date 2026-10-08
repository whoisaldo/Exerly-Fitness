import Combine
import ExerlyCore
import Foundation

enum GymWeightDestination: Hashable, Identifiable {
    case bars, plates, loads(ExerlyCore.Equipment)
    var id: String {
        switch self {
        case .bars: "bars"
        case .plates: "plates"
        case .loads(let equipment): equipment.rawValue
        }
    }
    var title: String {
        switch self {
        case .bars: "Barbells"
        case .plates: "Weight plates"
        case .loads(let equipment): "\(TrainingFormat.words(equipment.rawValue)) weights"
        }
    }
}

/// An unsaved presentation draft. Core validates and stores the profile.
@MainActor
final class GymEditorModel: ObservableObject {
    @Published var draft: GymProfile
    @Published private(set) var error: String?
    private var original: GymProfile?
    private let store: GymStore
    private let ownerIsActive: () -> Bool

    init(store: GymStore, unit: MassUnit, gym: GymProfile? = nil, ownerIsActive: @escaping () -> Bool = { true }) {
        self.store = store
        self.original = gym
        self.ownerIsActive = ownerIsActive
        draft = gym ?? GymProfile(name: "", equipment: [.bodyweight],
                                 bars: [unit == .pounds ? .lb(45) : .kg(20)], plates: [])
    }

    func addWeight(_ text: String, unit: MassUnit, to destination: GymWeightDestination, pairs: Int = 1) -> Bool {
        guard let value = TrainingInput.number(text), value > 0 else {
            error = "Enter a weight greater than zero."
            return false
        }
        let weight = Mass(value, unit)
        var candidate = draft
        switch destination {
        case .bars:
            guard !candidate.bars.contains(weight) else { return duplicate() }
            candidate.bars.append(weight)
        case .plates:
            guard !candidate.plates.contains(where: { $0.weight == weight }) else { return duplicate() }
            candidate.plates.append(PlateStock(weight, pairs: pairs))
        case .loads(let equipment):
            guard !(candidate.loads[equipment] ?? []).contains(weight) else { return duplicate() }
            candidate.loads[equipment, default: []].append(weight)
        }
        // The name is edited independently. Validate the proposed inventory
        // with a valid temporary name without changing the actual draft.
        var inventory = candidate
        inventory.name = "Inventory"
        guard inventory.problems.isEmpty else {
            error = inventory.problems.joined(separator: ". ")
            return false
        }
        draft = candidate
        error = nil
        return true
    }

    func clearError() { error = nil }

    @discardableResult
    func save() -> Bool {
        guard ownerIsActive() else { error = "Sign in again before saving this gym."; return false }
        guard store.gym(draft.id) == original else {
            error = "This gym changed while you were editing. Close and reopen it to see the saved version. Your edits are still shown here."
            return false
        }
        var candidate = draft
        candidate.name = candidate.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.problems.isEmpty else {
            error = candidate.problems.joined(separator: ". ")
            return false
        }
        do {
            try store.save(candidate)
            draft = candidate
            original = candidate
            error = nil
            return true
        } catch {
            self.error = "This gym could not be saved. Your changes are still here. Try again."
            return false
        }
    }

    private func duplicate() -> Bool {
        error = "That weight is already listed."
        return false
    }
}
