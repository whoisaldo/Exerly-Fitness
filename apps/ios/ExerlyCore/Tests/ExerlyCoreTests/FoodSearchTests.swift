import Foundation
import Testing
@testable import ExerlyCore

@Suite struct FoodSearchTests {
    let names = ["Tomatoes, canned, cooked", "Tomato sauce", "Crème fraîche", "Canned tuna in water", "Diced chicken"]

    func search(_ query: String) -> [String] { FoodSearch.matching(names, query: query) { $0 } }

    @Test func everyWordMatchesInAnyOrderIgnoringCaseAndAccents() {
        #expect(search("canned tomatoes") == ["Tomatoes, canned, cooked"])
        #expect(search("CREME FRAICHE") == ["Crème fraîche"])
        #expect(search("tomato") == ["Tomatoes, canned, cooked", "Tomato sauce"], "In the order given")
        #expect(search("zzqx").isEmpty && search("  ").isEmpty)
    }

    @Test func withoutEveryWordTheFoodsWithMostOfThemComeFirst() {
        // No food says "diced tomatoes canned"; canned tomatoes have two of the
        // words, canned tuna and diced chicken only one, which isn't enough.
        #expect(search("diced tomatoes canned") == ["Tomatoes, canned, cooked"])
        #expect(search("diced canned tuna water") == ["Canned tuna in water"], "Three of four")
        #expect(search("canned water tomatoes zzqx").isEmpty, "Two of four is only half")
        #expect(search("ground tomato").isEmpty, "One of two is only half: another food, not a near match")
    }
}
