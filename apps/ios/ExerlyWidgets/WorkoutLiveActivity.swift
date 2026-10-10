import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The workout in progress on the Lock Screen, in StandBy and in the Dynamic
/// Island: its name, elapsed time and sets done, and while resting a
/// countdown ring with the next set. Its buttons run in the app's process.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(workoutID: context.attributes.workoutID, state: context.state,
                                  rest: context.state.activeRest(isStale: context.isStale))
                .activityBackgroundTint(WidgetPalette.surface)
                .activitySystemActionForegroundColor(WidgetPalette.textPrimary)
                .widgetURL(ExerlyLinks.train)
        } dynamicIsland: { context in
            let state = context.state
            let rest = state.activeRest(isStale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        PulseMark(size: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(state.title).font(.subheadline.weight(.semibold)).foregroundStyle(WidgetPalette.textPrimary)
                            Text(timerInterval: state.elapsed, countsDown: false)
                                .font(.caption.monospacedDigit()).foregroundStyle(WidgetPalette.textSecondary)
                        }
                        .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.leading, 4)
                    .accessibilityElement(children: .combine)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(state.setsLabel).font(.system(.title3, design: .rounded, weight: .bold)).monospacedDigit()
                            .foregroundStyle(WidgetPalette.textPrimary)
                        Text("sets").font(.caption).foregroundStyle(WidgetPalette.textSecondary)
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.trailing, 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(state.spokenSets)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Clear of the island's rounded corners. The island's regions have fixed
                    // heights, so their text stops growing at extra large.
                    WorkoutActivityDetail(workoutID: context.attributes.workoutID, state: state, rest: rest, ringSize: 36)
                        .padding(.horizontal, 10).padding(.top, 4)
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                }
            } compactLeading: {
                Group {
                    if let rest { RestRing(rest: rest).frame(width: 18, height: 18) } else { PulseMark(size: 20) }
                }
                .padding(.leading, 2)
            } compactTrailing: {
                Group {
                    if let rest {
                        Text(timerInterval: rest.startedAt...rest.endsAt, countsDown: true)
                            .foregroundStyle(WidgetPalette.accent)
                            .accessibilityLabel("Rest")
                    } else {
                        Text(state.setsLabel).foregroundStyle(WidgetPalette.primaryText)
                            .accessibilityLabel(state.spokenSets)
                    }
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold)).monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 52, alignment: .trailing)
            } minimal: {
                if let rest { RestRing(rest: rest).frame(width: 20, height: 20) } else { PulseMark(size: 18) }
            }
            .widgetURL(ExerlyLinks.train)
            .keylineTint(WidgetPalette.primary)
        }
    }
}

/// The Lock Screen presentation, which StandBy shows enlarged.
struct WorkoutLockScreenView: View {
    let workoutID: UUID
    let state: WorkoutActivityAttributes.ContentState
    let rest: WorkoutActivityAttributes.Rest?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                PulseMark(size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.title).font(.headline).foregroundStyle(WidgetPalette.textPrimary)
                    if let program = state.program {
                        Text(program).font(.caption).foregroundStyle(WidgetPalette.textSecondary)
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    let sets = Text(state.setsLabel).font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(WidgetPalette.textPrimary)
                    let word = Text(" sets").font(.caption).foregroundStyle(WidgetPalette.textSecondary)
                    Text("\(sets)\(word)").monospacedDigit().lineLimit(1)
                        .accessibilityLabel(state.spokenSets)
                    // A timer text takes all the width it's offered.
                    Text(timerInterval: state.elapsed, countsDown: false)
                        .font(.caption).monospacedDigit().foregroundStyle(WidgetPalette.textSecondary)
                        .multilineTextAlignment(.trailing).frame(maxWidth: 80, alignment: .trailing)
                }
            }
            .accessibilityElement(children: .combine)
            WorkoutActivityDetail(workoutID: workoutID, state: state, rest: rest, ringSize: 36)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

/// Rest with the next set and its buttons, or the next set ready to log.
struct WorkoutActivityDetail: View {
    let workoutID: UUID
    let state: WorkoutActivityAttributes.ContentState
    let rest: WorkoutActivityAttributes.Rest?
    let ringSize: CGFloat
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if let rest {
            // Rest can end while the app is suspended, and only a push could
            // redraw the activity then, so the next set can always be logged.
            // Above the default text size the next set's line doesn't fit the
            // activity's fixed height; its Log button joins the countdown.
            if typeSize <= .large, let next = state.next {
                VStack(alignment: .leading, spacing: 6) {
                    restRow(rest, log: nil)
                    HStack(spacing: 10) {
                        NextSetLine(next: next, eyebrow: "Next", inline: true)
                        Spacer(minLength: 4)
                        if next.isLoggable { logButton(next, text: "Log", compact: true) }
                    }
                }
            } else {
                restRow(rest, log: state.next.flatMap { $0.isLoggable ? $0 : nil })
            }
        } else if let next = state.next {
            // At large text sizes the button shortens so the set stays whole.
            ViewThatFits(in: .horizontal) {
                nextRow(next, button: "Complete set")
                nextRow(next, button: "Log")
            }
        } else {
            Label("All sets done. Finish in Exerly.", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(WidgetPalette.success)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func nextRow(_ next: WorkoutActivityAttributes.NextSet, button: String) -> some View {
        HStack(spacing: 12) {
            NextSetLine(next: next, eyebrow: "Up next")
            Spacer(minLength: 4)
            if next.isLoggable { logButton(next, text: button, compact: false) }
        }
    }

    /// Logs the next set with its filled-in values.
    private func logButton(_ next: WorkoutActivityAttributes.NextSet, text: String, compact: Bool) -> some View {
        Button(intent: CompleteWorkoutSetIntent(workoutID: workoutID, setID: next.setID)) {
            ActivityButtonLabel(text: text, systemImage: "checkmark", prominent: true, compact: compact)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Complete set \(next.number), \(next.exercise), \(next.spokenValues)")
    }

    /// The countdown with +30 s, then Skip, or Log where the next set has no row of its own.
    private func restRow(_ rest: WorkoutActivityAttributes.Rest, log next: WorkoutActivityAttributes.NextSet?) -> some View {
        HStack(spacing: 10) {
            RestRing(rest: rest).frame(width: ringSize, height: ringSize)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Rest").font(.subheadline.weight(.semibold)).foregroundStyle(WidgetPalette.textSecondary)
                // A timer text takes all the width it's offered.
                Text(timerInterval: rest.startedAt...rest.endsAt, countsDown: true)
                    .monospacedDigit().font(.title2).fontWeight(.bold).fontDesign(.rounded)
                    .foregroundStyle(WidgetPalette.textPrimary)
                    .frame(maxWidth: 80, alignment: .leading)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 4)
            Button(intent: ExtendWorkoutRestIntent(workoutID: workoutID)) {
                ActivityButtonLabel(text: "+30 s", prominent: false, compact: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add 30 seconds of rest")
            if let next {
                logButton(next, text: "Log", compact: true)
            } else {
                Button(intent: SkipWorkoutRestIntent(workoutID: workoutID)) {
                    ActivityButtonLabel(text: "Skip", prominent: false, compact: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip rest")
            }
        }
    }
}

/// "Up next" above the set, or "Next" beside it where height is short.
private struct NextSetLine: View {
    let next: WorkoutActivityAttributes.NextSet
    let eyebrow: String
    var inline = false

    var body: some View {
        let label = Text(eyebrow).foregroundStyle(WidgetPalette.primaryText)
        let line = Text(next.line).foregroundStyle(WidgetPalette.textPrimary)
        Group {
            if inline {
                Text("\(label)  \(line)").font(.subheadline.weight(.semibold))
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    label.font(.caption.weight(.semibold))
                    line.font(.subheadline.weight(.semibold))
                }
            }
        }
        .lineLimit(1).minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(next.spokenLine)
    }
}

private struct ActivityButtonLabel: View {
    let text: String
    var systemImage: String?
    let prominent: Bool
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.caption.weight(.bold)) }
            Text(text).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(prominent ? Color.white : WidgetPalette.primaryText)
        .padding(.horizontal, compact ? 10 : 12).frame(minHeight: compact ? 30 : 36)
        .background(prominent ? WidgetPalette.actionFill : WidgetPalette.primary.opacity(0.2), in: Capsule())
    }
}

/// The rest countdown as a ring that drains on its own.
struct RestRing: View {
    let rest: WorkoutActivityAttributes.Rest

    var body: some View {
        ProgressView(timerInterval: rest.startedAt...rest.endsAt, countsDown: true) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(WidgetPalette.accent)
        .accessibilityHidden(true)
    }
}
