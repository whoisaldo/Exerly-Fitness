import Foundation

extension Nutrient: Identifiable {
    public var id: String { rawValue }

    /// Energy and the macros, whose goals are the plan's daily targets.
    public var isTarget: Bool { self == .energy || group == .macros }
}

extension NutrientGoal {
    public enum Part: String, Sendable, Hashable, CaseIterable {
        case floor, target, ceiling
    }

    /// The first two parts out of order, the one that should be lower first:
    /// (.floor, .target) when the floor is above the target. Nil when in order.
    public var misordered: (lower: Part, upper: Part)? {
        let parts: [(Part, Double?)] = [(.floor, floor), (.target, target), (.ceiling, ceiling)]
        for (index, lower) in parts.enumerated() {
            for upper in parts[(index + 1)...] {
                if let low = lower.1, let high = upper.1, low > high { return (lower.0, upper.0) }
            }
        }
        return nil
    }

    /// Where an amount so far in a day stands against the goal.
    public enum DayStanding: Sendable, Hashable {
        /// Below the goal's band, by how much is still to go to the floor, or to a target without one.
        case short(Double)
        /// Inside it, with what's left under the ceiling when there is one.
        case met(left: Double?)
        /// Above it, by how much past the ceiling, or past a target without one.
        case over(Double)
    }

    /// The day so far against the goal, by the same band as `contains`.
    public func standing(of amount: Double, tolerance: Double = IntakeSeries.tolerance) -> DayStanding {
        let band = band(tolerance: tolerance)
        if let upper = band.upper, amount > upper { return .over(amount - (ceiling ?? target ?? upper)) }
        if let lower = band.lower, amount < lower { return .short((floor ?? target ?? lower) - amount) }
        return .met(left: ceiling.map { $0 - amount })
    }
}

/// A nutrient's day so far against the goal in force that day, as Today
/// shows a pinned one.
public struct NutrientDay: Sendable, Hashable, Identifiable {
    public var nutrient: Nutrient
    /// What the reporting entries add up to; nil when none reports it,
    /// which is unknown, not zero.
    public var amount: Double?
    public var goal: NutrientGoal?
    public var entries: Int
    /// Of `entries`, those whose food reports the nutrient.
    public var reporting: Int

    public init(nutrient: Nutrient, amount: Double?, goal: NutrientGoal?, entries: Int, reporting: Int) {
        self.nutrient = nutrient
        self.amount = amount
        self.goal = goal
        self.entries = entries
        self.reporting = reporting
    }

    public var id: Nutrient { nutrient }

    public var standing: NutrientGoal.DayStanding? {
        guard let amount, let goal else { return nil }
        return goal.standing(of: amount)
    }
}

extension NutritionPlan {
    /// Whether two versions differ only in nutrient goals and pins.
    public func sameTargets(as other: NutritionPlan) -> Bool {
        var mine = self, theirs = other
        mine.id = theirs.id
        mine.startDate = theirs.startDate
        mine.createdAt = theirs.createdAt
        (mine.nutrientGoals, mine.pinnedNutrients, theirs.nutrientGoals, theirs.pinnedNutrients) = (nil, nil, nil, nil)
        return mine == theirs
    }
}

extension NutritionStore {
    /// Sets a nutrient's goal from today. Nil, or the reference intake
    /// itself, goes back to the reference intake.
    public func setGoal(_ goal: NutrientGoal?, for nutrient: Nutrient, timeZone: TimeZone) throws {
        guard !nutrient.isTarget else { throw StoreError.invalid(["\(nutrient.name) comes from your daily targets"]) }
        try revisePlan(timeZone: timeZone) { plan in
            var goals = plan.nutrientGoals ?? [:]
            goals[nutrient] = goal == NutrientGoal(reference: nutrient) ? nil : goal
            plan.nutrientGoals = goals.isEmpty ? nil : goals
        }
    }

    /// Pins a nutrient to Today after those already pinned, or unpins it, from today.
    public func setPinned(_ nutrient: Nutrient, _ pinned: Bool, timeZone: TimeZone) throws {
        try revisePlan(timeZone: timeZone) { plan in
            var pins = (plan.pinnedNutrients ?? []).filter { $0 != nutrient }
            if pinned { pins.append(nutrient) }
            plan.pinnedNutrients = pins.isEmpty ? nil : pins
        }
    }

    /// The nutrients pinned to Today: the version in force on `today`'s.
    public func pinnedNutrients(today: LocalDate) -> [Nutrient] { plan(on: today)?.pinnedNutrients ?? [] }

    /// Each nutrient's day on `date`, against the goals in force then.
    public func nutrientDays(_ nutrients: [Nutrient], on date: LocalDate) -> [NutrientDay] {
        guard !nutrients.isEmpty else { return [] }
        let summary = summary(on: date)
        let plan = plan(on: date)
        return nutrients.map {
            NutrientDay(nutrient: $0, amount: summary.totals[$0], goal: plan?.goal(for: $0, on: date), entries: summary.entries,
                        reporting: summary.reporting[$0] ?? 0)
        }
    }

    /// Versions in force on at least one day, oldest first: a later version
    /// starting the same day replaces an earlier one outright.
    public var versionsInForce: [NutritionPlan] {
        plans.indices.filter { $0 == plans.count - 1 || plans[$0 + 1].startDate != plans[$0].startDate }.map { plans[$0] }
    }
}
