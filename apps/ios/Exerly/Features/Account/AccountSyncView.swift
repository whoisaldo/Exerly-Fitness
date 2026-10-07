import ExerlyCore
import SwiftUI

struct AccountSyncView: View {
    @ObservedObject var workspace: TrainingWorkspace

    var body: some View {
        List {
            Section("Account backup") {
                if let engine = workspace.sync {
                    status(engine)
                    if let date = engine.lastSyncedAt {
                        LabeledContent("Last synced") {
                            Text(date, format: .dateTime.month().day().hour().minute())
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    Button("Sync now", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await workspace.synchronize() }
                    }
                    .disabled(engine.state == .syncing)
                    .accessibilityIdentifier("account.syncNow")
                    if !engine.rejected.isEmpty {
                        Text("Some items from another device could not be read. They are kept on your account for a future update.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Text("Your workouts and food log are saved on this device. When connected, Exerly syncs them along with programs, foods, nutrition targets and agent proposals.")
                Text("You can keep logging offline. Your saved changes sync when Exerly reconnects.")
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.exBackground)
        .task { await workspace.synchronize() }
    }

    @ViewBuilder
    private func status(_ engine: ExerlyCore.SyncEngine) -> some View {
        switch engine.state {
        case .syncing: ProgressView("Syncing account…")
        case .idle:
            Label(engine.lastSyncedAt == nil ? "Ready to sync" : "Account synced", systemImage: "checkmark.icloud")
                .accessibilityIdentifier("account.syncStatus")
        case .offline:
            Label("Offline. Your changes are saved on this device.", systemImage: "wifi.slash")
                .accessibilityIdentifier("account.syncStatus")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.icloud")
                .foregroundStyle(Color.exError)
                .accessibilityIdentifier("account.syncStatus")
        }
    }
}
