import SwiftUI

/// Rest after a set: a countdown ring, +30 s and Skip, and the set that's
/// next below them. The screen plays a haptic and shows the next set when it ends.
struct RestView: View {
    let active: WatchState.Active
    let rest: WatchState.Rest
    let heartRate: Double?
    let waiting: Int
    let extend: () -> Void
    let skip: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Eyebrow(text: "Rest")
                    Spacer(minLength: 4)
                    HeartRateView(bpm: heartRate)
                }
                countdown
                let buttons = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
                buttons {
                    Button(action: extend) { Text("+30 s").font(.headline).frame(maxWidth: .infinity) }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Add 30 seconds of rest")
                        .accessibilityIdentifier("watch.addRest")
                    Button(action: skip) { Text("Skip").font(.headline).frame(maxWidth: .infinity) }
                        .buttonStyle(.glassProminent).tint(WatchPalette.action)
                        .accessibilityLabel("Skip rest")
                        .accessibilityIdentifier("watch.skipRest")
                }
                if let next = active.upcoming.first {
                    VStack(spacing: 1) {
                        Eyebrow(text: "Next")
                        Text("\(next.exercise) · Set \(next.number)").font(.footnote.weight(.semibold))
                        Text(next.values).font(.footnote).foregroundStyle(WatchPalette.textSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Next, \(next.exercise), set \(next.number), \(next.spokenValues)")
                }
                if waiting > 0 { WorkoutFooter(active: active, waiting: waiting) }
            }
        }
    }

    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let total = max(1, rest.endsAt.timeIntervalSince(rest.startedAt))
            let left = max(0, rest.endsAt.timeIntervalSince(context.date))
            ZStack {
                Circle().stroke(WatchPalette.primary.opacity(0.22), lineWidth: 8)
                Circle().trim(from: 0, to: left / total)
                    .stroke(WatchPalette.ring, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: left)
                Text(timerInterval: rest.startedAt...rest.endsAt, countsDown: true)
                    .font(.system(.title, design: .rounded).weight(.bold)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.4)
                    .padding(14)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rest")
            .accessibilityValue(Duration.seconds(left.rounded()).formatted(.units(allowed: [.minutes, .seconds], width: .wide)) + " left")
        }
        // Small enough to keep +30 s and Skip on screen.
        .frame(maxWidth: 96)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityIdentifier("watch.rest")
    }
}
