import SwiftUI
import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has written one.
    let snapshot: WidgetSnapshot?
}

/// Reads the snapshot the app writes. The app reloads timelines whenever it
/// writes, so a timeline only adds the day boundaries ahead.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample(at: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let now = Date()
        completion(SnapshotEntry(date: now, snapshot: WidgetSnapshot.read() ?? (context.isPreview ? .sample(at: now) : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshot.read()
        let dates = [now] + (snapshot?.changes(after: now) ?? [])
        completion(Timeline(entries: dates.map { SnapshotEntry(date: $0, snapshot: snapshot) }, policy: .never))
    }
}

extension WidgetSnapshot {
    /// Synthetic numbers for the widget gallery before the app has written any.
    static func sample(at date: Date) -> WidgetSnapshot {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? date.addingTimeInterval(86_400)
        let day = Day(start: start, end: end, energy: Amount(consumed: 1_060, target: 2_300),
                      protein: Amount(consumed: 92, target: 160), carbohydrate: Amount(consumed: 118, target: 250),
                      fat: Amount(consumed: 38, target: 70))
        let planned = PlannedWorkout(name: "Upper A", program: "Strength foundations", isDeload: false, exercises: [
            .init(name: "Barbell Bench Press", sets: 3), .init(name: "Pull-Up", sets: 3),
            .init(name: "Overhead Press", sets: 3), .init(name: "Cable Row", sets: 3),
        ])
        return WidgetSnapshot(days: [day], active: nil, done: nil, planned: planned)
    }
}

/// What a widget shows before the app has written a snapshot.
struct OpenExerlyPrompt: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Open Exerly")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image("ExerlyPulse").resizable().scaledToFit().padding(12)
            }
            .accessibilityLabel("Open Exerly")
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("Exerly").font(.headline)
                Text("Open the app to show today").font(.caption)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                PulseMark(size: 24)
                Spacer(minLength: 0)
                Text("Open Exerly").font(.headline).foregroundStyle(WidgetPalette.textPrimary)
                Text("Your day shows here once you sign in.").font(.caption).foregroundStyle(WidgetPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}
