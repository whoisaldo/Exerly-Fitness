import SwiftUI
import WidgetKit

@main
struct ExerlyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // The widgets read the app's snapshot through the App Group, which
        // release builds don't have until it's registered (see project.yml).
        #if EXERLY_APP_GROUP
        TodayWidget()
        NextWorkoutWidget()
        #endif
        WorkoutLiveActivity()
        LogFoodControl()
        ScanBarcodeControl()
        WeighInControl()
        StartWorkoutControl()
    }
}
