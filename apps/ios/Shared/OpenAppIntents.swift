import AppIntents
import Foundation

/// Opens a screen of the app. The intents below are compiled into the app and
/// the widget extension, so a control can show them while the system runs them
/// in the app's process, after bringing the app to the front. The app installs
/// this at launch and follows the link as if it had been opened. (A control
/// can't open a custom-scheme URL itself, and Xcode 26.2 records only the
/// plain `.foreground` mode in the intents' metadata, which is what opens the app.)
enum ExerlyLinkHandler {
    @MainActor static var open: ((URL) -> Void)?
}

/// Food search, ready to type.
struct SearchFoodsIntent: AppIntent {
    static let title: LocalizedStringResource = "Search foods"
    static let description = IntentDescription("Opens Exerly on food search.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        ExerlyLinkHandler.open?(ExerlyLinks.search)
        return .result()
    }
}

/// The barcode scanner, logging to today.
struct ScanBarcodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan a barcode"
    static let description = IntentDescription("Opens the barcode scanner to log a packaged food.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        ExerlyLinkHandler.open?(ExerlyLinks.scan)
        return .result()
    }
}

/// A new weigh-in, on the last reading.
struct WeighInIntent: AppIntent {
    static let title: LocalizedStringResource = "Weigh in"
    static let description = IntentDescription("Opens a new weigh-in, starting from your last reading.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        ExerlyLinkHandler.open?(ExerlyLinks.weighIn)
        return .result()
    }
}

/// Today's workout on Train, started; the one in progress if there is one.
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start workout"
    static let description = IntentDescription("Starts your program's next workout, or returns to the one in progress.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        ExerlyLinkHandler.open?(ExerlyLinks.startWorkout)
        return .result()
    }
}
