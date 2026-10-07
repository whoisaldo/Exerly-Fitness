import ExerlyCore
import SwiftUI

struct AccountSyncView: View {
    @ObservedObject var workspace: TrainingWorkspace
    @EnvironmentObject private var dailySync: SyncEngine
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var requestingSync = false

    var body: some View {
        ExScreen {
            ExCard(accent: true) {
                Image(systemName: statusSymbol).font(.system(size: 36, weight: .light)).foregroundStyle(Color.exPrimaryText)
                    .accessibilityHidden(true)
                if let engine = workspace.sync {
                    status(engine).font(.exH2).labelStyle(.titleOnly)
                    if let date = lastSyncedAt {
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
                        Task { await synchronizeAll() }
                    }
                    .buttonStyle(ExActionStyle())
                    .disabled(requestingSync || dailySync.isSyncing || engine.state == .syncing)
                    .accessibilityIdentifier("account.syncNow")
                    if !engine.rejected.isEmpty {
                        Text("Some items from another device could not be read. They are kept on your account for a future update.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if dailySync.attentionCount > 0 {
                        NavigationLink { SavedChangesReviewView() } label: {
                            ExNavigationLabel(title: "Review saved changes", icon: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            ExCard {
                ExSectionHeading("Saved as you go")
                Text("Workouts, food and changes are saved on this device, even offline.")
                Text("When connected, your workouts, foods, targets, activity, body measurements and agent proposals sync with your account.")
                    .foregroundStyle(Color.exTextSecondary)
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.exBackground)
        .task { await synchronizeAll() }
    }

    private func synchronizeAll() async {
        guard !requestingSync else { return }
        requestingSync = true
        defer { requestingSync = false }
        if dailySync.isConfigured(for: workspace.accountID) { await dailySync.synchronize(force: true) }
        await workspace.synchronize()
    }

    private var lastSyncedAt: Date? {
        guard dailySync.isConfigured(for: workspace.accountID),
              let daily = dailySync.lastSyncedAt, let training = workspace.sync?.lastSyncedAt else { return nil }
        return min(daily, training)
    }

    private var statusSymbol: String {
        if requestingSync || dailySync.isSyncing { return "arrow.triangle.2.circlepath.icloud" }
        if dailySync.attentionCount > 0 || dailySync.error != nil { return "exclamationmark.icloud" }
        if dailySync.pendingCount > 0 || dailySync.isOffline { return "icloud.slash" }
        switch workspace.sync?.state {
        case .offline: return "icloud.slash"
        case .failed: return "exclamationmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        default: return "checkmark.icloud"
        }
    }

    @ViewBuilder
    private func status(_ engine: ExerlyCore.SyncEngine) -> some View {
        if requestingSync || dailySync.isSyncing {
            ProgressView("Syncing account…")
        } else if dailySync.attentionCount > 0 {
            Text("Changes need your review").accessibilityIdentifier("account.syncStatus")
        } else if dailySync.pendingCount > 0 {
            Text("Changes waiting to sync").accessibilityIdentifier("account.syncStatus")
        } else if dailySync.isOffline {
            Text("Offline. Your changes are saved on this device.").accessibilityIdentifier("account.syncStatus")
        } else if let error = dailySync.error {
            Text(error).foregroundStyle(Color.exError).accessibilityIdentifier("account.syncStatus")
        } else {
        switch engine.state {
        case .syncing: ProgressView("Syncing account…")
        case .idle:
            Label(lastSyncedAt == nil ? "Ready to sync" : "Account synced", systemImage: "checkmark.icloud")
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
}
