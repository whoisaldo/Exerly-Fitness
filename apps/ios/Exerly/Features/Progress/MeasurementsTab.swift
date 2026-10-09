import Charts
import ExerlyCore
import SwiftData
import SwiftUI

private let centimetersPerInch = USUnits.centimetersPerInch

@MainActor
final class MeasurementsViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published var error: String?
    @Published private(set) var measurements: [BodyMeasurementDTO] = []
    private var generation = UUID()

    /// Body measurements stay on the daily-log sync for now; weigh-ins live in ExerlyCore.
    func load(today: CalendarDay) async {
        let generation = UUID()
        self.generation = generation
        isLoading = true
        error = nil
        let from = today.adding(days: -3650)!.rawValue
        let to = today.rawValue
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
        if self.generation == generation { isLoading = false }
    }
}

/// What the weigh-in sheet opens on.
private enum WeighInRequest: Identifiable {
    case new
    case edit(WeightEntry)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let entry): entry.id.uuidString
        }
    }
}

struct MeasurementsTab: View {
    let workspace: TrainingWorkspace?
    let unit: MassUnit
    let timeZone: TimeZone
    let openingError: String?
    @Query private var legacyMeasurements: [Measurement]
    @EnvironmentObject private var sync: SyncEngine
    @AppStorage("unitSystem") private var unitSystem = "imperial"
    @StateObject private var viewModel = MeasurementsViewModel()
    @State private var showAddSheet = false
    @State private var editing: BodyMeasurementDTO?
    @State private var lastDeletedID: String?
    @State private var actionError: String?
    @State private var showLegacyReview = false
    @State private var weighIn: WeighInRequest?
    @State private var deletedWeight: WeightEntry?

    init(initialDate: CalendarDay, workspace: TrainingWorkspace?, unit: MassUnit, timeZone: TimeZone, openingError: String? = nil) {
        self.workspace = workspace
        self.unit = unit
        self.timeZone = timeZone
        self.openingError = openingError
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ExSpacing.page) {
                if let deletedWeight {
                    banner("Weigh-in deleted.", action: "Undo") { undoDelete(deletedWeight) }
                        .accessibilityIdentifier("body.undoDelete")
                }
                if lastDeletedID != nil {
                    banner("Measurement removed.", action: "Undo") {
                        do {
                            try sync.undoMeasurementDeletion(entityID: lastDeletedID!)
                            lastDeletedID = nil
                        } catch { actionError = error.localizedDescription }
                    }
                }
                if let actionError { Text(actionError).font(.exCaption).foregroundStyle(Color.exError) }
                if let workspace {
                    BodyWeightSection(workspace: workspace, unit: unit, timeZone: timeZone, onWeighIn: { weighIn = .new },
                                      onEdit: { weighIn = .edit($0) }, onDelete: delete)
                } else if let openingError {
                    ExCard { Text(openingError).font(.exBody).foregroundStyle(Color.exTextSecondary) }
                } else {
                    LoadingStateView(message: "Opening your weigh-ins…").frame(height: 160)
                }
                measurementsSection
                if !legacyMeasurements.isEmpty {
                    Text("Measurements from an older version are preserved on this device. They have not been assigned to this account.")
                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    Button("Review older measurements") { showLegacyReview = true }.frame(minHeight: 44)
                }
                if sync.attentionCount > 0 {
                    NavigationLink("Review unsynced changes") { SavedChangesReviewView() }
                        .frame(minHeight: 44)
                }
                #if DEBUG
                // Design review only: the home screen's card, shown here until Today hosts it.
                if let workspace, ProcessInfo.processInfo.environment["EXERLY_SHOW_WEIGHT_CARD"] == "1" {
                    ExSectionHeading("Home card preview")
                    WeightTrendCard(workspace: workspace, unit: unit, timeZone: timeZone) { weighIn = .new }
                }
                #endif
            }
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, ExSpacing.page)
            .padding(.top, ExSpacing.small)
            .padding(.bottom, ExSpacing.major)
        }
        .exScrollEdges()
        .refreshable {
            await viewModel.load(today: sync.today)
            await workspace?.synchronize()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
                    .frame(minWidth: 44, minHeight: 44).accessibilityLabel("Add measurement")
            }
        }
        .sheet(item: $weighIn) { request in
            if let workspace {
                switch request {
                case .new: WeighInSheet(workspace: workspace, unit: unit, timeZone: timeZone)
                case .edit(let entry):
                    WeighInSheet(workspace: workspace, unit: unit, timeZone: timeZone, editing: entry,
                                 onDeleted: { deletedWeight = $0 })
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMeasurementSheet(initialDate: sync.today, onSaved: {
                Task { await viewModel.load(today: sync.today) }
            })
        }
        .sheet(item: $editing) { measurement in
            AddMeasurementSheet(initialDate: sync.today, editing: measurement, onDeleted: { lastDeletedID = $0 },
                                onSaved: { Task { await viewModel.load(today: sync.today) } })
        }
        .sheet(isPresented: $showLegacyReview) { LegacyMeasurementReview() }
        .onChange(of: sync.changeToken) { _, _ in Task { await viewModel.load(today: sync.today) } }
        .task(id: "\(sync.today.rawValue)-\(sync.calendar.timeZoneIdentifier)") {
            await viewModel.load(today: sync.today)
        }
        .task(id: workspace?.identity) {
            if let workspace { await LegacyWeighIns.importIfNeeded(workspace, timeZone: timeZone) }
        }
    }

    private func banner(_ message: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack {
            Text(message).font(.exBody).foregroundStyle(Color.exTextPrimary)
            Spacer()
            Button(action, action: perform).font(.exBodyMedium).foregroundStyle(Color.exPrimaryText).frame(minHeight: 44)
        }
        .padding(.horizontal, ExSpacing.content)
        .background(Color.exSurface2, in: RoundedRectangle(cornerRadius: ExRadius.control, style: .continuous))
    }

    private func delete(_ entry: WeightEntry) {
        guard let workspace else { return }
        do {
            try workspace.nutrition.deleteWeight(entry.id)
        } catch {
            actionError = BodyFormat.message(error)
            return
        }
        deletedWeight = entry
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task {
            await LegacyWeighIns.forget(entry, accountID: workspace.accountID)
            await workspace.synchronize()
        }
    }

    /// Brings a deleted weigh-in back as a new one with the same reading and time.
    private func undoDelete(_ entry: WeightEntry) {
        guard let workspace else { return }
        do {
            try workspace.nutrition.logWeight(entry.weight, bodyFat: entry.bodyFat, at: entry.at, timeZone: timeZone)
            deletedWeight = nil
            Task { await workspace.synchronize() }
        } catch { actionError = BodyFormat.message(error) }
    }

    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            ExSectionHeading("Measurements", detail: viewModel.measurements.isEmpty ? nil : "\(viewModel.measurements.count)")
            if viewModel.measurements.isEmpty {
                ExCard {
                    Text(viewModel.isLoading ? "Loading measurements…" : "Waist, hips, arms and more. Add one with +.")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary)
                    if let error = viewModel.error { Text(error).font(.exCaption).foregroundStyle(Color.exError) }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.measurements.enumerated()), id: \.element.id) { index, measurement in
                        if index > 0 { Rectangle().fill(Color.exBorder.opacity(0.5)).frame(height: 0.5).padding(.leading, ExSpacing.content) }
                        Button { editing = measurement } label: {
                            HStack(spacing: ExSpacing.item) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(measurement.type.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                                    Text(measurement.day?.formatted() ?? measurement.entry_date)
                                        .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                                    if measurement.sync_state != "synced" {
                                        Text(measurement.sync_state == "attention" ? "Needs review" : "Waiting to sync")
                                            .font(.exCaption).foregroundStyle(Color.exTextSecondary)
                                    }
                                }
                                Spacer(minLength: ExSpacing.small)
                                Text(formatBodyMeasurement(measurement)).font(.exStatSmall).foregroundStyle(Color.exTextPrimary)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.exTextMuted)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, ExSpacing.content).frame(minHeight: 56).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).accessibilityLabel("Edit \(measurement.type) measurement")
                    }
                }
                .background(Color.exSurface1, in: RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: ExRadius.card, style: .continuous).strokeBorder(Color.exBorder.opacity(0.5), lineWidth: 0.5)
                }
            }
        }
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
    @AppStorage("unitSystem") private var unitSystem = "imperial"
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
            ExScreen {
                ExCard(accent: true) {
                    ExEyebrow("Area", color: .exPrimaryText)
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("measurement.type")
                    .tint(.exPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ExQuantityControl(title: "Value (\(displayUnit))", text: $value,
                                      step: type == "body_fat" ? 0.5 : 1, unit: displayUnit)
                }

                    ExCard {
                        CalendarDayPicker("Measurement date", selection: $selectedDate, today: sync.today,
                                          timeZoneIdentifier: sync.calendar.timeZoneIdentifier)
                        .font(.exLabel)
                        .foregroundStyle(.exTextSecondary)
                        .tint(.exPrimaryText)
                    }

                    Button("Save", action: save).buttonStyle(ExActionStyle())
                        .disabled(numericValue == nil || (numericValue ?? 0) <= 0)
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
            ExList {
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
