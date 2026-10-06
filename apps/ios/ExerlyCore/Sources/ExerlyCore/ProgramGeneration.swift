import Foundation

/// Builds a program from a few answers and the gym, offered as a proposal.
/// See docs/design/017-program-generation.md. PARITY P02.
public enum ProgramGeneration {
    public enum Goal: String, Sendable, Codable, Hashable, CaseIterable {
        case hypertrophy, strength, general
    }

    public enum Experience: String, Sendable, Codable, Hashable, CaseIterable {
        case beginner, intermediate, advanced
    }

    public struct Request: Sendable, Hashable {
        /// Training days in each cycle, 2 to 6.
        public var daysPerWeek: Int
        public var goal: Goal
        public var experience: Experience
        /// Muscles to give 30 % more.
        public var emphasis: [Muscle]
        /// How long a session can be, which caps its sets at a third of it.
        public var minutes: Int

        public init(daysPerWeek: Int, goal: Goal, experience: Experience, emphasis: [Muscle] = [], minutes: Int = 60) {
            self.daysPerWeek = daysPerWeek
            self.goal = goal
            self.experience = experience
            self.emphasis = emphasis
            self.minutes = minutes
        }

        public var problems: [String] {
            var problems: [String] = []
            if !(2...6).contains(daysPerWeek) { problems.append("Choose 2 to 6 training days a week") }
            if !(30...150).contains(minutes) { problems.append("Sessions must be 30 to 150 minutes") }
            return problems
        }
    }

    public struct Result: Sendable, Hashable {
        public var program: Program
        /// Fractional sets in a cycle, by muscle.
        public var weeklySets: [Muscle: Double]
        public var targets: [Muscle: Double]
        /// Muscles under 80 % of their target, most short first.
        public var shortfalls: [Muscle]
    }

    static let larger: [Muscle] = [.chest, .lats, .midBack, .quads, .hamstrings, .glutes, .sideDelts, .biceps, .triceps]
    static let smaller: [Muscle] = [.rearDelts, .calves, .abs]
    static let skilled: Set<ExerciseID> = ["pistol-squat", "handstand-push-up", "nordic-hamstring-curl"]

    /// Weekly fractional sets for each muscle with a target.
    public static func targets(for request: Request) -> [Muscle: Double] {
        let level = Experience.allCases.firstIndex(of: request.experience)!
        let (big, small): ([Double], [Double]) = switch request.goal {
        case .hypertrophy: ([10, 14, 18], [6, 8, 10])
        case .strength: ([8, 10, 12], [4, 6, 6])
        case .general: ([8, 10, 12], [4, 6, 8])
        }
        var targets: [Muscle: Double] = [:]
        for muscle in larger { targets[muscle] = big[level] }
        for muscle in smaller { targets[muscle] = small[level] }
        for muscle in request.emphasis where targets[muscle] != nil { targets[muscle] = (targets[muscle]! * 1.3).rounded() }
        return targets
    }

    /// Movement patterns, each with its exercises in order of preference.
    enum Pattern: CaseIterable {
        case squat, hinge, singleLeg, horizontalPush, inclinePush, verticalPush, verticalPull, horizontalPull
        case chestFly, lateralRaise, rearDelt, curl, triceps, legExtension, legCurl, calfRaise, abs

        func exercises(_ goal: Goal) -> [ExerciseID] {
            switch self {
            case .squat: ["back-squat", "hack-squat", "leg-press", "front-squat", "smith-machine-squat", "belt-squat", "goblet-squat",
                          "bulgarian-split-squat", "dumbbell-reverse-lunge", "pistol-squat", "bodyweight-squat"]
            case .hinge: (goal == .strength ? ["deadlift", "romanian-deadlift"] : ["romanian-deadlift", "deadlift"])
                + ["trap-bar-deadlift", "dumbbell-romanian-deadlift", "barbell-hip-thrust", "single-leg-romanian-deadlift",
                   "cable-pull-through", "good-morning", "back-extension", "glute-bridge"]
            case .singleLeg: ["bulgarian-split-squat", "dumbbell-reverse-lunge", "dumbbell-walking-lunge", "dumbbell-step-up", "pistol-squat"]
            case .horizontalPush: ["barbell-bench-press", "dumbbell-bench-press", "machine-chest-press", "smith-machine-bench-press",
                                   "push-up", "kneeling-push-up"]
            case .inclinePush: ["incline-dumbbell-bench-press", "incline-barbell-bench-press", "dip", "feet-elevated-push-up"]
            case .verticalPush: ["overhead-press", "seated-dumbbell-shoulder-press", "machine-shoulder-press", "landmine-press",
                                 "pike-push-up", "handstand-push-up"]
            case .verticalPull: ["pull-up", "lat-pulldown", "chin-up", "close-grip-lat-pulldown"]
            case .horizontalPull: ["barbell-row", "chest-supported-dumbbell-row", "seated-cable-row", "one-arm-dumbbell-row",
                                   "machine-row", "t-bar-row", "inverted-row"]
            case .chestFly: ["cable-fly", "dumbbell-fly", "machine-fly"]
            case .lateralRaise: ["dumbbell-lateral-raise", "cable-lateral-raise", "machine-lateral-raise"]
            case .rearDelt: ["face-pull", "dumbbell-reverse-fly", "reverse-machine-fly"]
            case .curl: ["dumbbell-curl", "barbell-curl", "cable-curl", "incline-dumbbell-curl", "hammer-curl", "ez-bar-curl", "preacher-curl"]
            case .triceps: ["triceps-pushdown", "overhead-dumbbell-triceps-extension", "skull-crusher", "overhead-cable-triceps-extension",
                            "close-grip-bench-press", "bench-dip"]
            case .legExtension: ["leg-extension"]
            case .legCurl: ["lying-leg-curl", "seated-leg-curl", "nordic-hamstring-curl"]
            case .calfRaise: ["standing-calf-raise", "seated-calf-raise", "leg-press-calf-raise", "single-leg-calf-raise"]
            case .abs: ["cable-crunch", "hanging-leg-raise", "crunch", "ab-wheel-rollout"]
            }
        }

        /// The pattern to use when a gym has nothing for this one.
        var fallback: Pattern? {
            switch self {
            case .squat: .singleLeg
            case .singleLeg: .squat
            case .legExtension: .singleLeg
            case .legCurl: .hinge
            case .inclinePush, .triceps: .horizontalPush
            case .chestFly: .inclinePush
            case .horizontalPush: .inclinePush
            case .verticalPush: .inclinePush
            case .lateralRaise: .verticalPush
            case .horizontalPull, .curl: .verticalPull
            case .verticalPull, .rearDelt: .horizontalPull
            case .hinge, .calfRaise, .abs: nil
            }
        }
    }

    static func split(_ days: Int) -> (name: String, days: [(name: String, patterns: [Pattern])]) {
        let fullA: [Pattern] = [.squat, .horizontalPush, .verticalPull, .legCurl, .lateralRaise, .triceps, .abs]
        let fullB: [Pattern] = [.hinge, .verticalPush, .horizontalPull, .singleLeg, .chestFly, .curl, .calfRaise]
        let fullC: [Pattern] = [.squat, .inclinePush, .horizontalPull, .legCurl, .rearDelt, .curl, .triceps]
        let upperA: [Pattern] = [.horizontalPush, .verticalPull, .verticalPush, .horizontalPull, .lateralRaise, .triceps, .curl]
        let upperB: [Pattern] = [.inclinePush, .horizontalPull, .verticalPull, .chestFly, .lateralRaise, .rearDelt, .curl, .triceps]
        let lowerA: [Pattern] = [.squat, .hinge, .legExtension, .legCurl, .calfRaise, .abs]
        let lowerB: [Pattern] = [.hinge, .singleLeg, .legCurl, .legExtension, .calfRaise, .abs]
        let push: [Pattern] = [.horizontalPush, .verticalPush, .inclinePush, .lateralRaise, .triceps, .chestFly]
        let pull: [Pattern] = [.verticalPull, .horizontalPull, .horizontalPull, .rearDelt, .curl, .curl]
        let legs: [Pattern] = [.squat, .hinge, .singleLeg, .legCurl, .legExtension, .calfRaise, .abs]
        return switch days {
        case 2: ("Full body", [("Full body A", fullA), ("Full body B", fullB)])
        case 3: ("Full body", [("Full body A", fullA), ("Full body B", fullB), ("Full body C", fullC)])
        case 4: ("Upper/Lower", [("Upper A", upperA), ("Lower A", lowerA), ("Upper B", upperB), ("Lower B", lowerB)])
        case 5: ("Upper/Lower and Push/Pull/Legs", [("Upper", upperA), ("Lower", lowerA), ("Push", push), ("Pull", pull), ("Legs", legs)])
        default: ("Push/Pull/Legs", [("Push A", push), ("Pull A", pull), ("Legs A", legs), ("Push B", push), ("Pull B", pull),
                                     ("Legs B", legs)])
        }
    }

    /// A program for the request, using only exercises `gym` allows (all of
    /// them without a gym). Throws `.invalid` for a request out of range.
    public static func generate(_ request: Request, library: ExerciseLibrary, gym: GymProfile? = nil,
                                createdAt: Date = Date().roundedToMilliseconds) throws -> Result {
        guard request.problems.isEmpty else { throw ProgramStore.StoreError.invalid(request.problems) }
        let targets = targets(for: request)
        let (splitName, plan) = split(request.daysPerWeek)
        let cap = request.minutes / 3
        func usable(_ id: ExerciseID) -> Exercise? {
            guard let exercise = library.exercise(id), request.experience != .beginner || !skilled.contains(id),
                  gym?.allows(exercise) ?? true else { return nil }
            return exercise
        }
        // Each pattern's n-th appearance in the cycle takes its n-th usable
        // exercise, for variety; a strength program keeps each day's main lift.
        var seen: [Pattern: Int] = [:]
        var days: [ProgramDay] = []
        for (name, patterns) in plan {
            var slots: [ProgramSlot] = []
            for (position, pattern) in patterns.enumerated() {
                var options: [Exercise] = []
                var tried: Set<Pattern> = []
                var current: Pattern? = pattern
                while options.isEmpty, let next = current, tried.insert(next).inserted {
                    options = next.exercises(request.goal).compactMap(usable).filter { option in !slots.contains { $0.exerciseID == option.id } }
                    current = next.fallback
                }
                let occurrence = seen[pattern, default: 0]
                seen[pattern] = occurrence + 1
                guard !options.isEmpty else { continue }
                let exercise = options[request.goal == .strength && position == 0 ? 0 : occurrence % options.count]
                let sets = request.goal == .strength && slots.isEmpty ? 4 : 3
                slots.append(ProgramSlot(exerciseID: exercise.id, target: target(request.goal, exercise: exercise, sets: sets,
                                                                                   main: slots.isEmpty)))
            }
            days.append(ProgramDay(name: name, slots: slots))
        }
        balance(&days, targets: targets, cap: cap, library: library)
        let weekly = weeklySets(days, library: library)
        let program = Program(name: "\(request.daysPerWeek)-day \(splitName)", days: days, cycles: 6,
                              deload: request.experience == .beginner ? .none : .last, createdAt: createdAt)
        let shortfalls = targets.filter { (weekly[$0.key] ?? 0) < 0.8 * $0.value }
            .sorted { ((weekly[$0.key] ?? 0) / $0.value, $0.key.rawValue) < ((weekly[$1.key] ?? 0) / $1.value, $1.key.rawValue) }
            .map(\.key)
        return Result(program: program, weeklySets: weekly, targets: targets, shortfalls: shortfalls)
    }

    static func weeklySets(_ days: [ProgramDay], library: ExerciseLibrary) -> [Muscle: Double] {
        var weekly: [Muscle: Double] = [:]
        for slot in days.flatMap(\.slots) {
            for (muscle, credit) in library.exercise(slot.exerciseID)?.muscles ?? [:] {
                weekly[muscle, default: 0] += credit * Double(slot.target.sets)
            }
        }
        return weekly
    }

    /// Moves sets toward the targets: trims days over the cap, then adds a set
    /// where a muscle is furthest under target and removes one where it is
    /// furthest over, isolation work first, 2 to 5 sets an exercise.
    static func balance(_ days: inout [ProgramDay], targets: [Muscle: Double], cap: Int, library: ExerciseLibrary) {
        func sets(_ day: ProgramDay) -> Int { day.slots.reduce(0) { $0 + $1.target.sets } }
        /// A day's main lift keeps at least 3 sets.
        func floor(_ slot: Int) -> Int { slot == 0 ? 3 : 2 }
        func isolationFirst(_ a: (Int, Int), _ b: (Int, Int)) -> Bool {
            let first = library.exercise(days[a.0].slots[a.1].exerciseID)?.mechanics == .isolation
            let second = library.exercise(days[b.0].slots[b.1].exerciseID)?.mechanics == .isolation
            return first != second ? first : a < b
        }
        for index in days.indices {
            while sets(days[index]) > cap {
                if let slot = days[index].slots.indices.reversed().first(where: { days[index].slots[$0].target.sets > floor($0) }) {
                    days[index].slots[slot].target.sets -= 1
                } else {
                    days[index].slots.removeLast()
                }
            }
        }
        for _ in 0..<300 {
            let weekly = weeklySets(days, library: library)
            func ratio(_ muscle: Muscle) -> Double { (weekly[muscle] ?? 0) / targets[muscle]! }
            func slots(training muscle: Muscle) -> [(Int, Int)] {
                days.indices.flatMap { day in
                    days[day].slots.indices.filter { library.exercise(days[day].slots[$0].exerciseID)?.muscles[muscle] == 1 }
                        .map { (day, $0) }
                }.sorted(by: isolationFirst)
            }
            /// The lowest ratio among the muscles a slot targets, after taking a set from it.
            func afterTaking(_ day: Int, _ slot: Int) -> Double {
                let muscles = (library.exercise(days[day].slots[slot].exerciseID)?.muscles ?? [:]).filter { $0.value == 1 && targets[$0.key] != nil }
                return muscles.map { ((weekly[$0.key] ?? 0) - 1) / targets[$0.key]! }.min() ?? .infinity
            }
            var changed = false
            // The neediest muscle gains a set: with room in the day, or from a
            // slot in the same day whose muscles stay better served after.
            for muscle in targets.keys.sorted(by: { (ratio($0), $0.rawValue) < (ratio($1), $1.rawValue) }) where ratio(muscle) < 0.95 {
                let gain = ratio(muscle) + 1 / targets[muscle]!
                for (day, slot) in slots(training: muscle) where days[day].slots[slot].target.sets < 5 {
                    if sets(days[day]) < cap {
                        days[day].slots[slot].target.sets += 1
                        changed = true
                    } else if let donor = days[day].slots.indices.first(where: { other in
                        other != slot && days[day].slots[other].target.sets > floor(other) && afterTaking(day, other) > gain + 1e-9
                    }) {
                        days[day].slots[donor].target.sets -= 1
                        days[day].slots[slot].target.sets += 1
                        changed = true
                    }
                    if changed { break }
                }
                if changed { break }
            }
            // Otherwise an over-served muscle, most over first, gives up a set,
            // or a whole exercise (never a main lift) when every muscle it
            // targets stays at target and trained on two days without it.
            for high in targets.keys.sorted(by: { (ratio($0), $1.rawValue) > (ratio($1), $0.rawValue) }) where !changed && ratio(high) > 1.3 {
                let candidates = slots(training: high)
                if let (day, slot) = candidates.first(where: { days[$0.0].slots[$0.1].target.sets > floor($0.1) }) {
                    days[day].slots[slot].target.sets -= 1
                    changed = true
                } else if let (day, slot) = candidates.first(where: { candidate in
                    let slot = days[candidate.0].slots[candidate.1]
                    let muscles = (library.exercise(slot.exerciseID)?.muscles ?? [:]).filter { targets[$0.key] != nil }
                    // Still at target, and still trained on two days.
                    return candidate.1 > 0 && muscles.allSatisfy { muscle, credit in
                        ((weekly[muscle] ?? 0) - credit * Double(slot.target.sets)) / targets[muscle]! >= 1
                            && (credit < 1 || Set(slots(training: muscle).filter { $0 != candidate }.map(\.0)).count >= 2)
                    }
                }) {
                    days[day].slots.remove(at: slot)
                    changed = true
                }
            }
            if !changed { break }
        }
    }

    static func target(_ goal: Goal, exercise: Exercise, sets: Int, main: Bool) -> SlotTarget {
        let isolation = exercise.mechanics == .isolation
        switch goal {
        case .hypertrophy:
            return isolation ? SlotTarget(sets: sets, minReps: 10, maxReps: 15, rir: 1) : SlotTarget(sets: sets, minReps: 6, maxReps: 10, rir: 2)
        case .strength:
            if isolation { return SlotTarget(sets: sets, minReps: 8, maxReps: 12, rir: 2) }
            return main ? SlotTarget(sets: sets, minReps: 3, maxReps: 5, rir: 2) : SlotTarget(sets: sets, minReps: 5, maxReps: 8, rir: 2)
        case .general:
            return isolation ? SlotTarget(sets: sets, minReps: 10, maxReps: 15, rir: 2) : SlotTarget(sets: sets, minReps: 8, maxReps: 12, rir: 2)
        }
    }

    /// The generated program as a proposal to add it, with the research it
    /// rests on and any muscle it couldn't fully cover.
    public static func proposal(for request: Request, library: ExerciseLibrary, gym: GymProfile? = nil,
                                now: Date = Date()) throws -> Proposal {
        let result = try generate(request, library: library, gym: gym, createdAt: now.roundedToMilliseconds)
        let program = result.program
        var summary = "\(program.days.count) training days a cycle for \(request.goal.rawValue), \(program.cycles) cycles"
            + (program.deload == .last ? ", the last a deload." : ".")
        if !result.shortfalls.isEmpty {
            summary += " Under 80 % of the weekly target: " + result.shortfalls.map(\.name).joined(separator: ", ")
                + (gym == nil ? "." : ", with this gym's equipment and session length.")
            if result.shortfalls.count >= 4 { summary += " More days or longer sessions would cover more." }
        }
        return Proposal(createdAt: now.roundedToMilliseconds, author: ProgramChanges.author, title: "New program: \(program.name)",
                        summary: summary,
                        changes: [try ProposedChange(kind: ProgramStore.kind, id: program.id.uuidString, before: nil as Program?, after: program)],
                        evidence: [
                            Evidence(claim: "About 10 or more weekly sets per muscle grow more muscle than fewer.", level: .humanRCT,
                                     caveats: ["A meta-analysis of trials: an average, not a prediction for you"],
                                     source: "Schoenfeld, Ogborn and Krieger 2017, Journal of Sports Sciences"),
                            Evidence(claim: "Training each muscle at least twice a week grows more muscle than once.", level: .humanRCT,
                                     caveats: ["A meta-analysis of trials"],
                                     source: "Schoenfeld, Ogborn and Krieger 2016, Sports Medicine"),
                        ],
                        confidence: .medium,
                        falsifier: "Your estimated maxes stall for three weeks, or sessions run well past \(request.minutes) minutes.")
    }
}
