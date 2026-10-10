import XCTest

/// The phone's half of the watch's UI test, run beside it by
/// `apps/ios/scripts/watch-uitest.sh`: signs into a fixture account whose
/// program plans Pull (deadlift, 3 sets), opens Train, and stays open while
/// ExerlyWatchUITests drives the paired watch. Passes when the set logged on
/// the watch shows as done in the phone's workout, and the watch then
/// finishes it.
final class WatchCompanionUITests: ExerlyUITestCase {
    func testTheWatchStartsLogsAndFinishesThePhonesWorkout() async throws {
        guard ProcessInfo.processInfo.environment["EXERLY_WATCH_COMPANION"] == "1" else {
            throw XCTSkip("Runs beside the watch's UI test: apps/ios/scripts/watch-uitest.sh")
        }
        let app = try await signedInWithWeek(prefix: "watch")
        tap(app.tabBars.buttons["Train"], in: app)
        // Signed in: the watch's half can start now.
        if let ready = ProcessInfo.processInfo.environment["EXERLY_WATCH_READY"], !ready.isEmpty {
            FileManager.default.createFile(atPath: ready, contents: nil)
        }
        XCTAssertTrue(app.buttons["Complete set 1, Deadlift"].waitForExistence(timeout: 600), "The watch started today's workout")
        XCTAssertTrue(app.buttons["Reopen set 1, Deadlift"].waitForExistence(timeout: 300), "The set logged on the watch is done here")
        if let directory = ProcessInfo.processInfo.environment["EXERLY_SCREEN_DIR"], !directory.isEmpty {
            try? XCUIScreen.main.screenshot().pngRepresentation
                .write(to: URL(fileURLWithPath: directory).appendingPathComponent("phone-set-logged-from-watch.png"))
        }
        XCTAssertTrue(app.buttons["Reopen set 2, Deadlift"].waitForExistence(timeout: 300), "The set edited on the watch is done here")
        XCTAssertTrue(app.buttons["training.finish"].waitForNonExistence(timeout: 600), "The watch finished the workout")
    }
}
