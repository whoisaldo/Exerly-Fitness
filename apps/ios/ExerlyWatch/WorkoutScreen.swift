import SwiftUI
import WatchKit

/// The watch app's one screen: the next workout to start, the set to do, or
/// the rest after it, drawn from what the phone publishes.
struct WorkoutScreen: View {
    @State private var link = PhoneLink.shared
    @State private var recorder = WorkoutRecorder.shared
    @State private var summary: Summary?
    @State private var finishing = false
    /// Changes when rest ends, to draw the next set.
    @State private var restEnded = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let _ = restEnded
        let state = link.display(at: .now)
        NavigationStack {
            screen(state).containerBackground(WatchPalette.background, for: .navigation)
        }
        #if DEBUG
        // Commands the phone hasn't handled yet, for UI tests.
        .overlay {
            Color.clear.frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("debug.pending")
                .accessibilityValue("\(link.pending.count)")
                .allowsHitTesting(false)
        }
        #endif
        .onChange(of: RecordingKey(workout: state?.active?.id, finished: state?.finished, inFront: scenePhase == .active),
                  initial: true) { followRecording() }
        .task(id: state?.active?.rest?.endsAt) { await alertAtEnd(of: state?.active?.rest) }
    }

    @ViewBuilder
    private func screen(_ state: WatchState?) -> some View {
        if let summary {
            SummaryView(summary: summary) { self.summary = nil }
        } else if let state, state.signedIn, let active = state.active {
            workout(active)
        } else if let state, state.signedIn {
            StartView(planned: state.planned, starting: link.isStarting) {
                WKInterfaceDevice.current().play(.start)
                link.send(.start, for: nil)
            }
        } else {
            MessageView(text: state == nil ? "Open Exerly on your iPhone to begin." : "Sign in to Exerly on your iPhone.")
        }
    }

    private func workout(_ active: WatchState.Active) -> some View {
        let waiting = link.isReachable ? 0 : link.pending.count
        return Group {
            if let rest = active.rest, rest.endsAt > .now {
                RestView(active: active, rest: rest, heartRate: recorder.heartRate, waiting: waiting,
                         extend: { link.send(.extendRest(seconds: 30), for: active.id) },
                         skip: { link.send(.skipRest, for: active.id) })
            } else if let set = active.upcoming.first {
                SetView(active: active, set: set, heartRate: recorder.heartRate, waiting: waiting) { weight, reps in
                    WKInterfaceDevice.current().play(.success)
                    link.send(.completeSet(set.id, weight: weight, reps: reps, unit: active.unit), for: active.id)
                }
                .id(set.id)
            } else {
                AllSetsDoneView { finishing = true }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { finishing = true } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("End workout")
                    .accessibilityIdentifier("watch.finish")
            }
        }
        .confirmationDialog(active.completedSets > 0 ? "Finish workout?" : "End workout?", isPresented: $finishing,
                            titleVisibility: .visible) {
            Button(active.completedSets > 0 ? "Save workout" : "End workout") { finish(active) }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text(active.completedSets == 0 ? "No sets are done, so nothing is saved."
                 : active.completedSets == active.totalSets ? "All \(active.totalSets) sets are done."
                 : "\(active.completedSets) of \(active.totalSets) sets are done. Sets you didn't do are removed.")
        }
    }

    private func finish(_ active: WatchState.Active) {
        summary = Summary(title: active.title, sets: active.completedSets, startedAt: active.startedAt, endedAt: .now)
        WKInterfaceDevice.current().play(.stop)
        link.send(.finish, for: active.id)
    }

    /// Records the workout in progress in Health while the app is in front,
    /// and ends the recording when the workout ends: kept if it was saved
    /// with the person's Health switch on, discarded otherwise.
    private func followRecording() {
        guard scenePhase == .active || recorder.workoutID != nil else { return }
        let link = link
        recorder.follow(link.display(at: .now)?.active.map { ($0.id, $0.startedAt) }, saving: { id in
            let state = link.display(at: .now)
            return state?.savesToHealth == true && state?.finished == id
        }, onRecording: { id in link.send(.recording, for: id) })
    }

    private struct RecordingKey: Equatable {
        var workout: UUID?
        var finished: UUID?
        var inFront: Bool
    }

    private func alertAtEnd(of rest: WatchState.Rest?) async {
        guard let rest, rest.endsAt > .now else { return }
        try? await Task.sleep(for: .seconds(rest.endsAt.timeIntervalSinceNow))
        guard !Task.isCancelled else { return }
        WKInterfaceDevice.current().play(.notification)
        restEnded += 1
    }
}

/// The program's next workout with one big Start, or why there's none.
struct StartView: View {
    let planned: WatchState.Planned?
    let starting: Bool
    let start: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    PulseMark()
                    Eyebrow(text: planned == nil ? "Exerly" : "Today's workout")
                }
                if let planned {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(planned.title).font(.title2.weight(.bold)).accessibilityIdentifier("watch.plannedTitle")
                        if let program = planned.program {
                            Text(program).font(.footnote).foregroundStyle(WatchPalette.textSecondary)
                        }
                    }
                    Text("\(count(planned.exercises, "exercise")) · \(count(planned.sets, "set"))")
                        .font(.footnote.weight(.semibold)).foregroundStyle(WatchPalette.primaryText)
                    Button(action: start) {
                        HStack(spacing: 6) {
                            if starting { ProgressView().frame(width: 20, height: 20) } else { Image(systemName: "play.fill") }
                            Text(starting ? "Starting" : "Start")
                        }
                        .font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent).tint(WatchPalette.action).controlSize(.large)
                    .disabled(starting)
                    .accessibilityIdentifier("watch.start")
                } else {
                    Text("No workout planned").font(.headline)
                    Text("Choose a program in Exerly on your iPhone. Its next workout shows up here.")
                        .font(.footnote).foregroundStyle(WatchPalette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func count(_ value: Int, _ noun: String) -> String { "\(value) \(noun)\(value == 1 ? "" : "s")" }
}

/// Every set is done; the workout waits to be finished.
struct AllSetsDoneView: View {
    let finish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 40))
                    .symbolRenderingMode(.palette).foregroundStyle(.white, WatchPalette.action)
                Text("All sets done").font(.headline)
                Button(action: finish) { Text("Finish").font(.headline).frame(maxWidth: .infinity) }
                    .buttonStyle(.glassProminent).tint(WatchPalette.action)
                    .accessibilityIdentifier("watch.finishAll")
            }
        }
    }
}

struct Summary: Equatable {
    var title: String
    var sets: Int
    var startedAt: Date
    var endedAt: Date
}

/// What the finished workout came to, until the person taps Done.
struct SummaryView: View {
    let summary: Summary
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: summary.sets > 0 ? "checkmark.circle.fill" : "xmark.circle.fill").font(.system(size: 40))
                    .symbolRenderingMode(.palette).foregroundStyle(.white, WatchPalette.action)
                Text(summary.sets > 0 ? "Workout saved" : "Workout ended").font(.title3.weight(.bold))
                Text(summary.title).font(.headline).foregroundStyle(WatchPalette.primaryText)
                Text(summary.sets > 0 ? "\(summary.sets) set\(summary.sets == 1 ? "" : "s") · \(WatchFormat.minutes(from: summary.startedAt, to: summary.endedAt))"
                     : "Nothing was logged.")
                    .font(.footnote).foregroundStyle(WatchPalette.textSecondary)
                Button(action: done) { Text("Done").font(.headline).frame(maxWidth: .infinity) }
                    .buttonStyle(.glassProminent).tint(WatchPalette.action)
                    .accessibilityIdentifier("watch.summaryDone")
            }
            .multilineTextAlignment(.center)
        }
    }
}

/// Before the phone has published anything, or with nobody signed in.
struct MessageView: View {
    let text: String

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                PulseMark(size: 36)
                Text("Exerly").font(.headline)
                Text(text).font(.footnote).foregroundStyle(WatchPalette.textSecondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
