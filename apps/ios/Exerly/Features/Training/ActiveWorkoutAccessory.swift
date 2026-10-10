import SwiftUI
import ExerlyCore

/// The workout in progress, in one line for the tab bar's bottom accessory:
/// its name, elapsed time and sets done, or the rest countdown while resting.
/// The tab view owns tap handling.
struct ActiveWorkoutAccessory: View {
    let store: TrainingStore
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if let session = store.activeSession {
            let summary = store.summary(of: session)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let resting = store.restTimer.flatMap { $0.isFinished(at: context.date) ? nil : $0 }
                HStack(spacing: 10) {
                    if let resting {
                        RestRing(timer: resting, now: context.date, lineWidth: 3).frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.exPrimaryText)
                            .frame(width: 22, height: 22)
                    }
                    if let resting {
                        Text("Rest").font(.subheadline.weight(.semibold)).foregroundStyle(Color.exTextPrimary)
                        Text(timerInterval: context.date...max(context.date, resting.endsAt), countsDown: true)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(Color.exPrimaryText)
                    } else {
                        Text(TrainingFormat.title(of: session).name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.exTextPrimary)
                            .lineLimit(1).truncationMode(.tail)
                            .layoutPriority(-1)
                        if placement != .inline {
                            Text(session.startedAt, style: .timer)
                                .font(.system(.subheadline, design: .rounded)).monospacedDigit()
                                .foregroundStyle(Color.exTextSecondary)
                        }
                    }
                    Spacer(minLength: 4)
                    Text("\(summary.completedSets)/\(summary.totalSets)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Color.exTextSecondary)
                }
                .lineLimit(1)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .padding(.horizontal, ExSpacing.content)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(session: session, summary: summary, resting: resting, now: context.date))
                .accessibilityIdentifier("training.accessory")
            }
        }
    }

    private func label(session: WorkoutSession, summary: WorkoutSummary, resting: RestTimer?, now: Date) -> String {
        let sets = "\(summary.completedSets) of \(summary.totalSets) sets done"
        let name = TrainingFormat.title(of: session).name
        if let resting { return "\(name), resting, \(Int(resting.remaining(at: now).rounded())) seconds left, \(sets)" }
        let minutes = Int(now.timeIntervalSince(session.startedAt) / 60)
        return "\(name), \(minutes) minutes, \(sets)"
    }
}
