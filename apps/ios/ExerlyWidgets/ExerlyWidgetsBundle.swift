import SwiftUI
import WidgetKit

@main
struct ExerlyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        NextWorkoutWidget()
        WorkoutLiveActivity()
    }
}
