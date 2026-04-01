import Foundation

struct Friend: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let streak: Int?
}

struct Challenge: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let startDate: String
    let endDate: String
    let participants: [ChallengeParticipant]
}

struct ChallengeParticipant: Identifiable, Codable {
    let id: String
    let name: String
    let score: Int
    let rank: Int
}

@MainActor
final class SocialService: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var challenges: [Challenge] = []
    @Published var isLoading = false

    static let shared = SocialService()
    private init() {}

    func loadFriends() async {
        // Placeholder — API integration would go here
        isLoading = true
        try? await Task.sleep(for: .seconds(0.5))
        isLoading = false
    }

    func addFriend(email: String) async -> Bool {
        // Placeholder
        try? await Task.sleep(for: .seconds(0.5))
        return true
    }

    func loadChallenges() async {
        isLoading = true
        try? await Task.sleep(for: .seconds(0.5))
        isLoading = false
    }

    func createChallenge(name: String, type: String) async -> Bool {
        try? await Task.sleep(for: .seconds(0.5))
        return true
    }
}
