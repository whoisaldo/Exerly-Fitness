import Foundation

// What the watch app shows and what it asks the phone to do. The phone's store
// is the source of truth: it publishes a `WatchState` as WatchConnectivity's
// application context whenever the workout changes, and applies each
// `WatchCommand` with the calls its screens use. The watch never opens the
// database; it draws the phone's state with its own unhandled commands applied.

/// Both types travel as JSON under a version, so a payload from an older or
/// newer build is ignored instead of misread.
enum WatchLink {
    static let version = 1

    static func payload(_ state: WatchState) -> [String: Any] { encode(state, as: "state") }
    static func payload(_ command: WatchCommand) -> [String: Any] { encode(command, as: "command") }
    static func state(from payload: [String: Any]) -> WatchState? { decode(payload, "state") }
    static func command(from payload: [String: Any]) -> WatchCommand? { decode(payload, "command") }

    private static func encode<T: Encodable>(_ value: T, as key: String) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(value) else { return [:] }
        return ["v": version, key: data]
    }

    private static func decode<T: Decodable>(_ payload: [String: Any], _ key: String) -> T? {
        guard payload["v"] as? Int == version, let data = payload[key] as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

struct WatchState: Codable, Equatable, Sendable {
    /// Rises with every state the phone publishes, so one that arrives late is ignored.
    var revision: Int64 = 0
    var signedIn: Bool
    /// The program's next workout, while none is in progress.
    var planned: Planned?
    var active: Active?
    /// The workout saved last, so the watch keeps its recording of it and
    /// discards one the phone deleted.
    var finished: UUID?
    /// The person's switch for writing workouts to Health.
    var savesToHealth = false
    /// The last watch command the phone handled. Commands reach it in order,
    /// so this state reflects every command up to this one.
    var handled: UUID?

    struct Planned: Codable, Equatable, Sendable {
        var title: String
        var program: String?
        var exercises: Int
        var sets: Int
    }

    struct Active: Codable, Equatable, Sendable {
        var id: UUID
        var title: String
        var startedAt: Date
        var completedSets: Int
        var totalSets: Int
        /// "kg" or "lb", the unit of every weight here.
        var unit: String
        var rest: Rest?
        /// Sets still to do in the order they're done, the next one first.
        var upcoming: [WatchSet]
        /// The weights each exercise's equipment allows, for the Digital
        /// Crown, by exercise ID. Only weight × reps exercises have them.
        var loads: [String: [Double]]
    }

    struct Rest: Codable, Equatable, Sendable {
        var startedAt: Date
        var endsAt: Date
    }
}

/// One set still to do, with its values in the person's unit.
struct WatchSet: Codable, Equatable, Sendable {
    var id: UUID
    /// The exercise in this workout it belongs to.
    var exerciseID: UUID
    var exercise: String
    /// Its position in its exercise, from 1, and how many sets the exercise has.
    var number: Int
    var count: Int
    /// The weight of a weight × reps set, nil until it's filled in.
    var weight: Double?
    /// Nil for an exercise that doesn't count reps; 0 when they aren't filled in.
    var reps: Int?
    /// Its values as written and as spoken: "160 lb × 7", "BW × 9", "45 s".
    var values: String
    var spokenValues: String
    var isLoggable: Bool
    /// Seconds of rest after it.
    var rest: Double
}

struct WatchCommand: Codable, Equatable, Sendable, Identifiable {
    enum Action: Codable, Equatable, Sendable {
        /// Starts the program's next workout.
        case start
        /// Logs a set, with the weight or reps changed on the watch, if any.
        case completeSet(UUID, weight: Double?, reps: Int?, unit: String)
        case extendRest(seconds: Double)
        case skipRest
        /// Saves the workout, or discards it when no set was done.
        case finish
        /// The watch is recording the workout in Health, so the phone doesn't too.
        case recording
    }

    var id = UUID()
    /// The workout it was made for, nil to start one. A command for another
    /// workout does nothing.
    var workoutID: UUID?
    var action: Action
}

extension WatchState {
    /// The state after the watch's unhandled commands, done the way the phone
    /// will do them, so a tap shows at once even with the phone out of reach.
    func predicting(_ commands: [WatchCommand], at now: Date) -> WatchState {
        commands.reduce(self) { $0.applying($1, at: now) }
    }

    func applying(_ command: WatchCommand, at now: Date) -> WatchState {
        guard var active, active.id == command.workoutID else { return self }
        var state = self
        switch command.action {
        case .start, .recording:
            return self
        case .completeSet(let id, let weight, let reps, _):
            guard let index = active.upcoming.firstIndex(where: { $0.id == id }) else { return self }
            let done = active.upcoming.remove(at: index)
            // Later sets of the exercise still holding the old values follow, as on the phone.
            let later = active.upcoming.indices
                .filter { active.upcoming[$0].exerciseID == done.exerciseID && active.upcoming[$0].number > done.number }
                .sorted { active.upcoming[$0].number < active.upcoming[$1].number }
            if let weight, weight != done.weight {
                for i in later {
                    guard active.upcoming[i].weight == done.weight else { break }
                    active.upcoming[i].weight = weight
                }
            }
            if let reps, reps != done.reps {
                for i in later {
                    guard active.upcoming[i].reps == done.reps else { break }
                    active.upcoming[i].reps = reps
                }
            }
            active.completedSets += 1
            active.rest = done.rest > 0 ? Rest(startedAt: now, endsAt: now.addingTimeInterval(done.rest)) : nil
        case .extendRest(let seconds):
            guard let rest = active.rest, rest.endsAt > now else { return self }
            active.rest?.endsAt = rest.endsAt.addingTimeInterval(seconds)
        case .skipRest:
            active.rest = nil
        case .finish:
            state.active = nil
            if active.completedSets > 0 { state.finished = active.id }
            return state
        }
        state.active = active
        return state
    }
}
