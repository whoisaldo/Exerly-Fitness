import Foundation

/// Muscle regions used for set and volume counting.
public enum Muscle: String, Sendable, Codable, Hashable, CaseIterable, CodingKeyRepresentable {
    case chest, frontDelts, sideDelts, rearDelts, lats, upperTraps, midBack, lowerBack
    case biceps, triceps, forearms, abs, obliques
    case glutes, abductors, adductors, hipFlexors, quads, hamstrings, calves, neck

    public var name: String {
        switch self {
        case .chest: "Chest"
        case .frontDelts: "Front delts"
        case .sideDelts: "Side delts"
        case .rearDelts: "Rear delts"
        case .lats: "Lats"
        case .upperTraps: "Upper traps"
        case .midBack: "Mid back"
        case .lowerBack: "Lower back"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .abs: "Abs"
        case .obliques: "Obliques"
        case .glutes: "Glutes"
        case .abductors: "Abductors"
        case .adductors: "Adductors"
        case .hipFlexors: "Hip flexors"
        case .quads: "Quads"
        case .hamstrings: "Hamstrings"
        case .calves: "Calves"
        case .neck: "Neck"
        }
    }
}

public enum JointAction: String, Sendable, Codable, Hashable, CaseIterable {
    case shoulderFlexion, shoulderExtension, shoulderAbduction, shoulderAdduction
    case shoulderHorizontalAdduction, shoulderHorizontalAbduction
    case shoulderInternalRotation, shoulderExternalRotation
    case scapularElevation, scapularDepression, scapularRetraction, scapularProtraction
    case elbowFlexion, elbowExtension, wristFlexion, wristExtension, grip
    case spinalFlexion, spinalExtension, spinalRotation, spinalLateralFlexion, trunkStabilization
    case hipFlexion, hipExtension, hipAbduction, hipAdduction
    case kneeFlexion, kneeExtension, anklePlantarFlexion, ankleDorsiflexion
    case neckFlexion, neckExtension
}

public enum Equipment: String, Sendable, Codable, Hashable, CaseIterable, CodingKeyRepresentable {
    // Resistance
    case barbell, ezBar, trapBar, dumbbell, kettlebell, cable, machine, smithMachine
    case resistanceBand, bodyweight, weightPlate, medicineBall, landmine, sled
    case suspensionTrainer, abWheel
    // Support
    case flatBench, inclineBench, declineBench, rack, pullUpBar, dipStation, box
    case preacherBench, hyperextensionBench
    // Cardio
    case treadmill, bike, rowingMachine, stairClimber, elliptical, jumpRope
}

/// What a set of this exercise records.
public enum TrackingMetric: String, Sendable, Codable, Hashable, CaseIterable {
    /// External load and reps.
    case weightReps
    /// Reps, with optional added load. Effective load includes a share of bodyweight.
    case bodyweightReps
    /// Reps, where the load is machine or band assistance subtracted from bodyweight.
    case assistedReps
    case duration
    case weightDuration
    case distanceDuration
    case weightDistance

    public var tracksReps: Bool { [.weightReps, .bodyweightReps, .assistedReps].contains(self) }
    public var tracksLoad: Bool { [.weightReps, .bodyweightReps, .assistedReps, .weightDuration, .weightDistance].contains(self) }
    public var requiresLoad: Bool { [.weightReps, .weightDuration, .weightDistance].contains(self) }
    public var tracksDuration: Bool { [.duration, .weightDuration, .distanceDuration].contains(self) }
    public var tracksDistance: Bool { [.distanceDuration, .weightDistance].contains(self) }
    public var usesBodyweight: Bool { self == .bodyweightReps || self == .assistedReps }
}

public enum Laterality: String, Sendable, Codable, Hashable, CaseIterable {
    /// Both sides together.
    case bilateral
    /// One side per set; left and right are logged as separate sets.
    case unilateral
    /// Sides alternate within one set.
    case alternating
}

public enum Mechanics: String, Sendable, Codable, Hashable, CaseIterable {
    case compound, isolation
}

public enum BodyRegion: String, Sendable, Codable, Hashable, CaseIterable {
    case upper, lower, core, fullBody
}

public enum ExerciseCategory: String, Sendable, Codable, Hashable, CaseIterable {
    case strength, cardio
}

public struct ExerciseID: RawRepresentable, Sendable, Codable, Hashable, Comparable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { rawValue = value }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func custom() -> ExerciseID { ExerciseID("custom-\(UUID().uuidString.lowercased())") }
    public var isCustom: Bool { rawValue.hasPrefix("custom-") }
    public var description: String { rawValue }
    public static func < (lhs: ExerciseID, rhs: ExerciseID) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct Exercise: Sendable, Codable, Hashable, Identifiable {
    public var id: ExerciseID
    public var name: String
    public var aliases: [String]
    public var category: ExerciseCategory
    public var metric: TrackingMetric
    public var laterality: Laterality
    public var mechanics: Mechanics
    public var region: BodyRegion
    /// Share of a set credited to each muscle: 1 for a target, 0.5 for a synergist.
    public var muscles: [Muscle: Double]
    public var actions: [JointAction]
    /// Equipment that provides resistance. All of it is required.
    public var equipment: [Equipment]
    /// Benches, racks and bars the exercise needs.
    public var support: [Equipment]
    /// Share of bodyweight that counts as load. Zero for external-load exercises.
    public var bodyweightShare: Double

    public init(
        id: ExerciseID, name: String, aliases: [String] = [], category: ExerciseCategory = .strength,
        metric: TrackingMetric, laterality: Laterality = .bilateral, mechanics: Mechanics,
        region: BodyRegion, muscles: [Muscle: Double], actions: [JointAction] = [],
        equipment: [Equipment], support: [Equipment] = [], bodyweightShare: Double = 0
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
        self.metric = metric
        self.laterality = laterality
        self.mechanics = mechanics
        self.region = region
        self.muscles = muscles
        self.actions = actions
        self.equipment = equipment
        self.support = support
        self.bodyweightShare = bodyweightShare
    }

    enum CodingKeys: String, CodingKey {
        case id, name, aliases, category, metric, laterality, mechanics, region, muscles, actions
        case equipment, support, bodyweightShare = "bodyweight"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ExerciseID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        category = try c.decodeIfPresent(ExerciseCategory.self, forKey: .category) ?? .strength
        metric = try c.decode(TrackingMetric.self, forKey: .metric)
        laterality = try c.decodeIfPresent(Laterality.self, forKey: .laterality) ?? .bilateral
        mechanics = try c.decode(Mechanics.self, forKey: .mechanics)
        region = try c.decode(BodyRegion.self, forKey: .region)
        muscles = try c.decodeIfPresent([Muscle: Double].self, forKey: .muscles) ?? [:]
        actions = try c.decodeIfPresent([JointAction].self, forKey: .actions) ?? []
        equipment = try c.decodeIfPresent([Equipment].self, forKey: .equipment) ?? []
        support = try c.decodeIfPresent([Equipment].self, forKey: .support) ?? []
        bodyweightShare = try c.decodeIfPresent(Double.self, forKey: .bodyweightShare) ?? 0
    }

    /// Target muscles (share 1), in the order of `Muscle.allCases`.
    public var targetMuscles: [Muscle] { Muscle.allCases.filter { muscles[$0] == 1 } }
    /// Synergists (share below 1), in the order of `Muscle.allCases`.
    public var synergistMuscles: [Muscle] { Muscle.allCases.filter { (muscles[$0] ?? 1) < 1 } }

    /// Problems that make the definition unusable. Empty when valid.
    public var validationErrors: [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("name is empty") }
        if muscles.values.contains(where: { !($0 > 0 && $0 <= 1) }) { errors.append("muscle shares must be in (0, 1]") }
        if category == .strength {
            if !muscles.values.contains(1) { errors.append("a strength exercise needs a target muscle") }
            if equipment.isEmpty { errors.append("a strength exercise needs equipment") }
        }
        if !(0...1).contains(bodyweightShare) { errors.append("bodyweight share must be in [0, 1]") }
        if metric.usesBodyweight {
            if bodyweightShare == 0 && metric == .assistedReps { errors.append("an assisted exercise needs a bodyweight share") }
        } else if bodyweightShare != 0 {
            errors.append("only bodyweight metrics take a bodyweight share")
        }
        if metric.requiresLoad && equipment.contains(.bodyweight) {
            errors.append("an external-load metric cannot use bodyweight as equipment")
        }
        if metric == .bodyweightReps && !equipment.contains(.bodyweight) {
            errors.append("a bodyweight exercise lists bodyweight as equipment")
        }
        if Set(equipment).count != equipment.count || Set(support).count != support.count || Set(actions).count != actions.count {
            errors.append("duplicate equipment or actions")
        }
        return errors
    }
}
