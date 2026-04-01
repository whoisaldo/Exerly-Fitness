import SwiftUI

struct LogFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [OpenFoodItem] = []
    @State private var isSearching = false
    @State private var selectedFood: OpenFoodItem?
    @State private var isSubmitting = false

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
                    NavigationLink(destination: BarcodeScannerView()) {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundStyle(.exPrimary)
                    }
                }
            }
            .sheet(item: $selectedFood) { food in
                QuickFoodLogSheet(food: food) { dismiss() }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.exTextMuted)
            TextField("Search foods...", text: $searchText)
                .font(.exBody)
                .foregroundStyle(.exTextPrimary)
                .onSubmit { Task { await search() } }
        }
        .padding(12)
        .background(Color.exSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var contentArea: some View {
        if isSearching {
            LoadingStateView(message: "Searching...")
        } else if results.isEmpty && searchText.isEmpty {
            emptyState
        } else if results.isEmpty {
            EmptyStateView(icon: "magnifyingglass", title: "No results",
                           message: "Try a different search term")
        } else {
            resultsList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Text("Recent Foods")
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            EmptyStateView(
                icon: "fork.knife",
                title: "No recent foods",
                message: "Search or scan a barcode to log food"
            )
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(results) { food in
                    FoodRowView(food: food) {
                        selectedFood = food
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private func search() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        results = await OpenFoodFactsService.shared.search(query: searchText)
        isSearching = false
    }
}

// MARK: - Food Row

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
                    if let brand = food.brand {
                        Text(brand)
                            .font(.exCaption)
                            .foregroundStyle(.exTextMuted)
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
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 12)
        }
    }
}

// MARK: - Quick Log Sheet

struct QuickFoodLogSheet: View {
    let food: OpenFoodItem
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var servings: Double = 1
    @State private var isSubmitting = false

    var scaledCalories: Int { Int(Double(food.calories) * servings) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(food.name)
                    .font(.exH3)
                    .foregroundStyle(.exTextPrimary)

                GlassCard {
                    HStack {
                        Text("Servings")
                            .font(.exLabel)
                            .foregroundStyle(.exTextSecondary)
                        Spacer()
                        Stepper(value: $servings, in: 0.5...10, step: 0.5) {
                            Text(String(format: "%.1f", servings))
                                .font(.exStatSmall)
                                .foregroundStyle(.exPrimary)
                        }
                    }
                }

                GlassCard {
                    HStack {
                        Text("Total Calories")
                            .font(.exLabel)
                            .foregroundStyle(.exTextSecondary)
                        Spacer()
                        Text("\(scaledCalories) kcal")
                            .font(.exStatSmall)
                            .foregroundStyle(.exAccent)
                    }
                }

                Spacer()

                ActionButton(title: "Log Food", isLoading: isSubmitting) {
                    Task { await log() }
                }
            }
            .padding(20)
            .background(Color.exBackground)
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func log() async {
        isSubmitting = true
        let req = FoodRequest(
            name: food.name, calories: scaledCalories,
            protein: food.protein * servings,
            carbs: food.carbs * servings,
            fat: food.fat * servings,
            sugar: nil, servingSize: food.servingSize
        )
        do {
            let _: FoodDTO = try await APIClient.shared.createFoodLog(req)
            dismiss()
            onComplete()
        } catch {
            isSubmitting = false
        }
    }
}
