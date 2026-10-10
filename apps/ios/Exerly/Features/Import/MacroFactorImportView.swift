import ExerlyCore
import SwiftUI
import UniformTypeIdentifiers

/// Imports MacroFactor's data export: where to export it, choosing the file,
/// a preview of what it adds, the import kind by kind, and the result.
/// Reading, mapping and saving are ExerlyCore's (`MacroFactorExport`,
/// `MacroFactorImport`); this screen shows them.
struct MacroFactorImportView: View {
    @ObservedObject var workspace: TrainingWorkspace
    let unit: MassUnit
    let timeZone: TimeZone
    @EnvironmentObject private var sync: SyncEngine
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var phase: Phase = .start
    @State private var choosing = false

    typealias Kind = MacroFactorImportSummary.Kind

    enum Phase {
        case start
        case reading
        case unreadable(String)
        case preview(MacroFactorImport, files: [String])
        case importing(Kind, step: Int, of: Int)
        case done(MacroFactorImportSummary)
    }

    init(workspace: TrainingWorkspace, unit: MassUnit, timeZone: TimeZone) {
        self.workspace = workspace
        self.unit = unit
        self.timeZone = timeZone
    }

    private static let types: [UTType] = [UTType("org.openxmlformats.spreadsheetml.sheet"), .commaSeparatedText, .spreadsheet]
        .compactMap { $0 }

    private var isImporting: Bool {
        if case .importing = phase { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ExSpacing.content) {
                switch phase {
                case .start: start
                case .reading: reading
                case .unreadable(let message):
                    unreadable(message)
                    start
                case .preview(let plan, let files): preview(plan, files: files)
                case .importing(let kind, let step, let total): importing(kind, step: step, of: total)
                case .done(let summary): done(summary)
                }
            }
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, ExSpacing.page)
            .padding(.top, ExSpacing.small)
            .padding(.bottom, ExSpacing.major)
        }
        .scrollIndicators(.hidden)
        .exScrollEdges()
        .background(Color.exBackground)
        .accessibilityIdentifier("mfImport.screen")
        .navigationTitle("Import from MacroFactor")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isImporting)
        .fileImporter(isPresented: $choosing, allowedContentTypes: Self.types, allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): if !urls.isEmpty { read(urls: urls) }
            case .failure(let error): withAnimation(.snappy) { phase = .unreadable(error.localizedDescription) }
            }
        }
    }

    // MARK: Start

    @ViewBuilder
    private var start: some View {
        ExCard(accent: true) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: "arrow.down.doc").font(.system(size: 26, weight: .medium)).foregroundStyle(Color.exPrimaryText)
                    .frame(width: 56, height: 56).background(Color.exPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
            }
            Text("Bring your MacroFactor history").font(.exH2).foregroundStyle(Color.exTextPrimary)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            if typeSize.isAccessibilitySize { chooseButtons }
            Text("Import MacroFactor's export to see your food log, weigh-ins, trend and workouts here. The file is read on this iPhone.")
                .font(typeSize.isAccessibilitySize ? .exCaption : .exBody).foregroundStyle(Color.exTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !typeSize.isAccessibilitySize { chooseButtons }
        }
        ExCard {
            ExEyebrow("Export from MacroFactor")
            step(1, "Open Data Export", "In MacroFactor, tap More, then Data Export under Data Management.")
            step(2, "Choose Granular Export", "Select every kind of data, including the food log and workouts. Quick Export works too, "
                 + "with each day's totals instead of each food.")
            step(3, "Save the spreadsheet", "Export it and save it to Files or iCloud Drive, then choose it here. You can choose several files at once.")
        }
        ExCard {
            ExEyebrow("What comes across")
            VStack(spacing: 0) {
                included("fork.knife", "Food log", "Each food with its nutrients, or each day's totals")
                TargetsDivider()
                included("scalemass", "Weigh-ins", "With body fat. Exerly works out your trend and expenditure from them.")
                TargetsDivider()
                included("calendar", "Fasting and partial days", "So expenditure counts the right days")
                TargetsDivider()
                included("target", "Nutrition targets", "As past versions. Your Exerly targets stay in force.")
                TargetsDivider()
                included("books.vertical", "Custom foods, favorites and recipes", "Into your food library")
                TargetsDivider()
                included("dumbbell", "Workouts", "Matched to Exerly's exercises by name")
            }
            Text("Left out: MacroFactor's trend weight and expenditure, steps, body measurements and training programs. "
                 + "Importing the same file again adds nothing twice.")
                .font(.exSmall).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var chooseButtons: some View {
        Button { choosing = true } label: { Label("Choose export file", systemImage: "doc.badge.plus") }
            .buttonStyle(ExActionStyle()).accessibilityIdentifier("mfImport.choose")
        #if DEBUG
        if let file = ProcessInfo.processInfo.environment["EXERLY_MF_IMPORT_FILE"].flatMap({ Data(base64Encoded: $0) }) {
            Button("Use the test export") { read(files: [("Test export.xlsx", file)]) }
                .buttonStyle(ExActionStyle(secondary: true)).accessibilityIdentifier("mfImport.testFile")
        }
        #endif
    }

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ExSpacing.item) {
            Text("\(number)").font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(Color.exPrimaryText)
                .frame(width: 28, height: 28).background(Color.exPrimary.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                Text(detail).font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number), \(title). \(detail)")
    }

    private func included(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: ExSpacing.item) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.exPrimaryText)
                    .frame(width: 32, height: 32).background(Color.exPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
                Text(detail).font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, ExSpacing.small)
        .accessibilityElement(children: .combine)
    }

    // MARK: Reading

    private var reading: some View {
        ExCard {
            HStack(spacing: ExSpacing.item) {
                ProgressView().tint(Color.exPrimaryText)
                Text("Reading your export…").font(.exBodyMedium).foregroundStyle(Color.exTextPrimary)
            }
            .frame(minHeight: 44)
            Text("Large exports take a few seconds.").font(.exCaption).foregroundStyle(Color.exTextSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mfImport.reading")
    }

    private func unreadable(_ message: String) -> some View {
        Label {
            Text(message).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .font(.exCaption).foregroundStyle(Color.exError)
        .padding(ExSpacing.item)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.exError.opacity(0.08), in: RoundedRectangle(cornerRadius: ExRadius.control))
        .accessibilityIdentifier("mfImport.error")
    }

    private func read(urls: [URL]) {
        read {
            try urls.map { url in
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                return (url.lastPathComponent, try Data(contentsOf: url))
            }
        }
    }

    private func read(files: [(name: String, data: Data)]) { read { files } }

    /// Reads and maps the files away from the main thread, then checks them
    /// against what Exerly already has.
    private func read(_ load: @escaping @Sendable () throws -> [(name: String, data: Data)]) {
        withAnimation(.snappy) { phase = .reading }
        let library = workspace.store.library, timeZone = timeZone, unit = unit
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<(MacroFactorExport, [String]), Error> in
                Result {
                    let files = try load()
                    return (try MacroFactorExport.read(files, timeZone: timeZone, unit: unit, library: library), files.map(\.name))
                }
            }.value
            withAnimation(.snappy) {
                switch result {
                case .success(let (export, names)):
                    phase = .preview(MacroFactorImport(export, nutrition: workspace.nutrition, training: workspace.store), files: names)
                case .failure(let error):
                    phase = .unreadable(Self.message(error))
                }
            }
        }
    }

    private static func message(_ error: Error) -> String {
        switch error {
        case Spreadsheet.ReadError.unreadable: "This file isn't a spreadsheet. Choose the .xlsx file MacroFactor exported."
        case Spreadsheet.ReadError.damaged(let detail): "This spreadsheet can't be read (\(detail)). Export it from MacroFactor again."
        case Spreadsheet.ReadError.tooLarge: "This spreadsheet is too large to import."
        default: "The file couldn't be opened. \(error.localizedDescription)"
        }
    }

    // MARK: Preview

    @ViewBuilder
    private func preview(_ plan: MacroFactorImport, files: [String]) -> some View {
        let summary = plan.summary
        ExCard(accent: true) {
            ExEyebrow(plan.steps.isEmpty ? "Nothing new" : "Ready to import", color: .exPrimaryText)
            Text(range(summary.dateRange) ?? "No dated history").font(.exH2).foregroundStyle(Color.exTextPrimary)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(previewDetail(plan, files: files)).font(.exCaption).foregroundStyle(Color.exTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            counts(summary, showExisting: true)
            if !plan.steps.isEmpty {
                Button { runImport(plan) } label: { Label("Import", systemImage: "square.and.arrow.down") }
                    .buttonStyle(ExActionStyle()).accessibilityIdentifier("mfImport.import")
            }
            Button("Choose another file") { choosing = true }
                .buttonStyle(ExActionStyle(secondary: true)).accessibilityIdentifier("mfImport.chooseAgain")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mfImport.preview")
        report(summary)
    }

    private func previewDetail(_ plan: MacroFactorImport, files: [String]) -> String {
        let from = files.count == 1 ? files[0] : "\(files.count) files"
        if plan.export.isEmpty { return "Exerly found nothing it can import in \(from). Below is what it saw." }
        if plan.steps.isEmpty { return "Everything in \(from) is already in Exerly." }
        return "From \(from). Nothing is saved until you import."
    }

    @ViewBuilder
    private func counts(_ summary: MacroFactorImportSummary, showExisting: Bool) -> some View {
        let kinds = Kind.allCases.filter { summary[$0].new > 0 || (showExisting && summary[$0].existing > 0) }
        if !kinds.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(kinds.enumerated()), id: \.element) { index, kind in
                    if index > 0 { TargetsDivider() }
                    countRow(kind, summary[kind], replaced: kind == .entries ? summary.replacedDayTotals : 0, showExisting: showExisting)
                }
            }
        }
    }

    private func countRow(_ kind: Kind, _ count: MacroFactorImportSummary.Count, replaced: Int, showExisting: Bool) -> some View {
        let detail = [showExisting && count.existing > 0 ? "\(count.existing) already in Exerly" : nil,
                      replaced > 0 ? "replaces \(replaced) day \(replaced == 1 ? "total" : "totals")" : nil]
            .compactMap { $0 }.joined(separator: ", ")
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: ExSpacing.small))
        return layout {
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.title(kind)).font(.exBody).foregroundStyle(Color.exTextSecondary)
                if !detail.isEmpty { Text(detail).font(.exSmall).foregroundStyle(Color.exTextMuted) }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: ExSpacing.small) }
            Text(count.new.formatted()).font(.exStatSmall).monospacedDigit()
                .foregroundStyle(count.new > 0 ? Color.exTextPrimary : Color.exTextMuted)
        }
        .padding(.vertical, ExSpacing.small).frame(minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.title(kind))
        .accessibilityValue([count.new.formatted() + " to add", detail.isEmpty ? nil : detail].compactMap { $0 }.joined(separator: ", "))
        .accessibilityIdentifier("mfImport.count.\(kind.rawValue)")
    }

    static func title(_ kind: Kind) -> String {
        switch kind {
        case .foods: "Foods and recipes"
        case .entries: "Foods logged"
        case .dayTotals: "Days as daily totals"
        case .days: "Day statuses"
        case .weights: "Weigh-ins"
        case .plans: "Target versions"
        case .workouts: "Workouts"
        }
    }

    private func range(_ range: ClosedRange<LocalDate>?) -> String? {
        guard let range else { return nil }
        let today = LocalDate(Date(), in: timeZone)
        let last = TargetsFormat.shortDate(range.upperBound, today: today)
        guard range.lowerBound != range.upperBound else { return last }
        return "\(TargetsFormat.shortDate(range.lowerBound, today: range.lowerBound.year == range.upperBound.year ? range.upperBound : today)) – \(last)"
    }

    // MARK: Report

    /// What was left out and how the file was read, for checking a real export.
    @ViewBuilder
    private func report(_ summary: MacroFactorImportSummary) -> some View {
        let report = summary.report
        let skipped = Dictionary(grouping: report.skipped, by: \.sheet)
        if !report.skipped.isEmpty || !report.unmappedExercises.isEmpty || !report.unknownColumns.isEmpty {
            ExCard {
                ExSectionHeading("Not imported")
                ForEach(skipped.keys.sorted(), id: \.self) { sheet in
                    let rows = skipped[sheet] ?? []
                    issue("\(sheet) · \(rows.count) \(rows.count == 1 ? "row" : "rows") left out",
                          lines: rows.prefix(3).map { ($0.row.map { "Row \($0): " } ?? "") + $0.reason },
                          more: rows.count - 3)
                }
                if !report.unmappedExercises.isEmpty {
                    let names = report.unmappedExercises.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
                    issue("Exercises Exerly doesn't have", lines: names.prefix(6).map { "\($0.key) · \($0.value) \($0.value == 1 ? "set" : "sets")" },
                          more: names.count - 6, note: "Their sets were left out.")
                }
                if !report.unknownColumns.isEmpty {
                    issue("Columns Exerly didn't recognise",
                          lines: report.unknownColumns.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value.joined(separator: ", "))" },
                          note: "Their cells were ignored.")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("mfImport.issues")
        }
        let leftOut = report.sheets.filter { !$0.imported }
        if !leftOut.isEmpty || !report.assumptions.isEmpty {
            ExCard {
                ExSectionHeading("How the file was read")
                if !report.assumptions.isEmpty {
                    VStack(alignment: .leading, spacing: ExSpacing.small) {
                        ForEach(report.assumptions, id: \.self) { line(text: $0) }
                    }
                }
                if !leftOut.isEmpty {
                    issue("Sheets left out", lines: leftOut.map { "\($0.name): \($0.detail)" })
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("mfImport.notes")
        }
    }

    private func issue(_ title: String, lines: [String], more: Int = 0, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: ExSpacing.tight) {
            Text(title).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary).fixedSize(horizontal: false, vertical: true)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, text in line(text: text) }
            if more > 0 { Text("and \(more) more").font(.exSmall).foregroundStyle(Color.exTextMuted) }
            if let note { Text(note).font(.exSmall).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true) }
        }
        .accessibilityElement(children: .combine)
    }

    private func line(text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ExSpacing.small) {
            Circle().fill(Color.exTextMuted).frame(width: 4, height: 4).accessibilityHidden(true)
            Text(text).font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Import

    /// Saves kind by kind, each as one unit, checked again against the stores
    /// first in case sync changed them since the preview.
    private func runImport(_ preview: MacroFactorImport) {
        let plan = MacroFactorImport(preview.export, nutrition: workspace.nutrition, training: workspace.store)
        let steps = plan.steps
        Task {
            var result = plan.summary
            for (index, kind) in steps.enumerated() {
                withAnimation(.snappy) { phase = .importing(kind, step: index, of: steps.count) }
                // Let the step show before the save holds the main thread.
                try? await Task.sleep(for: .milliseconds(60))
                do {
                    try plan.save(kind, nutrition: workspace.nutrition, training: workspace.store)
                } catch {
                    result.failures[kind] = MacroFactorImport.describe(error)
                }
            }
            UINotificationFeedbackGenerator().notificationOccurred(result.failures.isEmpty ? .success : .warning)
            withAnimation(.snappy) { phase = .done(result) }
            UIAccessibility.post(notification: .announcement, argument: result.failures.isEmpty ? "Import finished" : "Import finished with problems")
            await workspace.synchronize()
        }
    }

    private func importing(_ kind: Kind, step: Int, of total: Int) -> some View {
        ExCard {
            ExEyebrow("Importing", color: .exPrimaryText)
            Text("Saving \(Self.title(kind).lowercased())…").font(.exH2).foregroundStyle(Color.exTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            ExProgressBar(value: Double(step + 1), total: Double(total))
            Text("Step \(step + 1) of \(total). Each kind is saved whole or not at all.")
                .font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mfImport.importing")
    }

    // MARK: Done

    @ViewBuilder
    private func done(_ summary: MacroFactorImportSummary) -> some View {
        ExCard(accent: true) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: summary.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(summary.failures.isEmpty ? Color.exSuccess : Color.exWarning)
                    .accessibilityHidden(true)
            }
            Text(summary.failures.isEmpty ? "Your history is in Exerly" : "Imported, with problems").font(.exH2)
                .foregroundStyle(Color.exTextPrimary).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(doneDetail(summary)).font(.exCaption).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
            counts(summary, showExisting: false)
            ForEach(Kind.allCases.filter { summary.failures[$0] != nil }, id: \.self) { kind in
                Label("\(Self.title(kind)) weren't imported: \(summary.failures[kind] ?? "")", systemImage: "exclamationmark.triangle")
                    .font(.exCaption).foregroundStyle(Color.exError).fixedSize(horizontal: false, vertical: true)
            }
            NavigationLink {
                ProgressView_(initialDate: sync.today)
            } label: {
                Label("See your trend", systemImage: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(ExActionStyle()).accessibilityIdentifier("mfImport.seeTrend")
            Button("Import another file") { choosing = true }
                .buttonStyle(ExActionStyle(secondary: true)).accessibilityIdentifier("mfImport.chooseAgain")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mfImport.done")
        report(summary)
    }

    private func doneDetail(_ summary: MacroFactorImportSummary) -> String {
        let range = range(summary.dateRange).map { " from \($0)" } ?? ""
        let saved = Kind.allCases.filter { summary.failures[$0] == nil }.reduce(0) { $0 + summary[$1].new }
        return "\(saved.formatted()) \(saved == 1 ? "item" : "items")\(range) are saved and syncing. "
            + "Your trend and expenditure now include them."
    }
}
