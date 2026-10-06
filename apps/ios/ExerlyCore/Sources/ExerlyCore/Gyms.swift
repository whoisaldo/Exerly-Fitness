import Foundation
import Observation

/// A place the person trains, and what it has. See docs/design/016-gym-profiles.md.
public struct GymProfile: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    /// The equipment the gym has. Bodyweight exercises need none.
    public var equipment: [Equipment]
    /// Barbell weights, the usual one first.
    public var bars: [Mass]
    public var plates: [PlateStock]
    /// The weights some equipment comes in, such as dumbbells or a machine's
    /// stack. Equipment without a list uses its usual steps.
    public var loads: [Equipment: [Mass]]
    /// Exercises the person can't or won't do here.
    public var excluded: [ExerciseID]
    public var createdAt: Date
    public var activatedAt: Date?
    public var archivedAt: Date?

    /// A full gym with standard kilogram plates and a 20 kg bar, until edited.
    public init(id: UUID = UUID(), name: String, equipment: [Equipment] = Equipment.allCases, bars: [Mass] = [.kg(20)],
                plates: [PlateStock] = PlateStock.standardKilograms, loads: [Equipment: [Mass]] = [:],
                excluded: [ExerciseID] = [], createdAt: Date = Date().roundedToMilliseconds) {
        self.id = id
        self.name = name
        self.equipment = equipment
        self.bars = bars
        self.plates = plates
        self.loads = loads
        self.excluded = excluded
        self.createdAt = createdAt
    }

    /// True when the exercise isn't excluded and the gym has all of its
    /// resistance and support equipment.
    public func allows(_ exercise: Exercise) -> Bool {
        let available = Set(equipment).union([.bodyweight])
        return !excluded.contains(exercise.id) && Set(exercise.equipment + exercise.support).isSubset(of: available)
    }

    /// Load steps for an exercise here: the usual ones for its equipment, the
    /// gym's own weights when it lists them, and for a barbell, twice the
    /// smallest plate, with the usual bar as the minimum.
    public func increments(for exercise: Exercise) -> LoadIncrements {
        var increments = LoadIncrements.defaults(for: exercise)
        if let listed = exercise.equipment.lazy.compactMap({ self.loads[$0] }).first(where: { !$0.isEmpty }) {
            increments.available = listed
        }
        if exercise.equipment.contains(.barbell) {
            if let bar = bars.first { increments.minimum = bar }
            if let smallest = plates.filter({ $0.pairs > 0 }).min(by: { $0.weight.kilograms < $1.weight.kilograms })?.weight {
                increments.kilograms = 2 * smallest.value(in: .kilograms)
                increments.pounds = 2 * smallest.value(in: .pounds)
            }
        }
        return increments
    }

    public var problems: [String] {
        var problems: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 60 {
            problems.append("The gym needs a name up to 60 characters")
        }
        if bars.contains(where: { !($0.kilograms.isFinite && $0.kilograms > 0 && $0.kilograms <= 60) }) {
            problems.append("A bar must weigh more than 0 and up to 60 kg")
        }
        if plates.contains(where: { !($0.weight.kilograms.isFinite && $0.weight.kilograms > 0 && $0.weight.kilograms <= 50) || !(0...50).contains($0.pairs) }) {
            problems.append("Plates must weigh more than 0 and up to 50 kg, with 0 to 50 pairs")
        }
        for (equipment, weights) in loads.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        where weights.count > 200 || weights.contains(where: { !($0.kilograms.isFinite && $0.kilograms > 0 && $0.kilograms <= 500) }) {
            problems.append("\(equipment.rawValue) weights must be more than 0 and up to 500 kg, at most 200 of them")
        }
        return problems
    }
}

/// The person's gyms. They sync as documents of kind `gym_profile`.
@MainActor
@Observable
public final class GymStore {
    public enum StoreError: Error, Equatable {
        case invalid([String])
        case notFound
    }

    /// By name.
    public private(set) var gyms: [GymProfile] = []

    static let kind = "gym_profile"

    @ObservationIgnored private let persistence: DocumentPersistence
    @ObservationIgnored private let now: () -> Date

    public init(persistence: DocumentPersistence, now: @escaping () -> Date = Date.init) throws {
        self.persistence = persistence
        self.now = { now().roundedToMilliseconds }
        gyms = try persistence.loadDocuments(kind: Self.kind).map { try ExerlyJSON.decoder.decode(GymProfile.self, from: $0) }
            .sorted(by: Self.order)
    }

    static func order(_ a: GymProfile, _ b: GymProfile) -> Bool {
        (a.name.lowercased(), a.id.uuidString) < (b.name.lowercased(), b.id.uuidString)
    }

    public func gym(_ id: UUID) -> GymProfile? { gyms.first { $0.id == id } }

    /// The gym being used: the most recently chosen one that isn't archived.
    public var active: GymProfile? {
        gyms.filter { $0.activatedAt != nil && $0.archivedAt == nil }.max { $0.activatedAt! < $1.activatedAt! }
    }

    /// Load steps for an exercise at the active gym; the usual ones without one.
    public func increments(for exercise: Exercise) -> LoadIncrements {
        active?.increments(for: exercise) ?? .defaults(for: exercise)
    }

    /// Adds or replaces a gym after checking it.
    public func save(_ gym: GymProfile) throws {
        guard gym.problems.isEmpty else { throw StoreError.invalid(gym.problems) }
        try write(gym)
    }

    /// Makes a gym the one being used.
    public func activate(_ id: UUID) throws {
        guard var gym = gym(id) else { throw StoreError.notFound }
        gym.activatedAt = now()
        gym.archivedAt = nil
        try write(gym)
    }

    public func archive(_ id: UUID) throws {
        guard var gym = gym(id) else { throw StoreError.notFound }
        gym.archivedAt = now()
        try write(gym)
    }

    private func write(_ gym: GymProfile) throws {
        try prepareWrite(kind: Self.kind, id: gym.id.uuidString, payload: ExerlyJSON.canonical(gym))()
    }
}

extension GymStore: DocumentHost {
    public var documentKinds: [String] { [Self.kind] }

    public func documentIDs(kind: String) -> [String] { gyms.map(\.id.uuidString) }

    public func payload(kind: String, id: String) throws -> Data? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try gym(uuid).map(ExerlyJSON.canonical)
    }

    public func canonicalize(kind: String, payload: Data) throws -> Data {
        guard kind == Self.kind else { throw DocumentError(message: "Unknown kind \(kind)") }
        return try ExerlyJSON.canonical(ExerlyJSON.decoder.decode(GymProfile.self, from: payload))
    }

    public func validate(kind: String, id: String, payload: Data) throws {
        guard kind == Self.kind else { throw DocumentError(message: "Unknown kind \(kind)") }
        let gym = try ExerlyJSON.decoder.decode(GymProfile.self, from: payload)
        let problems = (gym.id.uuidString == id ? [] : ["the ID doesn't match"]) + gym.problems
        guard problems.isEmpty else { throw DocumentError(message: problems.joined(separator: "; ")) }
    }

    /// Gyms merge as whole values: whichever side changed wins, local when both did.
    public func merge(kind: String, base: Data?, local: Data, remote: Data) throws -> Data {
        let decoder = ExerlyJSON.decoder
        return try ExerlyJSON.canonical(Merge.value(try base.map { try decoder.decode(GymProfile.self, from: $0) },
                                                    try decoder.decode(GymProfile.self, from: local),
                                                    try decoder.decode(GymProfile.self, from: remote)))
    }

    public func prepareWrite(kind: String, id: String, payload: Data?) throws -> () -> Void {
        guard kind == Self.kind, let uuid = UUID(uuidString: id) else { throw DocumentError(message: "Invalid gym") }
        guard let payload else {
            try persistence.deleteDocument(kind: kind, id: id)
            return { [self] in gyms.removeAll { $0.id == uuid } }
        }
        let gym = try ExerlyJSON.decoder.decode(GymProfile.self, from: payload)
        try persistence.saveDocument(kind: kind, id: id, payload: ExerlyJSON.canonical(gym))
        return { [self] in gyms = (gyms.filter { $0.id != uuid } + [gym]).sorted(by: Self.order) }
    }
}
