import AppIntents
import Foundation

/// What a button on the workout's Live Activity asks for.
enum WorkoutActivityCommand: Equatable, Sendable {
    case completeSet(UUID)
    case extendRest(seconds: Double)
    case skipRest
}

/// The system runs a `LiveActivityIntent` in the app's process, launching it
/// in the background if needed. The app installs this at launch and applies
/// the command to the workout; the widget extension only builds the buttons.
enum WorkoutActivityIntentHandler {
    @MainActor static var perform: ((_ workoutID: UUID, _ command: WorkoutActivityCommand) async -> Void)?
}

/// Logs the next set with the values already filled in for it.
struct CompleteWorkoutSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete set"
    static let description = IntentDescription("Logs the next set of the workout in progress with its filled-in values.")
    static let isDiscoverable = false

    @Parameter(title: "Workout") var workoutID: String
    @Parameter(title: "Set") var setID: String

    init() {}

    init(workoutID: UUID, setID: UUID) {
        self.workoutID = workoutID.uuidString
        self.setID = setID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let workout = UUID(uuidString: workoutID), let set = UUID(uuidString: setID) {
            await WorkoutActivityIntentHandler.perform?(workout, .completeSet(set))
        }
        return .result()
    }
}

/// Adds 30 seconds to the rest between sets.
struct ExtendWorkoutRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add 30 seconds of rest"
    static let description = IntentDescription("Adds 30 seconds to the rest in the workout in progress.")
    static let isDiscoverable = false
    static let seconds: Double = 30

    @Parameter(title: "Workout") var workoutID: String

    init() {}

    init(workoutID: UUID) { self.workoutID = workoutID.uuidString }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let workout = UUID(uuidString: workoutID) {
            await WorkoutActivityIntentHandler.perform?(workout, .extendRest(seconds: Self.seconds))
        }
        return .result()
    }
}

/// Ends the rest between sets now.
struct SkipWorkoutRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip rest"
    static let description = IntentDescription("Ends the rest in the workout in progress.")
    static let isDiscoverable = false

    @Parameter(title: "Workout") var workoutID: String

    init() {}

    init(workoutID: UUID) { self.workoutID = workoutID.uuidString }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let workout = UUID(uuidString: workoutID) {
            await WorkoutActivityIntentHandler.perform?(workout, .skipRest)
        }
        return .result()
    }
}
