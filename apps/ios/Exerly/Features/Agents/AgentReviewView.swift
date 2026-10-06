import ExerlyCore
import SwiftUI

struct AgentReviewView: View {
    @ObservedObject var workspace: TrainingWorkspace
    let unit: MassUnit

    var body: some View {
        List {
            Section {
                Text("Review the changes and evidence before deciding. You can keep logging with no agent connected.")
                    .foregroundStyle(.secondary)
                NavigationLink {
                    AgentAuditView(workspace: workspace, unit: unit)
                } label: { Label("Activity history", systemImage: "clock.arrow.circlepath") }
                .accessibilityIdentifier("suggestions.audit")
            }
            let pending = workspace.agent.proposals.filter { $0.status == .pending }
            Section("Awaiting review") {
                if pending.isEmpty {
                    Text("No suggestions to review").foregroundStyle(.secondary)
                } else {
                    ForEach(pending) { proposal in row(proposal) }
                }
            }
            let decisions = workspace.agent.proposals.filter { $0.status != .pending }
            if !decisions.isEmpty {
                Section("Previous decisions") {
                    ForEach(decisions) { proposal in row(proposal) }
                }
            }
        }
        .navigationTitle("Suggestions").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(Color.exBackground)
        .refreshable { await workspace.synchronize() }
    }

    private func row(_ proposal: Proposal) -> some View {
        NavigationLink {
            ProposalDetailView(workspace: workspace, proposalID: proposal.id, unit: unit)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(proposal.title).font(.headline)
                Text(proposal.author.name).font(.subheadline).foregroundStyle(.secondary)
                Text(AgentFormat.status(proposal.status)).font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 4)
        }.accessibilityIdentifier("suggestions.proposal.\(proposal.id.uuidString)")
    }
}

struct ProposalDetailView: View {
    @ObservedObject var workspace: TrainingWorkspace
    let proposalID: UUID
    let unit: MassUnit
    @StateObject private var review: AgentReviewModel
    @AccessibilityFocusState private var errorFocused: Bool

    init(workspace: TrainingWorkspace, proposalID: UUID, unit: MassUnit) {
        self.workspace = workspace
        self.proposalID = proposalID
        self.unit = unit
        _review = StateObject(wrappedValue: AgentReviewModel(store: workspace.agent) {
            Task { await workspace.synchronize() }
        })
    }

    var body: some View {
        ScrollViewReader { scroll in
            List {
                if let proposal = workspace.agent.proposal(proposalID) {
                    Section {
                        Text(proposal.title).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        Text(proposal.summary)
                        Text("From \(proposal.author.name)").foregroundStyle(.secondary)
                        Text(proposal.createdAt, format: .dateTime.month().day().year().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                        Label(AgentFormat.status(proposal.status), systemImage: statusIcon(proposal.status))
                            .accessibilityIdentifier("suggestions.status")
                    }
                    Section("Proposed changes") {
                        ForEach(Array(workspace.agent.diff(proposalID).enumerated()), id: \.offset) { _, diff in
                            if let change = proposal.changes.first(where: { $0.kind == diff.kind && $0.id == diff.id }) {
                                ProposalChangeView(diff: diff, change: change, library: workspace.store.library, unit: unit)
                            }
                        }
                    }
                    Section("Evidence") {
                        if proposal.evidence.isEmpty {
                            Label("No supporting evidence supplied", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(Color.exWarning)
                        }
                        ForEach(Array(proposal.evidence.enumerated()), id: \.offset) { _, evidence in
                            ProposalEvidenceView(evidence: evidence, store: workspace.store, unit: unit)
                        }
                    }
                    Section("Confidence") {
                        Text("\(proposal.confidence.rawValue.capitalized) · reported by \(proposal.author.name)")
                    }
                    Section("What would show this is wrong") { Text(proposal.falsifier) }
                    Section {
                        if let error = review.error {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(Color.exError).accessibilityFocused($errorFocused)
                                .accessibilityIdentifier("suggestions.error")
                                .id("decision-error")
                        }
                        if proposal.status == .pending {
                            if workspace.supportsChanges(in: proposal) {
                                Button("Accept suggestion", systemImage: "checkmark") { decide(.accept) }
                                    .accessibilityIdentifier("suggestions.accept")
                            } else {
                                Text("This build cannot apply all the records in this suggestion. You can inspect its changes and evidence, or reject it.")
                                    .foregroundStyle(.secondary).accessibilityIdentifier("suggestions.unsupported")
                            }
                            Button("Reject suggestion", systemImage: "xmark") { decide(.reject) }
                                .accessibilityIdentifier("suggestions.reject")
                        } else if proposal.status == .accepted {
                            if workspace.supportsChanges(in: proposal) {
                                Button("Undo suggestion", systemImage: "arrow.uturn.backward") { decide(.undo) }
                                    .accessibilityIdentifier("suggestions.undo")
                                Text("Undo is available while the affected records still match this suggestion.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            } else {
                                Text("Undo requires an app version that supports every record in this suggestion.")
                                    .foregroundStyle(.secondary).accessibilityIdentifier("suggestions.unsupported")
                            }
                        } else if proposal.status == .stale {
                            Text("Your data changed after this suggestion was made. It can no longer be applied.")
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Decisions save on this device, including offline, and sync when connected.")
                    }
                } else {
                    ContentUnavailableView("Suggestion unavailable", systemImage: "doc.questionmark",
                                           description: Text("It may have been removed on another device."))
                }
            }
            .navigationTitle("Review suggestion").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(Color.exBackground)
            .onChange(of: review.error) { _, message in
                guard message != nil else { return }
                Task { @MainActor in
                    await Task.yield()
                    scroll.scrollTo("decision-error", anchor: .center)
                }
            }
        }
    }

    private func decide(_ decision: AgentReviewModel.Decision) {
        review.decide(decision, proposal: proposalID)
        errorFocused = review.error != nil
    }

    private func statusIcon(_ status: ProposalStatus) -> String {
        switch status {
        case .pending: "tray"
        case .accepted: "checkmark.circle"
        case .rejected: "xmark.circle"
        case .undone: "arrow.uturn.backward"
        case .stale: "exclamationmark.triangle"
        }
    }
}

private struct ProposalChangeView: View {
    let diff: AgentStore.DocumentDiff
    let change: ProposedChange
    let library: ExerlyCore.ExerciseLibrary
    let unit: MassUnit

    var body: some View {
        ForEach(Array(diff.fields.enumerated()), id: \.offset) { _, field in
            let display = ProposalFieldPresentation(field: field, change: change, library: library, unit: unit)
            VStack(alignment: .leading, spacing: 8) {
                Text(display.title).font(.headline)
                if field.path.isEmpty || isCollection(field.before) || isCollection(field.after) {
                    NavigationLink("View complete change") {
                        ProposalRawChangeView(title: display.title, before: field.before, after: field.after)
                    }
                } else {
                    Text("Before: \(display.before)").foregroundStyle(.secondary)
                    Text("After: \(display.after)")
                }
            }.padding(.vertical, 4)
        }
        DisclosureGroup("Full record details") {
            Text("\(TrainingFormat.words(change.kind)) · \(change.id)")
                .font(.caption).textSelection(.enabled)
            NavigationLink("Compare complete records") {
                ProposalRawChangeView(title: "Complete records", before: change.before, after: change.after)
            }
        }
    }

    private func isCollection(_ value: ExerlyCore.JSONValue?) -> Bool {
        switch value {
        case .array?, .object?: true
        default: false
        }
    }
}

private struct ProposalRawChangeView: View {
    let title: String
    let before: ExerlyCore.JSONValue?
    let after: ExerlyCore.JSONValue?

    var body: some View {
        List {
            Section("Before") { Text(AgentFormat.value(before)).font(.body.monospaced()).textSelection(.enabled) }
            Section("After") { Text(AgentFormat.value(after)).font(.body.monospaced()).textSelection(.enabled) }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct ProposalEvidenceView: View {
    let evidence: Evidence
    let store: TrainingStore
    let unit: MassUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AgentFormat.level(evidence.level)).font(.subheadline.weight(.semibold))
            Text(evidence.claim)
            ForEach(Array(evidence.caveats.enumerated()), id: \.offset) { _, caveat in
                Label(caveat, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
            }
            if let metric = evidence.metric { metricView(metric) }
            ForEach(Array(evidence.dataRefs.enumerated()), id: \.offset) { _, reference in
                AgentDataLink(reference: reference, store: store, unit: unit)
            }
            if let source = evidence.source, !source.isEmpty {
                if let url = URL(string: source), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                    Link("Source: \(url.host ?? source)", destination: url)
                } else { Text("Source: \(source)").font(.footnote).textSelection(.enabled) }
            }
        }.padding(.vertical, 6)
    }

    private func metricView(_ metric: MetricReference) -> some View {
        let display = MetricPresentation(metric: metric, history: store.history, unit: unit)
        return VStack(alignment: .leading, spacing: 6) {
            Text(display.title).font(.subheadline.weight(.semibold))
            Text("Reported value: \(display.claimed)")
            if let actual = display.actual { Text("From saved data: \(actual)") }
            switch display.status {
            case .verified:
                Label("Matches saved data", systemImage: "checkmark.circle").foregroundStyle(.secondary)
            case .mismatch:
                Label("Does not match saved data", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color.exWarning)
            case .unavailable:
                Label("Cannot verify from saved data", systemImage: "questionmark.circle").foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
}

private struct AgentDataLink: View {
    let reference: DataRef
    let store: TrainingStore
    let unit: MassUnit

    var body: some View {
        if reference.kind == "workout_session", let id = UUID(uuidString: reference.id),
           let session = store.history.sessions.first(where: { $0.id == id }) ?? (store.activeSession?.id == id ? store.activeSession : nil) {
            NavigationLink {
                WorkoutDetailView(store: store, sessionID: id, unit: unit)
            } label: { Label("\(session.name) · \(TrainingFormat.date(session))", systemImage: "dumbbell") }
                .accessibilityIdentifier("evidence.workout.\(id.uuidString)")
        } else if reference.kind == "exercise", let exercise = store.library.exercise(ExerciseID(reference.id)) {
            NavigationLink {
                ExerciseLogView(store: store, exerciseID: exercise.id, unit: unit)
            } label: { Label("Logged sets · \(exercise.name)", systemImage: "list.bullet.rectangle") }
                .accessibilityIdentifier("evidence.exercise.\(exercise.id.rawValue)")
        } else {
            Text("Referenced \(TrainingFormat.words(reference.kind).lowercased()) is unavailable on this device.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct AgentAuditView: View {
    @ObservedObject var workspace: TrainingWorkspace
    let unit: MassUnit

    var body: some View {
        List {
            if workspace.agent.auditLog.isEmpty {
                ContentUnavailableView("No agent activity yet", systemImage: "clock",
                                       description: Text("Suggestions, decisions and connected-agent activity appear here."))
            }
            ForEach(Array(workspace.agent.auditLog.reversed())) { event in
                Section {
                    Text(AgentFormat.action(event.action)).font(.headline)
                    Text(event.actor.name)
                    Text(event.at, format: .dateTime.month().day().year().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                    if let note = event.note, !note.isEmpty { Text(note) }
                    if let id = event.proposalID, let proposal = workspace.agent.proposal(id) {
                        NavigationLink(proposal.title) {
                            ProposalDetailView(workspace: workspace, proposalID: id, unit: unit)
                        }
                    }
                    ForEach(Array(event.targets.enumerated()), id: \.offset) { _, reference in
                        AgentDataLink(reference: reference, store: workspace.store, unit: unit)
                    }
                }
            }
        }
        .navigationTitle("Activity history").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(Color.exBackground)
    }
}
