import Foundation

/// Any JSON value. Proposals carry document payloads of any kind as JSONValue,
/// and diffs are computed on it.
public enum JSONValue: Sendable, Hashable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// The JSON form of a typed value, in Exerly's wire format.
    public init<T: Encodable>(encoding value: T) throws {
        self = try ExerlyJSON.decoder.decode(JSONValue.self, from: ExerlyJSON.canonical(value))
    }

    public init(data: Data) throws {
        self = try ExerlyJSON.decoder.decode(JSONValue.self, from: data)
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try ExerlyJSON.decoder.decode(type, from: ExerlyJSON.canonical(self))
    }

    public var canonicalData: Data {
        // Encoding a JSONValue can't fail: it holds only JSON.
        (try? ExerlyJSON.canonical(self)) ?? Data("null".utf8)
    }

    /// Fields that differ, as paths like `exercises[0].sets[1].rir`, in key order.
    public static func diff(_ before: JSONValue?, _ after: JSONValue?) -> [FieldChange] {
        var changes: [FieldChange] = []
        walk(before, after, path: "", into: &changes)
        return changes
    }

    private static func walk(_ before: JSONValue?, _ after: JSONValue?, path: String, into changes: inout [FieldChange]) {
        if before == after { return }
        switch (before, after) {
        case (.object(let a)?, .object(let b)?):
            for key in Set(a.keys).union(b.keys).sorted() {
                walk(a[key], b[key], path: path.isEmpty ? key : "\(path).\(key)", into: &changes)
            }
        case (.array(let a)?, .array(let b)?) where a.count == b.count:
            for index in a.indices { walk(a[index], b[index], path: "\(path)[\(index)]", into: &changes) }
        default:
            changes.append(FieldChange(path: path, before: before, after: after))
        }
    }
}

/// One field that a proposal changes.
public struct FieldChange: Sendable, Hashable {
    public var path: String
    public var before: JSONValue?
    public var after: JSONValue?
}
