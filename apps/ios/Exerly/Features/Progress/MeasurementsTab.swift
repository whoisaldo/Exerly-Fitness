import Charts
import SwiftData
import SwiftUI

private let poundsPerKilogram = 2.20462262
private let centimetersPerInch = 2.54

private enum WeightRange: Int, CaseIterable, Identifiable {
    case month = 30
    case quarter = 90
    case halfYear = 180
    case year = 365

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .month: "30d"
        case .quarter: "90d"
        case .halfYear: "6m"
        case .year: "1y"
        }
    }
}

@MainActor
final class MeasurementsViewModel: ObservableObject {
    @Published private(set) var trend: TrendResponseDTO?
    @Published private(set) var isLoading = false
    @Published var error: String?
    @Published private(set) var measurements: [BodyMeasurementDTO] = []
    @Published private(set) var weights: [WeightDayDTO] = []
    private var generation = UUID()

    func load(days: Int, today: CalendarDay) async {
        let generation = UUID()
        self.generation = generation
        isLoading = true
        error = nil
        let from = today.adding(days: -(days - 1))!.rawValue
        let to = today.rawValue
        if let saved = try? await SyncEngine.shared.weights(from: from, to: to, cachedOnly: true), self.generation == generation {
            weights = saved
            trend = .savedWeights(saved, from: from, to: to)
        }
        if let saved = try? await SyncEngine.shared.measurements(from: from, to: to, cachedOnly: true), self.generation == generation {
            measurements = saved
        }
        do {
            let values = try await SyncEngine.shared.measurements(from: from, to: to)
            guard self.generation == generation else { return }
            measurements = values
        } catch {
            if self.generation == generation { self.error = error.localizedDescription }
        }
        do {
            let readings = try await SyncEngine.shared.weights(from: from, to: to)
            guard self.generation == generation else { return }
            weights = readings
            trend = .savedWeights(readings, from: from, to: to)
        } catch { if self.generation == generation { self.error = error.localizedDescription } }
        if self.generation == generation { isLoading = false }
    }
}

struct MeasurementsTab: View {
    @Query private var legacyMeasurements: [Measurement]
    @EnvironmentObject private var sync: SyncEngine
    @AppStorage("unitSystem") private var unitSystem = "metric"
    @StateObject private var viewModel = MeasurementsViewModel()
    @State private var selectedRange: WeightRange = .quarter
    @State private var showAddSheet = false
    @State private var editing: BodyMeasurementDTO?
    @State private var lastDeletedID: String?
    @State private var actionError: String?
    @State private var showLegacyReview = false
    @State private var addingWeight = false
    @State private var weightDate: CalendarDay
    @State private var lastDeletedWeight: String?

    init(initialDate: CalendarDay) { _weightDate = State(initialValue: initialDate) }

    private var nonWeightMeasurements: [BodyMeasurementDTO] {
        viewModel.measurements
    }

    private var weighIns: [WeightDayDTO] { viewModel.weights }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if lastDeletedID != nil {
                    HStack {
                        Text("Measurement removed.")
                        Spacer()
                        Button("Undo") {
                            do {
                                try sync.undoMeasurementDeletion(entityID: lastDeletedID!)
                                lastDeletedID = nil
                            } catch { actionError = error.localizedDescription }
                        }.frame(minHeight: 44)
                    }.font(.callout)
                }
                if lastDeletedWeight != nil {
                    HStack {
                        Text("Weight reading removed.")
                        Spacer()
                        Button("Undo weight deletion") {
                            do { try sync.undoWeightDeletion(entityID: lastDeletedWeight!); lastDeletedWeight = nil }
                            catch { actionError = error.localizedDescription }
                        }.frame(minHeight: 44)
                    }
                }
                if let actionError { Text(actionError).foregroundStyle(.exError) }
                summarySection
                chartSection
                historySection
                if !legacyMeasurements.isEmpty {
                    Text("Measurements from an older version are preserved on this device. They have not been assigned to this account.")
                        .font(.callout).foregroundStyle(.exTextSecondary)
                    Button("Review older measurements") { showLegacyReview = true }.frame(minHeight: 44)
                }
                if sync.attentionCount > 0 {
                    NavigationLink("Review unsynced changes") { SyncIssuesView() }
                        .frame(minHeight: 44)
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .refreshable { await viewModel.load(days: selectedRange.rawValue, today: sync.today) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { weightDate = sync.today; addingWeight = true } label: { Label("Log weight", systemImage: "scalemass") }
                    .frame(minHeight: 44).accessibilityLabel("Log weight")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
                    .frame(minWidth: 44, minHeight: 44).accessibilityLabel("Add measurement")
            }
        }
        .sheet(isPresented: $addingWeight) {
            WeightEntrySheet(date: weightDate, onDeleted: { lastDeletedWeight = $0 }) {
                Task { await viewModel.load(days: selectedRange.rawValue, today: sync.today) }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMeasurementSheet(initialDate: sync.today) {
                Task { await viewModel.load(days: selectedRange.rawValue, today: sync.today) }
            }
        }
        .sheet(item: $editing) { measurement in
            AddMeasurementSheet(initialDate: sync.today, editing: measurement, onDeleted: { lastDeletedID = $0 }) { Task { await viewModel.load(days: selectedRange.rawValue, today: sync.today) } }
        }
        .sheet(isPresented: $showLegacyReview) { LegacyMeasurementReview() }
        .onChange(of: sync.changeToken) { _, _ in Task { await viewModel.load(days: selectedRange.rawValue, today: sync.today) } }
        .task(id: "\(selectedRange.rawValue)-\(sync.today.rawValue)-\(sync.calendar.timeZoneIdentifier)") {
            await viewModel.load(days: selectedRange.rawValue, today: sync.today)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if let summary = viewModel.trend?.summary {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryCard(
                    label: "Trend now",
                    value: formatWeight(summary.currentTrendKg, digits: 1)
                )
                summaryCard(
                    label: "Last scale",
                    value: summary.currentWeightKg.map { formatWeight($0, digits: 1) } ?? "—"
                )
                summaryCard(
                    label: "Change (\(selectedRange.label))",
                    value: signedWeight(summary.changeKg),
                    color: .exTextPrimary
                )
                summaryCard(
                    label: "Weekly rate",
                    value: signedWeight(summary.weeklyRateKg, suffix: "/wk"),
                    color: .exTextPrimary
                )
            }
        }
    }

    private func summaryCard(label: String, value: String, color: Color = .exTextPrimary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.exCaption)
                .foregroundStyle(.exTextMuted)
            Text(value)
                .font(.exStatSmall)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 12)
    }

    private var chartSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Weight trend")
                            .font(.exH3)
                            .foregroundStyle(.exTextPrimary)
                        Text("Dots show recorded weights. The line shows your trend.")
                            .font(.exCaption)
                            .foregroundStyle(.exTextMuted)
                    }
                    Spacer()
                }

                rangeSelector

                if viewModel.isLoading && viewModel.trend == nil {
                    LoadingStateView(message: "Loading trend…")
                        .frame(height: 220)
                } else if let error = viewModel.error, viewModel.trend == nil {
                    ErrorStateView(message: error) {
                        Task { await viewModel.load(days: selectedRange.rawValue, today: sync.today) }
                    }
                    .frame(height: 240)
                } else if let series = viewModel.trend?.series, series.count >= 2 {
                    trendChart(series)
                    if let summary = viewModel.trend?.summary {
                        Text("\(summary.weighIns) weigh-ins across \(summary.days) days")
                            .font(.exSmall)
                            .foregroundStyle(.exTextMuted)
                    }
                } else {
                    EmptyStateView(
                        icon: "scalemass",
                        title: "Build your trend",
                        message: "Log at least two weigh-ins to see your recorded weights and trend."
                    )
                    .frame(height: 240)
                }
            }
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(WeightRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.label)
                        .font(.exCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedRange == range ? .exPrimary : .exTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(selectedRange == range ? Color.exPrimary.opacity(0.12) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(3)
        .background(Color.exSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func trendChart(_ series: [TrendPointDTO]) -> some View {
        Chart {
            ForEach(series) { point in
                if let date = CalendarDay(rawValue: point.date)?.pickerDate {
                    AreaMark(
                        x: .value("Date", date),
                        yStart: .value("Baseline", chartDomain(series).lowerBound),
                        yEnd: .value("Trend", displayValue(point.trend))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.exPrimary.opacity(0.18), .exPrimary.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", date),
                        y: .value("Trend", displayValue(point.trend))
                    )
                    .foregroundStyle(Color.exPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    if let weight = point.weight {
                        PointMark(
                            x: .value("Date", date),
                            y: .value("Scale", displayValue(weight))
                        )
                        .symbolSize(20)
                        .foregroundStyle(Color.exTextSecondary.opacity(0.55))
                    }
                }
            }
        }
        .environment(\.calendar, CalendarDay.pickerCalendar)
        .environment(\.timeZone, CalendarDay.pickerCalendar.timeZone)
        .chartYScale(domain: chartDomain(series))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                AxisValueLabel {
                    if let date = value.as(Date.self), let day = CalendarDay(pickerDate: date) {
                        Text(day.formatted()).foregroundStyle(Color.exTextMuted).font(.exSmall)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.exBorder)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.precision(.fractionLength(1))))
                            .font(.exSmall)
                            .foregroundStyle(.exTextMuted)
                    }
                }
            }
        }
        .frame(height: 220)
        .accessibilityLabel("Weight trend chart")
    }

    private func chartDomain(_ series: [TrendPointDTO]) -> ClosedRange<Double> {
        let values = series.flatMap { point -> [Double] in
            var values = [displayValue(point.trend)]
            if let weight = point.weight { values.append(displayValue(weight)) }
            return values
        }
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let padding = max((high - low) * 0.15, unitSystem == "imperial" ? 0.8 : 0.4)
        return (low - padding)...(high + padding)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.exLabel)
                .foregroundStyle(.exTextSecondary)

            if weighIns.isEmpty && nonWeightMeasurements.isEmpty {
                EmptyStateView(
                    icon: "ruler",
                    title: "No measurements",
                    message: "Track weight and body measurements to see progress."
                )
            } else {
                ForEach(weighIns, id: \.entry_date) { point in
                    Button {
                        guard let day = CalendarDay(rawValue: point.entry_date) else { return }
                        weightDate = day
                        addingWeight = true
                    } label: {
                    GlassCard(padding: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weight")
                                    .font(.exBodyMedium)
                                    .foregroundStyle(.exTextPrimary)
                                Text(formattedDay(point.entry_date))
                                    .font(.exCaption)
                                    .foregroundStyle(.exTextMuted)
                            }
                            Spacer()
                            Text(formatWeight(point.weight_kg ?? 0, digits: 2))
                                .font(.exStatSmall)
                                .foregroundStyle(.exPrimary)
                        }
                    }
                    }.buttonStyle(.plain).accessibilityLabel("Edit weight for \(point.entry_date)")
                    if point.sync_state != "synced" {
                        Text(point.sync_state == "attention" ? "Needs review" : "Saved on this device. Waiting to sync.").font(.caption)
                    }
                }

                ForEach(nonWeightMeasurements) { measurement in
                    Button { editing = measurement } label: {
                    GlassCard(padding: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(measurement.type.capitalized)
                                    .font(.exBodyMedium)
                                    .foregroundStyle(.exTextPrimary)
                                Text(measurement.day?.formatted() ?? measurement.entry_date)
                                    .font(.exCaption)
                                    .foregroundStyle(.exTextMuted)
                                if measurement.sync_state != "synced" {
                                    Text(measurement.sync_state == "attention" ? "Needs review" : "Waiting to sync")
                                        .font(.caption).foregroundStyle(.exTextSecondary)
                                }
                            }
                            Spacer()
                            Text(formatBodyMeasurement(measurement))
                                .font(.exStatSmall)
                                .foregroundStyle(.exPrimary)
                        }
                    }
                    }.buttonStyle(.plain).accessibilityLabel("Edit \(measurement.type) measurement")
                }
            }
        }
    }

    private func displayValue(_ kilograms: Double) -> Double {
        unitSystem == "imperial" ? kilograms * poundsPerKilogram : kilograms
    }

    private func formatWeight(_ kilograms: Double, digits: Int) -> String {
        let scale = pow(10, Double(digits))
        let value = (displayValue(kilograms) * scale).rounded() / scale
        let unit = unitSystem == "imperial" ? "lb" : "kg"
        return "\(value.formatted(.number.precision(.fractionLength(digits)))) \(unit)"
    }

    private func signedWeight(_ kilograms: Double, suffix: String = "") -> String {
        let value = displayValue(kilograms)
        let sign = value > 0 ? "+" : ""
        let unit = unitSystem == "imperial" ? "lb" : "kg"
        return "\(sign)\(value.formatted(.number.precision(.fractionLength(2)))) \(unit)\(suffix)"
    }

    private func formattedDay(_ day: String) -> String {
        CalendarDay(rawValue: day)?.formatted() ?? day
    }

    private func formatBodyMeasurement(_ measurement: BodyMeasurementDTO) -> String {
        guard unitSystem == "imperial", measurement.unit.lowercased() == "cm" else {
            return "\(measurement.value.formatted(.number.precision(.fractionLength(0...2)))) \(measurement.unit)"
        }
        return "\((measurement.value / centimetersPerInch).formatted(.number.precision(.fractionLength(0...2)))) in"
    }
}

struct AddMeasurementSheet: View {
    let onSaved: () -> Void
    let editing: BodyMeasurementDTO?
    let onDeleted: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sync: SyncEngine
    @AppStorage("unitSystem") private var unitSystem = "metric"
    @State private var type = "waist"
    @State private var value = ""
    @State private var selectedDate: CalendarDay
    @State private var loadedInitialValue = false
    @State private var errorMessage: String?

    private let types = ["waist", "chest", "hips", "arms", "thighs", "neck", "calves", "body_fat"]

    init(initialDate: CalendarDay, editing: BodyMeasurementDTO? = nil, onDeleted: @escaping (String) -> Void = { _ in }, onSaved: @escaping () -> Void = {}) {
        self.editing = editing
        self.onDeleted = onDeleted
        self.onSaved = onSaved
        _type = State(initialValue: editing?.type ?? "waist")
        _selectedDate = State(initialValue: editing?.day ?? initialDate)
    }

    private var displayUnit: String {
        if type == "body_fat" { return "%" }
        return unitSystem == "imperial" ? "in" : "cm"
    }
    private var numericValue: Double? { try? Double(value, format: .number.locale(.current)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("measurement.type")
                    .tint(.exPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    FloatingLabelTextField(
                        label: "Value (\(displayUnit))",
                        text: $value,
                        keyboardType: .decimalPad
                    )

                    GlassCard {
                        CalendarDayPicker("Measurement date", selection: $selectedDate, today: sync.today,
                                          timeZoneIdentifier: sync.calendar.timeZoneIdentifier)
                        .font(.exLabel)
                        .foregroundStyle(.exTextSecondary)
                        .tint(.exPrimary)
                        .colorScheme(.dark)
                    }

                    ActionButton(
                        title: "Save",
                        isDisabled: numericValue == nil
                    ) {
                        save()
                    }
                    if let editing {
                        Button("Delete measurement", role: .destructive) {
                            do {
                                let id = try sync.deleteMeasurement(editing)
                                onDeleted(id)
                                onSaved()
                                dismiss()
                            } catch { errorMessage = error.localizedDescription }
                        }.frame(minHeight: 44)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.exCaption)
                            .foregroundStyle(.exError)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .background(Color.exBackground)
            .navigationTitle(editing == nil ? "Add Measurement" : "Edit Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.exTextSecondary)
                }
            }
        }
        .onAppear {
            guard !loadedInitialValue else { return }
            loadedInitialValue = true
            if let editing {
                let number = editing.unit == "cm" && unitSystem == "imperial" ? editing.value / centimetersPerInch : editing.value
                value = number.formatted(.number.grouping(.never).precision(.fractionLength(0...4)))
            }
        }
    }

    private func save() {
        guard let numeric = numericValue, numeric.isFinite, numeric > 0 else { return }
        errorMessage = nil

        let centimeters = type != "body_fat" && unitSystem == "imperial" ? numeric * centimetersPerInch : numeric
        do {
            try sync.saveMeasurement(BodyMeasurementRequest(type: type, value: centimeters,
                unit: type == "body_fat" ? "%" : "cm", entry_date: selectedDate.rawValue, note: editing?.note,
                source: editing?.source ?? "manual"), editing: editing)
            onSaved()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

}

private struct LegacyMeasurementReview: View {
    @Query(sort: \Measurement.date, order: .reverse) private var records: [Measurement]
    @EnvironmentObject private var sync: SyncEngine
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmedOwner = false
    @State private var selection: Set<PersistentIdentifier> = []
    @State private var reviewed: [PersistentIdentifier: LegacyMeasurementImport] = [:]
    @State private var proposedTimeZone: String?
    @State private var error: String?
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("The older app did not record which account these measurements belong to. Review them only if this device's saved measurements are yours.")
                    Toggle("These saved measurements are mine", isOn: $confirmedOwner)
                    Text("Selected measurements will sync to \(auth.currentUser?.email ?? "your signed-in account").")
                        .font(.callout)
                    Text("The original time zone was not saved. Import dates are proposed using \(proposedTimeZone ?? sync.calendar.timeZoneIdentifier). Check each date before importing; changing your account time zone does not change a reviewed date.")
                        .font(.callout)
                }
                if confirmedOwner {
                    Section("Choose measurements to import") {
                        ForEach(records) { record in
                            if canImport(record), let item = reviewed[record.persistentModelID] {
                                Toggle(isOn: Binding(
                                    get: { selection.contains(record.persistentModelID) },
                                    set: { if $0 { selection.insert(record.persistentModelID) } else { selection.remove(record.persistentModelID) } }
                                )) { recordLabel(record) }
                                if selection.contains(record.persistentModelID) {
                                    CalendarDayPicker("Import date", selection: Binding(
                                        get: { reviewed[record.persistentModelID]?.day ?? item.day },
                                        set: { reviewed[record.persistentModelID]?.day = $0 }
                                    ), today: sync.today, timeZoneIdentifier: sync.calendar.timeZoneIdentifier)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    recordLabel(record)
                                    Text("Keep this record in the export for review.").font(.caption)
                                }
                            }
                        }
                    }
                    Section {
                        Button("Import \(selection.count) selected measurements") {
                            do {
                                let items = selection.compactMap { reviewed[$0] }
                                guard items.count == selection.count else { throw APIError.unknown }
                                try sync.importLegacyMeasurements(items)
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }.disabled(selection.isEmpty).frame(minHeight: 44)
                        Button("Prepare an export of all older measurements") { prepareExport() }.frame(minHeight: 44)
                        if let exportURL { ShareLink("Share measurement export", item: exportURL).frame(minHeight: 44) }
                    }
                }
                if let error { Text(error).foregroundStyle(.exError) }
            }.navigationTitle("Older measurements")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .onAppear {
            guard proposedTimeZone == nil else { return }
            proposedTimeZone = sync.calendar.timeZoneIdentifier
            for record in records {
                if let day = sync.calendar.day(containing: record.date) {
                    reviewed[record.persistentModelID] = LegacyMeasurementImport(record, day: day)
                }
            }
        }
    }
    private func recordLabel(_ record: Measurement) -> some View {
        VStack(alignment: .leading) {
            Text("\(record.type.replacingOccurrences(of: "_", with: " ").capitalized): \(record.value, format: .number) \(record.unit)")
            Text("Original timestamp: \(record.date.ISO8601Format())").font(.caption)
        }
    }
    private func canImport(_ record: Measurement) -> Bool {
        let types = ["waist", "chest", "hips", "arms", "thighs", "neck", "calves", "body_fat"]
        let units = record.type == "body_fat" ? ["%"] : ["cm", "in"]
        return types.contains(record.type) && units.contains(record.unit.lowercased()) && record.value.isFinite && record.value > 0
    }
    private func prepareExport() {
        do {
            let rows: [[String: Any]] = records.map {
                ["type": $0.type, "value": $0.value, "unit": $0.unit, "date": $0.date.ISO8601Format()]
            }
            let data = try JSONSerialization.data(withJSONObject: ["version": 1, "account_unassigned": true, "measurements": rows], options: [.prettyPrinted, .sortedKeys])
            let url = FileManager.default.temporaryDirectory.appending(path: "exerly-older-measurements-\(UUID().uuidString).json")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            exportURL = url
        } catch { self.error = error.localizedDescription }
    }
}

struct WeightEntrySheet: View {
    let onDeleted: (String) -> Void
    let onSaved: () -> Void
    @EnvironmentObject private var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitSystem") private var unitSystem = "metric"
    @State private var date: CalendarDay
    @State private var current: WeightDayDTO?
    @State private var value = ""
    @State private var note = ""
    @State private var error: String?
    @State private var offline = false
    @State private var confirmingDelete = false
    @FocusState private var focused: Bool

    init(date: CalendarDay, onDeleted: @escaping (String) -> Void = { _ in }, onSaved: @escaping () -> Void = {}) {
        _date = State(initialValue: date)
        self.onDeleted = onDeleted
        self.onSaved = onSaved
    }
    private var unit: String { unitSystem == "imperial" ? "lb" : "kg" }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CalendarDayPicker("Reading date", selection: $date, today: sync.today, timeZoneIdentifier: sync.calendar.timeZoneIdentifier)
                    if let current {
                        if current.deleted_at != nil {
                            Text("This reading was deleted. Restore it to keep the same reading and history.")
                            Button("Restore weight reading") {
                                do { try sync.undoWeightDeletion(entityID: current.entry_date); onSaved(); dismiss() }
                                catch { self.error = error.localizedDescription }
                            }.frame(minHeight: 44)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Weight (\(unit))")
                                TextField("Weight (\(unit))", text: $value)
                                    .keyboardType(.decimalPad).focused($focused)
                                    .accessibilityIdentifier("weight.value")
                            }
                            TextField("Optional note", text: $note, axis: .vertical)
                                .focused($focused).accessibilityIdentifier("weight.note")
                            if current.exists {
                                Text("Current reading: \((current.weight_kg ?? 0) * (unitSystem == "imperial" ? poundsPerKilogram : 1), format: .number.precision(.fractionLength(0...2))) \(unit) · \(current.source ?? "manual")")
                                    .font(.callout)
                                Button("Delete weight reading", role: .destructive) { confirmingDelete = true }.frame(minHeight: 44)
                            }
                        }
                        if current.sync_state == "pending" { Text("Saved on this device. Waiting to sync.").font(.callout) }
                        if current.sync_state == "attention" { NavigationLink("Review weight changes") { SyncIssuesView() } }
                    } else { ProgressView("Loading this day's reading") }
                }
                if offline { Section { Text("Offline. Your reading will be saved on this device and checked for competing changes when you reconnect.").font(.callout) } }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Log weight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save weight") { save() }
                        .disabled(current == nil || current?.deleted_at != nil || value.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
            }
            .alert("Delete this weight reading?", isPresented: $confirmingDelete) {
                Button("Delete reading", role: .destructive) {
                    guard let current else { return }
                    do { onDeleted(try sync.deleteWeight(current)); onSaved(); dismiss() }
                    catch { self.error = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("You can undo the deletion after closing this form.") }
            .task(id: date.rawValue) { await load() }
        }
    }
    private func load() async {
        let selectedDay = date.rawValue
        current = nil; error = nil; offline = false
        do {
            let row: WeightDayDTO
            do { row = try await sync.weightDay(for: date) }
            catch {
                if error is CancellationError { throw error }
                if let apiError = error as? APIError, !apiError.permitsReadRetry { throw error }
                row = try await sync.weightDay(for: date, cachedOnly: true)
                offline = true
            }
            guard date.rawValue == selectedDay, !Task.isCancelled else { return }
            current = row
            value = row.weight_kg.map { ($0 * (unitSystem == "imperial" ? poundsPerKilogram : 1)).formatted(.number.grouping(.never).precision(.fractionLength(0...4))) } ?? ""
            note = row.note ?? ""
        } catch { self.error = error.localizedDescription }
    }
    private func save() {
        guard let current else { return }
        guard let number = try? Double(value, format: .number.locale(.current)), number.isFinite else {
            error = "Enter a valid weight in \(unit)."; return
        }
        do {
            try sync.saveWeight(current, kilograms: unitSystem == "imperial" ? number / poundsPerKilogram : number, note: note)
            onSaved(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
