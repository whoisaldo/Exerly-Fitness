import ExerlyCore
import SwiftUI

/// App presentation for the existing daily-health sync contract.
/// Core keeps ownership of the queue, revisions and resolution operations.
struct SavedChangesReviewView: View {
    @EnvironmentObject private var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss
    @State private var issues: [SyncEngine.Issue] = []
    @State private var error: String?

    var body: some View {
        ExScreen {
            if let error {
                ExEmptyState(icon: "exclamationmark.icloud", title: "Changes could not load",
                             message: error, action: "Try again", perform: load)
            } else if issues.isEmpty {
                ExEmptyState(icon: "checkmark.icloud", title: "All changes are synced",
                             message: "There are no saved changes waiting for your review.",
                             action: "Done") { dismiss() }
            } else {
                ExCard(accent: true) {
                    ExEyebrow("Sync review", color: .exPrimaryText)
                    Text("\(issues.count) \(issues.count == 1 ? "change" : "changes") to review").font(.exH1)
                    Text("An entry changed on another device. Compare both versions before deciding what to keep.")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary)
                }
                ExCard {
                    ForEach(issues) { issue in
                        NavigationLink {
                            SavedChangeReviewView(issue: issue)
                        } label: {
                            ExNavigationLabel(title: issue.name, icon: "arrow.triangle.2.circlepath")
                        }
                        if issue.id != issues.last?.id { Divider() }
                    }
                }
            }
        }
        .navigationTitle("Changes to review").navigationBarTitleDisplayMode(.inline)
        .task(id: sync.changeToken) { load() }
    }

    private func load() {
        do { issues = try sync.issues(); error = nil } catch { self.error = error.localizedDescription }
    }
}

private struct SavedChangeReviewView: View {
    let issue: SyncEngine.Issue
    @EnvironmentObject private var sync: SyncEngine
    @AppStorage("unitSystem") private var unitSystem = "imperial"
    @Environment(\.dismiss) private var dismiss
    @State private var server: FoodDTO?
    @State private var serverMeasurement: BodyMeasurementDTO?
    @State private var serverDay: DiaryDayDTO?
    @State private var serverWater: WaterDayDTO?
    @State private var serverWeight: WeightDayDTO?
    @State private var serverActivity: ActivityDTO?
    @State private var serverSleep: SleepDTO?
    @State private var deleted = false
    @State private var loaded = false
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        ExScreen {
            VStack(alignment: .leading, spacing: ExSpacing.small) {
                ExEyebrow("Review before syncing", color: .exPrimaryText)
                Text(issue.name).font(.exH2)
                Text(issue.message).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            }
            ExCard(accent: true) {
                ExSectionHeading("Your saved change")
                if let food = issue.local { foodSummary(food) }
                if let measurement = issue.measurement { measurementSummary(measurement) }
                if let day = issue.diaryDay { daySummary(day) }
                if let water = issue.water { waterSummary(water) }
                if let weight = issue.weight { weightSummary(weight) }
                if let activity = issue.activity { activitySummary(activity) }
                if let sleep = issue.sleep { sleepSummary(sleep) }
            }
            if loaded {
                ExCard {
                    ExSectionHeading("Server version")
                    if deleted { Text("This entry was deleted on another device.") } else if let server { foodSummary(server) } else if let serverMeasurement { measurementSummary(serverMeasurement) } else if let serverDay { daySummary(serverDay) } else if let serverWater { waterSummary(serverWater) } else if let serverWeight { weightSummary(serverWeight) } else if let serverActivity { activitySummary(serverActivity) } else if let serverSleep { sleepSummary(serverSleep) } else { Text("This entry has not reached the server.") }
                }
                VStack(spacing: ExSpacing.small) {
                    if !deleted || issue.intent == .restore {
                        if issue.intent == .delete {
                            Button("Delete reviewed entry", role: .destructive) { resolve(useServer: false) }
                                .font(.exBodyMedium).frame(minHeight: 44)
                        } else {
                            Button(issue.kind == "water" ? "Retry pending additions" : issue.intent == .restore ? "Restore reviewed entry" : "Save my changes") {
                                resolve(useServer: false)
                            }.buttonStyle(ExActionStyle())
                        }
                    }
                    Button(discardTitle, role: .destructive) { resolve(useServer: true) }
                        .font(.exBodyMedium).frame(minHeight: 44)
                }.disabled(isSaving)
            } else if error == nil { ProgressView("Loading current entry") }
            if let error {
                ExCard {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Color.exError)
                    if !loaded { Button("Try again") { Task { await loadServer() } }.frame(minHeight: 44) }
                }
            }
        }
        .navigationTitle("Review change").navigationBarTitleDisplayMode(.inline)
        .task { await loadServer() }
    }

    private var discardTitle: String {
        if deleted { return "Keep the deletion" }
        if server == nil && serverMeasurement == nil && serverDay == nil && serverWater == nil && serverWeight == nil && serverActivity == nil && serverSleep == nil {
            return "Discard my unsynced entry"
        }
        return "Use the server version"
    }

    private func loadServer() async {
        error = nil
        do {
            if issue.kind == "measurement" { (serverMeasurement, deleted) = try await sync.serverMeasurementVersion(for: issue) } else if issue.kind == "diary_day" { (serverDay, deleted) = try await sync.serverDiaryDayVersion(for: issue) } else if issue.kind == "water" { (serverWater, deleted) = try await sync.serverWaterVersion(for: issue) } else if issue.kind == "weight" { (serverWeight, deleted) = try await sync.serverWeightVersion(for: issue) } else if issue.kind == "activity" { (serverActivity, deleted) = try await sync.serverActivityVersion(for: issue) } else if issue.kind == "sleep" { (serverSleep, deleted) = try await sync.serverSleepVersion(for: issue) } else { (server, deleted) = try await sync.serverVersion(for: issue) }
            loaded = true
        } catch { self.error = error.localizedDescription }
    }

    private func date(_ value: String) -> String {
        CalendarDay(rawValue: value)?.formatted() ?? value
    }

    private func foodSummary(_ food: FoodDTO) -> some View {
        Text("\(food.servings, format: .number) servings · \(food.calories) kcal").font(.exStatSmall)
    }

    private func measurementSummary(_ item: BodyMeasurementDTO) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            Text("\(item.value, format: .number) \(item.unit)").font(.exStatMedium)
            Text(date(item.entry_date)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
        }
    }

    private func waterSummary(_ row: WaterDayDTO) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            Text("\(row.ml.formatted()) ml").font(.exStatMedium)
            Text(date(row.entry_date)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
        }
    }

    private func weightSummary(_ row: WeightDayDTO) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            if let kg = row.weight_kg {
                let unit: MassUnit = unitSystem == "imperial" ? .pounds : .kilograms
                Text("\(Mass.kg(kg).value(in: unit), format: .number.precision(.fractionLength(0...2))) \(unit.rawValue)").font(.exStatMedium)
            } else { Text("No reading") }
            Text(date(row.entry_date)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            if let note = row.note, !note.isEmpty { Text(note) }
            Text("Source: \(row.source ?? "manual") · Revision \(row.revision)").font(.exCaption).foregroundStyle(Color.exTextSecondary)
        }
    }

    private func activitySummary(_ row: ActivityDTO) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            Text(row.type).font(.exBodyMedium)
            Text("\(row.duration, format: .number) minutes").font(.exStatMedium)
            if let value = row.date { Text(date(value)).font(.exCaption).foregroundStyle(Color.exTextSecondary) }
            if let calories = row.calories { Text("\(calories, format: .number) kcal") } else { Text("Energy not recorded") }
            if let intensity = row.intensity { Text(intensity.capitalized) }
        }
    }

    private func sleepSummary(_ row: SleepDTO) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            Text("\(row.hours, format: .number) hours").font(.exStatMedium)
            if let value = row.date { Text(date(value)).font(.exCaption).foregroundStyle(Color.exTextSecondary) }
            if let quality = row.qualityLabel { Text("Quality: \(quality)") }
            if let bedtime = row.bedtime { Text("Bedtime: \(bedtime)") }
            if let wakeTime = row.wakeTime { Text("Wake time: \(wakeTime)") }
        }
    }

    private func daySummary(_ day: DiaryDayDTO) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.small) {
            Text(day.status.title).font(.exBodyMedium)
            Text(date(day.entry_date)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
            if let note = day.note, !note.isEmpty { Text(note) }
        }
    }

    private func resolve(useServer: Bool) {
        isSaving = true
        Task {
            do {
                try await sync.resolveIssue(issue.id, useServer: useServer,
                    reviewedRevision: server?.revision ?? serverMeasurement?.revision ?? serverDay?.revision ?? serverWeight?.revision ?? serverActivity?.revision ?? serverSleep?.revision)
                dismiss()
            } catch { self.error = error.localizedDescription; isSaving = false }
        }
    }
}
