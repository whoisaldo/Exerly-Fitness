import Compression
import Foundation
@testable import ExerlyCore

/// A cell of a synthetic workbook.
enum TestCell {
    /// Text kept in the shared strings.
    case s(String)
    /// Text written inline in the cell.
    case inline(String)
    case n(Double)
    /// A serial shown with a date format.
    case date(Double)
    /// A serial shown with a time format.
    case time(Double)
    case b(Bool)
    /// A formula's saved text result.
    case formula(String)
    case empty
}

/// Builds small .xlsx workbooks in tests, as Excel writes them: a ZIP of XML
/// parts with shared strings, styles and one part per sheet.
struct XLSXBuilder {
    var sheets: [(name: String, rows: [[TestCell]])]
    var date1904 = false
    var deflate = true
    /// Leave out the `r` references, as some writers do.
    var omitReferences = false
    /// Numbers of the rows to write, when they shouldn't be 1, 2, 3…
    var rowNumbers: [Int]?

    init(_ sheets: [(name: String, rows: [[TestCell]])]) { self.sheets = sheets }

    static func column(_ index: Int) -> String {
        var index = index + 1
        var name = ""
        while index > 0 {
            let remainder = (index - 1) % 26
            name = String(UnicodeScalar(65 + remainder)!) + name
            index = (index - 1) / 26
        }
        return name
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    func data() -> Data {
        var strings: [String] = []
        var index: [String: Int] = [:]
        func shared(_ text: String) -> Int {
            if let found = index[text] { return found }
            strings.append(text)
            index[text] = strings.count - 1
            return strings.count - 1
        }
        var parts: [(String, String)] = []
        for (sheetIndex, sheet) in sheets.enumerated() {
            var xml = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#
            xml += #"<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>"#
            for (rowIndex, row) in sheet.rows.enumerated() {
                let number = rowNumbers?[rowIndex] ?? rowIndex + 1
                xml += omitReferences ? "<row>" : #"<row r="\#(number)">"#
                for (columnIndex, cell) in row.enumerated() {
                    let reference = omitReferences ? "" : #" r="\#(Self.column(columnIndex))\#(number)""#
                    switch cell {
                    case .s(let text): xml += #"<c\#(reference) t="s"><v>\#(shared(text))</v></c>"#
                    case .inline(let text): xml += #"<c\#(reference) t="inlineStr"><is><t xml:space="preserve">\#(Self.escape(text))</t></is></c>"#
                    case .n(let value): xml += "<c\(reference)><v>\(value)</v></c>"
                    case .date(let value): xml += #"<c\#(reference) s="1"><v>\#(value)</v></c>"#
                    case .time(let value): xml += #"<c\#(reference) s="2"><v>\#(value)</v></c>"#
                    case .b(let value): xml += #"<c\#(reference) t="b"><v>\#(value ? 1 : 0)</v></c>"#
                    case .formula(let text): xml += #"<c\#(reference) t="str"><f>CONCAT("a")</f><v>\#(Self.escape(text))</v></c>"#
                    case .empty: if omitReferences { xml += "<c/>" }
                    }
                }
                xml += "</row>"
            }
            xml += "</sheetData></worksheet>"
            parts.append(("xl/worksheets/sheet\(sheetIndex + 1).xml", xml))
        }
        let sheetList = sheets.enumerated().map { #"<sheet name="\#(Self.escape($1.name))" sheetId="\#($0 + 1)" r:id="rId\#($0 + 1)"/>"# }.joined()
        let workbook = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><workbookPr\#(date1904 ? #" date1904="1""# : "")/><sheets>\#(sheetList)</sheets></workbook>"#
        let relationships = sheets.indices.map {
            #"<Relationship Id="rId\#($0 + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet\#($0 + 1).xml"/>"#
        }.joined() + #"<Relationship Id="rIdS" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/><Relationship Id="rIdT" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>"#
        // Style 1 is a built-in date, 2 a custom time; the cellStyleXfs entry must not count.
        let styles = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="1"><numFmt numFmtId="164" formatCode="h:mm\ AM/PM"/></numFmts><cellStyleXfs count="1"><xf numFmtId="14"/></cellStyleXfs><cellXfs count="3"><xf numFmtId="0"/><xf numFmtId="14" applyNumberFormat="1"/><xf numFmtId="164" applyNumberFormat="1"/></cellXfs></styleSheet>"#
        // A rich-text run and a phonetic guide, which must be left out.
        let sharedStrings = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">"#
            + strings.map { text in
                text == "Rich text"
                    ? #"<si><r><t>Rich </t></r><r><rPr><b/></rPr><t>text</t></r><rPh><t>ignored</t></rPh></si>"#
                    : #"<si><t xml:space="preserve">\#(Self.escape(text))</t></si>"#
            }.joined() + "</sst>"
        let contentTypes = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/></Types>"#
        let files = [("[Content_Types].xml", contentTypes), ("xl/workbook.xml", workbook),
                     ("xl/_rels/workbook.xml.rels", #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\#(relationships)</Relationships>"#),
                     ("xl/styles.xml", styles), ("xl/sharedStrings.xml", sharedStrings)] + parts
        return ZipWriter.archive(files.map { ($0.0, Data($0.1.utf8)) }, deflate: deflate)
    }
}

/// Writes ZIP archives of stored or deflated entries.
enum ZipWriter {
    static func archive(_ files: [(name: String, data: Data)], deflate: Bool) -> Data {
        var output = Data()
        var directory = Data()
        func u16(_ value: Int, into data: inout Data) { data.append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)]) }
        func u32(_ value: Int, into data: inout Data) { u16(value & 0xFFFF, into: &data); u16(value >> 16 & 0xFFFF, into: &data) }
        for file in files {
            let bytes = [UInt8](file.data)
            let body = deflate ? compress(bytes) : bytes
            let crc = Int(CRC32.checksum(bytes))
            let name = Data(file.name.utf8)
            let offset = output.count
            u32(0x0403_4B50, into: &output); u16(20, into: &output); u16(0, into: &output); u16(deflate ? 8 : 0, into: &output)
            u16(0, into: &output); u16(0x21, into: &output); u32(crc, into: &output); u32(body.count, into: &output)
            u32(bytes.count, into: &output); u16(name.count, into: &output); u16(0, into: &output)
            output.append(name); output.append(contentsOf: body)
            u32(0x0201_4B50, into: &directory); u16(20, into: &directory); u16(20, into: &directory); u16(0, into: &directory)
            u16(deflate ? 8 : 0, into: &directory); u16(0, into: &directory); u16(0x21, into: &directory); u32(crc, into: &directory)
            u32(body.count, into: &directory); u32(bytes.count, into: &directory); u16(name.count, into: &directory)
            u16(0, into: &directory); u16(0, into: &directory); u16(0, into: &directory); u16(0, into: &directory)
            u32(0, into: &directory); u32(offset, into: &directory); directory.append(name)
        }
        let start = output.count
        output.append(directory)
        u32(0x0605_4B50, into: &output); u16(0, into: &output); u16(0, into: &output); u16(files.count, into: &output)
        u16(files.count, into: &output); u32(directory.count, into: &output); u32(start, into: &output); u16(0, into: &output)
        return output
    }

    static func compress(_ bytes: [UInt8]) -> [UInt8] {
        guard !bytes.isEmpty else { return [0x03, 0x00] }
        var output = [UInt8](repeating: 0, count: bytes.count + 1024)
        let count = bytes.withUnsafeBufferPointer { source in
            output.withUnsafeMutableBufferPointer { destination in
                compression_encode_buffer(destination.baseAddress!, destination.count, source.baseAddress!, source.count, nil, COMPRESSION_ZLIB)
            }
        }
        return Array(output.prefix(count))
    }
}

/// A synthetic MacroFactor export with every sheet the import reads, some it
/// leaves out, and rows it must skip. No real person's data.
enum MacroFactorFixture {
    /// The Excel serial of a date.
    static func serial(_ date: LocalDate) -> Double { Double(LocalDate(year: 1899, month: 12, day: 30)!.days(until: date)) }
    static func day(_ text: String) -> LocalDate { LocalDate(text)! }
    static func header(_ names: [String]) -> [TestCell] { names.map(TestCell.s) }

    static var sheets: [(name: String, rows: [[TestCell]])] {
        let d = { (text: String) in TestCell.date(serial(day(text))) }
        return [
            ("Food Log", [
                header(["Date", "Time", "Food Name", "Brand", "Serving Size", "Serving Qty", "Serving Weight (g)", "Calories (kcal)",
                        "Protein (g)", "Carbs (g)", "Fat (g)", "Fiber (g)", "Sodium (mg)", "Mystery Column"]),
                [d("2026-10-01"), .s("07:30 AM"), .s("Synthetic Oats"), .empty, .s("cup"), .n(1), .n(80), .n(300), .n(10), .n(54), .n(5), .n(8), .n(2), .s("x")],
                [d("2026-10-01"), .time(0.5), .s("Test Chicken Breast"), .s("Fixture Farms"), .s("g"), .n(150), .n(150), .n(248),
                 .n(46.5), .n(0), .n(5.4), .empty, .n(111)],
                [d("2026-10-01"), .s("3:00 PM"), .s("Fixture Apple"), .empty, .s("medium"), .n(1), .n(180), .n(95), .n(0.5), .n(25), .n(0.3)],
                [d("2026-10-01"), .s("3:00 PM"), .s("Fixture Apple"), .empty, .s("medium"), .n(1), .n(180), .n(95), .n(0.5), .n(25), .n(0.3)],
                [d("2026-10-02"), .s("08:15"), .s("Synthetic Oats"), .empty, .s("cup"), .n(1.5), .n(120), .n(450), .n(15), .n(81), .n(7.5)],
                [d("2026-10-02"), .s("19:40"), .s("Restaurant Bowl"), .empty, .empty, .empty, .empty, .n(700), .n(35), .n(80), .n(25)],
                [.s("not a date"), .s("12:00"), .s("Lost Row"), .empty, .empty, .empty, .n(100), .n(100)],
                [d("2026-10-02"), .s("12:00"), .empty, .empty, .empty, .empty, .n(100), .n(100)],
                [d("2026-10-02"), .s("12:30"), .s("Broken Bar"), .empty, .empty, .empty, .n(50), .n(-20)],
            ]),
            ("Calories & Macros", [
                header(["Date", "Calories (kcal)", "Protein (g)", "Carbs (g)", "Fat (g)", "Target Calories (kcal)"]),
                [d("2026-09-29"), .n(2150), .n(150), .n(230), .n(70), .n(2200)],
                [d("2026-09-30"), .n(1400), .n(90), .n(150), .n(50), .n(2200)],
                [d("2026-10-01"), .n(1038), .n(57.5), .n(104), .n(11), .n(2200)],
                [d("2026-10-03"), .n(0), .n(0), .n(0), .n(0), .n(2200)],
            ]),
            ("Micronutrients", [
                header(["Date", "Fiber (g)", "Sodium (mg)", "Vitamin B12 (mcg)", "B1, Thiamine (mg)", "Omega-3 ALA (g)", "Alcohol (g)",
                        "Caffeine (mg)", "Folate (mcg DFE)", "Vitamin D (IU)", "Glitter (sparkles)"]),
                [d("2026-09-29"), .n(31), .n(2400), .n(4.2), .n(1.4), .n(1.1), .n(14), .n(200), .n(410), .n(400), .n(3)],
            ]),
            ("Scale Weight", [
                header(["Date", "Weight (kg)", "Fat Percent"]),
                [d("2026-09-28"), .n(82.4), .n(18.5)],
                [d("2026-09-30"), .n(82.1), .empty],
                [d("2026-10-02"), .n(81.9), .n(19)],
                [d("2026-10-03"), .n(900), .empty],
                [d("2026-10-04"), .n(81.7), .n(0.2)],
            ]),
            ("Weight Trend", [header(["Date", "Trend Weight (kg)"]), [d("2026-09-28"), .n(82.3)]]),
            ("Expenditure", [header(["Date", "Expenditure"]), [d("2026-09-28"), .n(2510)]]),
            ("Nutrition Program Settings", programRows(d)),
            ("Weight Goals", [
                header(["Goal", "Status", "Start Date", "End Date", "Goal Weight (kg)", "Goal Rate per Week (%)", "Starting Scale Weight (kg)"]),
                [.s("Lose"), .s("In Progress"), d("2026-09-01"), .empty, .n(78), .n(0.5), .n(83)],
            ]),
            ("Custom Foods", [
                header(["Food Name", "Brand", "Serving Size", "Serving Qty", "Serving Weight (g)", "Calories (kcal)", "Protein (g)",
                        "Carbs (g)", "Fat (g)"]),
                [.s("Synthetic Oats"), .empty, .s("cup"), .n(1), .n(80), .n(300), .n(10), .n(54), .n(5)],
                [.s("Fixture Protein Bar"), .s("Test Co"), .s("bar"), .n(1), .n(60), .n(220), .n(20), .n(22), .n(7)],
                [.s("Weightless Snack"), .empty, .s("pack"), .n(1), .empty, .n(150), .n(2), .n(20), .n(7)],
            ]),
            ("Favorites", [
                header(["Food Name", "Brand", "Serving Size", "Serving Qty", "Serving Weight (g)", "Calories (kcal)", "Protein (g)",
                        "Carbs (g)", "Fat (g)"]),
                [.s("Fixture Protein Bar"), .s("Test Co"), .s("bar"), .n(1), .n(60), .n(220), .n(20), .n(22), .n(7)],
                [.s("Test Greek Yogurt"), .empty, .s("container"), .n(1), .n(170), .n(100), .n(17), .n(6), .n(0.7)],
            ]),
            ("Recipes", [
                header(["Recipe Name", "Ingredient", "Serving Weight (g)", "Calories (kcal)", "Protein (g)", "Carbs (g)", "Fat (g)", "Servings"]),
                [.s("Fixture Chili"), .s("Synthetic Beans"), .n(200), .n(260), .n(17), .n(46), .n(1), .n(4)],
                [.s("Fixture Chili"), .s("Synthetic Beef"), .n(300), .n(750), .n(78), .n(0), .n(48), .empty],
            ]),
            ("History", [header(["Food Name"]), [.s("Synthetic Oats")]]),
            ("Workouts", [
                header(["Date", "Workout Duration", "Workout", "Exercise", "Exercise Base Weight (kg)", "Set Type", "Weight (kg)", "Reps",
                        "RIR", "Duration", "Distance short (m)", "Distance long (km)"]),
                [d("2026-10-01"), .n(3600), .s("Push A"), .s("Bench Press (Barbell)"), .n(20), .s("Warm-Up"), .n(40), .n(10), .empty],
                [d("2026-10-01"), .n(3600), .s("Push A"), .s("Bench Press (Barbell)"), .n(20), .s("Standard Set"), .n(80), .n(8), .n(2)],
                [d("2026-10-01"), .n(3600), .s("Push A"), .s("Dumbbell Lateral Raise"), .n(0), .s("Standard Set"), .n(10), .n(15), .s("6+")],
                [d("2026-10-01"), .n(3600), .s("Push A"), .s("Bench Press (Barbell)"), .n(20), .s("Failure Set"), .n(70), .n(9), .n(0)],
                [d("2026-10-01"), .n(3600), .s("Push A"), .s("Synthetic Zercher Hop"), .n(0), .s("Standard Set"), .n(50), .n(5), .n(2)],
                [d("2026-10-01"), .n(3600), .s("Push A"), .s("Plank"), .n(0), .s("Standard Set"), .empty, .empty, .empty, .n(60)],
                [d("2026-10-01"), .n(3600), .s("Push A"), .s("Back Squat"), .n(20), .s("Standard Set"), .empty, .n(5), .n(2)],
                [d("2026-10-03"), .n(1800), .s("Cardio"), .s("Running"), .n(0), .s("Standard Set"), .empty, .empty, .empty, .n(1500),
                 .empty, .n(5)],
            ]),
            ("Fasting", [header(["Date"]), [d("2026-10-03")]]),
            ("Partial Logging", [header(["Date"]), [d("2026-09-30")]]),
            ("Food Log Notes", [header(["Date", "Notes"]), [d("2026-10-01"), .s("Synthetic note: travel day")]]),
            ("Muscle Groups - Sets", [header(["Date", "Quads (sets)"]), [d("2026-10-01"), .n(3)]]),
            ("Mystery Sheet", [header(["Colour", "Shape"]), [.s("red"), .s("round")]]),
        ]
    }

    private static func programRows(_ d: (String) -> TestCell) -> [[TestCell]] {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        var rows: [[TestCell]] = [header(["Program Update Date", "Program Weekday", "Calories (kcal)", "Protein (g)", "Carbs (g)", "Fat (g)",
                                          "Expenditure (kcal)", "Daily Average (kcal)", "Weight (kg)", "Expenditure Calculation Mode"])]
        for name in days {
            rows.append([d("2026-09-01"), .s(name), .n(2200), .n(160), .n(220), .n(75), .n(2600), .n(2200), .n(83), .s("Dynamic")])
        }
        for name in days {
            let saturday = name == "Saturday"
            rows.append([d("2026-09-21"), .s(name), .n(saturday ? 2500 : 2100), .n(165), .n(saturday ? 280 : 205), .n(saturday ? 80 : 72),
                         .n(2550), .n(2143), .n(82.5), .s("Dynamic")])
        }
        for name in days.prefix(3) {
            rows.append([d("2026-09-25"), .s(name), .n(2000), .n(160), .n(200), .n(70), .n(2500), .n(2000), .n(82), .s("Dynamic")])
        }
        return rows
    }

    static var workbook: Data { XLSXBuilder(sheets).data() }
}
