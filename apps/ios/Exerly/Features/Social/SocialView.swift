import SwiftUI

enum SocialTab: String, CaseIterable {
    case friends = "Friends"
    case challenges = "Challenges"
}

struct SocialView: View {
    @State private var selectedTab: SocialTab = .friends

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                tabContent
            }
            .background(Color.exBackground)
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(SocialTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.exLabel)
                        .foregroundStyle(selectedTab == tab ? .exPrimary : .exTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if selectedTab == tab {
                                Capsule().fill(Color.exPrimary).frame(height: 2)
                            }
                        }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .friends: FriendsTab()
        case .challenges: ChallengesTab()
        }
    }
}

// MARK: - Friends Tab

struct FriendsTab: View {
    @State private var showAddFriend = false

    var body: some View {
        EmptyStateView(
            icon: "person.2",
            title: "No friends yet",
            message: "Add friends to compare progress and stay motivated",
            actionTitle: "Add Friend"
        ) {
            showAddFriend = true
        }
        .sheet(isPresented: $showAddFriend) { AddFriendSheet() }
    }
}

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                FloatingLabelTextField(label: "Friend's email", text: $email, keyboardType: .emailAddress)
                ActionButton(title: "Send Request", isDisabled: email.isEmpty) {
                    dismiss()
                }
                Spacer()
            }
            .padding(20)
            .background(Color.exBackground)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.exTextSecondary)
                }
            }
        }
    }
}

// MARK: - Challenges Tab

struct ChallengesTab: View {
    @State private var showCreateChallenge = false

    var body: some View {
        EmptyStateView(
            icon: "trophy",
            title: "No challenges",
            message: "Create a challenge and compete with friends",
            actionTitle: "Create Challenge"
        ) {
            showCreateChallenge = true
        }
        .sheet(isPresented: $showCreateChallenge) { CreateChallengeSheet() }
    }
}

struct CreateChallengeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type = "steps"

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                FloatingLabelTextField(label: "Challenge Name", text: $name)

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Type")
                            .font(.exLabel)
                            .foregroundStyle(.exTextSecondary)
                        HStack(spacing: 10) {
                            ForEach(["steps", "calories", "workouts"], id: \.self) { t in
                                Button {
                                    withAnimation { type = t }
                                } label: {
                                    Text(t.capitalized)
                                        .font(.exCaption)
                                        .foregroundStyle(type == t ? .white : .exTextSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(type == t ? Color.exPrimary : Color.exSurface2)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                ActionButton(title: "Create", isDisabled: name.isEmpty) { dismiss() }
                Spacer()
            }
            .padding(20)
            .background(Color.exBackground)
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.exTextSecondary)
                }
            }
        }
    }
}
