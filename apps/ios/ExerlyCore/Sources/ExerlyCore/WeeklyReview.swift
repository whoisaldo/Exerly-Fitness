import Foundation

/// One suggestion in the weekly review, with its evidence and a falsifier:
/// what would show it is wrong.
public struct ReviewItem: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable {
        /// A pending proposal: accepting it applies a change.
        case proposal
        case deload, stall
        /// The nutrition goal can't be kept on new targets.
        case goal
        /// Too little logging for a confident check-in.
        case logging
    }

    /// Stable across reviews of the same week, for dismissing.
    public var id: String
    public var kind: Kind
    public var title: String
    public var summary: String
    public var evidence: [Evidence]
    public var falsifier: String
    public var proposalID: UUID?
    public var exerciseIDs: [ExerciseID]
}

/// At most three ranked suggestions for the week, from Exerly's own signals:
/// pending proposals, the deload signal, stalls, and the nutrition check-in.
/// Nothing new is computed here; the order is what this file decides.
public enum WeeklyReview {
    public static let maximumItems = 3

    public static func make(training history: TrainingHistory, proposals: [Proposal], checkIn: NutritionCheckIn.Review?,
                            through date: LocalDate, firstWeekday: Weekday = .monday) -> [ReviewItem] {
        var ranked: [(priority: Double, item: ReviewItem)] = []
        if let checkIn {
            switch checkIn.outcome {
            case .cannotKeepGoal:
                ranked.append((3.0, ReviewItem(
                    id: "goal/\(checkIn.date)", kind: .goal, title: "Your nutrition goal needs a change",
                    summary: "New targets for this week can't keep your rate within the safe floors.",
                    evidence: checkIn.problems.map { Evidence(claim: $0, level: .personalData, caveats: ["n=1"]) },
                    falsifier: "Next week's check-in finds targets within the floors at this rate.", exerciseIDs: [])))
            case .notEnoughData:
                ranked.append((1.0, ReviewItem(
                    id: "logging/\(checkIn.date)", kind: .logging, title: "Log a few complete days",
                    summary: "Expenditure can't be estimated confidently from this week's log, so targets stayed as they were.",
                    evidence: [Evidence(claim: "\(checkIn.completeDays) of the last 7 days were marked complete, and "
                        + "\(checkIn.weighInDays) had a weigh-in.", level: .personalData, caveats: ["n=1"])],
                    falsifier: "The expenditure estimate's band narrows to 250 kcal without more complete days.", exerciseIDs: [])))
            default: break
            }
        }
        if let deload = TrainingSignals.deload(in: history, through: date) {
            ranked.append((2.8, item(deload, id: "deload/\(date.startOfWeek(firstWeekday: firstWeekday))",
                                     falsifier: "Your lifts return to their four-week averages within a week of normal training.")))
        }
        for stall in TrainingSignals.stalls(in: history, through: date, firstWeekday: firstWeekday) {
            let name = stall.exerciseIDs.first.flatMap { history.library.exercise($0)?.name } ?? "This lift"
            let falling = stall.title.hasSuffix("has dropped")
            ranked.append((falling ? 2.3 : 1.8, item(
                stall, id: "stall/\(stall.exerciseIDs.map(\.rawValue).joined(separator: ","))",
                falsifier: "Your \(name) estimate rises over the next three weeks with nothing changed.")))
        }
        for proposal in proposals where proposal.status == .pending {
            let priority: Double = switch proposal.author {
            case NutritionCheckIn.author: 2.5
            case EntryErrorDetector.author: 2.2
            default: 1.5
            }
            ranked.append((priority, ReviewItem(
                id: "proposal/\(proposal.id.uuidString)", kind: .proposal, title: proposal.title, summary: proposal.summary,
                evidence: proposal.evidence, falsifier: proposal.falsifier, proposalID: proposal.id,
                exerciseIDs: [])))
        }
        return ranked.sorted { ($0.priority, $1.item.id) > ($1.priority, $0.item.id) }.prefix(maximumItems).map(\.item)
    }

    private static func item(_ diagnosis: Diagnosis, id: String, falsifier: String) -> ReviewItem {
        ReviewItem(id: id, kind: diagnosis.kind == .deload ? .deload : .stall, title: diagnosis.title, summary: diagnosis.summary,
                   evidence: diagnosis.evidence, falsifier: falsifier, exerciseIDs: diagnosis.exerciseIDs)
    }
}
