import Foundation

/// Where a nutrient's average stands against its goal over a span.
public enum NutrientStanding: String, Sendable, Hashable, CaseIterable {
    /// Under the floor, or more than the tolerance under a lone target.
    case short
    case met
    /// Over the limit, or more than the tolerance over a lone target.
    case over
    /// No food logged on the counted days reported it, so nothing is known.
    case unreported
    /// Reported, but there's no goal to judge it by.
    case noGoal

    public init(average: Double, reported: Bool, goal: NutrientGoal?, tolerance: Double = IntakeSeries.tolerance) {
        guard reported else { self = .unreported; return }
        guard let goal else { self = .noGoal; return }
        let band = goal.band(tolerance: tolerance)
        if let upper = band.upper, average > upper {
            self = .over
        } else if let lower = band.lower, average < lower {
            self = .short
        } else {
            self = .met
        }
    }
}

extension IntakeSeries {
    /// A nutrient's standing: its average against the counted days' goals averaged.
    public func standing(_ row: NutrientOverview.Row) -> NutrientStanding {
        NutrientStanding(average: row.average, reported: row.observedDays > 0, goal: averageGoal(row.nutrient))
    }

    /// How many of the overview's nutrients stand each way.
    public func standings(_ overview: NutrientOverview) -> [NutrientStanding: Int] {
        overview.rows.reduce(into: [:]) { counts, row in counts[standing(row), default: 0] += 1 }
    }
}
