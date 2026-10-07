import ExerlyCore
import SwiftUI
import UIKit

/// Presentation values and injected account-service operations. The shared
/// Core session owner supplies these actions when its bridge is available.
struct AccountSignInMethods: Equatable {
    let appleConnected: Bool
    let hasPassword: Bool
}

struct AccountManagementActions {
    var signInMethods: @MainActor () async throws -> AccountSignInMethods
    var connectApple: @MainActor (AppleAuthorizationResult) async throws -> AccountSignInMethods
    var disconnectApple: @MainActor () async throws -> AccountSignInMethods
    var exportAccount: @MainActor () async throws -> Data
    var deleteAccount: @MainActor (String?) async throws -> Void
    var exportDeviceData: (@MainActor () throws -> Data)?
}

struct AccountManagementView: View {
    let accountID: String
    let email: String
    let actions: AccountManagementActions
    @State private var methods: AccountSignInMethods?
    @State private var busy: String?
    @State private var error: String?
    @State private var disconnecting = false
    @State private var exportFile: AccountExportFile?
    @State private var task: Task<Void, Never>?
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        ExList {
            Section {
                ExCard(accent: true) {
                    HStack(alignment: .top, spacing: ExSpacing.item) {
                        Image(systemName: "person.crop.circle.badge.checkmark").font(.system(size: 28, weight: .light))
                            .foregroundStyle(Color.exPrimaryText).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: ExSpacing.small) {
                            ExEyebrow("Your account", color: .exPrimaryText)
                            Text(email).font(.exBodyMedium).textSelection(.enabled)
                                .accessibilityIdentifier("account.email").fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            Section("Sign-in methods") {
                if let methods {
                    Label(methods.hasPassword ? "Email and password" : "No password set",
                          systemImage: methods.hasPassword ? "lock" : "lock.slash")
                    if methods.appleConnected {
                        Label("Apple connected", systemImage: "checkmark.circle")
                        Button("Disconnect Apple", role: .destructive) { disconnecting = true }
                            .disabled(!methods.hasPassword || busy != nil)
                            .accessibilityIdentifier("account.disconnectApple")
                        if !methods.hasPassword {
                            Text("Keep Apple connected so you can sign in to this account.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Connect Apple to sign in to this same account.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        AppleAuthorizationButton { payload in
                            guard busy == nil else { return }
                            busy = "Connecting Apple…"
                            defer { busy = nil }
                            let updated = try await actions.connectApple(payload)
                            try Task.checkCancellation()
                            self.methods = updated
                        }
                        .disabled(busy != nil)
                    }
                } else if busy == nil {
                    Button("Load sign-in methods") { start { try await loadMethods() } }
                }
            }
            Section {
                Button("Export account data", systemImage: "square.and.arrow.up") {
                    start {
                        busy = "Preparing export…"
                        let data = try await actions.exportAccount()
                        try Task.checkCancellation()
                        exportFile = try AccountExportFile(data: data)
                    }
                }
                .disabled(busy != nil)
                .accessibilityIdentifier("account.export").buttonStyle(ExActionStyle())
            } header: {
                Text("Your data")
            } footer: {
                Text("A JSON file with your account records, workouts and suggestions. Includes changes saved on this device that are still waiting to sync.")
            }
            if let exportDeviceData = actions.exportDeviceData {
                Section {
                    Button("Export saved device data", systemImage: "iphone.and.arrow.forward") {
                        start {
                            exportFile = try AccountExportFile(data: exportDeviceData(), deviceOnly: true)
                        }
                    }
                    .disabled(busy != nil)
                    .accessibilityIdentifier("account.exportDevice")
                } footer: {
                    Text("Works offline. Includes this device’s training, suggestions and entries waiting to sync. Account details and records kept only on the server are excluded.")
                }
            }
            Section {
                if let methods {
                    NavigationLink {
                        DeleteAccountView(email: email, appleConnected: methods.appleConnected,
                                          delete: actions.deleteAccount)
                    } label: {
                        Label("Delete account", systemImage: "trash")
                            .foregroundStyle(Color.exError)
                    }
                    .disabled(busy != nil)
                    .accessibilityIdentifier("account.delete")
                }
            }
            if let busy { Section { ProgressView(busy) } }
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.circle")
                        .foregroundStyle(Color.exError)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityFocused($errorFocused)
                        .accessibilityIdentifier("account.error")
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .exListStyle()
        .task(id: accountID) {
            do { try await loadMethods() }
            catch is CancellationError { }
            catch { showError(error) }
        }
        .alert("Disconnect Apple?", isPresented: $disconnecting) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect Apple", role: .destructive) {
                start {
                    busy = "Disconnecting Apple…"
                    let updated = try await actions.disconnectApple()
                    try Task.checkCancellation()
                    methods = updated
                }
            }
        } message: {
            Text("You will use your email and password to sign in.")
        }
        .sheet(item: $exportFile) { file in
            AccountShareSheet(url: file.url)
                .onDisappear { file.remove() }
        }
        .onDisappear { task?.cancel() }
    }

    private func loadMethods() async throws {
        busy = "Loading account…"
        defer { busy = nil }
        let loaded = try await actions.signInMethods()
        try Task.checkCancellation()
        methods = loaded
    }

    private func start(_ operation: @escaping @MainActor () async throws -> Void) {
        guard busy == nil else { return }
        error = nil
        busy = "Working…"
        task = Task { @MainActor in
            defer { busy = nil }
            do { try await operation() }
            catch is CancellationError { }
            catch {
                guard !Task.isCancelled else { return }
                showError(error)
            }
        }
    }

    private func showError(_ failure: Error) {
        error = AccountScreenError.message(failure)
        errorFocused = true
    }
}

private struct DeleteAccountView: View {
    let email: String
    let appleConnected: Bool
    let delete: @MainActor (String?) async throws -> Void
    @State private var confirm = false
    @State private var needsApple = false
    @State private var deleting = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        ExList {
            Section {
                Text(email).textSelection(.enabled)
                Text("Deleting your account removes its training, food, body measurements and other saved records from Exerly and this device. This cannot be undone.")
                Text("Exports you saved elsewhere and records already shared with Apple Health remain there.")
                    .foregroundStyle(.secondary)
            }
            Section {
                if needsApple {
                    Text("Confirm with Apple to finish deleting this account.")
                    AppleAuthorizationButton { payload in
                        guard let code = payload.authorizationCode, !code.isEmpty else {
                            throw DeleteError.missingAppleCode
                        }
                        try await performDelete(code)
                    }
                    .disabled(deleting)
                } else {
                    Button("Delete my account", role: .destructive) { confirm = true }
                        .disabled(deleting)
                        .accessibilityIdentifier("account.confirmDelete")
                }
            }
            if deleting { Section { ProgressView("Deleting account…") } }
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.circle")
                        .foregroundStyle(Color.exError)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityFocused($errorFocused)
                }
            }
        }
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.inline)
        .exListStyle()
        .interactiveDismissDisabled(deleting)
        .navigationBarBackButtonHidden(deleting)
        .alert("Delete this account?", isPresented: $confirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete account", role: .destructive) {
                if appleConnected { needsApple = true }
                else {
                    task = Task { @MainActor in
                        do { try await performDelete(nil) }
                        catch is CancellationError { }
                        catch {
                            guard !Task.isCancelled else { return }
                            self.error = AccountScreenError.message(error)
                            errorFocused = true
                        }
                    }
                }
            }
        } message: {
            Text("Your saved Exerly records will be permanently removed.")
        }
        .onDisappear { task?.cancel() }
    }

    private func performDelete(_ code: String?) async throws {
        guard !deleting else { return }
        error = nil
        deleting = true
        defer { deleting = false }
        do { try await delete(code) }
        catch ExerlyCore.APIError.appleReauthorizationRequired { needsApple = true }
    }

    private enum DeleteError: LocalizedError {
        case missingAppleCode
        var errorDescription: String? { "Apple authorization expired. Confirm with Apple again." }
    }
}

struct AccountExportFile: Identifiable {
    let id = UUID()
    let url: URL

    init(data: Data, directory: URL = FileManager.default.temporaryDirectory, deviceOnly: Bool = false) throws {
        _ = try JSONSerialization.jsonObject(with: data)
        let folder = directory.appendingPathComponent("ExerlyExport-\(id.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent(deviceOnly ? "exerly-device.json" : "exerly-account.json")
        do { try data.write(to: url, options: [.atomic, .completeFileProtection]) }
        catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    func remove() { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
}

private struct AccountShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
