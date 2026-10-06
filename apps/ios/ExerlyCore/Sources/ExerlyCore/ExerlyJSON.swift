import CryptoKit
import Foundation

/// The JSON Exerly sends to its API. Keys are sorted, so equal values encode
/// to equal bytes, and dates are ISO 8601 UTC strings with milliseconds.
/// ExerlyCore rounds the dates it creates to whole milliseconds, so they
/// survive a round trip through the server exactly.
public enum ExerlyJSON {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISOMilliseconds.format(date.millisecondsSince1970))
        }
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let milliseconds = ISOMilliseconds.parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date \(text)")
            }
            return Date.milliseconds(milliseconds)
        }
        return decoder
    }()

    /// Canonical bytes for comparing two values.
    public static func canonical<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }
}

extension Date {
    public static func milliseconds(_ milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }

    public var millisecondsSince1970: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    /// This instant at whole-millisecond precision, as it comes back from the server.
    public var roundedToMilliseconds: Date { .milliseconds(millisecondsSince1970) }
}

/// `YYYY-MM-DDTHH:MM:SS.mmmZ` with exact integer arithmetic, for any year from 0 to 9999.
enum ISOMilliseconds {
    static func format(_ milliseconds: Int64) -> String {
        let (days, msOfDay) = floorDivide(milliseconds, 86_400_000)
        let (year, month, day) = civil(fromDays: days)
        let hours = msOfDay / 3_600_000
        let minutes = msOfDay / 60_000 % 60
        let seconds = msOfDay / 1000 % 60
        return String(format: "%04lld-%02lld-%02lldT%02lld:%02lld:%02lld.%03lldZ",
                      year, month, day, hours, minutes, seconds, msOfDay % 1000)
    }

    /// Accepts `Z` or `±HH:MM`, and zero to nine fraction digits.
    static func parse(_ text: String) -> Int64? {
        let chars = Array(text.utf8)
        var index = 0
        func number(_ count: Int) -> Int64? {
            guard index + count <= chars.count else { return nil }
            var value: Int64 = 0
            for c in chars[index..<index + count] {
                guard c >= 48 && c <= 57 else { return nil }
                value = value * 10 + Int64(c - 48)
            }
            index += count
            return value
        }
        func expect(_ c: UInt8) -> Bool {
            guard index < chars.count, chars[index] == c else { return false }
            index += 1
            return true
        }
        guard let year = number(4), expect(45), let month = number(2), expect(45), let day = number(2),
              expect(84), let hour = number(2), expect(58), let minute = number(2), expect(58), let second = number(2),
              (1...12).contains(month), day >= 1, day <= daysIn(month: month, year: year),
              hour < 24, minute < 60, second < 60
        else { return nil }
        var fraction: Int64 = 0
        if index < chars.count, chars[index] == 46 {
            index += 1
            var digits = 0
            while index < chars.count, chars[index] >= 48, chars[index] <= 57 {
                if digits < 3 { fraction = fraction * 10 + Int64(chars[index] - 48) }
                digits += 1
                index += 1
            }
            guard (1...9).contains(digits) else { return nil }
            for _ in 0..<max(0, 3 - digits) { fraction *= 10 }
        }
        var offsetMinutes: Int64 = 0
        if expect(90) {
            offsetMinutes = 0
        } else if index < chars.count, chars[index] == 43 || chars[index] == 45 {
            let sign: Int64 = chars[index] == 45 ? -1 : 1
            index += 1
            guard let h = number(2), expect(58), let m = number(2), h < 24, m < 60 else { return nil }
            offsetMinutes = sign * (h * 60 + m)
        } else {
            return nil
        }
        guard index == chars.count else { return nil }
        let days = daysFromCivil(year: year, month: month, day: day)
        let local = ((days * 24 + hour) * 60 + minute) * 60_000 + second * 1000 + fraction
        return local - offsetMinutes * 60_000
    }

    private static func floorDivide(_ a: Int64, _ b: Int64) -> (Int64, Int64) {
        let q = a / b
        let r = a % b
        return r < 0 ? (q - 1, r + b) : (q, r)
    }

    private static func daysIn(month: Int64, year: Int64) -> Int64 {
        switch month {
        case 2: return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    // Howard Hinnant's days-from-civil algorithms.
    private static func daysFromCivil(year: Int64, month: Int64, day: Int64) -> Int64 {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    private static func civil(fromDays days: Int64) -> (Int64, Int64, Int64) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }
}

/// The nonce for a Sign in with Apple request. Give Apple `sha256` and send
/// `raw` to the server with the identity token.
public struct AppleSignInNonce: Sendable, Hashable {
    public let raw: String
    public let sha256: String

    public init() {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        raw = bytes.map { String(format: "%02x", $0) }.joined()
        sha256 = Self.sha256Hex(raw)
    }

    public static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
