import Foundation
import Testing
@testable import ExerlyCore

@Suite struct SpreadsheetTests {
    @Test func aWorkbookGivesSharedAndInlineTextNumbersBooleansDatesAndFormulaResults() throws {
        let data = XLSXBuilder([
            ("First", [[.s("Name"), .inline("Inline & <text>"), .n(1.5), .b(true), .date(46296), .time(0.75), .formula("Formula"), .s("Rich text")]]),
            ("Second & more", [[.s("A"), .empty, .s("C")], [], [.empty, .n(2)]]),
        ]).data()
        let book = try Spreadsheet.xlsx(data)
        #expect(book.sheets.map(\.name) == ["First", "Second & more"])
        #expect(book.sheets[0].rows[0].cells == [.text("Name"), .text("Inline & <text>"), .number(1.5), .bool(true), .date(46296),
                                                 .date(0.75), .text("Formula"), .text("Rich text")],
                "Rich text runs join and the phonetic guide is left out")
        #expect(book.sheets[1].rows.map(\.number) == [1, 3], "An empty row is left out and row numbers stay the file's")
        #expect(book.sheets[1].rows[0].cells == [.text("A"), nil, .text("C")], "An empty cell is nil, in its column")
        #expect(book.sheets[1].rows[1][0] == nil && book.sheets[1].rows[1][1] == .number(2) && book.sheets[1].rows[1][9] == nil)
        #expect(try Spreadsheet.read(data, name: "ignored") == book, "Read by content, a ZIP is a workbook")
    }

    @Test func serialsBecomeCalendarDaysAndTimes() throws {
        let day = try #require(Spreadsheet.day(serial: 46296.75))
        #expect(day.date == LocalDate("2026-10-01") && day.seconds == 64_800)
        #expect(Spreadsheet.day(serial: 0.5)?.seconds == 43_200)
        #expect(Spreadsheet.day(serial: 46296.999_999_99)?.date == LocalDate("2026-10-02"), "Rounding to midnight carries to the next day")
        #expect(Spreadsheet.day(serial: -1) == nil && Spreadsheet.day(serial: .nan) == nil)
        #expect(MacroFactorFixture.serial(LocalDate("2026-10-01")!) == 46296)
    }

    @Test func storedEntriesRowsWithoutReferencesAndThe1904SystemRead() throws {
        var builder = XLSXBuilder([("Sheet", [[.s("Date"), .date(44834)], [.n(1), .empty, .n(3)]])])
        builder.deflate = false
        builder.omitReferences = true
        builder.date1904 = true
        let book = try Spreadsheet.xlsx(builder.data())
        #expect(book.sheets[0].rows.map(\.cells) == [[.text("Date"), .date(46296)], [.number(1), nil, .number(3)]],
                "1904 serials move into the 1900 system; cells without references follow in order")

        var numbered = XLSXBuilder([("Sheet", [[.s("Header")], [.n(4)]])])
        numbered.rowNumbers = [3, 9]
        #expect(try Spreadsheet.xlsx(numbered.data()).sheets[0].rows.map(\.number) == [3, 9])
    }

    @Test func manySheetsAndWideRowsRead() throws {
        let sheets = (0..<12).map { index in
            (name: "Sheet \(index)", rows: [(0..<30).map { TestCell.n(Double(index * 100 + $0)) }])
        }
        let book = try Spreadsheet.xlsx(XLSXBuilder(sheets).data())
        #expect(book.sheets.count == 12)
        #expect(book.sheets[11].rows[0][29] == .number(1129), "Column AD of the twelfth sheet")
        #expect(Spreadsheet.columnIndex("A1") == 0 && Spreadsheet.columnIndex("Z9") == 25 && Spreadsheet.columnIndex("AA1") == 26
                && Spreadsheet.columnIndex("XFD1") == 16_383 && Spreadsheet.columnIndex("12") == nil)
    }

    @Test func damagedWorkbooksThrowInsteadOfReadingWrongly() throws {
        let data = XLSXBuilder([("Sheet", [[.s("Some text that compresses well, some text that compresses well")]])]).data()
        var corrupted = [UInt8](data)
        // Flip a byte inside the workbook part's compressed data, just after its local header.
        let name = try #require(data.range(of: Data("xl/workbook.xml".utf8)))
        corrupted[name.upperBound + 3] ^= 0xFF
        #expect(throws: Spreadsheet.ReadError.self) { try Spreadsheet.xlsx(Data(corrupted)) }
        #expect(throws: Spreadsheet.ReadError.self) { try Spreadsheet.xlsx(data.prefix(data.count / 2)) }
        #expect(throws: Spreadsheet.ReadError.self) { try Spreadsheet.xlsx(Data("not a zip".utf8)) }
        let empty = ZipWriter.archive([("hello.txt", Data("hi".utf8))], deflate: true)
        #expect(throws: Spreadsheet.ReadError.damaged("xl/workbook.xml is missing")) { try Spreadsheet.xlsx(empty) }
    }

    @Test func aCSVIsOneSheetOfText() throws {
        let csv = "\u{FEFF}Date;Food Name;Calories (kcal)\r\n2026-10-01;\"Oats; rolled\";300\r\n\r\n;;\n2026-10-02;\"Say \"\"hi\"\"\";1,5\n"
        let book = try Spreadsheet.read(Data(csv.utf8), name: "Food Log")
        #expect(book.sheets.map(\.name) == ["Food Log"])
        #expect(book.sheets[0].rows.map(\.cells) == [
            [.text("Date"), .text("Food Name"), .text("Calories (kcal)")],
            [.text("2026-10-01"), .text("Oats; rolled"), .text("300")],
            [.text("2026-10-02"), .text("Say \"hi\""), .text("1,5")],
        ])
        #expect(throws: Spreadsheet.ReadError.unreadable) { try Spreadsheet.read(Data([0x00, 0x01, 0x02]), name: "x") }
    }

    @Test func numberFormatsThatShowDatesAreTold() {
        for code in ["yyyy-mm-dd", "h:mm AM/PM", "[$-409]mmm d, yyyy", "d/m/yy h:mm", "[h]:mm:ss"] {
            #expect(Spreadsheet.isDateFormat(code), "\(code)")
        }
        for code in ["General", "0.00", "#,##0", "0.0\"h\"", "[Red]0.00", "0.00E+00", "\\d0"] {
            #expect(!Spreadsheet.isDateFormat(code), "\(code)")
        }
    }
}
