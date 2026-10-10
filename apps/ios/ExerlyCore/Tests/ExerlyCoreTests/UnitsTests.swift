import Foundation
import Testing
@testable import ExerlyCore

@Suite struct LocalDateSpacingTests {
    @Test func evenlySpacedDaysIncludeBothEnds() {
        let start = LocalDate("2026-09-16")!
        #expect(LocalDate.evenlySpaced(from: start, through: LocalDate("2026-10-10")!, count: 4)
            == ["2026-09-16", "2026-09-24", "2026-10-02", "2026-10-10"].map { LocalDate($0)! })
        #expect(LocalDate.evenlySpaced(from: LocalDate("2026-10-07")!, through: LocalDate("2026-10-09")!, count: 4)
            == ["2026-10-07", "2026-10-08", "2026-10-09"].map { LocalDate($0)! }, "No more marks than days")
        #expect(LocalDate.evenlySpaced(from: start, through: start, count: 4) == [start])
    }
}

@Suite struct MassTests {
    @Test func keepsTheEnteredValueAndUnit() throws {
        let mass = Mass(225, .pounds)
        #expect(mass.value == 225)
        #expect(mass.unit == .pounds)
        let decoded = try JSONDecoder().decode(Mass.self, from: JSONEncoder().encode(mass))
        #expect(decoded == mass)
    }

    @Test func convertsWithTheExactPoundDefinition() {
        #expect(Mass(1, .pounds).kilograms == 0.45359237)
        #expect(Mass(100, .kilograms).kilograms == 100)
        #expect(abs(Mass(100, .kilograms).value(in: .pounds) - 220.462_262_185) < 1e-9)
    }

    @Test func comparesByPhysicalAmount() {
        #expect(Mass(100, .kilograms) > Mass(220, .pounds))
        #expect(Mass(100, .kilograms) < Mass(221, .pounds))
        #expect(Mass(0, .kilograms).isZero)
    }

    @Test func rejectsNonFiniteOrNegativeInput() {
        #expect(Mass(validating: -1, .kilograms) == nil)
        #expect(Mass(validating: .nan, .kilograms) == nil)
        #expect(Mass(validating: .infinity, .pounds) == nil)
        #expect(Mass(validating: 0, .kilograms) == Mass(0, .kilograms))
    }
}

@Suite struct LocalDateTests {
    @Test func parsesAndFormatsISOCalendarDates() throws {
        let date = try #require(LocalDate("2026-10-06"))
        #expect(date.year == 2026 && date.month == 10 && date.day == 6)
        #expect(date.description == "2026-10-06")
        #expect(LocalDate("2026-02-29") == nil)
        #expect(LocalDate("2024-02-29") != nil)
        #expect(LocalDate("2026-13-01") == nil)
        #expect(LocalDate("2026-1-01") == nil)
        #expect(LocalDate("20261001") == nil)
    }

    @Test func encodesAsAString() throws {
        let date = try #require(LocalDate("2026-03-08"))
        let data = try JSONEncoder().encode([date])
        #expect(String(bytes: data, encoding: .utf8) == "[\"2026-03-08\"]")
        #expect(try JSONDecoder().decode([LocalDate].self, from: data) == [date])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([LocalDate].self, from: Data("[\"2026-02-30\"]".utf8))
        }
    }

    @Test func takesTheDateFromTheGivenTimeZone() throws {
        // 2026-03-08 06:30 UTC is still March 7 in Los Angeles (PST, UTC-8).
        let instant = Date(timeIntervalSince1970: 1_772_951_400)
        let la = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        #expect(LocalDate(instant, in: la).description == "2026-03-07")
        #expect(LocalDate(instant, in: tokyo).description == "2026-03-08")
    }

    @Test func steppingAcrossDaylightSavingKeepsWholeDays() throws {
        // US clocks spring forward on 2026-03-08.
        let start = try #require(LocalDate("2026-03-07"))
        #expect(start.adding(days: 1).description == "2026-03-08")
        #expect(start.adding(days: 2).description == "2026-03-09")
        #expect(start.adding(days: -7).description == "2026-02-28")
        #expect(start.days(until: try #require(LocalDate("2026-03-14"))) == 7)
    }

    @Test func findsTheStartOfTheWeek() throws {
        let tuesday = try #require(LocalDate("2026-10-06"))
        #expect(tuesday.weekday == .tuesday)
        #expect(tuesday.startOfWeek(firstWeekday: .monday).description == "2026-10-05")
        #expect(tuesday.startOfWeek(firstWeekday: .sunday).description == "2026-10-04")
        #expect(tuesday.startOfWeek(firstWeekday: .tuesday) == tuesday)
        #expect(tuesday.startOfWeek(firstWeekday: .wednesday).description == "2026-09-30")
    }

    @Test func ordersChronologically() throws {
        let a = try #require(LocalDate("2025-12-31"))
        let b = try #require(LocalDate("2026-01-01"))
        #expect(a < b)
    }
}
