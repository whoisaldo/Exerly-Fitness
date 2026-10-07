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

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published private(set) var summary: DaySummaryDTO?
    @Published private(set) var isLoading = false
    @Published private(set) var deletingFoodIds: Set<String> = []
    @Published private(set) var lastDeletedEntityID: String?
    @Published var error: String?

    private let api = APIClient.shared
    private var requestedDay: String?

    func load(for date: CalendarDay) async {
        let day = date.rawValue
        requestedDay = day
        isLoading = true
        error = nil

        if summary?.date != day {
            summary = try? await SyncEngine.shared.diary(for: date, cachedOnly: true)
        }

        do {
            await SyncEngine.shared.synchronize()
            let loaded = try await SyncEngine.shared.diary(for: date)
            guard requestedDay == day else { return }
            summary = loaded
        } catch {
            guard requestedDay == day else { return }
            self.error = error.localizedDescription
        }

        if requestedDay == day { isLoading = false }
    }

    func deleteFood(_ food: FoodDTO, from date: CalendarDay) async {
        guard let id = food.id else { return }
        deletingFoodIds.insert(id)
        error = nil
        do {
            lastDeletedEntityID = try SyncEngine.shared.deleteFood(food)
            await load(for: date)
        } catch {
            self.error = error.localizedDescription
        }
        deletingFoodIds.remove(id)
    }
    func undoDeletion(from date: CalendarDay) async {
        guard let id = lastDeletedEntityID else { return }
        do {
            try SyncEngine.shared.undoFoodDeletion(entityID: id)
            lastDeletedEntityID = nil
            await load(for: date)
        } catch { self.error = error.localizedDescription }
    }
}
