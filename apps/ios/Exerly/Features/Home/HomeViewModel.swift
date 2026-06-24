import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var dashboard: DashboardData?
    @Published var recentActivities: [ActivityDTO] = []
    @Published var recentFood: [FoodDTO] = []
    @Published var weeklyData: [WeeklyDayDTO] = []
    @Published var waterGlasses: Int = 0
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
        // These are secondary; don't fail the whole dashboard if they error.
        if let weekly = try? await api.getWeeklyDashboard() { weeklyData = weekly }
        if let water = try? await api.getWater() { waterGlasses = water.glasses }
        isLoading = false
    }

    func addWater(_ delta: Int = 1) async {
        do {
            let updated = try await api.addWater(delta: delta)
            waterGlasses = updated.glasses
        } catch {
            print("Water update failed: \(error)")
        }
    }
}
