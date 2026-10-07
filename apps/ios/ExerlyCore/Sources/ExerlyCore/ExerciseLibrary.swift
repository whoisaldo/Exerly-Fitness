import Foundation

/// The bundled exercises plus any custom ones. Immutable; `adding` returns a copy.
public struct ExerciseLibrary: Sendable {
    public enum Error: Swift.Error, Equatable {
        case invalid(ExerciseID, [String])
        case duplicateID(ExerciseID)
    }

    public let exercises: [Exercise]
    private let byID: [ExerciseID: Int]
    private let searchKeys: [[String]]

    public init(exercises: [Exercise]) throws {
        var byID: [ExerciseID: Int] = [:]
        for (index, exercise) in exercises.enumerated() {
            let errors = exercise.validationErrors
            guard errors.isEmpty else { throw Error.invalid(exercise.id, errors) }
            guard byID[exercise.id] == nil else { throw Error.duplicateID(exercise.id) }
            byID[exercise.id] = index
        }
        self.exercises = exercises
        self.byID = byID
        searchKeys = exercises.map { ([$0.name] + $0.aliases).map(Self.normalize) }
    }

    /// The library shipped in the package resources.
    public static let bundled: ExerciseLibrary = {
        struct File: Decodable { let exercises: [Exercise] }
        do {
            let url = Bundle.module.url(forResource: "exercises", withExtension: "json")!
            let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
            return try ExerciseLibrary(exercises: file.exercises)
        } catch {
            fatalError("Bundled exercise library is invalid: \(error)")
        }
    }()

    public func exercise(_ id: ExerciseID) -> Exercise? {
        byID[id].map { exercises[$0] }
    }

    public func adding(_ exercise: Exercise) throws -> ExerciseLibrary {
        try ExerciseLibrary(exercises: exercises + [exercise])
    }

    /// Adds the exercise, or replaces the one with the same ID.
    func replacing(_ exercise: Exercise) throws -> ExerciseLibrary {
        try ExerciseLibrary(exercises: exercises.filter { $0.id != exercise.id } + [exercise])
    }

    /// Exercises matching `query`, best first. An empty query lists every
    /// exercise alphabetically. `muscle` keeps exercises that target it;
    /// `available` keeps exercises whose resistance and support equipment are
    /// all available.
    public func search(_ query: String, muscle: Muscle? = nil, available: Set<Equipment>? = nil) -> [Exercise] {
        let tokens = Self.tokens(query)
        var ranked: [(score: Int, exercise: Exercise)] = []
        for (index, exercise) in exercises.enumerated() {
            if let muscle, exercise.muscles[muscle] != 1 { continue }
            if let available, !(exercise.equipment + exercise.support).allSatisfy(available.contains) { continue }
            guard let score = Self.score(tokens, keys: searchKeys[index]) else { continue }
            ranked.append((score, exercise))
        }
        return ranked.sorted {
            $0.score != $1.score
                ? $0.score < $1.score
                : $0.exercise.name.localizedCaseInsensitiveCompare($1.exercise.name) == .orderedAscending
        }.map(\.exercise)
    }

    // MARK: Matching

    private static let abbreviations = ["db": "dumbbell", "bb": "barbell", "kb": "kettlebell", "bw": "bodyweight"]

    /// Lowercased, without diacritics, with punctuation and hyphens removed so
    /// "Push-Up", "push up" and "pushup" compare equal by word or joined form.
    static func normalize(_ text: String) -> String {
        tokens(text).joined(separator: " ")
    }

    static func tokens(_ text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let words = folded.replacingOccurrences(of: "'", with: "")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        return words.map { abbreviations[$0] ?? $0 }
    }

    /// Lower is better; nil means no match.
    private static func score(_ query: [String], keys: [String]) -> Int? {
        if query.isEmpty { return 0 }
        let joinedQuery = query.joined(separator: " ")
        let compactQuery = query.joined()
        var best: Int?
        for (position, key) in keys.enumerated() {
            let aliasPenalty = position == 0 ? 0 : 1
            let compactKey = key.replacingOccurrences(of: " ", with: "")
            let words = key.split(separator: " ").map(String.init)
            let score: Int?
            if key == joinedQuery || compactKey == compactQuery {
                score = 0 + aliasPenalty
            } else if key.hasPrefix(joinedQuery) || compactKey.hasPrefix(compactQuery) {
                score = 2 + aliasPenalty
            } else if query.allSatisfy({ token in words.contains { $0.hasPrefix(token) } }) {
                score = 4 + aliasPenalty
            } else if compactKey.contains(compactQuery) {
                score = 6 + aliasPenalty
            } else {
                score = nil
            }
            if let score, score < (best ?? .max) { best = score }
        }
        return best
    }
}
