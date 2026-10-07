import SwiftUI

// MARK: - Admin DTOs

struct AdminUserItem: Decodable, Identifiable {
    let id: String?
    let name: String?
    let email: String
    let createdAt: String?
    let isAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email
        case createdAt = "created_at"
        case isAdmin = "is_admin"
    }
}

struct AdminStats: Decodable {
    let totalUsers: Int
    let activeToday: Int
    let totalEntries: Int
    let breakdown: Breakdown?

    struct Breakdown: Decodable {
        let activities: Int
        let food: Int
        let sleep: Int
    }
}

struct ToggleAdminRequest: Encodable {
    let email: String
    let isAdmin: Bool
}

// MARK: - Admin View

struct AdminView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var users: [AdminUserItem] = []
    @State private var stats: AdminStats?
    @State private var isLoading = true
    @State private var selectedTab = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            picker
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(.exPrimaryText)
                Spacer()
            } else {
                switch selectedTab {
                case 0: statsView
                case 1: usersView
                default: EmptyView()
                }
            }
        }
        .background(Color.exBackground)
        .navigationTitle("Admin Panel")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .alert(
            "Couldn't load admin data",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("Retry") { Task { await loadData() } }
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var picker: some View {
        ExSegmentedControl(values: [0, 1], selection: $selectedTab) { $0 == 0 ? "Overview" : "Users" }
            .padding(ExSpacing.content)
    }

    private var statsView: some View {
        ExScreen {
            if let stats {
                ExCard(accent: true) {
                    ExEyebrow("Active today", color: .exPrimaryText)
                    Text(stats.activeToday.formatted()).font(.exStat)
                    Text("of \(stats.totalUsers.formatted()) accounts").font(.exBody).foregroundStyle(Color.exTextSecondary)
                }
                ExCard {
                    ExSectionHeading("Recorded entries", detail: stats.totalEntries.formatted())
                    LabeledContent("Activities", value: (stats.breakdown?.activities ?? 0).formatted())
                    Divider()
                    LabeledContent("Food logs", value: (stats.breakdown?.food ?? 0).formatted())
                    Divider()
                    LabeledContent("Sleep logs", value: (stats.breakdown?.sleep ?? 0).formatted())
                }
            } else {
                ExEmptyState(icon: "chart.bar", title: "Statistics unavailable",
                             message: "Connect to Exerly to load account activity.", action: "Try again") {
                    Task { await loadData() }
                }
            }
        }
    }

    // MARK: - Users

    private var usersView: some View {
        ExScreen {
            ExSectionHeading("Accounts", detail: users.count.formatted())
            if users.isEmpty {
                ExEmptyState(icon: "person.2", title: "No accounts loaded",
                             message: "Refresh to load the current account list.", action: "Refresh") {
                    Task { await loadData() }
                }
            } else {
                LazyVStack(spacing: ExSpacing.item) { ForEach(users) { user in userRow(user) } }
            }
        }
    }

    private func userRow(_ user: AdminUserItem) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Circle()
                    .fill(user.isAdmin == true ? Color.exPrimary : Color.exSurface2)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: user.isAdmin == true ? "shield.checkered" : "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(user.isAdmin == true ? .white : .exTextMuted)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name ?? "No Name")
                        .font(.exBodyMedium)
                        .foregroundStyle(.exTextPrimary)
                    Text(user.email)
                        .font(.exCaption)
                        .foregroundStyle(.exTextSecondary)
                }

                Spacer()

                Button {
                    Task { await toggleAdmin(user) }
                } label: {
                    Text(user.isAdmin == true ? "Admin" : "User")
                        .font(.exSmall)
                        .foregroundStyle(user.isAdmin == true ? .exPrimary : .exTextMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((user.isAdmin == true ? Color.exPrimary : Color.exSurface2).opacity(0.2))
                        .clipShape(Capsule())
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("\(user.email), \(user.isAdmin == true ? "Admin" : "User")")
            }
        }
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        async let fetchUsers: [AdminUserItem] = APIClient.shared.get("/api/admin/users")
        async let fetchStats: AdminStats = APIClient.shared.get("/api/admin/stats")

        do {
            let (u, s) = try await (fetchUsers, fetchStats)
            await MainActor.run {
                users = u
                stats = s
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    private func toggleAdmin(_ user: AdminUserItem) async {
        let newState = !(user.isAdmin ?? false)
        let _: APIMessageResponse? = try? await APIClient.shared.post(
            "/api/admin/toggle-admin",
            body: ToggleAdminRequest(email: user.email, isAdmin: newState)
        )
        await loadData()
    }
}
