import Foundation

/// The result of an experiment, with what could explain it besides the change.
public struct ExperimentAnalysis: Sendable, Hashable {
    public var comparison: Analytics.Comparison
    public var caveats: [String]
}

/// Daily series from the stores that hold them, and analyses over them. A day
/// with no value is missing, never zero. See docs/design/014-analytics.md.
@MainActor
public struct SeriesSources {
    public var training: TrainingHistory?
    public var nutrition: NutritionStore?
    public var metrics: MetricsStore?

    public init(training: TrainingHistory? = nil, nutrition: NutritionStore? = nil, metrics: MetricsStore? = nil) {
        self.training = training
        self.nutrition = nutrition
        self.metrics = metrics
    }

    /// One value per local date in the range:
    /// - a nutrient: the day's total on days that count, zero on fasting days;
    /// - trend and scale weight, in kilograms;
    /// - an exercise's best e1RM that day, in kilograms;
    /// - a custom metric's value;
    /// - a tag: 1 when the day has it, 0 on other days with a log or tags.
    public func values(_ id: SeriesID, from start: LocalDate, through end: LocalDate) -> [LocalDate: Double] {
        guard start <= end else { return [:] }
        let dates = (0...start.days(until: end)).map { start.adding(days: $0) }
        switch id.source {
        case .nutrient(let nutrient):
            guard let nutrition else { return [:] }
            var values: [LocalDate: Double] = [:]
            for date in dates where nutrition.counts(date) {
                if nutrition.day(date).status == .fasting {
                    values[date] = 0
                } else if let total = nutrition.entries(on: date).reduce(NutrientAmounts(), { $0 + $1.nutrients })[nutrient] {
                    values[date] = total
                }
            }
            return values
        case .trendWeight:
            guard let nutrition, let first = nutrition.weights.first?.date, first <= end else { return [:] }
            let prior = nutrition.plans.first?.basis.map { (mean: $0.expenditure, error: $0.expenditureError) }
            let estimates = EnergyBalance.estimate(nutrition.energyBalanceDays(from: min(first, start), through: end), prior: prior)
            return Dictionary(uniqueKeysWithValues: estimates.filter { $0.date >= start }.map { ($0.date, $0.trend) })
        case .scaleWeight:
            guard let nutrition else { return [:] }
            let readings = Dictionary(grouping: nutrition.weights.filter { (start...end).contains($0.date) }, by: \.date)
            return readings.mapValues { day in day.reduce(0) { $0 + $1.weight.kilograms } / Double(day.count) }
        case .oneRepMax(let exerciseID):
            guard let training, let exercise = training.library.exercise(exerciseID) else { return [:] }
            var values: [LocalDate: Double] = [:]
            for session in training.sessions where (start...end).contains(session.localDate) {
                let best = session.exercises.filter { $0.exerciseID == exerciseID }.flatMap(\.sets).filter(\.counts)
                    .compactMap { ExerciseStatistics.oneRepMax($0, exercise: exercise, bodyweight: session.bodyweight) }.max()
                if let best { values[session.localDate] = max(values[session.localDate] ?? 0, best) }
            }
            return values
        case .metric(let metricID):
            return (metrics?.values(of: metricID) ?? [:]).filter { (start...end).contains($0.key) }
        case .tag(let tag):
            guard let nutrition else { return [:] }
            var values: [LocalDate: Double] = [:]
            for date in dates {
                let day = nutrition.day(date)
                if day.tags.contains(tag) {
                    values[date] = 1
                } else if !day.tags.isEmpty || !nutrition.entries(on: date).isEmpty {
                    values[date] = 0
                }
            }
            return values
        }
    }

    /// How `x` today goes with `y` 0 to 3 days later. Association, not cause.
    public func correlations(_ x: SeriesID, _ y: SeriesID, from start: LocalDate, through end: LocalDate) -> [Analytics.Correlation] {
        Analytics.correlations(values(x, from: start, through: end), values(y, from: start, through: end.adding(days: 3)))
    }

    public func analyze(_ experiment: Experiment) -> ExperimentAnalysis {
        let baseline = values(experiment.metric, from: experiment.baselineStart, through: experiment.baselineEnd)
        let intervention = values(experiment.metric, from: experiment.interventionStart, through: experiment.interventionEnd)
        let comparison = Analytics.compare(baseline: baseline.sorted { $0.key < $1.key }.map(\.value),
                                           intervention: intervention.sorted { $0.key < $1.key }.map(\.value))
        var caveats = [
            "n=1 with no blinding or control: expectations, and anything else that changed, can explain a difference.",
            "A trend over time, such as getting fitter, also looks like an effect. Returning to the baseline afterwards tests that.",
        ]
        if let nutrition {
            for tag in nutrition.tags {
                let before = values(.init(.tag(tag)), from: experiment.baselineStart, through: experiment.baselineEnd)
                let after = values(.init(.tag(tag)), from: experiment.interventionStart, through: experiment.interventionEnd)
                guard !before.isEmpty, !after.isEmpty else { continue }
                let share = { (days: [LocalDate: Double]) in days.values.reduce(0, +) / Double(days.count) }
                if abs(share(after) - share(before)) >= 0.3 {
                    caveats.append("\"\(tag)\" was on \(Int((share(before) * 100).rounded())) % of baseline days and "
                        + "\(Int((share(after) * 100).rounded())) % of intervention days.")
                }
            }
        }
        return ExperimentAnalysis(comparison: comparison, caveats: caveats)
    }
}
