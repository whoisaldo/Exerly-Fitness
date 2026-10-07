import XCTest
import ExerlyCore
@testable import Exerly

@MainActor
final class AgentPresentationTests: XCTestCase {
    func testLoadCorrectionShowsTheExerciseSetAndBothUnits() throws {
        let (_, training, _, proposal) = try fixture()
        let change = try XCTUnwrap(proposal.changes.first)
        let fields = ExerlyCore.JSONValue.diff(change.before, change.after)
        let field = try XCTUnwrap(fields.first)
        let presentation = ProposalFieldPresentation(field: field, change: change,
                                                      library: training.library, unit: .kilograms)
        XCTAssertEqual(presentation.title, "Deadlift · Set 1 · Load")
        XCTAssertEqual(presentation.before, "1,500 kg")
        XCTAssertEqual(presentation.after, "150 kg")
        let pounds = ProposalFieldPresentation(field: field, change: change,
                                               library: training.library, unit: .pounds)
        XCTAssertEqual(pounds.after, TrainingFormat.mass(.kg(150), unit: .pounds))
    }

    func testUnknownFieldsAndWholeDocumentsKeepTheirCompleteValues() throws {
        let before = ExerlyCore.JSONValue.object(["futureField": .array([.string("first"), .string("second")])])
        let after = ExerlyCore.JSONValue.object(["futureField": .array([.string("third")])])
        let change = ProposedChange(kind: "future", id: "synthetic", before: before, after: after)
        let field = try XCTUnwrap(ExerlyCore.JSONValue.diff(before, after).first)
        let presentation = ProposalFieldPresentation(field: field, change: change, library: .bundled, unit: .kilograms)
        XCTAssertTrue(presentation.before.contains("first"))
        XCTAssertTrue(presentation.before.contains("second"))
        XCTAssertTrue(presentation.after.contains("third"))
        let create = ProposedChange(kind: "future", id: "new", before: nil, after: before)
        let created = ProposalFieldPresentation(field: try XCTUnwrap(ExerlyCore.JSONValue.diff(nil, before).first),
                                                change: create, library: .bundled, unit: .kilograms)
        XCTAssertEqual(created.before, "Not present")
        XCTAssertTrue(created.after.contains("futureField"))
        XCTAssertTrue(created.after.contains("second"))
    }

    func testMetricEvidenceDistinguishesVerifiedMismatchedAndUnavailable() throws {
        let (_, training, _, _) = try fixture()
        let metric = MetricReference.bestOneRepMax(exercise: "deadlift", from: LocalDate("2026-01-01")!,
                                                   through: LocalDate("2026-12-31")!, claimedKilograms: 1)
        guard case .mismatch(let actual) = metric.verify(against: training.history) else {
            return XCTFail("Fixture needs a computable metric")
        }
        let mismatch = MetricPresentation(metric: metric, history: training.history, unit: .kilograms)
        XCTAssertEqual(mismatch.status, .mismatch)
        XCTAssertEqual(mismatch.actual, TrainingFormat.mass(.kg(actual), unit: .kilograms))
        var matching = metric
        matching.claimed = actual
        XCTAssertEqual(MetricPresentation(metric: matching, history: training.history, unit: .pounds).status, .verified)
        var unknown = metric
        unknown.name = "future.metric"
        let missing = MetricPresentation(metric: unknown, history: training.history, unit: .kilograms)
        XCTAssertEqual(missing.status, .unavailable)
        XCTAssertNil(missing.actual)
    }

    func testReviewAcceptUndoAndRejectUpdateRealStoresAndSignalSync() throws {
        let (_, training, agent, proposal) = try fixture()
        let original = training.history.sessions
        var decisions = 0
        let review = AgentReviewModel(store: agent, onDecision: { decisions += 1 })
        review.decide(.accept, proposal: proposal.id)
        XCTAssertNil(review.error)
        XCTAssertEqual(agent.proposal(proposal.id)?.status, .accepted)
        XCTAssertEqual(training.history.sessions[0].exercises[0].sets[0].primary.load, .kg(150))
        review.decide(.undo, proposal: proposal.id)
        XCTAssertEqual(training.history.sessions, original)
        XCTAssertEqual(agent.proposal(proposal.id)?.status, .undone)
        var another = proposal
        another.id = UUID()
        try agent.file(another)
        review.decide(.reject, proposal: another.id)
        XCTAssertEqual(agent.proposal(another.id)?.status, .rejected)
        XCTAssertEqual(decisions, 3)
        XCTAssertEqual(agent.auditLog.map(\.action), [.proposalFiled, .proposalAccepted, .proposalUndone, .proposalFiled, .proposalRejected])
    }

    func testStaleReviewShowsAnErrorAndKeepsTheLaterWorkout() throws {
        let (_, training, agent, proposal) = try fixture()
        var later = training.history.sessions[0]
        later.notes = "A later manual change"
        try training.saveSession(later)
        let review = AgentReviewModel(store: agent, onDecision: {})
        review.decide(.accept, proposal: proposal.id)
        XCTAssertEqual(agent.proposal(proposal.id)?.status, .stale)
        XCTAssertEqual(training.history.sessions, [later])
        XCTAssertEqual(review.error, "These records changed after the suggestion was made. Nothing was applied.")
    }

    private func fixture() throws -> (InMemoryTrainingPersistence, TrainingStore, AgentStore, Proposal) {
        let persistence = InMemoryTrainingPersistence()
        let date = Date(timeIntervalSince1970: 1_791_289_200)
        let training = try TrainingStore(persistence: persistence, now: { date })
        try training.startSession(name: "Pull", bodyweight: .kg(80))
        let exercise = try training.addExercise("deadlift")
        var set = try XCTUnwrap(training.activeSession?.exercises.first?.sets.first)
        set.primary = Effort(reps: 3, load: .kg(1500))
        try training.updateSet(set, in: exercise)
        try training.completeSet(set.id)
        let before = try training.finishSession().session
        var after = before
        after.exercises[0].sets[0].primary.load = .kg(150)
        let proposal = try Proposal(author: AgentIdentity(kind: .mcp, name: "Training assistant"),
            title: "Check the deadlift load", summary: "A possible typing slip.",
            changes: [ProposedChange(kind: "workout_session", id: before.id.uuidString, before: before, after: after)],
            evidence: [Evidence(claim: "This load is unusual.", level: .personalData, caveats: ["n=1"])],
            confidence: .medium, falsifier: "The original load is correct.")
        let agent = try AgentStore(persistence: persistence, hosts: [training])
        try agent.file(proposal)
        return (persistence, training, agent, proposal)
    }
}
