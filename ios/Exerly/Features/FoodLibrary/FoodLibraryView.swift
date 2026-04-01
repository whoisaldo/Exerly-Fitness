import SwiftUI
import SwiftData

enum FoodLibraryTab: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
    case myFoods = "My Foods"
}

struct FoodLibraryView: View {
    @State private var searchText = ""
    @State private var selectedTab: FoodLibraryTab = .all
    @State private var searchResults: [OpenFoodItem] = []
    @State private var isSearching = false
    @Query(sort: \CachedFoodItem.lastUsed, order: .reverse) private var cachedFoods: [CachedFoodItem]

    private var favorites: [CachedFoodItem] {
        cachedFoods.filter { $0.isFavorite }
    }

    private var customFoods: [CachedFoodItem] {
        cachedFoods.filter { $0.isCustom }
    }

    private var recents: [CachedFoodItem] {
        Array(cachedFoods.prefix(10))
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
            }
        }
    }

    private var stickySearch: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.exTextMuted)
            TextField("Search foods...", text: $searchText)
                .font(.exBody)
                .foregroundStyle(.exTextPrimary)
                .onSubmit { Task { await search() } }
            if !searchText.isEmpty {
                Button { searchText = ""; searchResults = [] } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.exTextMuted)
                }
            }
            NavigationLink(destination: BarcodeScannerView()) {
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
                    withAnimation(.spring(response: 0.3)) { selectedTab = tab }
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
        if isSearching {
            LoadingStateView(message: "Searching...")
        } else if !searchResults.isEmpty {
            searchResultsList
        } else {
            switch selectedTab {
            case .all: allTab
            case .favorites: favoritesTab
            case .myFoods: myFoodsTab
            }
        }
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(searchResults) { food in
                    NavigationLink(destination: FoodDetailView(food: food)) {
                        FoodCardView(food: food)
                    }
                }
            }
            .padding(20)
        }
    }

    private var allTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !recents.isEmpty {
                    recentsSection
                }
                EmptyStateView(icon: "magnifyingglass", title: "Search for foods",
                               message: "Find nutritional info for thousands of foods")
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var recentsSection: some View {
        Text("Recent")
            .font(.exLabel)
            .foregroundStyle(.exTextSecondary)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(recents) { food in
                    recentChip(food)
                }
            }
        }
    }

    private func recentChip(_ food: CachedFoodItem) -> some View {
        VStack(spacing: 4) {
            Text(food.name)
                .font(.exCaption)
                .foregroundStyle(.exTextPrimary)
                .lineLimit(1)
            Text("\(food.calories) kcal")
                .font(.exSmall)
                .foregroundStyle(.exTextMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 10)
    }

    private var favoritesTab: some View {
        Group {
            if favorites.isEmpty {
                EmptyStateView(icon: "heart", title: "No favorites yet",
                               message: "Heart foods to save them here")
            } else {
                List(favorites) { food in
                    Text(food.name)
                        .foregroundStyle(.exTextPrimary)
                }
                .listStyle(.plain)
            }
        }
    }

    private var myFoodsTab: some View {
        Group {
            if customFoods.isEmpty {
                EmptyStateView(icon: "plus.circle", title: "No custom foods",
                               message: "Create your own foods for quick logging")
            } else {
                List(customFoods) { food in
                    Text(food.name)
                        .foregroundStyle(.exTextPrimary)
                }
                .listStyle(.plain)
            }
        }
    }

    private func search() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        searchResults = await OpenFoodFactsService.shared.search(query: searchText)
        isSearching = false
    }
}

// MARK: - Food Card

struct FoodCardView: View {
    let food: OpenFoodItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.exBodyMedium)
                    .foregroundStyle(.exTextPrimary)
                    .lineLimit(1)
                if let brand = food.brand {
                    Text(brand)
                        .font(.exSmall)
                        .foregroundStyle(.exTextMuted)
                }
                HStack(spacing: 8) {
                    macroPill("P", value: food.protein, color: .exPrimary)
                    macroPill("C", value: food.carbs, color: .exSuccess)
                    macroPill("F", value: food.fat, color: .exAccent)
                }
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(food.calories)")
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
        Text("\(label) \(Int(value))g")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}
