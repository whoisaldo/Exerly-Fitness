import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var dashboard: DashboardData?
    @Published var recentActivities: [ActivityDTO] = []
    @Published var recentFood: [FoodDTO] = []
    @Published var isLoading = false
    @Published var error: String?

    private let api = APIClient.shared

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    var caloriesConsumed: Int { dashboard?.calories?.consumed ?? 0 }
    var caloriesTarget: Int { dashboard?.calories?.target ?? 2000 }
    var workoutsCompleted: Int { dashboard?.workouts?.completed ?? 0 }
    var workoutsTarget: Int { dashboard?.workouts?.target ?? 5 }
    var sleepHours: Double { dashboard?.sleep?.hours ?? 0 }
    var sleepTarget: Double { dashboard?.sleep?.target ?? 8 }

    func load() async {
        isLoading = true
        error = nil
        do {
            async let dashboardTask = api.getDashboardData()
            async let recentTask = api.getRecentData()
            let (d, r) = try await (dashboardTask, recentTask)
            dashboard = d
            recentActivities = r.activities ?? []
            recentFood = r.food ?? []
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
