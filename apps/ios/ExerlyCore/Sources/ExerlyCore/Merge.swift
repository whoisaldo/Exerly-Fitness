import Foundation

/// Three-way merge of a local and a remote copy against their last common
/// version. Nothing logged on either side is lost:
/// - a field takes whichever side changed it, and local wins when both did;
/// - items in lists merge by ID, recursively, and additions on both sides stay;
/// - a deletion applies only when the other side left the item unchanged;
/// - the local order wins, and remote additions are appended.
/// Without a common version every item is treated as added on its side.
public enum Merge {
    public static func session(base: WorkoutSession?, local: WorkoutSession, remote: WorkoutSession) -> WorkoutSession {
        var merged = local
        merged.name = value(base?.name, local.name, remote.name)
        merged.startedAt = value(base?.startedAt, local.startedAt, remote.startedAt)
        merged.endedAt = value(base?.endedAt, local.endedAt, remote.endedAt)
        merged.timeZoneID = value(base?.timeZoneID, local.timeZoneID, remote.timeZoneID)
        merged.notes = value(base?.notes, local.notes, remote.notes)
        merged.bodyweight = value(base?.bodyweight, local.bodyweight, remote.bodyweight)
        merged.exercises = list(base?.exercises, local.exercises, remote.exercises, merge: exercise)
        return merged
    }

    public static func exercise(base: PerformedExercise?, local: PerformedExercise, remote: PerformedExercise) -> PerformedExercise {
        var merged = local
        merged.exerciseID = value(base?.exerciseID, local.exerciseID, remote.exerciseID)
        merged.notes = value(base?.notes, local.notes, remote.notes)
        merged.supersetID = value(base?.supersetID, local.supersetID, remote.supersetID)
        merged.restOverride = value(base?.restOverride, local.restOverride, remote.restOverride)
        merged.sets = list(base?.sets, local.sets, remote.sets, merge: set)
        return merged
    }

    public static func set(base: PerformedSet?, local: PerformedSet, remote: PerformedSet) -> PerformedSet {
        var merged = local
        merged.kind = value(base?.kind, local.kind, remote.kind)
        merged.side = value(base?.side, local.side, remote.side)
        merged.efforts = value(base?.efforts, local.efforts, remote.efforts)
        merged.rir = value(base?.rir, local.rir, remote.rir)
        merged.completedAt = value(base?.completedAt, local.completedAt, remote.completedAt)
        return merged
    }

    /// Custom exercises merge as whole values: whichever side changed wins,
    /// and local wins when both did.
    public static func exerciseDefinition(base: Exercise?, local: Exercise, remote: Exercise) -> Exercise {
        value(base, local, remote)
    }

    static func value<T: Equatable>(_ base: T?, _ local: T, _ remote: T) -> T {
        if local == remote { return local }
        if let base {
            if local == base { return remote }
            if remote == base { return local }
        }
        return local
    }

    static func list<Element: Identifiable & Equatable>(
        _ base: [Element]?, _ local: [Element], _ remote: [Element],
        merge: (Element?, Element, Element) -> Element
    ) -> [Element] {
        let baseByID = Dictionary((base ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let localIDs = Set(local.map(\.id))
        var result: [Element] = []
        for item in local {
            let original = baseByID[item.id]
            if let other = remoteByID[item.id] {
                result.append(merge(original, item, other))
            } else if original == nil || item != original {
                // Added locally, or the remote deleted something local changed.
                result.append(item)
            }
        }
        for item in remote where !localIDs.contains(item.id) {
            let original = baseByID[item.id]
            // Added remotely, or local deleted something the remote changed.
            if original == nil || item != original { result.append(item) }
        }
        return result
    }
}
