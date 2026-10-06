import Foundation
import Observation

/// A daily series Exerly can analyse, named as a string so it can be stored:
/// `nutrient:protein`, `body:trend`, `body:scale`, `exercise:e1rm:back-squat`,
/// `metric:<UUID>` or `tag:travel`. See docs/design/014-analytics.md.
public struct SeriesID: Sendable, Hashable, Codable, CustomStringConvertible {
    public enum Source: Sendable, Hashable {
        case nutrient(Nutrient)
        case trendWeight
        case scaleWeight
        case oneRepMax(ExerciseID)
        case metric(UUID)
        case tag(String)
    }

    public var source: Source

    public init(_ source: Source) { self.source = source }

    public init?(_ text: String) {
        let parts = text.split(separator: ":", maxSplits: 2).map(String.init)
        switch (parts.first, parts.count) {
        case ("nutrient", 2): guard let nutrient = Nutrient(rawValue: parts[1]) else { return nil }; source = .nutrient(nutrient)
        case ("body", 2) where parts[1] == "trend": source = .trendWeight
        case ("body", 2) where parts[1] == "scale": source = .scaleWeight
        case ("exercise", 3) where parts[1] == "e1rm" && !parts[2].isEmpty: source = .oneRepMax(ExerciseID(parts[2]))
        case ("metric", 2): guard let id = UUID(uuidString: parts[1]) else { return nil }; source = .metric(id)
        case ("tag", 2) where !parts[1].isEmpty: source = .tag(parts[1])
        default: return nil
        }
    }

    public var description: String {
        switch source {
        case .nutrient(let nutrient): "nutrient:\(nutrient.rawValue)"
        case .trendWeight: "body:trend"
        case .scaleWeight: "body:scale"
        case .oneRepMax(let exercise): "exercise:e1rm:\(exercise.rawValue)"
        case .metric(let id): "metric:\(id.uuidString)"
        case .tag(let tag): "tag:\(tag)"
        }
    }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let id = SeriesID(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown series \(text)"))
        }
        self = id
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// A metric the person defines and logs once a day: sleep quality, soreness, mood.
public struct CustomMetric: Sendable, Codable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Codable, Hashable, CaseIterable {
        case number
        /// 1 to 5.
        case scale
        /// 1 for yes, 0 for no.
        case yesNo
    }

    public var id: UUID
    public var name: String
    public var unit: String?
    public var kind: Kind
    public var minimum: Double?
    public var maximum: Double?
    public var createdAt: Date
    public var archivedAt: Date?

    public init(id: UUID = UUID(), name: String, unit: String? = nil, kind: Kind = .number, minimum: Double? = nil,
                maximum: Double? = nil, createdAt: Date = Date().roundedToMilliseconds, archivedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.unit = unit
        self.kind = kind
        self.minimum = minimum
        self.maximum = maximum
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    var problems: [String] {
        var problems: [String] = []
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.count > 60 { problems.append("a metric needs a name up to 60 characters") }
        if let minimum, let maximum, !(minimum.isFinite && maximum.isFinite && minimum < maximum) {
            problems.append("the minimum must be under the maximum")
        }
        return problems
    }

    /// Why a value doesn't fit this metric, or nil.
    func problem(with value: Double) -> String? {
        guard value.isFinite else { return "the value must be a number" }
        switch kind {
        case .scale where !(1...5).contains(value) || value != value.rounded(): return "\(name) takes a whole number from 1 to 5"
        case .yesNo where value != 0 && value != 1: return "\(name) takes yes (1) or no (0)"
        default: break
        }
        if let minimum, value < minimum { return "\(name) can't be under \(minimum)" }
        if let maximum, value > maximum { return "\(name) can't be over \(maximum)" }
        return nil
    }
}

/// One day's value of a custom metric. Its ID comes from the metric and the
/// date, so two devices logging the same day write one document.
public struct MetricEntry: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var metricID: UUID
    public var date: LocalDate
    public var value: Double

    public init(metricID: UUID, date: LocalDate, value: Double) {
        id = MetricEntry.id(metricID: metricID, date: date)
        self.metricID = metricID
        self.date = date
        self.value = value
    }

    static let namespace = UUID(uuidString: "6F1C2B8E-4D3A-4F27-9B51-0E8C7A2D5F14")!
    static func id(metricID: UUID, date: LocalDate) -> UUID { UUID(named: "\(metricID.uuidString)/\(date)", in: namespace) }
}

/// An n=1 experiment: a metric compared between a baseline phase and an
/// intervention phase, in whole local days.
public struct Experiment: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    /// What changes in the intervention phase, in the person's words.
    public var change: String
    public var metric: SeriesID
    public var baselineStart: LocalDate
    public var baselineEnd: LocalDate
    public var interventionStart: LocalDate
    public var interventionEnd: LocalDate
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, change: String, metric: SeriesID, baselineStart: LocalDate, baselineEnd: LocalDate,
                interventionStart: LocalDate, interventionEnd: LocalDate, createdAt: Date = Date().roundedToMilliseconds) {
        self.id = id
        self.name = name
        self.change = change
        self.metric = metric
        self.baselineStart = baselineStart
        self.baselineEnd = baselineEnd
        self.interventionStart = interventionStart
        self.interventionEnd = interventionEnd
        self.createdAt = createdAt
    }

    var problems: [String] {
        var problems: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { problems.append("an experiment needs a name") }
        if baselineStart > baselineEnd || interventionStart > interventionEnd { problems.append("each phase must start before it ends") }
        if baselineEnd >= interventionStart { problems.append("the baseline must end before the intervention starts") }
        return problems
    }
}

/// Custom metrics, their daily values and experiments, as synced documents.
@MainActor
@Observable
public final class MetricsStore {
    public enum StoreError: Error, Equatable {
        case invalid([String])
        case notFound
    }

    static let metricKind = "custom_metric"
    static let entryKind = "metric_entry"
    static let experimentKind = "experiment"

    public private(set) var metrics: [CustomMetric] = []
    public private(set) var entries: [MetricEntry] = []
    public private(set) var experiments: [Experiment] = []

    @ObservationIgnored let persistence: TrainingPersistence & DocumentPersistence

    public init(persistence: TrainingPersistence & DocumentPersistence) throws {
        self.persistence = persistence
        let decoder = ExerlyJSON.decoder
        metrics = try persistence.loadDocuments(kind: Self.metricKind).map { try decoder.decode(CustomMetric.self, from: $0) }
            .sorted { $0.createdAt < $1.createdAt }
        entries = try persistence.loadDocuments(kind: Self.entryKind).map { try decoder.decode(MetricEntry.self, from: $0) }
            .sorted { $0.date < $1.date }
        experiments = try persistence.loadDocuments(kind: Self.experimentKind).map { try decoder.decode(Experiment.self, from: $0) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func metric(_ id: UUID) -> CustomMetric? { metrics.first { $0.id == id } }

    public func saveMetric(_ metric: CustomMetric) throws {
        guard metric.problems.isEmpty else { throw StoreError.invalid(metric.problems) }
        try commit(Self.metricKind, metric.id, metric)
    }

    /// Sets a metric's value for a day, replacing any earlier one; nil clears it.
    public func setValue(_ value: Double?, for metricID: UUID, on date: LocalDate) throws {
        guard let metric = metric(metricID) else { throw StoreError.notFound }
        guard let value else {
            let id = MetricEntry.id(metricID: metricID, date: date)
            guard entries.contains(where: { $0.id == id }) else { return }
            try prepareWrite(kind: Self.entryKind, id: id.uuidString, payload: nil)()
            return
        }
        if let problem = metric.problem(with: value) { throw StoreError.invalid([problem]) }
        let entry = MetricEntry(metricID: metricID, date: date, value: value)
        try commit(Self.entryKind, entry.id, entry)
    }

    public func values(of metricID: UUID) -> [LocalDate: Double] {
        Dictionary(entries.filter { $0.metricID == metricID }.map { ($0.date, $0.value) }, uniquingKeysWith: { a, _ in a })
    }

    public func saveExperiment(_ experiment: Experiment) throws {
        guard experiment.problems.isEmpty else { throw StoreError.invalid(experiment.problems) }
        try commit(Self.experimentKind, experiment.id, experiment)
    }

    public func deleteExperiment(_ id: UUID) throws {
        guard experiments.contains(where: { $0.id == id }) else { throw StoreError.notFound }
        try prepareWrite(kind: Self.experimentKind, id: id.uuidString, payload: nil)()
    }

    private func commit<T: Encodable>(_ kind: String, _ id: UUID, _ value: T) throws {
        try prepareWrite(kind: kind, id: id.uuidString, payload: ExerlyJSON.canonical(value))()
    }
}

extension MetricsStore: DocumentHost {
    public var documentKinds: [String] { [Self.metricKind, Self.entryKind, Self.experimentKind] }

    public func documentIDs(kind: String) -> [String] {
        switch kind {
        case Self.metricKind: metrics.map(\.id.uuidString)
        case Self.entryKind: entries.map(\.id.uuidString)
        case Self.experimentKind: experiments.map(\.id.uuidString)
        default: []
        }
    }

    public func payload(kind: String, id: String) throws -> Data? {
        switch kind {
        case Self.metricKind: return try metrics.first { $0.id.uuidString == id }.map(ExerlyJSON.canonical)
        case Self.entryKind: return try entries.first { $0.id.uuidString == id }.map(ExerlyJSON.canonical)
        case Self.experimentKind: return try experiments.first { $0.id.uuidString == id }.map(ExerlyJSON.canonical)
        default: return nil
        }
    }

    public func canonicalize(kind: String, payload: Data) throws -> Data {
        let decoder = ExerlyJSON.decoder
        switch kind {
        case Self.metricKind: return try ExerlyJSON.canonical(decoder.decode(CustomMetric.self, from: payload))
        case Self.entryKind: return try ExerlyJSON.canonical(decoder.decode(MetricEntry.self, from: payload))
        case Self.experimentKind: return try ExerlyJSON.canonical(decoder.decode(Experiment.self, from: payload))
        default: throw DocumentError(message: "Unknown kind \(kind)")
        }
    }

    public func validate(kind: String, id: String, payload: Data) throws {
        let decoder = ExerlyJSON.decoder
        var problems: [String]
        switch kind {
        case Self.metricKind:
            let metric = try decoder.decode(CustomMetric.self, from: payload)
            problems = (metric.id.uuidString == id ? [] : ["the ID doesn't match"]) + metric.problems
        case Self.entryKind:
            let entry = try decoder.decode(MetricEntry.self, from: payload)
            problems = entry.id.uuidString == id && entry.id == MetricEntry.id(metricID: entry.metricID, date: entry.date)
                ? [] : ["the ID doesn't match the metric and date"]
            if let metric = metric(entry.metricID), let problem = metric.problem(with: entry.value) { problems.append(problem) }
        case Self.experimentKind:
            let experiment = try decoder.decode(Experiment.self, from: payload)
            problems = (experiment.id.uuidString == id ? [] : ["the ID doesn't match"]) + experiment.problems
        default:
            throw DocumentError(message: "Unknown kind \(kind)")
        }
        guard problems.isEmpty else { throw DocumentError(message: problems.joined(separator: "; ")) }
    }

    /// Each document merges as a whole value: a day's value is one number.
    public func merge(kind: String, base: Data?, local: Data, remote: Data) throws -> Data {
        let decoder = ExerlyJSON.decoder
        func whole<T: Codable & Equatable>(_ type: T.Type) throws -> Data {
            try ExerlyJSON.canonical(Merge.value(try base.map { try decoder.decode(type, from: $0) },
                                                 try decoder.decode(type, from: local), try decoder.decode(type, from: remote)))
        }
        switch kind {
        case Self.metricKind: return try whole(CustomMetric.self)
        case Self.entryKind: return try whole(MetricEntry.self)
        case Self.experimentKind: return try whole(Experiment.self)
        default: throw DocumentError(message: "Unknown kind \(kind)")
        }
    }

    public func prepareWrite(kind: String, id: String, payload: Data?) throws -> () -> Void {
        guard let payload else {
            try persistence.deleteDocument(kind: kind, id: id)
            return { [self] in
                metrics.removeAll { $0.id.uuidString == id }
                entries.removeAll { $0.id.uuidString == id }
                experiments.removeAll { $0.id.uuidString == id }
            }
        }
        let canonical = try canonicalize(kind: kind, payload: payload)
        try persistence.saveDocument(kind: kind, id: id, payload: canonical)
        let decoder = ExerlyJSON.decoder
        switch kind {
        case Self.metricKind:
            let metric = try decoder.decode(CustomMetric.self, from: canonical)
            return { [self] in metrics = (metrics.filter { $0.id != metric.id } + [metric]).sorted { $0.createdAt < $1.createdAt } }
        case Self.entryKind:
            let entry = try decoder.decode(MetricEntry.self, from: canonical)
            return { [self] in entries = (entries.filter { $0.id != entry.id } + [entry]).sorted { $0.date < $1.date } }
        default:
            let experiment = try decoder.decode(Experiment.self, from: canonical)
            return { [self] in
                experiments = (experiments.filter { $0.id != experiment.id } + [experiment]).sorted { $0.createdAt < $1.createdAt }
            }
        }
    }
}
