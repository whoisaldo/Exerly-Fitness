import ExerlyCore
import Foundation
import WidgetKit

/// Writes what the widgets show into the App Group whenever it changes, and
/// asks WidgetKit to redraw. Widgets run in another process and never open
/// the database; this snapshot is all they read.
@MainActor
final class WidgetSnapshotWriter {
    private let workspace: TrainingWorkspace
    private let unit: MassUnit
    private let timeZone: TimeZone
    private let url: URL?
    /// The program's next workout reads the whole history, so it's kept
    /// until something it shows can have changed, not redone per food logged.
    private var plan: (key: String, plan: WorkoutPlan?)?

    init(workspace: TrainingWorkspace, unit: MassUnit, timeZone: TimeZone, url: URL? = WidgetSnapshot.defaultURL) {
        self.workspace = workspace
        self.unit = unit
        self.timeZone = timeZone
        self.url = url
    }

    /// Writes on every change until the calling task is cancelled.
    func follow() async {
        for await snapshot in Observations({ @MainActor in self.snapshot(at: .now) }) {
            if (try? snapshot.write(to: url)) == true { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    /// Removes the snapshot at sign-out, so widgets stop showing the account.
    static func clear() {
        if WidgetSnapshot.remove() { WidgetCenter.shared.reloadAllTimelines() }
    }

    func snapshot(at now: Date) -> WidgetSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = LocalDate(now, in: timeZone)
        let start = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let after = calendar.date(byAdding: .day, value: 2, to: start) ?? tomorrow.addingTimeInterval(86_400)
        let store = workspace.store
        let done = store.history.sessions.filter { $0.localDate == today }.max { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) }
        return WidgetSnapshot(
            days: [day(today, from: start, to: tomorrow), day(today.adding(days: 1), from: tomorrow, to: after)],
            active: store.activeSession.map { session in
                let sets = session.exercises.flatMap(\.sets)
                return .init(name: TrainingFormat.title(of: session).name, startedAt: session.startedAt,
                             completedSets: sets.filter(\.isCompleted).count, totalSets: sets.count)
            },
            done: done.map { .init(name: TrainingFormat.title(of: $0).name, workingSets: store.summary(of: $0).workingSets, until: tomorrow) },
            planned: nextPlan(today: today).map { plan in
                let title = TrainingFormat.title(plan.name, planned: plan.program != nil)
                return .init(name: title.name, program: title.program, isDeload: plan.isDeload,
                             exercises: plan.exercises.compactMap { planned in
                                 store.library.exercise(planned.exerciseID).map { .init(name: $0.name, sets: planned.recommendation.sets.count) }
                             })
            })
    }

    private func day(_ date: LocalDate, from start: Date, to end: Date) -> WidgetSnapshot.Day {
        let progress = workspace.nutrition.progress(on: date)
        func amount(_ nutrient: NutrientProgress) -> WidgetSnapshot.Amount { .init(consumed: nutrient.consumed, target: nutrient.target) }
        return .init(start: start, end: end, energy: amount(progress.energy), protein: amount(progress.protein),
                     carbohydrate: amount(progress.carbohydrate), fat: amount(progress.fat))
    }

    private func nextPlan(today: LocalDate) -> WorkoutPlan? {
        let store = workspace.store
        let key = "\(today)-\(workspace.programs.active?.hashValue ?? 0)-\(store.history.sessions.count)-\(store.activeSession == nil)"
        if let plan, plan.key == key { return plan.plan }
        let next = workspace.nextWorkout(bodyweight: workspace.latestBodyweight, unit: unit)
        plan = (key, next)
        return next
    }
}
