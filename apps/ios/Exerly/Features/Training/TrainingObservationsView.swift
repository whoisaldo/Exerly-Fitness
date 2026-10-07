import Combine
import ExerlyCore
import SwiftUI

@MainActor
final class TrainingObservationsModel: ObservableObject {
    @Published private(set) var findings: [Diagnosis] = []
    @Published private(set) var isLoading = true
    @Published private(set) var through: LocalDate?
    private var generation = 0

    func refresh(history: TrainingHistory, now: Date, timeZone: TimeZone) async {
        generation += 1
        let current = generation
        let date = LocalDate(now, in: timeZone)
        isLoading = true
        let task = Task.detached(priority: .utility) {
            var result = TrainingSignals.stalls(in: history, through: date)
            if let deload = TrainingSignals.deload(in: history, through: date) { result.append(deload) }
            return result
        }
        let result = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        guard current == generation, !Task.isCancelled else { return }
        findings = result
        through = date
        isLoading = false
    }
}

struct TrainingObservationsView: View {
    @ObservedObject var workspace: TrainingWorkspace
    let unit: MassUnit
    let timeZone: TimeZone
    @StateObject private var observations = TrainingObservationsModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                Text("Patterns in your saved workouts, with the numbers and limits behind each observation. Nothing here changes your training.")
                    .foregroundStyle(.secondary)
            }
            Section("From your training log") {
                if observations.isLoading { ProgressView("Reading saved workouts…") } else if observations.findings.isEmpty {
                    Text("No observations yet").font(.headline)
                    Text("There may not be enough comparable workouts. No finding does not tell you whether training or recovery is going well.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("observations.empty")
                } else {
                    ForEach(Array(observations.findings.enumerated()), id: \.offset) { _, finding in
                        NavigationLink {
                            TrainingObservationDetailView(finding: finding, store: workspace.store, unit: unit)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(finding.title).font(.headline)
                                Text(finding.summary).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }.accessibilityIdentifier("observations.\(finding.kind.rawValue).\(finding.exerciseIDs.map(\.rawValue).joined(separator: "."))")
                    }
                }
            }
            if let date = observations.through {
                Section {
                    Text("Through \(date.description) · \(timeZone.identifier)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            EntryChecksSection(checks: workspace.entryChecks, workspace: workspace, unit: unit)
        }
        .navigationTitle("Observations").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(Color.exBackground)
        .task(id: TrainingAnalysisInput(workspace.store.history)) { await refresh() }
        .onChange(of: timeZone) { _, _ in Task { await refresh() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
        .refreshable {
            await workspace.synchronize()
            await refresh()
        }
    }

    private func refresh() async {
        await observations.refresh(history: workspace.store.history, now: Date(), timeZone: timeZone)
    }
}

private struct EntryChecksSection: View {
    @ObservedObject var checks: TrainingEntryChecks
    let workspace: TrainingWorkspace
    let unit: MassUnit

    var body: some View {
        Section {
            Toggle("Entry checks", isOn: Binding(get: { checks.isEnabled }, set: { enabled in
                checks.setEnabled(enabled)
                if enabled { Task { await workspace.synchronize() } }
            })).accessibilityIdentifier("observations.entryChecks")
            if checks.isChecking { ProgressView("Checking saved workouts…") }
            if let error = checks.error {
                Text(error).foregroundStyle(Color.exWarning).accessibilityIdentifier("observations.checkError")
                Button("Retry entry checks") {
                    Task {
                        await checks.retry()
                        await workspace.synchronize()
                    }
                }.disabled(checks.isChecking)
                    .accessibilityIdentifier("observations.retryChecks")
            }
            NavigationLink {
                AgentReviewView(workspace: workspace, unit: unit)
            } label: { Text("Review suggestions").fixedSize(horizontal: false, vertical: true) }
                .accessibilityIdentifier("observations.suggestions")
        } header: { Text("Optional checks") }
        footer: {
            Text("Check workouts finished in the last \(EntryErrorDetector.recentDays) days for likely typing mistakes on this device, including offline. Suggested corrections wait for your approval. Turning this off keeps existing suggestions and decisions. No data is sent to an AI service. This setting applies to this account on this device.")
        }
    }
}

private struct TrainingObservationDetailView: View {
    let finding: Diagnosis
    let store: TrainingStore
    let unit: MassUnit

    var body: some View {
        List {
            Section {
                Text(finding.title).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text(finding.summary)
                Text("An observation from your log. It does not establish a cause or change your plan.")
                    .foregroundStyle(.secondary)
            }
            Section("Evidence and limits") {
                ForEach(Array(finding.evidence.enumerated()), id: \.offset) { _, evidence in
                    ProposalEvidenceView(evidence: evidence, store: store, unit: unit)
                }
            }
        }
        .navigationTitle("Training observation").navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden).background(Color.exBackground)
    }
}
