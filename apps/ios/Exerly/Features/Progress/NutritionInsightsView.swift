import ExerlyCore
import SwiftUI

/// Calories, macros and nutrients over time.
struct NutritionInsightsView: View {
    let workspace: TrainingWorkspace?
    let unit: MassUnit
    let timeZone: TimeZone

    var body: some View {
        ContentUnavailableView("Nutrition", systemImage: "chart.bar.xaxis", description: Text("Calories, macros and nutrients over time."))
    }
}
