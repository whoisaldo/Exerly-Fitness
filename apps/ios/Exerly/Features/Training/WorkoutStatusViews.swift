import SwiftUI
import ExerlyCore

/// The countdown ring for a rest timer. It drains as the rest runs out.
struct RestRing: View {
    let timer: RestTimer
    let now: Date
    var lineWidth: CGFloat = 4

    var body: some View {
        let remaining = timer.remaining(at: now)
        let fraction = timer.duration > 0 ? remaining / timer.duration : 0
        ZStack {
            Circle().stroke(Color.exPrimary.opacity(0.22), lineWidth: lineWidth)
            Circle().trim(from: 0, to: fraction)
                .stroke(LinearGradient(colors: [.exPrimary, .exAccent], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
        }
        .accessibilityHidden(true)
    }
}

/// Rest between sets, floating over the workout: a countdown ring, the time
/// left, −15 and +15 seconds, and Skip. It taps out a haptic when rest ends.
struct RestTimerBar: View {
    let timer: RestTimer
    let adjust: (Double) -> Void
    let skip: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let finished = timer.isFinished(at: context.date)
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.item))
                : AnyLayout(HStackLayout(spacing: ExSpacing.item))
            layout {
                HStack(spacing: ExSpacing.item) {
                    RestRing(timer: timer, now: context.date).frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(finished ? "Rest over" : "Rest").font(.exCaption).foregroundStyle(Color.exTextSecondary)
                        Group {
                            if finished { Text("Go") } else { Text(timerInterval: context.date...max(context.date, timer.endsAt), countsDown: true) }
                        }
                        .font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(finished ? Color.exPrimaryText : Color.exTextPrimary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(finished ? "Rest over" : "Rest, \(Int(timer.remaining(at: context.date).rounded())) seconds left")
                .accessibilityIdentifier("training.restStatus")
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                HStack(spacing: ExSpacing.small) {
                    control("−15", label: "Remove 15 seconds of rest") { adjust(-15) }
                    control("+15", label: "Add 15 seconds of rest") { adjust(15) }
                    control(finished ? "Done" : "Skip", label: "Skip rest", prominent: true, action: skip)
                }
            }
            .padding(.leading, ExSpacing.content).padding(.trailing, ExSpacing.small).padding(.vertical, ExSpacing.small)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: typeSize.isAccessibilitySize ? 24 : 30, style: .continuous))
            .padding(.horizontal, ExSpacing.item).padding(.bottom, ExSpacing.small)
        }
        .task(id: timer.endsAt) {
            let wait = timer.endsAt.timeIntervalSinceNow
            guard wait > 0 else { return }
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func control(_ title: String, label: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(.subheadline, design: .rounded, weight: .semibold)).monospacedDigit()
                .foregroundStyle(prominent ? Color.white : Color.exPrimaryText)
                .padding(.horizontal, 12).frame(minWidth: 52, minHeight: 44)
                .background(prominent ? Color.exActionFill : Color.exPrimary.opacity(0.16), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// One clear summary above the sets: time, sets done and volume, with a
/// progress line underneath.
struct WorkoutStatusStrip: View {
    let session: WorkoutSession
    let summary: WorkoutSummary
    let unit: MassUnit
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: ExSpacing.small) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: ExSpacing.small))
                : AnyLayout(HStackLayout(spacing: 0))
            layout {
                stat("Time") {
                    Text(session.startedAt, style: .timer).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Workout time")
                stat("Sets") {
                    Text("\(Text("\(summary.completedSets)").foregroundStyle(Color.exTextPrimary))\(Text(" / \(summary.totalSets)").foregroundStyle(Color.exTextSecondary))")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(summary.completedSets) of \(summary.totalSets) sets done")
                .accessibilityIdentifier("training.setProgress")
                stat("Volume") {
                    Text(TrainingFormat.volume(summary.tonnage, unit: unit))
                }
                .accessibilityElement(children: .combine)
            }
            GeometryReader { geometry in
                let total = Double(summary.totalSets)
                let fraction = total > 0 ? Double(summary.completedSets) / total : 0
                Capsule().fill(Color.exPrimary.opacity(0.14))
                    .overlay(alignment: .leading) {
                        Capsule().fill(LinearGradient(colors: [.exPrimary, .exAccent], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geometry.size.width * fraction)
                            .animation(.snappy, value: fraction)
                    }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, ExSpacing.page).padding(.top, ExSpacing.tight).padding(.bottom, ExSpacing.small)
    }

    private func stat<Value: View>(_ title: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .center, spacing: 2) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(Color.exTextMuted)
            value().font(.system(.headline, design: .rounded, weight: .semibold)).foregroundStyle(Color.exTextPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: typeSize.isAccessibilitySize ? nil : .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .center)
    }
}
