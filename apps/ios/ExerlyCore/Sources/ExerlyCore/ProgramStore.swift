import Foundation
import Observation

/// The person's programs. They sync as documents of kind `program`, and agents
/// can propose new or changed programs through `AgentStore`.
@MainActor
@Observable
public final class ProgramStore {
    public enum StoreError: Error, Equatable {
        case invalid([String])
        case notFound
    }

    /// Newest first.
    public private(set) var programs: [Program] = []

    static let kind = "program"

    @ObservationIgnored private let persistence: TrainingPersistence & DocumentPersistence
    @ObservationIgnored private let training: TrainingStore
    @ObservationIgnored private let now: () -> Date

    /// `training` supplies the exercise library programs are checked against
    /// and the history their schedule follows.
    public init(persistence: TrainingPersistence & DocumentPersistence, training: TrainingStore,
                now: @escaping () -> Date = Date.init) throws {
        self.persistence = persistence
        self.training = training
        self.now = { now().roundedToMilliseconds }
        programs = try persistence.loadDocuments(kind: Self.kind)
            .map { try ExerlyJSON.decoder.decode(Program.self, from: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func program(_ id: UUID) -> Program? { programs.first { $0.id == id } }

    /// The program the person is following: the most recently activated one
    /// that isn't archived.
    public var active: Program? {
        programs.filter { $0.activatedAt != nil && $0.archivedAt == nil }.max { $0.activatedAt! < $1.activatedAt! }
    }

    /// Adds or replaces a program after checking it.
    public func save(_ program: Program) throws {
        let errors = program.validationErrors(library: training.library)
        guard errors.isEmpty else { throw StoreError.invalid(errors) }
        try write(program)
    }

    /// Makes a program the one being followed. Its history is kept.
    public func activate(_ id: UUID) throws {
        guard var program = program(id) else { throw StoreError.notFound }
        program.activatedAt = now()
        program.archivedAt = nil
        try write(program)
    }

    public func archive(_ id: UUID) throws {
        guard var program = program(id) else { throw StoreError.notFound }
        program.archivedAt = now()
        try write(program)
    }

    public func restore(_ id: UUID) throws {
        guard var program = program(id) else { throw StoreError.notFound }
        program.archivedAt = nil
        try write(program)
    }

    /// A copy with new IDs throughout, not yet activated.
    @discardableResult
    public func duplicate(_ id: UUID, name: String) throws -> Program {
        guard let original = program(id) else { throw StoreError.notFound }
        var copy = Program(name: name, icon: original.icon, color: original.color, days: [], cycles: original.cycles,
                           deload: original.deload, createdAt: now())
        let groups = Set(original.days.flatMap { $0.slots.compactMap(\.supersetID) })
        let supersets = Dictionary(uniqueKeysWithValues: groups.map { ($0, UUID()) })
        copy.days = original.days.map { day in
            ProgramDay(name: day.name, slots: day.slots.map { slot in
                var fresh = slot
                fresh.id = UUID()
                fresh.supersetID = slot.supersetID.flatMap { supersets[$0] }
                return fresh
            })
        }
        try save(copy)
        return copy
    }

    // MARK: Following a program

    /// The next workout of the active program, planned from the person's history.
    public func nextWorkout(bodyweight: Mass?, increments: (Exercise) -> LoadIncrements = LoadIncrements.defaults(for:))
        -> WorkoutPlan? {
        guard let program = active, let position = ProgramSchedule.next(for: program, in: training.history) else { return nil }
        return ProgramSchedule.plan(program, at: position, history: training.history, bodyweight: bodyweight,
                                    increments: increments)
    }

    private func write(_ program: Program) throws {
        let publish = try prepareWrite(kind: Self.kind, id: program.id.uuidString, payload: ExerlyJSON.canonical(program))
        publish()
    }
}

extension ProgramStore: DocumentHost {
    public var documentKinds: [String] { [Self.kind] }

    public func documentIDs(kind: String) -> [String] { programs.map(\.id.uuidString) }

    public func payload(kind: String, id: String) throws -> Data? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try program(uuid).map(ExerlyJSON.canonical)
    }

    public func canonicalize(kind: String, payload: Data) throws -> Data {
        guard kind == Self.kind else { throw DocumentError(message: "Unknown kind \(kind)") }
        return try ExerlyJSON.canonical(ExerlyJSON.decoder.decode(Program.self, from: payload))
    }

    public func validate(kind: String, id: String, payload: Data) throws {
        guard kind == Self.kind else { throw DocumentError(message: "Unknown kind \(kind)") }
        let program = try ExerlyJSON.decoder.decode(Program.self, from: payload)
        guard program.id.uuidString == id else { throw DocumentError(message: "The program ID doesn't match") }
        let errors = program.validationErrors(library: training.library)
        guard errors.isEmpty else { throw DocumentError(message: errors.joined(separator: "; ")) }
    }

    /// Programs merge as whole values: whichever side changed wins, local when both did.
    public func merge(kind: String, base: Data?, local: Data, remote: Data) throws -> Data {
        let decoder = ExerlyJSON.decoder
        return try ExerlyJSON.canonical(Merge.value(try base.map { try decoder.decode(Program.self, from: $0) },
                                                    try decoder.decode(Program.self, from: local),
                                                    try decoder.decode(Program.self, from: remote)))
    }

    public func prepareWrite(kind: String, id: String, payload: Data?) throws -> () -> Void {
        guard kind == Self.kind, let uuid = UUID(uuidString: id) else { throw DocumentError(message: "Invalid program") }
        guard let payload else {
            try persistence.deleteDocument(kind: kind, id: id)
            return { [self] in programs.removeAll { $0.id == uuid } }
        }
        let program = try ExerlyJSON.decoder.decode(Program.self, from: payload)
        try persistence.saveDocument(kind: kind, id: id, payload: ExerlyJSON.canonical(program))
        return { [self] in
            programs = ([program] + programs.filter { $0.id != uuid }).sorted { $0.createdAt > $1.createdAt }
        }
    }
}
