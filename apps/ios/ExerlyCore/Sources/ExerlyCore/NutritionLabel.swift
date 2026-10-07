import Foundation

/// What a nutrition label says, read from the lines of text the camera
/// recognised. PARITY N15; see docs/design/021-label-reading.md.
public struct LabelReading: Sendable, Hashable {
    public enum Basis: String, Sendable, Hashable {
        /// A US Nutrition Facts panel: amounts for one serving.
        case serving
        /// An EU-style declaration: amounts per 100 g or per 100 ml.
        case per100g, per100ml
    }

    public var basis: Basis
    /// The serving as printed, such as "2/3 cup (55g)".
    public var servingText: String?
    public var servingGrams: Double?
    public var servingMilliliters: Double?
    /// In ExerlyCore's units, for the basis.
    public var amounts: NutrientAmounts
    /// Values printed as "less than", read as their bound. Ask the person to check them.
    public var approximated: [Nutrient]
    /// Lines that named a nutrient but had no readable amount.
    public var unread: [String]

    /// Nutrients per 100 g: the amounts themselves for a label per 100 g, or
    /// scaled from a serving with a known weight. Nil otherwise; a serving
    /// given only in millilitres needs a density.
    public var per100g: NutrientAmounts? {
        switch basis {
        case .per100g: amounts
        case .per100ml: nil
        case .serving: servingGrams.flatMap { try? Food.per100g(fromLabel: amounts, servingGrams: $0) }
        }
    }
}

public enum NutritionLabel {
    /// Label words for each nutrient, most specific first, so "saturated fat"
    /// is read before "fat" and "added sugars" before "sugars".
    static let names: [(words: [String], nutrient: Nutrient)] = [
        (["saturated fat", "saturates", "saturated"], .saturatedFat),
        (["trans fat"], .transFat),
        (["monounsaturated", "mono-unsaturates", "monounsaturates"], .monounsaturatedFat),
        (["polyunsaturated", "polyunsaturates"], .polyunsaturatedFat),
        (["added sugars", "added sugar"], .addedSugars),
        (["total sugars", "of which sugars", "sugars", "sugar"], .sugars),
        (["dietary fiber", "dietary fibre", "fibre", "fiber"], .fiber),
        (["total carbohydrate", "carbohydrates", "carbohydrate", "total carb"], .carbohydrate),
        (["total fat", "fat"], .fat),
        (["protein"], .protein),
        (["cholesterol"], .cholesterol),
        (["sodium"], .sodium),
        (["potassium"], .potassium),
        (["calcium"], .calcium),
        (["iron"], .iron),
        (["vitamin d"], .vitaminD),
        (["calories", "energy"], .energy),
    ]

    /// Reads a label from its lines, top to bottom. Nil when the text doesn't
    /// look like a nutrition label: no energy and fewer than two macronutrients.
    public static func read(_ lines: [String]) -> LabelReading? {
        let text = lines.map(clean).filter { !$0.isEmpty }
        let servingLine = text.first { line in
            line.hasPrefix("serving size") || line.hasPrefix("serving") && line.contains("(")
                // Canadian: "Per 1 bar (50 g) / pour 1 barre (50 g)".
                || line.hasPrefix("per ") && line.contains("(") && line.range(of: #"^per 100\s?(g|ml)\b"#, options: .regularExpression) == nil
        }
        var reading = LabelReading(basis: basis(of: text, hasServing: servingLine != nil), amounts: NutrientAmounts(),
                                   approximated: [], unread: [])
        if let line = servingLine {
            let serving = line.replacingOccurrences(of: #"^(serving size[:\s]*|per\s+)"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*/\s*pour\s.*$"#, with: "", options: .regularExpression)
            reading.servingText = serving.isEmpty ? nil : serving
            reading.servingGrams = number(in: serving, before: #"\s*g\b"#)
            reading.servingMilliliters = number(in: serving, before: #"\s*ml\b"#)
        }
        var index = 0
        while index < text.count {
            let line = text[index]
            index += 1
            if line.hasPrefix("serving") || line == servingLine || line.contains("per container") || line.contains("daily value") {
                continue
            }
            if line.hasPrefix("salt") {
                // Salt is 2.5 times sodium; Exerly stores sodium in mg.
                if let (salt, _, approximate) = amount(in: line, after: "salt") {
                    reading.amounts[.sodium] = (salt * 400).rounded()
                    if approximate { reading.approximated.append(.sodium) }
                } else {
                    reading.unread.append(line)
                }
                continue
            }
            guard let (word, nutrient) = names.lazy.compactMap({ entry in
                entry.words.first { line.contains($0) }.map { ($0, entry.nutrient) }
            }).first else { continue }
            guard reading.amounts[nutrient] == nil else { continue }
            var found = nutrient == .energy ? energy(in: line) : amount(in: line, after: word)
            // Big type often puts the number on its own line, as with "Calories" then "230".
            if found == nil, index < text.count, text[index].range(of: #"^<?\s*\d+(\.\d+)?\s*(k?cal|g|mg|mcg)?$"#,
                                                                   options: .regularExpression) != nil {
                found = nutrient == .energy ? energy(in: text[index]) : amount(in: text[index], after: "")
                if found != nil { index += 1 }
            }
            guard let (value, unit, approximate) = found else {
                reading.unread.append(line)
                continue
            }
            reading.amounts[nutrient] = converted(value, from: unit, to: nutrient)
            if approximate { reading.approximated.append(nutrient) }
        }
        let macros = [Nutrient.protein, .fat, .carbohydrate].filter { reading.amounts[$0] != nil }.count
        guard reading.amounts[.energy] != nil || macros >= 2 else { return nil }
        return reading
    }

    /// What the amounts are for. The label's own declaration decides: whichever
    /// comes first of an amount per serving and one per 100 g or ml, since on
    /// a two-column label that is the first column (per 100 g first in the EU,
    /// per serving first in Australia). Declarations are read only from lines
    /// that name no nutrient. Without one, a "Nutrition Facts" title or a
    /// serving size means per serving, and only then do kilojoules or salt
    /// suggest a European label per 100 g.
    static func basis(of text: [String], hasServing: Bool) -> LabelReading.Basis {
        let headers = text.filter { line in
            !line.hasPrefix("serving") && !names.contains { entry in entry.words.contains { line.contains($0) } }
                && !line.hasPrefix("salt")
        }.joined(separator: "\n")
        let per100 = headers.firstMatch(of: /(^|[^\d])100\s?(g|ml)\b/)
        let perServing = headers.firstMatch(of: /per serving|per portion|amount per|amount\/serving|per \d+(\.\d+)?\s?(g|ml) serving|(^|\n)(per|pour) [^\n]*\(\s*\d/)
        // The panel's title says per serving only when nothing more explicit does.
        let title = headers.contains("nutrition facts") || headers.contains("valeur nutritive")
        switch (per100, perServing) {
        case let (hundred?, serving?):
            if serving.range.lowerBound < hundred.range.lowerBound { return .serving }
            return hundred.2 == "ml" ? .per100ml : .per100g
        case let (hundred?, nil):
            return hundred.2 == "ml" ? .per100ml : .per100g
        case (nil, _?):
            return .serving
        case (nil, nil):
            if title || hasServing { return .serving }
            let joined = text.joined(separator: "\n")
            return joined.contains("kj") || joined.contains("salt") ? .per100g : .serving
        }
    }

    /// Lowercase, decimal commas as points, and the usual misreads in amounts:
    /// a letter O for zero ("Og"), and µg or ug for mcg.
    static func clean(_ line: String) -> String {
        var line = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        line = line.replacingOccurrences(of: #"(\d),(\d)"#, with: "$1.$2", options: .regularExpression)
        line = line.replacingOccurrences(of: #"(^|[\s<])o(\s?(g|mg|mcg)\b)"#, with: "$10$2", options: .regularExpression)
        line = line.replacingOccurrences(of: #"(\d)o(\s?(g|mg|mcg)\b)"#, with: "$10$2", options: .regularExpression)
        line = line.replacingOccurrences(of: "µg", with: "mcg").replacingOccurrences(of: #"(\d)\s?ug\b"#, with: "$1mcg",
                                                                                     options: .regularExpression)
        return line.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// The first amount after `word`, skipping percentages: its value, unit
    /// and whether it was printed as "less than".
    static func amount(in line: String, after word: String) -> (Double, String?, Bool)? {
        let rest = word.isEmpty ? line : String(line[(line.range(of: word)?.upperBound ?? line.startIndex)...])
        let before = String(line[..<(line.range(of: word)?.lowerBound ?? line.startIndex)])
        // "Includes 10g Added Sugars": the amount comes first.
        for part in [rest, before] {
            guard let match = part.firstMatch(of: /(<)?\s*(\d+(?:\.\d+)?)\s*(mcg|mg|g|kcal|kj)?(?!\s*%|\d)/) else { continue }
            guard let value = Double(match.2) else { continue }
            return (value, match.3.map(String.init), match.1 != nil)
        }
        return nil
    }

    /// Energy in kcal: a value marked kcal, else kJ converted, else the first number.
    static func energy(in line: String) -> (Double, String?, Bool)? {
        if let kcal = number(in: line, before: #"\s*kcal"#) { return (kcal, "kcal", false) }
        if let kilojoules = number(in: line, before: #"\s*kj"#) { return ((kilojoules / 4.184).rounded(), "kcal", false) }
        return amount(in: line, after: line.contains("calories") ? "calories" : "energy")
    }

    static func number(in text: String, before unit: String) -> Double? {
        guard let range = text.range(of: #"(\d+(\.\d+)?)"# + unit, options: .regularExpression) else { return nil }
        return Double(text[range].prefix { $0.isNumber || $0 == "." })
    }

    /// The value in the nutrient's own unit. Without a printed unit, the usual
    /// label unit is assumed: kcal for energy, mg for sodium and minerals, g
    /// for the rest.
    static func converted(_ value: Double, from unit: String?, to nutrient: Nutrient) -> Double {
        let grams: Double? = switch unit {
        case "g": value
        case "mg": value / 1000
        case "mcg": value / 1_000_000
        default: nil
        }
        guard let grams else { return value }
        return switch nutrient.unit {
        case .grams: grams
        case .milligrams: (grams * 1000 * 1000).rounded() / 1000
        case .micrograms: (grams * 1_000_000 * 1000).rounded() / 1000
        case .kilocalories: value
        }
    }
}
