import Combine
import ExerlyCore
import Foundation

/// Builds Core's training report off the main thread, keeping the last one on
/// screen until the next is ready so changing the span never flashes empty.
@MainActor
final class TrainingInsightsModel: ObservableObject {
    @Published private(set) var report: TrainingInsights.Report?
    private var generation = 0

    struct Input: Hashable {
        let history: TrainingAnalysisInput
        let span: TrainingInsights.Span
        let today: LocalDate
        let firstWeekday: Weekday
    }

    func refresh(history: TrainingHistory, span: TrainingInsights.Span, today: LocalDate, firstWeekday: Weekday) async {
        generation += 1
        let current = generation
        let task = Task.detached(priority: .userInitiated) {
            TrainingInsights.report(history, span: span, through: today, firstWeekday: firstWeekday)
        }
        let result = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        guard current == generation, !Task.isCancelled else { return }
        report = result
    }

    /// The week start the person's locale uses.
    static var firstWeekday: Weekday { Weekday(rawValue: Calendar.current.firstWeekday) ?? .monday }
}
