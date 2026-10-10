import SwiftUI
import WatchKit

@main
struct ExerlyWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: ExerlyWatchDelegate

    init() { PhoneLink.shared.activate() }

    var body: some Scene {
        WindowGroup { WorkoutScreen() }
    }
}

final class ExerlyWatchDelegate: NSObject, WKApplicationDelegate {
    /// The system relaunches the app to hand back a workout session it kept running.
    func handleActiveWorkoutRecovery() {
        Task { await WorkoutRecorder.shared.recover() }
    }
}
