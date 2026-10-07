import Combine
import ExerlyCore
import Foundation

@MainActor
final class NutritionSearchModel: ObservableObject {
    enum Request: Equatable {
        case search(String)
        case barcode(String)
    }

    @Published private(set) var request: Request?
    @Published private(set) var result: DatabaseFoods?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    private let api: AccountAPI
    private var generation = 0
    private var closed = false

    init(api: AccountAPI) { self.api = api }

    func search(_ text: String) async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { clear(); return }
        await load(.search(query))
    }

    func lookup(_ text: String) async {
        let digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !digits.isEmpty else { clear(); return }
        await load(.barcode(digits))
    }

    func clear() {
        generation += 1
        request = nil
        result = nil
        error = nil
        isLoading = false
    }

    func close() {
        closed = true
        clear()
    }

    private func load(_ request: Request) async {
        guard !closed else { return }
        generation += 1
        let current = generation
        self.request = request
        result = nil
        error = nil
        isLoading = true
        defer { if generation == current { isLoading = false } }
        do {
            let found: DatabaseFoods?
            switch request {
            case .search(let query): found = try await api.searchFoods(query)
            case .barcode(let digits): found = try await api.food(barcode: digits)
            }
            guard !closed, generation == current, !Task.isCancelled else { return }
            result = found
        } catch {
            guard !closed, generation == current, !Task.isCancelled else { return }
            if case ExerlyCore.APIError.server(let status, let message) = error, status == 400 || status == 429 {
                self.error = message
            } else {
                self.error = "The food database is unavailable. Try again, use a saved food, or enter the label manually."
            }
        }
    }
}
