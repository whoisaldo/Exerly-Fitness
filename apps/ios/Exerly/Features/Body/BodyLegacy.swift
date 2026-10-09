import ExerlyCore
import SwiftUI

/// The diary's older weight entry point. Weigh-ins live in ExerlyCore now, so
/// it opens the same sheet as everywhere else.
struct WeightEntrySheet: View {
    let date: CalendarDay
    @EnvironmentObject private var account: AppAccountWorkspace
    @EnvironmentObject private var auth: AuthViewModel

    init(date: CalendarDay, onDeleted: @escaping (String) -> Void = { _ in }, onSaved: @escaping () -> Void = {}) {
        self.date = date
    }

    var body: some View {
        if let workspace = account.training, workspace.accountID == auth.currentUser?.id {
            WeighInSheet(workspace: workspace, unit: auth.currentUser?.unitSystem == "metric" ? .kilograms : .pounds,
                         timeZone: TimeZone(identifier: auth.currentUser?.timezone ?? "UTC") ?? .gmt, editing: nil,
                         date: LocalDate(date.rawValue))
        } else {
            LoadingStateView(message: "Opening your weigh-ins…")
        }
    }
}

/// Weight text fields that keep an unchanged value exact.
enum WeightFieldText {
    static func display(_ kilograms: Double?, unit: MassUnit) -> String {
        kilograms.map { Mass.kg($0).value(in: unit).formatted(.number.grouping(.never).precision(.fractionLength(0...2))) } ?? ""
    }

    static func kilograms(_ text: String, original: Double?, unit: MassUnit) -> Double? {
        if let original, text == display(original, unit: unit) { return original }
        guard let number = TrainingInput.number(text) else { return nil }
        return Mass(number, unit).kilograms
    }
}
