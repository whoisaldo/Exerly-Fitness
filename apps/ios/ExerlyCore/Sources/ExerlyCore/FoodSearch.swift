import Foundation

/// Typed words matched to foods already on the device, as the food database
/// matches them: each word appears in the name or brand, in any order and
/// ignoring case and accents. When no food has every word, the foods with
/// the most of them, more than half, so "diced tomatoes canned" still finds
/// "Tomatoes, canned" but "ground beef" doesn't offer ground turkey above the
/// database's beef.
public enum FoodSearch {
    /// The query's words, folded for matching.
    public static func words(_ query: String) -> [String] {
        query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// The items whose text matches `query`: those with every word in the
    /// order given, or else those with the most words, more than half, most
    /// first and otherwise in the order given.
    public static func matching<Item>(_ items: [Item], query: String, text: (Item) -> String) -> [Item] {
        let wanted = words(query)
        guard !wanted.isEmpty else { return [] }
        let found = items.map { item in
            let folded = text(item).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            return (item, wanted.filter { folded.contains($0) }.count)
        }
        let all = found.filter { $0.1 == wanted.count }
        if !all.isEmpty || wanted.count == 1 { return all.map(\.0) }
        let enough = wanted.count / 2 + 1
        return found.enumerated().filter { $0.element.1 >= enough }
            .sorted { ($0.element.1, -$0.offset) > ($1.element.1, -$1.offset) }
            .map(\.element.0)
    }
}
