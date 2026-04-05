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

    var body: some View {
        VStack(spacing: 0) {
            picker
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(.exPrimary)
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
    }

    private var picker: some View {
        Picker("", selection: $selectedTab) {
            Text("Overview").tag(0)
            Text("Users").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(16)
    }

    // MARK: - Stats

    private var statsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let stats {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statCard("Total Users", value: "\(stats.totalUsers)", icon: "person.3.fill", color: .exPrimary)
                        statCard("Active Today", value: "\(stats.activeToday)", icon: "bolt.fill", color: .exAccent)
                        statCard("Total Entries", value: "\(stats.totalEntries)", icon: "list.bullet", color: .exSuccess)
                        statCard("Activities", value: "\(stats.breakdown?.activities ?? 0)", icon: "figure.run", color: .orange)
                        statCard("Food Logs", value: "\(stats.breakdown?.food ?? 0)", icon: "fork.knife", color: .green)
                        statCard("Sleep Logs", value: "\(stats.breakdown?.sleep ?? 0)", icon: "bed.double.fill", color: .indigo)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }

    private func statCard(_ title: String, value: String, icon: String, color: Color) -> some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                Text(value)
                    .font(.exH2)
                    .foregroundStyle(.exTextPrimary)
                Text(title)
                    .font(.exCaption)
                    .foregroundStyle(.exTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Users

    private var usersView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(users) { user in
                    userRow(user)
                }
            }
            .padding(16)
            .padding(.bottom, 100)
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
            // Silently fail — user can pull to retry
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
