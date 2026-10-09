import ExerlyCore
import SwiftUI

/// Personal records set in the span, newest first, filterable by kind.
struct RecordsSection: View {
    let records: [TrainingInsights.DatedRecord]
    let span: TrainingInsights.Span
    let library: ExerlyCore.ExerciseLibrary
    let unit: MassUnit
    let today: LocalDate
    var identifier = "training.records"
    @State private var filter: RecordFilter = .all
    @State private var showsAll = false

    static let shown = 6

    enum RecordFilter: String, CaseIterable, Identifiable {
        case all = "All", oneRepMax = "e1RM", heaviest = "Heaviest", reps = "Reps", volume = "Set volume"
        var id: String { rawValue }

        func includes(_ kind: PersonalRecord.Kind) -> Bool {
            switch self {
            case .all: true
            case .oneRepMax: kind == .oneRepMax
            case .heaviest: kind == .heaviestLoad
            case .reps: kind == .repsAtLoad
            case .volume: kind == .setVolume
            }
        }
    }

    var body: some View {
        let filtered = records.filter { filter.includes($0.record.kind) }
        let shown = showsAll ? filtered : Array(filtered.prefix(Self.shown))
        VStack(alignment: .leading, spacing: ExSpacing.item) {
            ExSectionHeading("Records", detail: records.isEmpty ? nil : "\(records.count) in \(span == .all ? "all time" : InsightFormat.spokenSpan(span))")
            if records.isEmpty {
                ExCard {
                    Text("No records in \(InsightFormat.spanPhrase(span)) yet. A record needs an earlier session of the same lift to beat, so a lift's first session never sets one.")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ExChoiceChips(values: RecordFilter.allCases, selection: $filter) { $0.rawValue }
                    .onChange(of: filter) { _, _ in showsAll = false }
                if filtered.isEmpty {
                    Text("None of this kind in \(InsightFormat.spanPhrase(span)).").font(.exBody).foregroundStyle(Color.exTextSecondary)
                } else {
                    InsightList {
                        ForEach(Array(shown.enumerated()), id: \.offset) { index, item in
                            if index > 0 { InsightDivider() }
                            row(item)
                        }
                    }
                }
                if filtered.count > Self.shown {
                    Button(showsAll ? "Show fewer records" : "Show all \(filtered.count) records") {
                        withAnimation(.snappy) { showsAll.toggle() }
                    }
                    .font(.exBodyMedium).foregroundStyle(Color.exPrimaryText).frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("\(identifier).all")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private func row(_ item: TrainingInsights.DatedRecord) -> some View {
        let name = library.exercise(item.record.exerciseID)?.name ?? "Removed exercise"
        let value = InsightFormat.recordValue(item.record, unit: unit)
        let day = InsightFormat.day(item.date, today: today)
        return HStack(spacing: ExSpacing.item) {
            InsightIcon(systemName: InsightFormat.recordIcon(item.record.kind), color: .exAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.exBodyMedium).foregroundStyle(Color.exTextPrimary).fixedSize(horizontal: false, vertical: true)
                Text("\(InsightFormat.recordTitle(item.record.kind)) · \(day)").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: ExSpacing.small)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value.value).font(.exStatSmall).monospacedDigit().foregroundStyle(Color.exTextPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(value.detail).font(.exSmall).foregroundStyle(Color.exTextMuted)
            }
        }
        .padding(.vertical, ExSpacing.item)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(InsightFormat.recordTitle(item.record.kind)), \(value.spoken), \(day)")
    }
}
