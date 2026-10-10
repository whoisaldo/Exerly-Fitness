import Foundation

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
