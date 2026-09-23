import SwiftUI
import SwiftData

@main
struct ExerlyApp: App {
    private let container: ModelContainer?
    private let isUnitTestHost: Bool

    init() {
        #if DEBUG
        isUnitTestHost = NSClassFromString("XCTestCase") != nil
        // Hosted unit tests inject their own storage and transport. Do not also
        // launch the real account, Keychain, notification service or sync engine.
        if isUnitTestHost {
            container = nil
            return
        }
        #else
        isUnitTestHost = false
        #endif
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            KeychainService.shared.deleteToken()
            if ProcessInfo.processInfo.environment["EXERLY_API_BASE_URL"] == "http://127.0.0.1:39001",
               let store = ProcessInfo.processInfo.environment["EXERLY_TEST_STORE_ID"], UUID(uuidString: store) != nil,
               let token = ProcessInfo.processInfo.environment["EXERLY_TEST_LEGACY_TOKEN"] {
                KeychainService.shared.saveToken(token)
            }
        }
        #endif
        let schema = Schema(versionedSchema: ExerlySchemaV3.self)
        // Keep the existing store intact on failure. A temporary in-memory
        // replacement would appear to save entries that disappear at relaunch.
        #if DEBUG
        if let storeID = ProcessInfo.processInfo.environment["EXERLY_TEST_STORE_ID"], UUID(uuidString: storeID) != nil {
            let folder = URL.applicationSupportDirectory.appending(path: "SimulatorTests", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let config = ModelConfiguration(schema: schema, url: folder.appending(path: "\(storeID).store"))
            container = try? ModelContainer(for: schema, migrationPlan: ExerlyMigrationPlan.self, configurations: [config])
        } else {
            container = try? ModelContainer(for: schema, migrationPlan: ExerlyMigrationPlan.self)
        }
        #else
        container = try? ModelContainer(for: schema, migrationPlan: ExerlyMigrationPlan.self)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if isUnitTestHost {
                Color.clear
            } else if let container {
                RootView().modelContainer(container)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Saved data could not be opened").font(.title2)
                    Text("Your original data is still on this device. Close and reopen Exerly. If this continues, keep the app installed and contact support so your data can be recovered.")
                        .font(.body)
                    Text("Do not delete the app to troubleshoot this error.").font(.callout)
                }.padding(24)
            }
        }
    }
}
