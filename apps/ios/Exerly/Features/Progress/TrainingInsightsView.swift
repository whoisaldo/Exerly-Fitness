import ExerlyCore
import SwiftUI

/// Volume, strength and records over time.
struct TrainingInsightsView: View {
    let workspace: TrainingWorkspace?
    let unit: MassUnit
    let timeZone: TimeZone

    var body: some View {
        ContentUnavailableView("Training", systemImage: "chart.bar.xaxis", description: Text("Volume, strength and records over time."))
    }
}
