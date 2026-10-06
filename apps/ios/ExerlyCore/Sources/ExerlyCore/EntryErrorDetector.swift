import Foundation

/// Finds likely typing mistakes in a finished session and proposes the fix:
/// a load ten times off, pounds entered as kilograms (or the reverse), or a
/// stray digit in the reps. See docs/design/005-training-detectors.md, which
/// records the measured precision and recall.
///
/// A set is judged against the same exercise's working sets in at least
/// `minimumHistory` earlier sessions and the session's other working sets, or,
/// before there is that much history, against at least two other working sets
/// in the same session. A correction is proposed only when it lands inside the
/// typical band, so a genuine personal record or a light technique day isn't
/// mistaken for a typo.
public enum EntryErrorDetector {
    public static let author = AgentIdentity(kind: .builtIn, name: "Exerly entry check")
    public static let minimumHistory = 3
    /// Earlier sessions per exercise that set the typical band.
    static let window = 8

    public struct Finding: Sendable, Hashable {
        public enum Kind: String, Sendable, Hashable {
            /// A digit too many or too few: about ten times off.
            case loadDigit
            /// The number is right but the unit is wrong.
            case unitSwap
            /// A stray digit in the reps, such as 55 for 5.
            case repsDigit
        }

        public var kind: Kind
        public var setID: UUID
        public var exerciseID: ExerciseID
        public var logged: Effort
        public var corrected: Effort
        /// Typical working-set effective loads, in kilograms.
        public var typicalLoad: ClosedRange<Double>
        /// Reps this load allows at the person's recent strength, for a reps finding.
        public var typicalReps: Int?
        /// Earlier sessions the typical band came from; 0 when it came only from
        /// the session's other working sets.
        public var earlierSessions: Int
        public var confidence: Confidence
    }

    /// What a set is judged against: the exercise's working sets in recent
    /// earlier sessions plus the session's other working sets, summarised so
    /// that earlier typos in the log can't stretch the picture of normal.
    struct Reference {
        /// Median effective load, in kilograms.
        var median: Double
        /// Normal working loads: 55 % of the median up to 135 % of the
        /// heaviest load within 1.8 times the median.
        var band: ClosedRange<Double>
        /// Best e1RM among sets within 1.8 times the median e1RM, in kilograms.
        var oneRepMax: Double?
        /// The unit most of these sets were entered in.
        var usualUnit: MassUnit?
        var earlierSessions: Int
    }

    /// The findings for one session, judged against sessions that started earlier.
    public static func findings(in session: WorkoutSession, history: TrainingHistory) -> [Finding] {
        var findings: [Finding] = []
        for performed in session.exercises {
            guard let exercise = history.library.exercise(performed.exerciseID),
                  exercise.metric == .weightReps || exercise.metric == .bodyweightReps
            else { continue }
            let earlier = history.sets(of: exercise.id).filter {
                $0.sessionStart < session.startedAt && $0.sessionID != session.id
            }
            let sessionIDs = earlier.reduce(into: [UUID]()) { ids, record in
                if ids.last != record.sessionID { ids.append(record.sessionID) }
            }
            let recent = Set(sessionIDs.suffix(window))
            let earlierSets = sessionIDs.count >= minimumHistory
                ? earlier.filter { recent.contains($0.sessionID) }.map { ($0.set, $0.bodyweight) } : []
            let working = performed.sets.filter(\.counts)
            for set in working {
                let siblings = working.filter { $0.id != set.id }.map { ($0, session.bodyweight) }
                guard earlierSets.count >= minimumHistory || siblings.count >= 2,
                      let reference = reference(earlierSets + siblings, exercise: exercise,
                                                earlierSessions: earlierSets.isEmpty ? 0 : recent.count),
                      let finding = check(set, exercise: exercise, bodyweight: session.bodyweight, reference: reference)
                else { continue }
                findings.append(finding)
            }
        }
        return findings
    }

    static func reference(_ sets: [(PerformedSet, Mass?)], exercise: Exercise, earlierSessions: Int) -> Reference? {
        let loads = sets.compactMap { Volume.effectiveLoad($0.0.primary, exercise: exercise, bodyweight: $0.1) }
            .filter { $0 > 0 }.sorted()
        guard loads.count >= 2 else { return nil }
        // Two sets far apart can't say which of them is normal.
        if loads.count == 2, loads[1] > loads[0] * 2 { return nil }
        let median = loads[(loads.count - 1) / 2]
        let top = loads.last { $0 <= median * 1.8 } ?? median
        let maxes = sets.compactMap { ExerciseStatistics.oneRepMax($0.0, exercise: exercise, bodyweight: $0.1) }.sorted()
        let typicalMax = maxes.isEmpty ? nil : maxes[(maxes.count - 1) / 2]
        let units = sets.compactMap(\.0.primary.load?.unit)
        let kilograms = units.filter { $0 == .kilograms }.count
        return Reference(median: median, band: (median * 0.55)...(top * 1.35),
                         oneRepMax: typicalMax.flatMap { typical in maxes.last { $0 <= typical * 1.8 } },
                         usualUnit: units.isEmpty ? nil : (kilograms * 2 >= units.count ? .kilograms : .pounds),
                         earlierSessions: earlierSessions)
    }

    /// One proposal correcting every finding in the session, or nil. Never
    /// proposes again for a session this detector already proposed on, whatever
    /// the person decided. Its ID comes from the session's, so devices that
    /// check the same session before syncing file the same proposal, and sync
    /// keeps one, along with any decision made on it.
    public static func proposal(for session: WorkoutSession, history: TrainingHistory, existing: [Proposal],
                                now: Date) throws -> Proposal? {
        guard session.isFinished else { return nil }
        let sessionID = session.id.uuidString
        if existing.contains(where: { $0.author == author && $0.changes.contains { $0.id == sessionID } }) { return nil }
        let found = findings(in: session, history: history)
        guard !found.isEmpty else { return nil }
        var corrected = session
        for finding in found {
            for e in corrected.exercises.indices {
                if let s = corrected.exercises[e].sets.firstIndex(where: { $0.id == finding.setID }) {
                    corrected.exercises[e].sets[s].primary = finding.corrected
                }
            }
        }
        let library = history.library
        let evidence = found.map { finding -> Evidence in
            let name = library.exercise(finding.exerciseID)?.name ?? finding.exerciseID.rawValue
            let band = "\(format(finding.typicalLoad.lowerBound))–\(format(finding.typicalLoad.upperBound)) kg"
            let sets = finding.earlierSessions == 0
                ? "other working sets of \(name) in this workout"
                : "working sets of \(name) in this workout and your last \(finding.earlierSessions) sessions"
            let claim: String = switch finding.kind {
            case .loadDigit, .unitSwap:
                "Your \(sets) were \(band). "
                    + "\(describe(finding.logged)) is far outside that; \(describe(finding.corrected)) is inside it."
            case .repsDigit:
                "At the strength your \(sets) show, \(describe(finding.logged)) allows about \(finding.typicalReps ?? 0) reps. "
                    + "\(finding.logged.reps ?? 0) would be far beyond that; \(finding.corrected.reps ?? 0) is not."
            }
            return Evidence(claim: claim, level: .personalData,
                            caveats: ["Based on your own log (n=1)", "Typing mistakes are guessed from the numbers alone"],
                            dataRefs: [DataRef(kind: "workout_session", id: sessionID)])
        }
        let title: String
        if found.count > 1 {
            title = "\(found.count) sets look mistyped"
        } else if found[0].kind == .repsDigit {
            title = "Did you mean \(found[0].corrected.reps ?? 0) reps?"
        } else {
            title = "Did you mean \(describe(found[0].corrected))?"
        }
        let falsifier = found.count == 1
            ? "You really did \(describe(found[0].logged, withReps: true))."
            : "The sets are right as logged."
        return Proposal(id: proposalID(for: session.id), createdAt: now.roundedToMilliseconds, author: author, title: title,
                        summary: "A quick check of \(session.name.isEmpty ? "this workout" : session.name) found numbers that look like typing slips.",
                        changes: [try ProposedChange(kind: "workout_session", id: sessionID, before: session, after: corrected)],
                        evidence: evidence,
                        confidence: found.map(\.confidence).contains(.medium) ? .medium : .high,
                        falsifier: falsifier)
    }

    static let namespace = UUID(uuidString: "9DDD2C9C-1E91-46F7-800A-D974DD0D0F29")!

    static func proposalID(for session: UUID) -> UUID { UUID(named: session.uuidString, in: namespace) }

    // MARK: Checks

    private static func check(_ set: PerformedSet, exercise: Exercise, bodyweight: Mass?,
                              reference: Reference) -> Finding? {
        let effort = set.primary
        guard let logged = effort.load, let load = Volume.effectiveLoad(effort, exercise: exercise, bodyweight: bodyweight),
              load > 0
        else { return nil }
        let confidence: Confidence = reference.earlierSessions >= minimumHistory ? .high : .medium
        func finding(_ kind: Finding.Kind, _ corrected: Effort, reps: Int? = nil, _ level: Confidence) -> Finding {
            Finding(kind: kind, setID: set.id, exerciseID: exercise.id, logged: effort, corrected: corrected,
                    typicalLoad: reference.band, typicalReps: reps, earlierSessions: reference.earlierSessions,
                    confidence: level)
        }
        func effective(_ mass: Mass) -> Double? {
            var candidate = effort
            candidate.load = mass
            return Volume.effectiveLoad(candidate, exercise: exercise, bodyweight: bodyweight)
        }

        // A unit slip: entered in the unit this person doesn't use for this lift,
        // far from normal as entered and close to normal in their usual unit.
        if let usual = reference.usualUnit, usual != logged.unit, let swapped = effective(Mass(logged.value, usual)) {
            let distance = abs(log(load / reference.median))
            let swappedDistance = abs(log(swapped / reference.median))
            if distance > log(1.6) && swappedDistance < log(1.45) {
                var fixed = effort
                fixed.load = Mass(logged.value, usual)
                return finding(.unitSwap, fixed, confidence)
            }
        }

        // A digit too many or too few.
        if !reference.band.contains(load) {
            let tenth = load > reference.band.upperBound
            guard tenth || load / reference.band.upperBound < 0.2 else { return nil }
            let mass = Mass(tenth ? logged.value / 10 : logged.value * 10, logged.unit)
            guard let corrected = effective(mass), reference.band.contains(corrected) else { return nil }
            var fixed = effort
            fixed.load = mass
            return finding(.loadDigit, fixed, tenth ? confidence : .medium)
        }

        // A stray digit in the reps: far beyond what this load allows anyone at
        // this person's strength, and normal with one digit dropped.
        guard let reps = effort.reps, reps >= 15, let oneRepMax = reference.oneRepMax else { return nil }
        let allowed = Int(min(30, OneRepMax.repsToFailure(load: load, oneRepMax: oneRepMax * 1.15)).rounded(.down))
        guard reps >= max(2 * allowed, allowed + 12) else { return nil }
        let digits = String(reps).compactMap(\.wholeNumberValue)
        let candidates = Set(digits.indices.map { index in
            digits.enumerated().filter { $0.offset != index }.reduce(0) { $0 * 10 + $1.element }
        }).filter { (1...(allowed + 3)).contains($0) }
        guard let best = candidates.max() else { return nil }
        var fixed = effort
        fixed.reps = best
        return finding(.repsDigit, fixed, reps: allowed, candidates.count == 1 ? confidence : .medium)
    }

    private static func format(_ kilograms: Double) -> String {
        let rounded = (kilograms * 2).rounded() / 2
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    private static func describe(_ effort: Effort, withReps: Bool = false) -> String {
        var text = effort.load.map { "\(format($0.value)) \($0.unit.rawValue)" } ?? "no load"
        if withReps || effort.load == nil, let reps = effort.reps { text += " for \(reps) reps" }
        return text
    }
}
