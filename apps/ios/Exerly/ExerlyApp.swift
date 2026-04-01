import SwiftUI
import SwiftData

@main
struct ExerlyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            CachedFoodItem.self,
            DailyFoodLog.self,
            Measurement.self,
            ProgressPhoto.self,
            Achievement.self,
            OfflineAction.self,
        ])
    }
}
