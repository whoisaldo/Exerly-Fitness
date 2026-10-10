import ExerlyCore
import SwiftUI

/// Progress → Training: training per week, stall and fatigue signals, each
/// main lift's estimated 1RM, sets per muscle against Exerly's ranges, and
/// recent records, over a chosen span. Every number comes from ExerlyCore.
struct TrainingInsightsView: View {
    let workspace: TrainingWorkspace?
    let unit: MassUnit
    let timeZone: TimeZone

    var body: some View {
        if let workspace {
            TrainingInsightsScreen(workspace: workspace, unit: unit, timeZone: timeZone)
        } else {
            LoadingStateView(message: "Opening your training…")
        }
    }
}

private struct TrainingInsightsScreen: View {
    @ObservedObject var workspace: TrainingWorkspace
    let unit: MassUnit
    let timeZone: TimeZone
    @AppStorage("training.insightsSpan") private var span: TrainingInsights.Span = .threeMonths
    @StateObject private var model = TrainingInsightsModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let today = LocalDate(Date(), in: timeZone)
        let history = workspace.store.history
        let input = TrainingInsightsModel.Input(history: TrainingAnalysisInput(history), span: span, today: today,
                                                firstWeekday: TrainingInsightsModel.firstWeekday)
        ScrollView {
            VStack(alignment: .leading, spacing: ExSpacing.section) {
                InsightSpanPicker(span: $span)
                content(today: today)
            }
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, ExSpacing.page)
            .padding(.top, ExSpacing.small)
            .padding(.bottom, ExSpacing.major)
        }
        .exScrollEdges()
        .background(Color.exBackground)
        .refreshable { await workspace.synchronize() }
        .task(id: input) {
            await model.refresh(history: history, span: span, today: today, firstWeekday: input.firstWeekday)
        }
        .onChange(of: scenePhase) { _, phase in
            // A new day can start while the app is in the background.
            guard phase == .active else { return }
            Task {
                await model.refresh(history: workspace.store.history, span: span, today: LocalDate(Date(), in: timeZone),
                                    firstWeekday: TrainingInsightsModel.firstWeekday)
            }
        }
        .accessibilityIdentifier("training.screen")
    }

    @ViewBuilder
    private func content(today: LocalDate) -> some View {
        if let report = model.report {
            if report.firstSession == nil {
                emptyHistory
            } else if report.sessions == 0 {
                ExCard {
                    Text("No workouts in \(InsightFormat.spanPhrase(report.span))").font(.exH3).foregroundStyle(Color.exTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Choose a longer span to see earlier training.")
                        .font(.exBody).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("training.emptySpan")
            } else {
                TrainingConsistencyCard(report: report, unit: unit, span: report.span)
                TrainingSignalsSection(signals: report.signals, store: workspace.store, unit: unit, timeZone: timeZone, span: report.span)
                LiftsSection(report: report, store: workspace.store, unit: unit, timeZone: timeZone)
                MuscleVolumeSection(report: report, library: workspace.store.library)
                RecordsSection(records: report.records, span: report.span, library: workspace.store.library, unit: unit, today: today)
                footnote(report)
            }
        } else {
            LoadingStateView(message: "Reading your workouts…").frame(height: 220)
        }
    }

    private var emptyHistory: some View {
        ExCard {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.exPrimaryText).frame(width: 56, height: 56)
                .background(Color.exPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            Text("No workouts yet").font(.exH2).foregroundStyle(Color.exTextPrimary)
            Text("Finish a workout in Train and this fills in: sessions and sets per week, sets per muscle against "
                + "Exerly's ranges, each lift's estimated 1RM, your records, and any lift that stalls.")
                .font(.exBody).foregroundStyle(Color.exTextSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("training.empty")
    }

    private func footnote(_ report: TrainingInsights.Report) -> some View {
        Text("Hard sets exclude warm-ups. Weeks start on \(Calendar.current.weekdaySymbols[report.firstWeekdayIndex]) "
            + "and dates are in \(timeZone.localizedName(for: .generic, locale: .current) ?? timeZone.identifier). "
            + "A muscle's range runs from the fewest to the most weekly sets any Exerly program plans for it, "
            + "across strength, muscle-building and general goals.")
            .font(.exCaption).foregroundStyle(Color.exTextMuted).fixedSize(horizontal: false, vertical: true)
    }
}

private extension TrainingInsights.Report {
    /// Index into `Calendar.weekdaySymbols` for the week start the report used.
    var firstWeekdayIndex: Int { from.weekday.rawValue - 1 }
}
