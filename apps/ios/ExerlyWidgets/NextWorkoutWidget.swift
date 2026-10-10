import SwiftUI
import WidgetKit

/// The workout in progress, today's finished one, or the program's next.
struct NextWorkoutWidget: Widget {
    static let kind = "ExerlyNextWorkout"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SnapshotProvider()) { entry in
            NextWorkoutWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetSurface() }
                .widgetURL(ExerlyLinks.train)
        }
        .configurationDisplayName("Next workout")
        .description("Your program's next workout, or the one in progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct NextWorkoutWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            let workout = snapshot.workout(at: entry.date)
            content(workout)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.spoken(workout))
        } else {
            OpenExerlyPrompt(family: family)
        }
    }

    @ViewBuilder private func content(_ workout: WidgetSnapshot.Workout) -> some View {
        switch family {
        case .accessoryInline:
            Label(Self.inline(workout), systemImage: "dumbbell")
        case .accessoryCircular:
            if case .active(let active) = workout {
                Gauge(value: Double(active.completedSets), in: 0...Double(max(active.totalSets, 1))) {
                    Image(systemName: "dumbbell.fill")
                } currentValueLabel: {
                    Text("\(active.completedSets)")
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Image(systemName: Self.icon(workout)).font(.title3.weight(.semibold))
                        if case .planned(let planned) = workout {
                            Text(Self.count(planned.exercises.reduce(0) { $0 + $1.sets }, "set"))
                                .font(.caption2.weight(.semibold)).minimumScaleFactor(0.6)
                        }
                    }
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.eyebrow(workout)).font(.caption2.weight(.semibold)).widgetAccentable()
                Text(Self.name(workout)).font(.headline)
                detail(workout).font(.caption)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
        case .systemMedium:
            VStack(alignment: .leading, spacing: 0) {
                header(workout)
                Spacer(minLength: 4)
                HStack(alignment: .bottom, spacing: 16) {
                    details(workout).frame(maxWidth: .infinity, alignment: .leading)
                    aside(workout).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        default:
            summary(workout)
        }
    }

    /// The small widget: the eyebrow on top, the workout at the bottom.
    private func summary(_ workout: WidgetSnapshot.Workout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header(workout)
            Spacer(minLength: 0)
            details(workout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func header(_ workout: WidgetSnapshot.Workout) -> some View {
        HStack(spacing: 6) {
            PulseMark(size: 14)
            WidgetEyebrow(text: Self.eyebrow(workout), color: Self.isDone(workout) ? WidgetPalette.success : WidgetPalette.primaryText)
        }
    }

    /// Name, program and one line of detail.
    private func details(_ workout: WidgetSnapshot.Workout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.name(workout)).font(.headline).foregroundStyle(WidgetPalette.textPrimary)
                .lineLimit(2).minimumScaleFactor(0.75)
            if let program = Self.program(workout) {
                Text(program).font(.caption).foregroundStyle(WidgetPalette.textSecondary).lineLimit(1)
            }
            detail(workout).font(.caption.weight(.medium)).foregroundStyle(WidgetPalette.primaryText)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder private func detail(_ workout: WidgetSnapshot.Workout) -> some View {
        switch workout {
        case .active(let active):
            // A timer text takes all the width it's offered, so it goes last.
            HStack(spacing: 4) {
                Text("\(active.completedSets)/\(active.totalSets) sets ·")
                Text(timerInterval: active.startedAt...active.startedAt.addingTimeInterval(12 * 3600), countsDown: false)
            }
            .monospacedDigit()
        case .done(let done, _):
            Text(Self.count(done.workingSets, "working set"))
        case .planned(let planned):
            Text(Self.size(planned))
        case .none:
            Text("Plan your week in Exerly")
        }
    }

    /// The medium widget's right half: the exercises, progress, or what's next.
    @ViewBuilder private func aside(_ workout: WidgetSnapshot.Workout) -> some View {
        switch workout {
        case .planned(let planned):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(planned.exercises.prefix(4).enumerated()), id: \.offset) { _, exercise in
                    HStack(spacing: 6) {
                        Text(exercise.name).foregroundStyle(WidgetPalette.textPrimary).lineLimit(1)
                        Spacer(minLength: 2)
                        Text(Self.count(exercise.sets, "set")).foregroundStyle(WidgetPalette.textMuted).monospacedDigit()
                    }
                    .font(.caption).minimumScaleFactor(0.8)
                }
                if planned.exercises.count > 4 {
                    Text("+\(planned.exercises.count - 4) more").font(.caption2).foregroundStyle(WidgetPalette.textMuted)
                }
            }
        case .active(let active):
            VStack(alignment: .leading, spacing: 6) {
                Text("\(active.completedSets) of \(active.totalSets) sets").font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetPalette.textPrimary).monospacedDigit()
                WidgetBar(fraction: active.totalSets > 0 ? Double(active.completedSets) / Double(active.totalSets) : 0,
                          color: WidgetPalette.primary)
                Text("Tap to log your next set").font(.caption).foregroundStyle(WidgetPalette.textSecondary)
            }
        case .done(_, let next):
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(WidgetPalette.success)
                if let next {
                    Text("Next").font(.caption.weight(.semibold)).foregroundStyle(WidgetPalette.textSecondary)
                    Text(next.name).font(.subheadline.weight(.semibold)).foregroundStyle(WidgetPalette.textPrimary).lineLimit(2)
                }
            }
        case .none:
            Image(systemName: "calendar.badge.plus").font(.largeTitle).foregroundStyle(WidgetPalette.primaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    static func eyebrow(_ workout: WidgetSnapshot.Workout) -> String {
        switch workout {
        case .active: "In progress"
        case .done: "Workout done"
        case .planned(let planned): planned.isDeload ? "Deload workout" : "Today's workout"
        case .none: "Training"
        }
    }

    static func name(_ workout: WidgetSnapshot.Workout) -> String {
        switch workout {
        case .active(let active): active.name
        case .done(let done, _): done.name
        case .planned(let planned): planned.name
        case .none: "No workout planned"
        }
    }

    static func program(_ workout: WidgetSnapshot.Workout) -> String? {
        if case .planned(let planned) = workout { return planned.program }
        return nil
    }

    static func isDone(_ workout: WidgetSnapshot.Workout) -> Bool {
        if case .done = workout { return true }
        return false
    }

    static func icon(_ workout: WidgetSnapshot.Workout) -> String {
        switch workout {
        case .done: "checkmark"
        case .none: "calendar"
        default: "dumbbell.fill"
        }
    }

    /// "4 exercises · 12 sets"
    static func size(_ planned: WidgetSnapshot.PlannedWorkout) -> String {
        "\(count(planned.exercises.count, "exercise")) · \(count(planned.exercises.reduce(0) { $0 + $1.sets }, "set"))"
    }

    /// "1 set", "3 sets"
    static func count(_ value: Int, _ noun: String) -> String { "\(value) \(noun)\(value == 1 ? "" : "s")" }

    static func inline(_ workout: WidgetSnapshot.Workout) -> String {
        switch workout {
        case .active(let active): "\(active.name) · \(active.completedSets)/\(active.totalSets) sets"
        case .done(let done, _): "\(done.name) done"
        case .planned(let planned): "\(planned.name) · \(count(planned.exercises.count, "exercise"))"
        case .none: "No workout planned"
        }
    }

    static func spoken(_ workout: WidgetSnapshot.Workout) -> String {
        switch workout {
        case .active(let active):
            "Workout in progress, \(active.name), \(active.completedSets) of \(active.totalSets) sets done"
        case .done(let done, let next):
            "Workout done, \(done.name), \(count(done.workingSets, "working set"))" + (next.map { ". Next, \($0.name)" } ?? "")
        case .planned(let planned):
            "\(eyebrow(workout)), \(planned.name)" + (planned.program.map { ", \($0)" } ?? "") + ", \(size(planned))"
        case .none:
            "No workout planned. Plan your week in Exerly."
        }
    }
}
