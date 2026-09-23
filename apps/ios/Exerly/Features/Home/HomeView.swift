import SwiftUI

private struct MealLogDestination: Identifiable {
    let meal: String
    let date: CalendarDay
    var id: String { "\(meal)-\(date.rawValue)" }
}

struct HomeView: View {
    let refreshToken: Int

    @AppStorage("unitSystem") private var unitSystem = "metric"
    @StateObject private var viewModel = DiaryViewModel()
    @State private var selectedDate: CalendarDay
    @State private var mealToLog: MealLogDestination?
    @State private var editingFood: FoodDTO?
    @State private var editingDay = false
    @State private var addingWater = false
    @State private var addingWeight = false
    @State private var lastDeletedWeight: String?
    @State private var weightError: String?
    @State private var waterError: String?
    @EnvironmentObject private var sync: SyncEngine

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    init(refreshToken: Int, initialDate: CalendarDay) {
        self.refreshToken = refreshToken
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.summary == nil {
                LoadingStateView(message: "Loading diary…")
            } else if let summary = viewModel.summary {
                diary(summary)
            } else if let error = viewModel.error {
                ErrorStateView(message: error) {
                    Task { await viewModel.load(for: selectedDate) }
                }
            } else {
                EmptyStateView(
                    icon: "book.pages",
                    title: "Your diary is ready",
                    message: "Start by logging a meal."
                )
            }
        }
        .background(Color.exBackground)
        .navigationTitle("Diary")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(selectedDate.rawValue)-\(refreshToken)") {
            await viewModel.load(for: selectedDate)
        }
        .sheet(item: $mealToLog) { destination in
            LogFoodView(
                initialDate: destination.date,
                initialMealType: destination.meal
            ) {
                Task { await viewModel.load(for: selectedDate) }
            }
        }
        .sheet(item: $editingFood) { food in
            NavigationStack {
                FoodDetailView(food: food.perServingItem, initialDate: selectedDate, initialMealType: food.mealType ?? "snack", editing: food) {
                    Task { await viewModel.load(for: selectedDate) }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingFood = nil } } }
            }
        }
        .sheet(isPresented: $addingWeight) {
            WeightEntrySheet(date: selectedDate, onDeleted: { lastDeletedWeight = $0 }) {
                Task { await viewModel.load(for: selectedDate) }
            }
        }
        .sheet(isPresented: $addingWater) {
            if let summary = viewModel.summary {
                WaterEntryView(current: waterDay(summary)) {
                    Task { await viewModel.load(for: selectedDate) }
                }
            }
        }
        .sheet(isPresented: $editingDay) {
            if let summary = viewModel.summary {
                DiaryDayEditor(current: summary.diaryDay ?? .initial(summary.date)) {
                    Task { await viewModel.load(for: selectedDate) }
                }
            }
        }
        .onChange(of: sync.changeToken) { _, _ in Task { await viewModel.load(for: selectedDate) } }
    }

    private func diary(_ summary: DaySummaryDTO) -> some View {
        List {
            dateNavigation
                .diaryListRow()

            if sync.pendingCount > 0 || sync.attentionCount > 0 || sync.isOffline {
                VStack(alignment: .leading, spacing: 8) {
                    if sync.pendingCount > 0 { Text("\(sync.pendingCount) changes saved on this device, waiting to sync.") }
                    if sync.attentionCount > 0 { Text("\(sync.attentionCount) changes need your attention.") }
                    if sync.attentionCount > 0 { NavigationLink("Review changes") { SyncIssuesView() }.frame(minHeight: 44) }
                    if sync.isOffline { Text("Offline. Showing saved diary entries.") }
                    Button("Sync now") { Task { await sync.synchronize(force: true); await viewModel.load(for: selectedDate) } }
                        .frame(minHeight: 44)
                }.font(.callout).diaryListRow()
            }
            if viewModel.lastDeletedEntityID != nil {
                HStack {
                    Text("Food entry removed.")
                    Spacer()
                    Button("Undo") { Task { await viewModel.undoDeletion(from: selectedDate) } }.frame(minHeight: 44)
                }.diaryListRow()
            }

            if let error = viewModel.error {
                errorBanner(error)
                    .diaryListRow()
            }

            calorieCard(summary)
                .diaryListRow()

            contextCard(summary)
                .diaryListRow()

            waterCard(waterDay(summary))
                .diaryListRow()

            HStack {
                Label("Weight", systemImage: "scalemass")
                Spacer()
                if let weight = summary.weight { Text("\(weight.weightKg * (unitSystem == "imperial" ? 2.20462262 : 1), format: .number.precision(.fractionLength(0...2))) \(unitSystem == "imperial" ? "lb" : "kg")").monospacedDigit() }
                Button("Log weight") { addingWeight = true }.frame(minHeight: 44)
            }.diaryListRow()
            if let lastDeletedWeight {
                Button("Undo weight deletion") {
                    do {
                        try sync.undoWeightDeletion(entityID: lastDeletedWeight)
                        self.lastDeletedWeight = nil
                        Task { await viewModel.load(for: selectedDate) }
                    } catch { weightError = error.localizedDescription }
                }.frame(minHeight: 44).diaryListRow()
                if let weightError { Text(weightError).foregroundStyle(.red).diaryListRow() }
            }

            loggingStatus(summary.diaryDay ?? .initial(summary.date))
                .diaryListRow()

            ForEach(mealTypes, id: \.self) { meal in
                mealSection(meal, bucket: summary.meals[meal])
            }

            if let other = summary.meals["uncategorized"], !other.entries.isEmpty {
                mealSection("uncategorized", bucket: other)
            }

            ActivitySleepRows(summary: summary, date: selectedDate) {
                Task { await viewModel.load(for: selectedDate) }
            }.diaryListRow()

            Color.clear
                .frame(height: 80)
                .diaryListRow()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.exBackground)
        .refreshable { await viewModel.load(for: selectedDate) }
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView()
                    .tint(.exPrimary)
                    .padding(8)
                    .background(Color.exSurface3)
                    .clipShape(Capsule())
                    .padding(.top, 4)
            }
        }
    }

    private func loggingStatus(_ day: DiaryDayDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Logging status").font(.headline)
                Spacer()
                Button("Edit") { editingDay = true }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Edit logging status")
            }
            Text(day.status.title).font(.body.weight(.semibold))
                .accessibilityIdentifier("diary.logging-status")
            Text(day.status.explanation).font(.callout).foregroundStyle(.exTextSecondary)
            if let note = day.note, !note.isEmpty { Text(note).font(.callout) }
            if day.sync_state == "pending" { Text("Saved on this device. Waiting to sync.").font(.caption) }
            if day.sync_state == "attention" { Text("This day's status needs review.").font(.caption) }
        }
        .padding(.vertical, 8)
    }

    private var dateNavigation: some View {
        HStack(spacing: 12) {
            Button { moveDate(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.exTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.exSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Previous day")
            .disabled(selectedDate <= sync.today.adding(days: -3650)!)

            VStack(spacing: 2) {
                Text(isToday ? "Today" : selectedDate.formatted(weekdayOnly: true))
                    .font(.exBodyMedium)
                    .foregroundStyle(.exTextPrimary)
                    .accessibilityIdentifier("diary.selected-day")
                    .accessibilityValue(selectedDate.rawValue)
                CalendarDayPicker("Date", selection: $selectedDate, today: sync.today,
                                  timeZoneIdentifier: sync.calendar.timeZoneIdentifier)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(.exPrimary)
                .colorScheme(.dark)
                .font(.exCaption)
                if !isToday {
                    Button("Today") { selectedDate = sync.today }.frame(minHeight: 44)
                }
            }
            .frame(maxWidth: .infinity)

            Button { moveDate(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isToday ? Color.exTextMuted.opacity(0.4) : .exTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.exSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(selectedDate >= sync.today)
            .accessibilityLabel("Next day")
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 4)
    }

    private func calorieCard(_ summary: DaySummaryDTO) -> some View {
        GlassCard {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CALORIES")
                            .font(.exSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(.exTextMuted)
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(Int(summary.consumed.calories).formatted())
                                .font(.exStat)
                                .foregroundStyle(.exTextPrimary)
                            if let target = summary.targets.calories {
                                Text("/ \(target.formatted())")
                                    .font(.exMono)
                                    .foregroundStyle(.exTextMuted)
                            }
                        }
                    }
                    Spacer()
                    remainingCalories(summary.remaining.calories)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    DiaryMacroBar(
                        label: "Protein",
                        value: summary.consumed.protein,
                        target: summary.targets.proteinG,
                        color: .exPrimary
                    )
                    DiaryMacroBar(
                        label: "Carbs",
                        value: summary.consumed.carbs,
                        target: summary.targets.carbsG,
                        color: .exSuccess
                    )
                    DiaryMacroBar(
                        label: "Fat",
                        value: summary.consumed.fat,
                        target: summary.targets.fatG,
                        color: .exWarning
                    )
                    DiaryMacroBar(
                        label: "Fibre",
                        value: summary.consumed.fiber,
                        target: summary.targets.fiberG,
                        color: .exInfo
                    )
                }
            }
        }
    }

    private func remainingCalories(_ remaining: Int?) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let remaining {
                Text(remaining >= 0 ? "REMAINING" : "OVER TARGET")
                    .font(.exSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.exTextMuted)
                Text(abs(remaining).formatted())
                    .font(.exStatMedium)
                    .foregroundStyle(remaining >= 0 ? .exTextPrimary : .exWarning)
            } else {
                Text("NO TARGET")
                    .font(.exSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.exTextMuted)
            }
        }
    }

    private func waterDay(_ summary: DaySummaryDTO) -> WaterDayDTO {
        summary.water ?? WaterDayDTO(entry_date: summary.date, ml: summary.waterMl, revision: 0)
    }

    private func waterCard(_ water: WaterDayDTO) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Water", systemImage: "drop")
                        .font(.headline)
                    Spacer()
                    Text("\(water.ml.formatted()) ml")
                        .monospacedDigit()
                        .accessibilityIdentifier("water.total")
                }
                if water.sync_state == "pending" { Text("Saved on this device. Waiting to sync.").font(.callout) }
                if water.sync_state == "attention" { Text("Review your pending water additions before retrying.").font(.callout) }
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button { addWater(water, ml: 250) } label: {
                            Text("+250 ml").frame(maxWidth: .infinity, minHeight: 28)
                        }.accessibilityLabel("Add 250 ml of water")
                        Button { addWater(water, ml: 500) } label: {
                            Text("+500 ml").frame(maxWidth: .infinity, minHeight: 28)
                        }.accessibilityLabel("Add 500 ml of water")
                    }
                    Button { addingWater = true } label: {
                        Text("Custom amount").frame(maxWidth: .infinity, minHeight: 28)
                    }.accessibilityLabel("Add a custom water amount")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(water.entry_date > sync.today.rawValue)
                if let waterError { Text(waterError).foregroundStyle(.red).font(.callout) }
            }
        }
    }

    private func addWater(_ water: WaterDayDTO, ml: Int) {
        do {
            try sync.addWater(water, milliliters: ml)
            waterError = nil
            Task { await viewModel.load(for: selectedDate) }
        } catch { waterError = error.localizedDescription }
    }

    private func contextCard(_ summary: DaySummaryDTO) -> some View {
        GlassCard {
            HStack(spacing: 0) {
                contextStat(
                    icon: "flame",
                    value: summary.activities.contains { $0.calories != nil } ? "\(summary.burned)" : "—",
                    label: "logged kcal"
                )
                contextDivider
                contextStat(
                    icon: "drop",
                    value: waterValue(summary.waterMl),
                    label: "water"
                )
                contextDivider
                contextStat(
                    icon: "moon",
                    value: summary.sleep.map { _ in
                        (summary.sleepHours ?? summary.sleep?.hours ?? 0).formatted(.number.precision(.fractionLength(1)))
                    } ?? "—",
                    label: "sleep h"
                )
                contextDivider
                contextStat(
                    icon: "scalemass",
                    value: summary.weight.map { compactWeight($0.weightKg) } ?? "—",
                    label: unitSystem == "imperial" ? "lb" : "kg"
                )
            }
        }
    }

    private func contextStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.exPrimary)
            Text(value)
                .font(.exMono)
                .foregroundStyle(.exTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.exSmall)
                .foregroundStyle(.exTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var contextDivider: some View {
        Rectangle()
            .fill(Color.exBorder)
            .frame(width: 1, height: 50)
    }

    private func mealSection(_ meal: String, bucket: MealBucketDTO?) -> some View {
        let entries = bucket?.entries ?? []
        let calories = Int(bucket?.totals.calories ?? 0)

        return Section {
            mealHeader(meal, calories: calories)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.exSurface1)

            if entries.isEmpty {
                Text("Nothing logged")
                    .font(.exCaption)
                    .foregroundStyle(.exTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 14, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.exSurface1)
            } else {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, food in
                    Button { editingFood = food } label: {
                        foodRow(food)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit \(food.name)")
                        .listRowInsets(EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16))
                        .listRowSeparatorTint(Color.exBorder)
                        .listRowBackground(Color.exSurface1)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteFood(food, from: selectedDate) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(food.id.map { viewModel.deletingFoodIds.contains($0) } ?? true)
                        }
                }
            }
        }
        .listSectionSpacing(12)
    }

    private func mealHeader(_ meal: String, calories: Int) -> some View {
        HStack(spacing: 12) {
            Text(mealLabel(meal))
                .font(.exH3)
                .foregroundStyle(.exTextPrimary)
            Spacer()
            Text("\(calories) kcal")
                .font(.exMono)
                .foregroundStyle(.exTextSecondary)
            if meal != "uncategorized" {
                Button {
                    mealToLog = MealLogDestination(meal: meal, date: selectedDate)
                } label: {
                    Text("Add")
                        .font(.exCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.exPrimary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.exPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("Add food to \(mealLabel(meal).lowercased())")
                .accessibilityIdentifier("diary.add.\(meal)")
            }
        }
    }

    private func foodRow(_ food: FoodDTO) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(food.name)
                        .font(.exBodyMedium)
                        .foregroundStyle(.exTextPrimary)
                        .lineLimit(1)
                    Text("× \(servingText(food.servings))")
                        .font(.exMono)
                        .foregroundStyle(.exTextMuted)
                }
                Text(macroText(food))
                    .font(.exSmall.monospacedDigit())
                    .foregroundStyle(.exTextMuted)
                    .lineLimit(1)
                if food.syncState == "pending" { Text("Saved on device · Pending sync").font(.caption).foregroundStyle(.exTextSecondary) }
                if food.syncState == "attention" { Text("Needs attention · Review sync changes").font(.caption).foregroundStyle(.exWarning) }
            }
            Spacer()
            Text(food.calories.formatted())
                .font(.exMono)
                .foregroundStyle(.exTextSecondary)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.exError)
            Text(message)
                .font(.exCaption)
                .foregroundStyle(.exTextSecondary)
            Spacer()
            Button("Retry") {
                Task { await viewModel.load(for: selectedDate) }
            }
            .font(.exCaption)
            .foregroundStyle(.exPrimary)
        }
        .padding(12)
        .background(Color.exError.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var isToday: Bool {
        selectedDate == sync.today
    }

    private func moveDate(by days: Int) {
        guard let date = selectedDate.adding(days: days), date <= sync.today,
              date >= sync.today.adding(days: -3650)! else { return }
        selectedDate = date
    }

    private func mealLabel(_ meal: String) -> String {
        switch meal {
        case "snack": "Snacks"
        case "uncategorized": "Other"
        default: meal.capitalized
        }
    }

    private func servingText(_ servings: Double) -> String {
        servings.formatted(
            .number.precision(.fractionLength(servings.rounded() == servings ? 0 : 1))
        )
    }

    private func macroText(_ food: FoodDTO) -> String {
        let protein = food.protein.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—"
        let carbs = food.carbs.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—"
        let fat = food.fat.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—"
        let serving = food.servingSize.map { " · \($0)" } ?? ""
        return "P \(protein)g · C \(carbs)g · F \(fat)g\(serving)"
    }

    private func waterValue(_ milliliters: Int) -> String {
        if unitSystem == "imperial" {
            return (Double(milliliters) / 29.5735).formatted(.number.precision(.fractionLength(0)))
        }
        return "\(milliliters)"
    }

    private func compactWeight(_ kilograms: Double) -> String {
        let value = unitSystem == "imperial" ? kilograms * 2.20462262 : kilograms
        return value.formatted(.number.precision(.fractionLength(1)))
    }
}

private struct DiaryMacroBar: View {
    let label: String
    let value: Double
    let target: Double?
    let color: Color

    private var isOver: Bool {
        guard let target, target > 0 else { return false }
        return !["Protein", "Fibre"].contains(label) && value > target
    }

    private var progress: Double {
        guard let target, target > 0 else { return 0 }
        return min(max(value / target, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.exCaption)
                    .foregroundStyle(.exTextSecondary)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(0))))
                    .font(.exSmall.monospacedDigit())
                    .foregroundStyle(isOver ? .exWarning : .exTextPrimary)
                Text(target.map { "/ \(Int($0))g" } ?? "g")
                    .font(.exSmall.monospacedDigit())
                    .foregroundStyle(.exTextMuted)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.exSurface3)
                    Capsule()
                        .fill(isOver ? Color.exWarning : color)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct DiaryDayEditor: View {
    let current: DiaryDayDTO
    let onSave: () -> Void
    @EnvironmentObject private var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss
    @State private var status: DiaryLoggingStatus
    @State private var note: String
    @State private var error: String?

    init(current: DiaryDayDTO, onSave: @escaping () -> Void) {
        self.current = current
        self.onSave = onSave
        _status = State(initialValue: current.status)
        _note = State(initialValue: current.note ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(current.entry_date).monospacedDigit()
                    Picker("Logging status", selection: $status) {
                        ForEach(DiaryLoggingStatus.allCases) { value in Text(value.title).tag(value) }
                    }
                    .accessibilityIdentifier("diary.status-picker")
                    Text(status.explanation).font(.callout).foregroundStyle(.secondary)
                }
                Section("Optional note") {
                    TextField("Note", text: $note, axis: .vertical).lineLimit(3...6)
                        .accessibilityIdentifier("diary.note")
                    Text("\(note.count) / 500 characters").font(.caption).monospacedDigit()
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Day logging status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save status") {
                        do {
                            try sync.saveDiaryDay(current, status: status, note: note)
                            onSave()
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
        }
    }
}

private extension View {
    func diaryListRow() -> some View {
        listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

private struct WaterEntryView: View {
    let current: WaterDayDTO
    let onSave: () -> Void
    @EnvironmentObject private var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss
    @State private var amount = "250"
    @State private var error: String?
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            Form {
                Section("Water for \(current.entry_date)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount (ml)").font(.callout)
                        TextField("Amount (ml)", text: $amount)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("water.amount")
                            .focused($focused)
                            .onChange(of: amount) { _, _ in error = nil }
                    }
                    Text("Enter 1 to 5,000 ml. This adds to your day's total.")
                        .font(.callout)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Add water")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save water") {
                        guard let ml = Int(amount.trimmingCharacters(in: .whitespaces)), (1...5000).contains(ml) else {
                            error = "Enter a whole number from 1 to 5,000 ml."
                            return
                        }
                        do { try sync.addWater(current, milliliters: ml); onSave(); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
            }
        }
    }
}

private struct ActivitySleepRows: View {
    let summary: DaySummaryDTO
    let date: CalendarDay
    let onSaved: () -> Void
    @EnvironmentObject private var sync: SyncEngine
    @State private var addingActivity = false
    @State private var addingSleep = false
    @State private var editingActivity: ActivityDTO?
    @State private var editingSleep: SleepDTO?
    @State private var deletedActivity: String?
    @State private var deletedSleep: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activity").font(.headline)
                Spacer()
                Button { addingActivity = true } label: { Text("Log activity").frame(minHeight: 44) }
            }
            if summary.activities.isEmpty { Text("No saved activities for this day.").font(.callout).foregroundStyle(.secondary) }
            ForEach(summary.activities, id: \.clientID) { row in
                Button { editingActivity = row } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.type).font(.headline)
                        Text("\(row.duration, format: .number) minutes").monospacedDigit()
                        if let calories = row.calories { Text("\(calories, format: .number) kcal").monospacedDigit() }
                        else { Text("Energy not recorded") }
                        syncLabel(row.syncState)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 8)
                }.buttonStyle(.plain).accessibilityLabel("Edit activity \(row.type)")
            }
            if let deletedActivity {
                Button {
                    do { try sync.undoActivityDeletion(entityID: deletedActivity); self.deletedActivity = nil; error = nil; onSaved() }
                    catch { self.error = error.localizedDescription }
                } label: { Text("Undo activity deletion").frame(minHeight: 44) }
            }
            Divider()
            HStack {
                Text("Sleep").font(.headline)
                Spacer()
                Button { addingSleep = true } label: { Text("Log sleep").frame(minHeight: 44) }
            }
            let sleep = summary.sleepEntries ?? summary.sleep.map { [$0] } ?? []
            if sleep.isEmpty { Text("No saved sleep entries for this day.").font(.callout).foregroundStyle(.secondary) }
            ForEach(sleep, id: \.clientID) { row in
                Button { editingSleep = row } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(row.hours, format: .number) hours").font(.headline).monospacedDigit()
                        if let quality = row.qualityLabel { Text(quality.capitalized) }
                        if let bedtime = row.bedtime, let wakeTime = row.wakeTime { Text("\(bedtime) to \(wakeTime)") }
                        syncLabel(row.syncState)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 8)
                }.buttonStyle(.plain).accessibilityLabel("Edit sleep entry, \(row.hours.formatted(.number)) hours")
            }
            if let deletedSleep {
                Button {
                    do { try sync.undoSleepDeletion(entityID: deletedSleep); self.deletedSleep = nil; error = nil; onSaved() }
                    catch { self.error = error.localizedDescription }
                } label: { Text("Undo sleep deletion").frame(minHeight: 44) }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .buttonStyle(.borderless)
        .sheet(isPresented: $addingActivity) { LogActivityView(initialDate: date, onSaved: onSaved) }
        .sheet(item: $editingActivity) { row in
            LogActivityView(initialDate: date, editing: row, onDeleted: { deletedActivity = $0 }, onSaved: onSaved)
        }
        .sheet(isPresented: $addingSleep) { LogSleepView(initialDate: date, onSaved: onSaved) }
        .sheet(item: $editingSleep) { row in
            LogSleepView(initialDate: date, editing: row, onDeleted: { deletedSleep = $0 }, onSaved: onSaved)
        }
    }
    @ViewBuilder private func syncLabel(_ state: String?) -> some View {
        if state == "pending" { Text("Saved on this device. Waiting to sync.").font(.caption) }
        if state == "attention" { Text("Needs review").font(.caption) }
    }
}
