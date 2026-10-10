import Compression
import Foundation

/// A spreadsheet's sheets as rows of cell values, read from an .xlsx workbook
/// or a CSV file with Foundation and the system's DEFLATE decoder only.
/// Formulas give their saved results, and styles only decide which numbers
/// are dates. Importers such as `MacroFactorExport` read from it.
public struct Spreadsheet: Sendable, Hashable {
    public enum Value: Sendable, Hashable {
        case text(String)
        case number(Double)
        case bool(Bool)
        /// A number shown as a date or a time: days since 1899-12-30, with the
        /// time of day as the fraction. Excel's 1900 date system, whichever
        /// system the workbook used.
        case date(Double)
    }

    public struct Row: Sendable, Hashable {
        /// The row's number in its sheet, from 1, as a spreadsheet app shows it.
        public var number: Int
        /// Cells by column from column A; nil where a cell is empty.
        public var cells: [Value?]

        public init(number: Int, cells: [Value?]) {
            self.number = number
            self.cells = cells
        }

        public subscript(_ column: Int) -> Value? { cells.indices.contains(column) ? cells[column] : nil }
    }

    public struct Sheet: Sendable, Hashable {
        public var name: String
        /// Rows with at least one value, in order.
        public var rows: [Row]

        public init(name: String, rows: [Row]) {
            self.name = name
            self.rows = rows
        }
    }

    public enum ReadError: Error, Equatable {
        /// Neither a workbook nor text.
        case unreadable
        /// A part of the workbook is missing or broken: which, and why.
        case damaged(String)
        /// A part would inflate past `ZipArchive.limit`.
        case tooLarge
    }

    public var sheets: [Sheet]

    public init(sheets: [Sheet]) { self.sheets = sheets }

    /// An .xlsx workbook or a CSV file, told apart by content: a ZIP archive
    /// is read as a workbook, anything else as text whose one sheet is `name`.
    public static func read(_ data: Data, name: String) throws -> Spreadsheet {
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return try xlsx(data) }
        let text: String?
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            text = String(data: data, encoding: .utf16)
        } else {
            text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        }
        guard let text, !text.contains("\0") else { throw ReadError.unreadable }
        return csv(text, name: name)
    }

    /// A CSV file as one sheet of text cells. Commas or semicolons, quotes as
    /// in RFC 4180.
    public static func csv(_ text: String, name: String) -> Spreadsheet {
        let rows = WorkoutImport.csv(text).enumerated().compactMap { index, fields -> Row? in
            let cells = fields.map { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : Value.text($0) }
            return cells.contains { $0 != nil } ? Row(number: index + 1, cells: cells) : nil
        }
        return Spreadsheet(sheets: [Sheet(name: name, rows: rows)])
    }

    /// The calendar day and the seconds into it of a date serial in the 1900
    /// system. Nil outside years 1900 to 9999.
    public static func day(serial: Double) -> (date: LocalDate, seconds: Double)? {
        guard serial.isFinite, serial >= 0, serial < 2_958_466 else { return nil }
        var days = serial.rounded(.down)
        var seconds = ((serial - days) * 86_400).rounded()
        if seconds >= 86_400 {
            days += 1
            seconds = 0
        }
        guard let epoch = LocalDate(year: 1899, month: 12, day: 30) else { return nil }
        return (epoch.adding(days: Int(days)), seconds)
    }

    // MARK: Workbooks

    /// Reads `xl/workbook.xml`, its relationships, the shared strings, the
    /// styles and each worksheet.
    public static func xlsx(_ data: Data) throws -> Spreadsheet {
        let archive = try ZipArchive(data)
        guard let workbook = try archive.file("xl/workbook.xml") else { throw ReadError.damaged("xl/workbook.xml is missing") }
        let book = try WorkbookPart(workbook)
        let relationships = try archive.file("xl/_rels/workbook.xml.rels").map(Relationships.init) ?? Relationships()
        let strings = try archive.file(relationships.path(ofType: "sharedStrings") ?? "xl/sharedStrings.xml").map(sharedStrings) ?? []
        let dates = try archive.file(relationships.path(ofType: "styles") ?? "xl/styles.xml").map(dateStyles) ?? []
        var sheets: [Sheet] = []
        for (index, sheet) in book.sheets.enumerated() {
            let path = relationships.targets[sheet.relationship].map(Relationships.resolve) ?? "xl/worksheets/sheet\(index + 1).xml"
            guard let part = try archive.file(path) else { throw ReadError.damaged("\(path) is missing") }
            sheets.append(Sheet(name: sheet.name, rows: try rows(part, path: path, strings: strings, dates: dates,
                                                                 offset: book.uses1904 ? 1462 : 0)))
        }
        return Spreadsheet(sheets: sheets)
    }

    struct WorkbookPart {
        var sheets: [(name: String, relationship: String)] = []
        var uses1904 = false

        init(_ data: Data) throws {
            var sheets: [(name: String, relationship: String)] = []
            var uses1904 = false
            try XMLScanner.scan(data, part: "xl/workbook.xml", start: { name, attributes in
                if name == "sheet", let sheet = attributes["name"] { sheets.append((sheet, attributes["id"] ?? "")) }
                if name == "workbookPr", let flag = attributes["date1904"] { uses1904 = flag == "1" || flag.lowercased() == "true" }
            }, end: { _, _ in })
            self.sheets = sheets
            self.uses1904 = uses1904
        }
    }

    struct Relationships {
        /// Relationship ID to target, as written.
        var targets: [String: String] = [:]
        var types: [String: String] = [:]

        init() {}

        init(_ data: Data) throws {
            var targets: [String: String] = [:]
            var types: [String: String] = [:]
            try XMLScanner.scan(data, part: "xl/_rels/workbook.xml.rels", start: { name, attributes in
                guard name == "Relationship", let id = attributes["Id"], let target = attributes["Target"] else { return }
                targets[id] = target
                types[id] = attributes["Type"]
            }, end: { _, _ in })
            self.targets = targets
            self.types = types
        }

        /// The part of a relationship type such as "sharedStrings".
        func path(ofType type: String) -> String? {
            types.first { $0.value.hasSuffix("/\(type)") }.flatMap { targets[$0.key] }.map(Self.resolve)
        }

        /// A target relative to `xl/`, or absolute from the archive's root.
        static func resolve(_ target: String) -> String {
            if target.hasPrefix("/") { return String(target.dropFirst()) }
            var parts = ["xl"]
            for part in target.split(separator: "/") {
                if part == ".." { _ = parts.popLast() } else if part != "." { parts.append(String(part)) }
            }
            return parts.joined(separator: "/")
        }
    }

    /// Each `<si>`'s text runs joined, leaving out phonetic guides.
    static func sharedStrings(_ data: Data) throws -> [String] {
        var strings: [String] = []
        var current = ""
        var phonetic = 0
        try XMLScanner.scan(data, part: "xl/sharedStrings.xml", start: { name, _ in
            if name == "si" { current = "" }
            if name == "rPh" { phonetic += 1 }
        }, end: { name, text in
            switch name {
            case "t" where phonetic == 0: current += text
            case "rPh": phonetic -= 1
            case "si": strings.append(current)
            default: break
            }
        })
        return strings
    }

    /// The cell formats (`cellXfs` indices) that show a date or a time.
    static func dateStyles(_ data: Data) throws -> Set<Int> {
        var custom: [Int: String] = [:]
        var formats: [Int] = []
        var inCellFormats = false
        try XMLScanner.scan(data, part: "xl/styles.xml", start: { name, attributes in
            switch name {
            case "numFmt":
                if let id = attributes["numFmtId"].flatMap(Int.init), let code = attributes["formatCode"] { custom[id] = code }
            case "cellXfs": inCellFormats = true
            case "xf" where inCellFormats: formats.append(attributes["numFmtId"].flatMap(Int.init) ?? 0)
            default: break
            }
        }, end: { name, _ in
            if name == "cellXfs" { inCellFormats = false }
        })
        return Set(formats.indices.filter { index in
            let id = formats[index]
            if let code = custom[id] { return isDateFormat(code) }
            return builtInDates.contains(id)
        })
    }

    /// Excel's built-in date and time formats, including the East Asian ones.
    static let builtInDates: Set<Int> = Set(14...22).union(27...36).union(45...47).union(50...58)

    /// True when a number format shows a date or time: it has a day, month,
    /// year, hour or second code outside quotes, brackets and escapes.
    static func isDateFormat(_ code: String) -> Bool {
        var quoted = false, bracketed = false, escaped = false
        for character in code.lowercased() {
            if escaped { escaped = false; continue }
            switch character {
            case "\\" where !quoted: escaped = true
            case "\"": quoted.toggle()
            case "[" where !quoted: bracketed = true
            case "]" where !quoted: bracketed = false
            case "d", "m", "y", "h", "s": if !quoted && !bracketed { return true }
            default: break
            }
        }
        return false
    }

    /// A worksheet's rows. `offset` moves 1904-system serials into the 1900 system.
    static func rows(_ data: Data, path: String, strings: [String], dates: Set<Int>, offset: Double) throws -> [Row] {
        var rows: [Row] = []
        var number = 0
        var cells: [Value?] = []
        var column = -1
        var type: String?
        var style = 0
        var raw: String?
        var inline: String?
        var inInline = false
        var phonetic = 0
        try XMLScanner.scan(data, part: path, start: { name, attributes in
            switch name {
            case "row":
                number = attributes["r"].flatMap(Int.init) ?? number + 1
                cells = []
                column = -1
            case "c":
                column = attributes["r"].flatMap(columnIndex) ?? column + 1
                type = attributes["t"]
                style = attributes["s"].flatMap(Int.init) ?? 0
                raw = nil
                inline = nil
            case "is": inInline = true
            case "rPh": phonetic += 1
            default: break
            }
        }, end: { name, text in
            switch name {
            case "v": raw = text
            case "t" where inInline && phonetic == 0: inline = (inline ?? "") + text
            case "rPh": phonetic -= 1
            case "is": inInline = false
            case "c":
                guard column >= 0, let value = value(type: type, raw: raw, inline: inline, strings: strings,
                                                     isDate: dates.contains(style), offset: offset) else { return }
                if cells.count <= column { cells += Array(repeating: nil, count: column + 1 - cells.count) }
                cells[column] = value
            case "row":
                if cells.contains(where: { $0 != nil }) { rows.append(Row(number: number, cells: cells)) }
            default: break
            }
        })
        return rows
    }

    private static func value(type: String?, raw: String?, inline: String?, strings: [String], isDate: Bool,
                              offset: Double) -> Value? {
        func text(_ string: String?) -> Value? {
            guard let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return .text(string)
        }
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type {
        case "s": return trimmed.flatMap(Int.init).flatMap { strings.indices.contains($0) ? text(strings[$0]) : nil }
        case "inlineStr": return text(inline)
        case "str", "d": return text(raw)
        case "b": return trimmed.map { .bool($0 == "1" || $0.lowercased() == "true") }
        case "e": return nil
        default:
            guard let number = trimmed.flatMap(Double.init), number.isFinite else { return text(inline) }
            return isDate ? .date(number + offset) : .number(number)
        }
    }

    /// "B7" is column 1, "AA1" column 26.
    static func columnIndex(_ reference: String) -> Int? {
        var index = 0
        var letters = 0
        for scalar in reference.unicodeScalars {
            let value = scalar.value
            guard (65...90).contains(value) || (97...122).contains(value) else { break }
            index = index * 26 + Int((value & ~0x20) - 64)
            letters += 1
        }
        return (1...3).contains(letters) ? index - 1 : nil
    }
}

/// Event-driven XML reading for workbook parts. Element and attribute names
/// lose their namespace prefixes, so `x:c` is `c` and `r:id` is `id`.
final class XMLScanner: NSObject, XMLParserDelegate {
    private let start: (String, [String: String]) -> Void
    private let end: (String, String) -> Void
    private var text = ""

    private init(start: @escaping (String, [String: String]) -> Void, end: @escaping (String, String) -> Void) {
        self.start = start
        self.end = end
    }

    /// Calls `start` for each element with its attributes, and `end` with the
    /// text it held directly, since the last element started or ended.
    static func scan(_ data: Data, part: String, start: @escaping (String, [String: String]) -> Void,
                     end: @escaping (String, String) -> Void) throws {
        let scanner = XMLScanner(start: start, end: end)
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = scanner
        guard parser.parse() else {
            throw Spreadsheet.ReadError.damaged("\(part) isn't readable XML")
        }
    }

    private static func local(_ name: String) -> String {
        name.firstIndex(of: ":").map { String(name[name.index(after: $0)...]) } ?? name
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        text = ""
        var local: [String: String] = [:]
        for (key, value) in attributes where key != "xmlns" && !key.hasPrefix("xmlns:") { local[Self.local(key)] = value }
        start(Self.local(elementName), local)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        end(Self.local(elementName), text)
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
}

/// The entries of a ZIP archive, as an .xlsx workbook is. Stored and DEFLATE
/// entries are read and checked against their CRC-32; ZIP64 and encryption
/// are not supported.
struct ZipArchive {
    struct Entry {
        var flags: UInt16
        var method: UInt16
        var crc: UInt32
        var compressedSize: Int
        var size: Int
        var offset: Int
    }

    /// The largest part this will inflate, against archives built to exhaust memory.
    static let limit = 256 << 20

    private let bytes: [UInt8]
    let entries: [String: Entry]

    init(_ data: Data) throws {
        let bytes = [UInt8](data)
        self.bytes = bytes
        func u16(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
        func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }
        guard bytes.count >= 22 else { throw Spreadsheet.ReadError.damaged("The file is too short to be a workbook") }
        // The end record is the last of its signature within its 64 KiB comment's reach.
        var end: Int?
        var position = bytes.count - 22
        while position >= max(0, bytes.count - 22 - 65_535) {
            if u32(position) == 0x0605_4B50 { end = position; break }
            position -= 1
        }
        guard let end else { throw Spreadsheet.ReadError.damaged("The workbook's directory is missing") }
        let count = u16(end + 10), start = u32(end + 16)
        guard count != 0xFFFF, start != 0xFFFF_FFFF else {
            throw Spreadsheet.ReadError.damaged("Workbooks over 4 GB aren't supported")
        }
        var entries: [String: Entry] = [:]
        position = start
        for _ in 0..<count {
            guard position + 46 <= bytes.count, u32(position) == 0x0201_4B50 else {
                throw Spreadsheet.ReadError.damaged("The workbook's directory is broken")
            }
            let nameLength = u16(position + 28)
            guard position + 46 + nameLength <= bytes.count else { throw Spreadsheet.ReadError.damaged("The workbook's directory is broken") }
            let name = String(decoding: bytes[(position + 46)..<(position + 46 + nameLength)], as: UTF8.self)
            entries[name] = Entry(flags: UInt16(u16(position + 8)), method: UInt16(u16(position + 10)), crc: UInt32(u32(position + 16)),
                                  compressedSize: u32(position + 20), size: u32(position + 24), offset: u32(position + 42))
            position += 46 + nameLength + u16(position + 30) + u16(position + 32)
        }
        self.entries = entries
    }

    /// An entry's contents, nil when there is no such entry. Names match
    /// exactly, or else ignoring case.
    func file(_ name: String) throws -> Data? {
        guard let entry = entries[name] ?? entries.first(where: { $0.key.lowercased() == name.lowercased() })?.value else { return nil }
        func u16(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
        guard entry.flags & 1 == 0 else { throw Spreadsheet.ReadError.damaged("\(name) is encrypted") }
        guard entry.size <= Self.limit else { throw Spreadsheet.ReadError.tooLarge }
        let header = entry.offset
        guard header + 30 <= bytes.count, u16(header) | u16(header + 2) << 16 == 0x0403_4B50 else {
            throw Spreadsheet.ReadError.damaged("\(name) is broken")
        }
        let start = header + 30 + u16(header + 26) + u16(header + 28)
        guard start + entry.compressedSize <= bytes.count else { throw Spreadsheet.ReadError.damaged("\(name) is cut short") }
        let raw = bytes[start..<(start + entry.compressedSize)]
        let output: [UInt8]
        switch entry.method {
        case 0: output = Array(raw)
        case 8: output = try Self.inflate(raw, size: entry.size, name: name)
        default: throw Spreadsheet.ReadError.damaged("\(name) uses an unsupported compression method")
        }
        guard output.count == entry.size, CRC32.checksum(output) == entry.crc else {
            throw Spreadsheet.ReadError.damaged("\(name) fails its checksum")
        }
        return Data(output)
    }

    /// Raw DEFLATE (RFC 1951), which `COMPRESSION_ZLIB` decodes.
    static func inflate(_ input: ArraySlice<UInt8>, size: Int, name: String) throws -> [UInt8] {
        guard size > 0 else { return [] }
        guard !input.isEmpty else { throw Spreadsheet.ReadError.damaged("\(name) is empty") }
        var output = [UInt8](repeating: 0, count: size)
        let written = input.withUnsafeBufferPointer { source in
            output.withUnsafeMutableBufferPointer { destination in
                compression_decode_buffer(destination.baseAddress!, size, source.baseAddress!, source.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw Spreadsheet.ReadError.damaged("\(name) can't be decompressed") }
        return output
    }
}

/// The CRC-32 of ZIP archives (polynomial 0xEDB88320).
enum CRC32 {
    static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 { value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1 }
        return value
    }

    static func checksum<C: Collection>(_ bytes: C) -> UInt32 where C.Element == UInt8 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFF_FFFF
    }
}
