import AppIntents
import SwiftUI
import WidgetKit

// Control Center, Lock Screen and Action button controls. Each opens the app
// on its screen and reads nothing from the App Group, so they ship before
// the group is registered.

struct LogFoodControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.exerly.fitness.control.logFood") {
            ControlWidgetButton(action: SearchFoodsIntent()) { Label("Log food", systemImage: "magnifyingglass") }
        }
        .displayName("Log food")
        .description("Opens food search.")
    }
}

struct ScanBarcodeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.exerly.fitness.control.scanBarcode") {
            ControlWidgetButton(action: ScanBarcodeIntent()) { Label("Scan barcode", systemImage: "barcode.viewfinder") }
        }
        .displayName("Scan barcode")
        .description("Opens the barcode scanner.")
    }
}

struct WeighInControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.exerly.fitness.control.weighIn") {
            ControlWidgetButton(action: WeighInIntent()) { Label("Weigh in", systemImage: "scalemass.fill") }
        }
        .displayName("Weigh in")
        .description("Opens a new weigh-in.")
    }
}

struct StartWorkoutControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.exerly.fitness.control.startWorkout") {
            ControlWidgetButton(action: StartWorkoutIntent()) {
                Label("Start workout", systemImage: "figure.strengthtraining.traditional")
            }
        }
        .displayName("Start workout")
        .description("Starts today's workout.")
    }
}
