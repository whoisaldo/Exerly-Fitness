import ExerlyCore
import SwiftUI

struct AccountSyncView: View {
    @ObservedObject var workspace: TrainingWorkspace
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ExScreen {
            ExCard(accent: true) {
                Image(systemName: statusSymbol).font(.system(size: 36, weight: .light)).foregroundStyle(Color.exPrimaryText)
                    .accessibilityHidden(true)
                ExEyebrow("Backup", color: .exPrimaryText)
                if let engine = workspace.sync {
                    status(engine).font(.exH2).labelStyle(.titleOnly)
                    if let date = engine.lastSyncedAt {
                        if typeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: ExSpacing.tight) {
                                Text("Last synced").foregroundStyle(Color.exTextSecondary)
                                Text(date, format: .dateTime.month().day().hour().minute())
                            }.font(.exCaption)
                        } else {
                        LabeledContent("Last synced") {
                            Text(date, format: .dateTime.month().day().hour().minute())
                                .multilineTextAlignment(.trailing)
                        }.font(.exCaption)
                        }
                    }
                    Button("Sync now", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await workspace.synchronize() }
                    }
                    .buttonStyle(ExActionStyle())
                    .disabled(engine.state == .syncing)
                    .accessibilityIdentifier("account.syncNow")
                    if !engine.rejected.isEmpty {
                        Text("Some items from another device could not be read. They are kept on your account for a future update.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            ExCard {
                ExSectionHeading("Saved as you go")
                Text("Workouts, food and changes are saved on this device, even offline.")
                Text("When connected, your programs, foods, targets and agent proposals sync with your account.")
                    .foregroundStyle(Color.exTextSecondary)
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.exBackground)
        .task { await workspace.synchronize() }
    }

    private var statusSymbol: String {
        switch workspace.sync?.state {
        case .offline: "icloud.slash"
        case .failed: "exclamationmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        default: "checkmark.icloud"
        }
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
