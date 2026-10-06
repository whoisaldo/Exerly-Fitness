import Foundation
import ExerlyCore

/// App composition: the account determines which Core store a screen can open.
@MainActor
final class TrainingWorkspace {
    let url: URL
    let store: TrainingStore
    let unreadableCount: Int

    enum AccessError: Error { case missingAccount }

    init(accountID: String, root: URL? = nil) throws {
        guard !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccessError.missingAccount
        }
        let canonical = try SQLiteTrainingPersistence.defaultURL(accountID: accountID)
        if let testRoot = try root ?? Self.testStorageRoot() {
            url = testRoot.appendingPathComponent(accountID, isDirectory: true)
                .appendingPathComponent(canonical.lastPathComponent)
        } else {
            url = canonical
        }
        let persistence = try SQLiteTrainingPersistence(url: url)
        store = try TrainingStore(persistence: persistence)
        unreadableCount = persistence.unreadableRows.count
    }

    private static func testStorageRoot() throws -> URL? {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["EXERLY_TEST_STORE_ID"], UUID(uuidString: id) != nil {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
            return base.appendingPathComponent("SimulatorTests/\(id)/Training", isDirectory: true)
        }
        #endif
        return nil
    }
}

enum TrainingInput {
    // Input syntax belongs to the editor. Core still decides whether a set is loggable.
    static func number(_ text: String, locale: Locale = .current) -> Double? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = input.replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
        guard normalized.range(of: #"^[0-9]+(?:\.[0-9]*)?$"#, options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    static func reps(_ text: String) -> Int? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(input)
    }
}

enum TrainingFormat {
    static func number(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...3)))
    }

    static func mass(_ mass: Mass, unit: MassUnit) -> String {
        "\(number(mass.value(in: unit))) \(unit == .kilograms ? "kg" : "lb")"
    }

    static func set(_ set: PerformedSet, unit: MassUnit) -> String {
        let values = set.efforts.map { effort in
            var parts: [String] = []
            if let load = effort.load { parts.append(mass(load, unit: unit)) }
            if let reps = effort.reps { parts.append("\(reps) reps") }
            if let duration = effort.duration { parts.append("\(number(duration)) s") }
            if let distance = effort.distance { parts.append("\(number(distance)) m") }
            return parts.isEmpty ? "Enter values" : parts.joined(separator: " × ")
        }.joined(separator: " → ")
        return values
    }

    static func kind(_ kind: SetKind) -> String {
        switch kind {
        case .standard: "Working"
        case .warmUp: "Warm-up"
        case .drop: "Drop"
        case .myo: "Myo"
        case .failure: "To failure"
        }
    }

    static func words(_ raw: String) -> String {
        raw.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }

    static func date(_ session: WorkoutSession) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = session.timeZone
        return formatter.string(from: session.startedAt)
    }

    static func error(_ error: Error) -> String {
        if case TrainingStore.StoreError.edit(.incomplete) = error {
            return "Enter the required values before completing this set."
        }
        return "The change could not be saved. Your last saved workout is still on this device. Try again."
    }
}
