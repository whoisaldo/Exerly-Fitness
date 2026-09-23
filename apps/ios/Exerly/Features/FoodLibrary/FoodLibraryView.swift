import SwiftUI

enum FoodLibraryTab: String, CaseIterable {
    case all = "Recent"
    case favorites = "Favorites"
    case myFoods = "My Foods"
}

@MainActor
final class FoodLibraryViewModel: ObservableObject {
    @Published private(set) var foods: [LibraryFoodDTO] = []
    @Published private(set) var searchLibrary: [LibraryFoodDTO] = []
    @Published private(set) var searchProviders: [SearchFoodDTO] = []
    @Published private(set) var activeQuery = ""
    @Published private(set) var isLoading = false
    @Published private(set) var updatingFavoriteIds: Set<String> = []
    @Published var error: String?

    private let api = APIClient.shared
    private var requestedQuery = ""

    func load(favoritesOnly: Bool) async {
        isLoading = true
        error = nil
        do {
            foods = try await api.getLibraryFoods(limit: 200, favoritesOnly: favoritesOnly)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func search(_ rawQuery: String) async {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            clearSearch()
            return
        }

        requestedQuery = query
        activeQuery = query
        isLoading = true
        error = nil
        do {
            let response = try await api.searchFoods(query)
            guard requestedQuery == query else { return }
            searchLibrary = response.library
            searchProviders = response.results
        } catch {
            guard requestedQuery == query else { return }
            self.error = error.localizedDescription
        }
        if requestedQuery == query { isLoading = false }
    }

    func clearSearch() {
        requestedQuery = ""
        activeQuery = ""
        searchLibrary = []
        searchProviders = []
        error = nil
        isLoading = false
    }

    func toggleFavorite(_ food: LibraryFoodDTO, favoritesOnly: Bool) async {
        updatingFavoriteIds.insert(food.id)
        error = nil
        do {
            let updated = try await api.toggleFavorite(foodId: food.id)
            replace(updated, in: &foods, removeIfNotFavorite: favoritesOnly)
            replace(updated, in: &searchLibrary, removeIfNotFavorite: false)
        } catch {
            self.error = error.localizedDescription
        }
        updatingFavoriteIds.remove(food.id)
    }

    private func replace(
        _ updated: LibraryFoodDTO,
        in collection: inout [LibraryFoodDTO],
        removeIfNotFavorite: Bool
    ) {
        guard let index = collection.firstIndex(where: { $0.id == updated.id }) else { return }
        if removeIfNotFavorite && !updated.isFavorite {
            collection.remove(at: index)
        } else {
            collection[index] = updated
        }
    }
}

struct FoodLibraryView: View {
    @EnvironmentObject private var sync: SyncEngine
    @StateObject private var viewModel = FoodLibraryViewModel()
    @State private var searchText = ""
    @State private var selectedTab: FoodLibraryTab = .all

    private var visibleFoods: [LibraryFoodDTO] {
        switch selectedTab {
        case .all, .favorites:
            viewModel.foods
        case .myFoods:
            viewModel.foods.filter { $0.source?.lowercased() == "custom" }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            stickySearch
            tabPicker
            contentArea
        }
        .background(Color.exBackground)
        .navigationTitle("Food Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: CreateFoodView()) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.exPrimary)
                }
                .accessibilityLabel("Create food")
            }
        }
        .task(id: selectedTab) {
            guard viewModel.activeQuery.isEmpty else { return }
            await viewModel.load(favoritesOnly: selectedTab == .favorites)
        }
        .onChange(of: searchText) { _, value in
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.clearSearch()
                Task { await viewModel.load(favoritesOnly: selectedTab == .favorites) }
            }
        }
    }

    private var stickySearch: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.exTextMuted)
            TextField("Search foods…", text: $searchText)
                .font(.exBody)
                .foregroundStyle(.exTextPrimary)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.search(searchText) } }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.exTextMuted)
                }
                .accessibilityLabel("Clear search")
            }
            NavigationLink(destination: BarcodeScannerView(initialDate: sync.today)) {
                Image(systemName: "barcode.viewfinder")
                    .foregroundStyle(.exPrimary)
            }
        }
        .padding(12)
        .background(Color.exSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(FoodLibraryTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.exLabel)
                        .foregroundStyle(selectedTab == tab ? .exPrimary : .exTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.exPrimary)
                                    .frame(height: 2)
                            }
                        }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading {
            LoadingStateView(
                message: viewModel.activeQuery.isEmpty ? "Loading your foods…" : "Searching…"
            )
        } else if let error = viewModel.error,
                  visibleFoods.isEmpty,
                  viewModel.searchLibrary.isEmpty,
                  viewModel.searchProviders.isEmpty {
            ErrorStateView(message: error) {
                Task {
                    if viewModel.activeQuery.isEmpty {
                        await viewModel.load(favoritesOnly: selectedTab == .favorites)
                    } else {
                        await viewModel.search(viewModel.activeQuery)
                    }
                }
            }
        } else if !viewModel.activeQuery.isEmpty {
            searchResults
        } else if visibleFoods.isEmpty {
            emptyState
        } else {
            libraryList(visibleFoods)
        }
    }

    private var emptyState: some View {
        let title: String
        let message: String
        let icon: String

        switch selectedTab {
        case .all:
            title = "No recent foods"
            message = "Anything you log will be remembered here automatically."
            icon = "fork.knife"
        case .favorites:
            title = "No favorites yet"
            message = "Tap the heart beside a food to keep it close."
            icon = "heart"
        case .myFoods:
            title = "No custom foods"
            message = "Create a food with the plus button above."
            icon = "plus.circle"
        }

        return EmptyStateView(icon: icon, title: title, message: message)
    }

    private func libraryList(_ foods: [LibraryFoodDTO]) -> some View {
        ScrollView {
            LazyVStack(spacing: 9) {
                ForEach(foods) { food in
                    libraryRow(food)
                }
            }
            .padding(20)
            .padding(.bottom, 90)
        }
        .refreshable { await viewModel.load(favoritesOnly: selectedTab == .favorites) }
    }

    private var searchResults: some View {
        Group {
            if viewModel.searchLibrary.isEmpty && viewModel.searchProviders.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No results",
                    message: "Try a different food or brand."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if !viewModel.searchLibrary.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionHeader("Your foods", detail: "Logged before")
                                ForEach(viewModel.searchLibrary) { food in
                                    libraryRow(food)
                                }
                            }
                        }

                        if !viewModel.searchProviders.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionHeader("More results", detail: "Food databases")
                                ForEach(viewModel.searchProviders) { food in
                                    NavigationLink(destination: FoodDetailView(food: food.openFoodItem, initialDate: sync.today)) {
                                        FoodCardView(food: food.openFoodItem)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 90)
                }
            }
        }
    }

    private func libraryRow(_ food: LibraryFoodDTO) -> some View {
        HStack(spacing: 10) {
            NavigationLink(destination: FoodDetailView(food: food.openFoodItem, initialDate: sync.today)) {
                FoodLibraryRowContent(food: food)
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    await viewModel.toggleFavorite(
                        food,
                        favoritesOnly: selectedTab == .favorites && viewModel.activeQuery.isEmpty
                    )
                }
            } label: {
                Group {
                    if viewModel.updatingFavoriteIds.contains(food.id) {
                        ProgressView().tint(.exPrimary)
                    } else {
                        Image(systemName: food.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(food.isFavorite ? .exPrimary : .exTextMuted)
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.exSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.updatingFavoriteIds.contains(food.id))
            .accessibilityLabel(food.isFavorite ? "Remove favorite" : "Add favorite")
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.exLabel)
                .foregroundStyle(.exTextPrimary)
            Spacer()
            Text(detail)
                .font(.exSmall)
                .foregroundStyle(.exTextMuted)
        }
    }
}

private struct FoodLibraryRowContent: View {
    let food: LibraryFoodDTO

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.exBodyMedium)
                    .foregroundStyle(.exTextPrimary)
                    .lineLimit(1)
                if let brand = food.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.exSmall)
                        .foregroundStyle(.exTextMuted)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    macroPill("P", value: food.protein ?? 0, color: .exPrimary)
                    macroPill("C", value: food.carbs ?? 0, color: .exSuccess)
                    macroPill("F", value: food.fat ?? 0, color: .exWarning)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(food.calories.formatted())
                    .font(.exStatSmall)
                    .foregroundStyle(.exPrimary)
                Text("kcal")
                    .font(.exSmall)
                    .foregroundStyle(.exTextMuted)
                if food.useCount > 0 {
                    Text("used \(food.useCount)×")
                        .font(.exSmall.monospacedDigit())
                        .foregroundStyle(.exTextMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func macroPill(_ label: String, value: Double, color: Color) -> some View {
        Text("\(label) \(Int(value.rounded()))g")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

struct FoodCardView: View {
    let food: OpenFoodItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.exBodyMedium)
                    .foregroundStyle(.exTextPrimary)
                    .lineLimit(1)
                if let brand = food.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.exSmall)
                        .foregroundStyle(.exTextMuted)
                }
                HStack(spacing: 8) {
                    macroPill("P", value: food.protein, color: .exPrimary)
                    macroPill("C", value: food.carbs, color: .exSuccess)
                    macroPill("F", value: food.fat, color: .exWarning)
                }
            }
            Spacer()
            VStack(spacing: 2) {
                Text(food.calories.formatted())
                    .font(.exStatSmall)
                    .foregroundStyle(.exPrimary)
                Text("kcal")
                    .font(.exSmall)
                    .foregroundStyle(.exTextMuted)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 12)
    }

    private func macroPill(_ label: String, value: Double, color: Color) -> some View {
        Text("\(label) \(Int(value.rounded()))g")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}
