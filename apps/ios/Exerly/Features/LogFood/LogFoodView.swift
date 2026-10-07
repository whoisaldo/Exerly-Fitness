import SwiftUI

@MainActor
final class FoodSearchViewModel: ObservableObject {
    @Published private(set) var recents: [LibraryFoodDTO] = []
    @Published private(set) var libraryMatches: [LibraryFoodDTO] = []
    @Published private(set) var providerMatches: [SearchFoodDTO] = []
    @Published private(set) var activeQuery = ""
    @Published private(set) var isLoading = false
    @Published var error: String?

    private let api = APIClient.shared
    private var requestedQuery = ""

    func loadRecents() async {
        isLoading = true
        error = nil
        do {
            let data = try await SyncEngine.shared.read("/api/library/foods?limit=50")
            recents = try JSONDecoder().decode([LibraryFoodDTO].self, from: data)
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
            libraryMatches = response.library
            providerMatches = response.results
        } catch {
            guard requestedQuery == query else { return }
            self.error = error.localizedDescription
        }
        if requestedQuery == query { isLoading = false }
    }

    func clearSearch() {
        requestedQuery = ""
        activeQuery = ""
        libraryMatches = []
        providerMatches = []
        error = nil
        isLoading = false
    }
}

struct LogFoodView: View {
    let initialDate: CalendarDay
    let initialMealType: String
    let onLogged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FoodSearchViewModel()
    @State private var searchText = ""
    @State private var selectedFood: OpenFoodItem?

    init(
        initialDate: CalendarDay,
        initialMealType: String = "snack",
        onLogged: @escaping () -> Void = {}
    ) {
        self.initialDate = initialDate
        self.initialMealType = initialMealType
        self.onLogged = onLogged
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                contentArea
            }
            .background(Color.exBackground)
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.exTextSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: BarcodeScannerView(initialDate: initialDate, initialMealType: initialMealType, onLogged: { onLogged(); dismiss() })) {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundStyle(.exPrimary)
                            .accessibilityLabel("Scan food barcode")
                    }
                }
            }
            .task { await viewModel.loadRecents() }
            .onChange(of: searchText) { _, value in
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.clearSearch()
                }
            }
            .fullScreenCover(item: $selectedFood) { food in
                QuickFoodLogSheet(
                    food: food,
                    initialMealType: initialMealType,
                    initialDate: initialDate
                ) {
                    onLogged()
                    dismiss()
                }
            }
        }
    }

    private var searchBar: some View {
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
        }
        .padding(12)
        .background(Color.exSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading {
            LoadingStateView(
                message: viewModel.activeQuery.isEmpty ? "Loading recent foods…" : "Searching…"
            )
        } else if let error = viewModel.error {
            ErrorStateView(message: error) {
                Task {
                    if viewModel.activeQuery.isEmpty {
                        await viewModel.loadRecents()
                    } else {
                        await viewModel.search(viewModel.activeQuery)
                    }
                }
            }
        } else if viewModel.activeQuery.isEmpty {
            recentList
        } else if viewModel.libraryMatches.isEmpty && viewModel.providerMatches.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No results",
                message: "Try a different food or brand."
            )
        } else {
            searchResults
        }
    }

    private var recentList: some View {
        Group {
            if viewModel.recents.isEmpty {
                EmptyStateView(
                    icon: "fork.knife",
                    title: "No recent foods",
                    message: "Search or scan a barcode. Foods you log will appear here next time."
                )
            } else {
                ScrollView {
                    foodSection(
                        title: "Recent foods",
                        subtitle: "Most recently used",
                        foods: viewModel.recents
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var searchResults: some View {
        ScrollView {
            VStack(spacing: 22) {
                if !viewModel.libraryMatches.isEmpty {
                    foodSection(
                        title: "Your foods",
                        subtitle: "Logged before",
                        foods: viewModel.libraryMatches
                    )
                }

                if !viewModel.providerMatches.isEmpty {
                    providerSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func foodSection(
        title: String,
        subtitle: String,
        foods: [LibraryFoodDTO]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.exLabel)
                    .foregroundStyle(.exTextPrimary)
                Spacer()
                Text(subtitle)
                    .font(.exSmall)
                    .foregroundStyle(.exTextMuted)
            }
            ForEach(foods) { food in
                FoodRowView(food: food.openFoodItem) {
                    selectedFood = food.openFoodItem
                }
            }
        }
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("More results")
                .font(.exLabel)
                .foregroundStyle(.exTextPrimary)
            ForEach(viewModel.providerMatches) { food in
                FoodRowView(food: food.openFoodItem) {
                    selectedFood = food.openFoodItem
                }
            }
        }
    }
}

struct FoodRowView: View {
    let food: OpenFoodItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.exBodyMedium)
                        .foregroundStyle(.exTextPrimary)
                        .lineLimit(1)
                    if let brand = food.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.exCaption)
                            .foregroundStyle(.exTextMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(food.calories) kcal")
                        .font(.exStatSmall)
                        .foregroundStyle(.exPrimary)
                    Text(food.servingSize)
                        .font(.exSmall)
                        .foregroundStyle(.exTextMuted)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

struct QuickFoodLogSheet: View {
    let food: OpenFoodItem
    var initialMealType: String = "snack"
    var initialDate: CalendarDay
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            FoodDetailView(food: food, initialDate: initialDate, initialMealType: initialMealType, onLogged: onComplete)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
