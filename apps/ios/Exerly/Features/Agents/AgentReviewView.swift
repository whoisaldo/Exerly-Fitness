import ExerlyCore
import SwiftUI

struct AgentReviewView: View {
    @ObservedObject var workspace: TrainingWorkspace
    let unit: MassUnit

    var body: some View {
        ExList {
            Section {
                ExCard(accent: true) {
                    ExEyebrow("Your review", color: .exPrimaryText)
                    let count = workspace.agent.proposals.filter { $0.status == .pending }.count
                    Text(count == 0 ? "You're up to date" : "\(count) to review").font(.exH1)
                        .accessibilityIdentifier("suggestions.pendingSummary")
                    Text(count == 0 ? "New suggestions will appear here. Your training and food log work with or without an agent." :
                         "See the changes and evidence. You decide what gets applied.")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary)
                    NavigationLink {
                        AgentAuditView(workspace: workspace, unit: unit)
                    } label: { ExNavigationLabel(title: "Activity history", icon: "clock.arrow.circlepath", showChevron: false) }
                        .accessibilityIdentifier("suggestions.audit")
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            let pending = workspace.agent.proposals.filter { $0.status == .pending }
            if !pending.isEmpty {
                Section("Awaiting review") { ForEach(pending) { proposal in row(proposal) } }
            }
            let decisions = workspace.agent.proposals.filter { $0.status != .pending }
            if !decisions.isEmpty {
                Section("Previous decisions") {
                    ForEach(decisions) { proposal in row(proposal) }
                }
            }
        }
        .navigationTitle("Suggestions").navigationBarTitleDisplayMode(.inline)
        .exListStyle()
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
            ExList {
                if let proposal = workspace.agent.proposal(proposalID) {
                    Section {
                        ExCard(accent: true) {
                        Text(proposal.title).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        Text(proposal.summary)
                        Text("From \(proposal.author.name)").foregroundStyle(.secondary)
                        Text(proposal.createdAt, format: .dateTime.month().day().year().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                        Label(AgentFormat.status(proposal.status), systemImage: statusIcon(proposal.status))
                            .accessibilityIdentifier("suggestions.status")
                        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
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
                            ProposalEvidenceView(evidence: evidence, store: workspace.store, unit: unit, programs: workspace.programs)
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
                                    .accessibilityIdentifier("suggestions.accept").buttonStyle(ExActionStyle())
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
            .exListStyle()
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
        if change.kind == "program" {
            if let before = try? change.before?.decode(Program.self) {
                NavigationLink("Read original program") {
                    ProposalProgramView(program: before, library: library, title: "Original program")
                }.accessibilityIdentifier("suggestions.program.before")
            } else if change.before == nil {
                Text("Creates a new program").font(.headline)
            }
            if let after = try? change.after?.decode(Program.self) {
                NavigationLink("Read proposed program") {
                    ProposalProgramView(program: after, library: library, title: "Proposed program")
                }.accessibilityIdentifier("suggestions.program.after")
            } else if change.after == nil {
                Text("Removes this program").font(.headline)
            }
        }
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

private struct ProposalProgramView: View {
    let program: Program
    let library: ExerlyCore.ExerciseLibrary
    let title: String

    var body: some View {
        ExList {
            Section {
                Text(program.name).font(.title2.weight(.semibold))
                Text("\(program.cycles) cycles · \(TrainingProgramFormat.deload(program.deload))")
                if program.archivedAt != nil { Text("Archived") }
                if let date = program.activatedAt {
                    Text("Followed: \(date.formatted(date: .abbreviated, time: .shortened))")
                }
                Text("These are the program's saved targets. Planned workouts also use your completed sets and the cycle's deload setting.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            TrainingProgramDays(program: program, library: library)
            Section("Appearance") {
                Text("Icon: \(program.icon ?? "Default")")
                Text("Color: \(program.color ?? "Default")")
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .exListStyle()
    }
}

private struct ProposalRawChangeView: View {
    let title: String
    let before: ExerlyCore.JSONValue?
    let after: ExerlyCore.JSONValue?

    var body: some View {
        ExList {
            Section("Before") { Text(AgentFormat.value(before)).font(.body.monospaced()).textSelection(.enabled) }
            Section("After") { Text(AgentFormat.value(after)).font(.body.monospaced()).textSelection(.enabled) }
        }.exListStyle().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct ProposalEvidenceView: View {
    let evidence: Evidence
    let store: TrainingStore
    let unit: MassUnit
    var programs: ProgramStore?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AgentFormat.level(evidence.level)).font(.subheadline.weight(.semibold))
            Text(evidence.claim)
            ForEach(Array(evidence.caveats.enumerated()), id: \.offset) { _, caveat in
                Label(caveat, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
            }
            if let metric = evidence.metric { metricView(metric) }
            ForEach(Array(evidence.dataRefs.enumerated()), id: \.offset) { _, reference in
                AgentDataLink(reference: reference, store: store, unit: unit, programs: programs)
            }
            if let source = evidence.source, !source.isEmpty {
                if let url = URL(string: source), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                    Link("Source: \(url.host ?? source)", destination: url)
                } else { Text("Source: \(source)").font(.footnote).textSelection(.enabled) }
            }
        }.fixedSize(horizontal: false, vertical: true).padding(.vertical, 6)
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
        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
}

private struct AgentDataLink: View {
    let reference: DataRef
    let store: TrainingStore
    let unit: MassUnit
    var programs: ProgramStore?

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
        } else if reference.kind == "program", let id = UUID(uuidString: reference.id), let program = programs?.program(id) {
            NavigationLink {
                ProposalProgramView(program: program, library: store.library, title: "Saved program")
            } label: { Label(program.name, systemImage: "dumbbell") }
                .accessibilityIdentifier("evidence.program.\(id.uuidString)")
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
        ExList {
            Section {
                ExCard(accent: true) {
                    ExEyebrow("Agent record", color: .exPrimaryText)
                    Text("Every decision, recorded").font(.exH2)
                    Text("\(workspace.agent.auditLog.count) events").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
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
                        AgentDataLink(reference: reference, store: workspace.store, unit: unit, programs: workspace.programs)
                    }
                }
            }
        }
        .navigationTitle("Activity history").navigationBarTitleDisplayMode(.inline)
        .exListStyle()
    }
}
