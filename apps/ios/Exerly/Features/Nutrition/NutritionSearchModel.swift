import Combine
import ExerlyCore
import Foundation

@MainActor
final class NutritionSearchModel: ObservableObject {
    enum Request: Equatable {
        case search(String)
        case barcode(String)
    }

    /// Typing searches the database only from this many characters, after a
    /// pause, so a word costs one request rather than one per keystroke. The
    /// server spends a shared Open Food Facts budget on each search.
    static let typeAheadMinimum = 3

    @Published private(set) var request: Request?
    @Published private(set) var result: DatabaseFoods?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    private let api: AccountAPI
    private let pause: Duration
    private var generation = 0
    private var closed = false
    private var pending: Task<Void, Never>?
    private var cache: [String: DatabaseFoods] = [:]
    private var cacheOrder: [String] = []

    init(api: AccountAPI, pause: Duration = .milliseconds(400)) {
        self.api = api
        self.pause = pause
    }

    /// Call on every keystroke. Searches once typing pauses; a newer keystroke
    /// cancels both the wait and a request still in flight. Results already
    /// shown stay until newer ones replace them.
    func type(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isLoading, request == .search(query) { return }
        pending?.cancel()
        guard query.count >= Self.typeAheadMinimum else { clear(); return }
        if shownQuery == query, error == nil { request = .search(query); return }
        if let cached = cache[query.lowercased()] { show(cached, for: query); return }
        pending = Task { [weak self, pause] in
            try? await Task.sleep(for: pause)
            guard !Task.isCancelled else { return }
            await self?.load(.search(query), keepResult: true)
        }
    }

    /// Searches now, as when the person submits the search.
    func search(_ text: String) async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isLoading, request == .search(query) { return }
        pending?.cancel()
        guard !query.isEmpty else { clear(); return }
        if shownQuery == query, error == nil { request = .search(query); return }
        if let cached = cache[query.lowercased()] { show(cached, for: query); return }
        await load(.search(query), keepResult: true)
    }

    /// The search whose results are shown; they can lag the latest request
    /// while it loads.
    @Published private(set) var shownQuery: String?

    func lookup(_ text: String, symbology: AccountAPI.BarcodeSymbology? = nil) async {
        let digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !digits.isEmpty else { clear(); return }
        await load(.barcode(digits), symbology: symbology)
    }

    func clear() {
        pending?.cancel()
        generation += 1
        request = nil
        result = nil
        shownQuery = nil
        error = nil
        isLoading = false
    }

    func close() {
        closed = true
        clear()
    }

    private func show(_ cached: DatabaseFoods, for query: String) {
        generation += 1
        request = .search(query)
        result = cached
        shownQuery = query
        error = nil
        isLoading = false
    }

    private func load(_ request: Request, symbology: AccountAPI.BarcodeSymbology? = nil, keepResult: Bool = false) async {
        guard !closed else { return }
        generation += 1
        let current = generation
        self.request = request
        if !keepResult { result = nil; shownQuery = nil }
        error = nil
        isLoading = true
        defer { if generation == current { isLoading = false } }
        do {
            let found: DatabaseFoods?
            switch request {
            case .search(let query): found = try await api.searchFoods(query)
            case .barcode(let digits): found = try await api.food(barcode: digits, symbology: symbology)
            }
            guard !closed, generation == current, !Task.isCancelled else { return }
            result = found
            shownQuery = nil
            if case .search(let query) = request, let found { shownQuery = query; remember(found, for: query) }
        } catch {
            guard !closed, generation == current, !Task.isCancelled else { return }
            result = nil
            shownQuery = nil
            if case ExerlyCore.APIError.server(let status, let message) = error, status == 400 || status == 429 {
                self.error = message
            } else {
                self.error = "The food database is unavailable. Try again, use a saved food, or enter the label manually."
            }
        }
    }

    private func remember(_ foods: DatabaseFoods, for query: String) {
        let key = query.lowercased()
        if cache.updateValue(foods, forKey: key) == nil { cacheOrder.append(key) }
        if cacheOrder.count > 40 { cache[cacheOrder.removeFirst()] = nil }
    }
}
