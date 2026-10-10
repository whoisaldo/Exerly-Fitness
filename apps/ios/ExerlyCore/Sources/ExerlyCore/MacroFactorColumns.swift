import Foundation

/// How the MacroFactor import reads headers and cells. Headers match by their
/// words, ignoring case, spacing and punctuation, with a trailing unit read
/// apart: "Weight (kg)", "weight kg" and "WEIGHT  (KG)" are all `weight` in
/// kilograms. Cells are read whether a workbook typed them or a CSV left
/// them as text.
enum MFColumns {
    enum Unit: String, Sendable {
        case kcal, kj, g, mg, mcg, kg, lb, oz, percent, ml, iu, m, km, mi, seconds, minutes
    }

    /// A header understood as words and an optional unit.
    struct Header: Sendable, Hashable {
        /// As written in the file.
        var text: String
        /// Its words without the unit: "trend weight".
        var base: String
        var unit: Unit?

        init(_ text: String) {
            self.text = text
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // A unit in a final parenthesis wins: "Folate (mcg DFE)".
            if let open = trimmed.lastIndex(of: "("), trimmed.hasSuffix(")") {
                let inner = MFColumns.words(String(trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)]))
                if let unit = inner.lazy.compactMap({ MFColumns.units[$0] }).first {
                    self.base = MFColumns.words(String(trimmed[..<open])).joined(separator: " ")
                    self.unit = unit
                    return
                }
            }
            var words = MFColumns.words(trimmed)
            if let last = words.last, let unit = MFColumns.units[last], words.count > 1 || unit == .kcal {
                words.removeLast()
                self.unit = unit
            } else {
                self.unit = nil
            }
            self.base = words.joined(separator: " ")
        }
    }

    /// Lowercased words without accents or punctuation. "%" becomes
    /// "percent" and "µg" "mcg".
    static func words(_ text: String) -> [String] {
        let folded = text.replacingOccurrences(of: "%", with: " percent ")
            .replacingOccurrences(of: "µ", with: "mc").replacingOccurrences(of: "μ", with: "mc")
            .replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return folded.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// A name compared by its words: "Chicken Breast, Raw" is "chicken breast raw".
    static func key(_ text: String) -> String { words(text).joined(separator: " ") }

    static let units: [String: Unit] = {
        var units: [String: Unit] = [:]
        let names: [(Unit, [String])] = [
            (.kcal, ["kcal", "kcals"]), (.kj, ["kj"]), (.g, ["g", "gram", "grams", "gr"]), (.mg, ["mg", "milligrams"]),
            (.mcg, ["mcg", "ug", "microgram", "micrograms"]), (.kg, ["kg", "kgs", "kilogram", "kilograms"]),
            (.lb, ["lb", "lbs", "pound", "pounds"]), (.oz, ["oz", "ounce", "ounces"]), (.percent, ["percent", "pct"]),
            (.ml, ["ml", "milliliters", "millilitres"]), (.iu, ["iu"]), (.m, ["m", "meters", "metres"]),
            (.km, ["km", "kilometers", "kilometres"]), (.mi, ["mi", "mile", "miles"]),
            (.seconds, ["s", "sec", "secs", "seconds"]), (.minutes, ["min", "mins", "minutes"]),
        ]
        for (unit, words) in names { for word in words { units[word] = unit } }
        return units
    }()

    // MARK: Nutrients

    /// Each nutrient's names as header words. MacroFactor writes "Calories
    /// (kcal)", "Protein (g)", "Carbs (g)", "Fat (g)", "Fiber (g)", "Sodium
    /// (mg)" and "Alcohol (g)"; the rest are common spellings of the
    /// micronutrients its export lists.
    static let nutrients: [String: Nutrient] = {
        var names: [String: Nutrient] = [:]
        func add(_ nutrient: Nutrient, _ aliases: [String]) {
            for alias in aliases where names[key(alias)] == nil { names[key(alias)] = nutrient }
        }
        add(.energy, ["calories", "calorie", "energy", "food energy", "total calories", ""])
        add(.protein, ["protein", "proteins", "total protein"])
        add(.carbohydrate, ["carbs", "carb", "carbohydrate", "carbohydrates", "total carbs", "total carbohydrate", "total carbohydrates"])
        add(.fat, ["fat", "fats", "total fat", "lipids"])
        add(.fiber, ["fiber", "fibre", "dietary fiber", "dietary fibre", "total fiber"])
        add(.sugars, ["sugars", "sugar", "total sugars", "total sugar"])
        add(.addedSugars, ["added sugars", "added sugar", "sugars added", "sugar added"])
        add(.starch, ["starch"])
        add(.saturatedFat, ["saturated fat", "saturated fats", "saturated", "fat saturated", "sat fat"])
        add(.monounsaturatedFat, ["monounsaturated fat", "monounsaturated fats", "monounsaturated", "fat monounsaturated", "mono fat", "mufa"])
        add(.polyunsaturatedFat, ["polyunsaturated fat", "polyunsaturated fats", "polyunsaturated", "fat polyunsaturated", "poly fat", "pufa"])
        add(.transFat, ["trans fat", "trans fats", "trans", "fat trans"])
        add(.omega3, ["omega 3", "omega 3 total", "total omega 3", "omega 3 fatty acids", "omega3"])
        add(.omega3ALA, ["omega 3 ala", "ala", "ala omega 3", "alpha linolenic acid"])
        add(.omega3EPA, ["omega 3 epa", "epa", "epa omega 3"])
        add(.omega3DHA, ["omega 3 dha", "dha", "dha omega 3"])
        add(.omega6, ["omega 6", "omega 6 total", "total omega 6", "omega6"])
        add(.cholesterol, ["cholesterol"])
        let named: [Nutrient] = [.sodium, .potassium, .calcium, .iron, .magnesium, .phosphorus, .zinc, .copper, .manganese,
                                 .selenium, .choline, .alcohol, .caffeine, .water, .histidine, .isoleucine, .leucine, .lysine,
                                 .methionine, .phenylalanine, .threonine, .tryptophan, .valine, .cystine, .tyrosine]
        for nutrient in named { add(nutrient, [nutrient.rawValue]) }
        add(.cystine, ["cysteine"])
        add(.alcohol, ["ethanol"])
        for (nutrient, letter) in [(Nutrient.vitaminA, "a"), (.vitaminC, "c"), (.vitaminD, "d"), (.vitaminE, "e"), (.vitaminK, "k")] {
            add(nutrient, ["vitamin \(letter)", "vit \(letter)"])
        }
        add(.vitaminA, ["vitamin a rae"])
        add(.vitaminC, ["ascorbic acid"])
        add(.vitaminD, ["vitamin d2 d3", "vitamin d d2 d3"])
        add(.vitaminE, ["alpha tocopherol", "vitamin e alpha tocopherol"])
        let bVitamins: [(Nutrient, String, [String])] = [
            (.thiamin, "1", ["thiamin", "thiamine"]), (.riboflavin, "2", ["riboflavin"]), (.niacin, "3", ["niacin"]),
            (.pantothenicAcid, "5", ["pantothenic acid"]), (.vitaminB6, "6", ["pyridoxine"]),
            (.vitaminB12, "12", ["cobalamin", "cyanocobalamin"]), (.folate, "9", ["folate", "folate dfe", "folate total"]),
        ]
        for (nutrient, number, words) in bVitamins {
            let codes = ["b\(number)", "b \(number)", "vitamin b\(number)", "vitamin b \(number)"]
            add(nutrient, codes + words)
            for code in codes { for word in words { add(nutrient, ["\(code) \(word)", "\(word) \(code)"]) } }
        }
        return names
    }()

    /// The factor from a header's unit to the nutrient's unit in Exerly; nil
    /// when the unit can't measure it. Without a unit, the amount is taken in
    /// Exerly's unit, which is MacroFactor's.
    static func factor(_ unit: Unit?, to nutrient: Nutrient) -> Double? {
        guard let unit else { return 1 }
        switch (nutrient.unit, unit) {
        case (.kilocalories, .kcal): return 1
        case (.kilocalories, .kj): return 1 / 4.184
        case (.grams, .g): return 1
        case (.grams, .mg): return 0.001
        case (.grams, .mcg): return 0.000_001
        case (.grams, .ml) where nutrient == .water: return 1
        case (.milligrams, .g): return 1000
        case (.milligrams, .mg): return 1
        case (.milligrams, .mcg): return 0.001
        case (.micrograms, .g): return 1_000_000
        case (.micrograms, .mg): return 1000
        case (.micrograms, .mcg): return 1
        case (.micrograms, .iu) where nutrient == .vitaminD: return 0.025
        default: return nil
        }
    }

    // MARK: Cells

    enum DateOrder: Sendable { case dayFirst, monthFirst }

    static func text(_ value: Spreadsheet.Value?) -> String? {
        switch value {
        case .text(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .number(let number):
            return number.formatted(.number.grouping(.never).precision(.fractionLength(0...6)).locale(Locale(identifier: "en_US_POSIX")))
        case .bool(let flag): return flag ? "TRUE" : "FALSE"
        case .date(let serial): return Spreadsheet.day(serial: serial).map { "\($0.date)" }
        case nil: return nil
        }
    }

    static func number(_ value: Spreadsheet.Value?) -> Double? {
        switch value {
        case .number(let number), .date(let number): return number
        case .text(let text): return number(text)
        case .bool, nil: return nil
        }
    }

    /// "82.5", "82,5", "1,234.5", "1.234,5", "15 %" and "6+".
    static func number(_ text: String) -> Double? {
        var text = text.filter { !$0.isWhitespace }
        while let last = text.last, last == "%" || last == "+" { text.removeLast() }
        let commas = text.filter { $0 == "," }.count
        if commas > 0, let comma = text.lastIndex(of: ","), let dot = text.lastIndex(of: ".") {
            text = comma > dot ? text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                : text.replacingOccurrences(of: ",", with: "")
        } else if commas == 1, text.range(of: #"^-?\d{1,3},\d{3}$"#, options: .regularExpression) == nil {
            text = text.replacingOccurrences(of: ",", with: ".")
        } else if commas > 0 {
            text = text.replacingOccurrences(of: ",", with: "")
        }
        guard text.range(of: #"^-?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$"#, options: .regularExpression) != nil,
              let value = Double(text), value.isFinite else { return nil }
        return value
    }

    static func bool(_ value: Spreadsheet.Value?) -> Bool? {
        switch value {
        case .bool(let flag): return flag
        case .number(let number): return number != 0
        case .text(let text):
            switch key(text) {
            case "true", "yes", "y", "x", "1", "checked", "on": return true
            case "false", "no", "n", "0", "unchecked", "off", "": return false
            default: return nil
            }
        case .date, nil: return nil
        }
    }

    /// A calendar day from a date cell, a serial number or text: ISO dates,
    /// slashed dates in `order`, or English month names.
    static func date(_ value: Spreadsheet.Value?, order: DateOrder) -> LocalDate? {
        switch value {
        case .date(let serial): return serial >= 1 ? Spreadsheet.day(serial: serial)?.date : nil
        case .number(let serial): return (10_000...120_000).contains(serial) ? Spreadsheet.day(serial: serial)?.date : nil
        case .text(let text): return date(text, order: order)
        case .bool, nil: return nil
        }
    }

    static func date(_ text: String, order: DateOrder) -> LocalDate? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = groups(text, #"^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})"#) {
            return LocalDate(year: match[0], month: match[1], day: match[2])
        }
        if let match = groups(text, slashed) {
            let year = match[2] < 100 ? 2000 + match[2] : match[2]
            return order == .dayFirst ? LocalDate(year: year, month: match[1], day: match[0])
                : LocalDate(year: year, month: match[0], day: match[1])
        }
        if let serial = number(text), (10_000...120_000).contains(serial) { return Spreadsheet.day(serial: serial)?.date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for pattern in ["MMM d, yyyy", "MMMM d, yyyy", "d MMM yyyy", "d MMMM yyyy", "EEE, MMM d, yyyy", "EEEE, MMMM d, yyyy",
                        "MMM d yyyy", "EEE MMM d yyyy"] {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: text) { return LocalDate(date, in: formatter.timeZone) }
        }
        return nil
    }

    private static let slashed = #"^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2}|\d{4})\b"#

    /// The order of slashed dates in a column: day first when a first part
    /// is over 12, month first when a second part is, else the locale's.
    /// `decided` is false when slashed dates left it to the locale.
    static func dateOrder(_ values: [Spreadsheet.Value?], locale: Locale) -> (order: DateOrder, decided: Bool) {
        var dayFirst = false, monthFirst = false, seen = false
        for case .text(let text)? in values {
            guard let match = groups(text.trimmingCharacters(in: .whitespaces), slashed) else { continue }
            seen = true
            if match[0] > 12 { dayFirst = true }
            if match[1] > 12 { monthFirst = true }
        }
        if dayFirst != monthFirst { return (dayFirst ? .dayFirst : .monthFirst, true) }
        let pattern = DateFormatter.dateFormat(fromTemplate: "yMd", options: 0, locale: locale) ?? "M/d/y"
        let order: DateOrder = (pattern.firstIndex(of: "d") ?? pattern.endIndex) < (pattern.firstIndex(of: "M") ?? pattern.endIndex)
            ? .dayFirst : .monthFirst
        return (order, !seen)
    }

    /// Seconds into the day: a time or date-time cell, a fraction of a day,
    /// or text such as "07:38 PM", "19:38" or "2026-10-05 19:38".
    static func time(_ value: Spreadsheet.Value?) -> Double? {
        switch value {
        case .date(let serial): return Spreadsheet.day(serial: serial)?.seconds
        case .number(let number): return (0..<1).contains(number) ? Spreadsheet.day(serial: number)?.seconds : nil
        case .text(let text): return time(text)
        case .bool, nil: return nil
        }
    }

    static func time(_ text: String) -> Double? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = text.range(of: #"\d{1,2}:\d{2}(:\d{2})?(\.\d+)?\s*([AaPp]\.?[Mm]\.?)?$"#, options: .regularExpression) else {
            return nil
        }
        let part = String(text[range])
        let numbers = part.split { !$0.isNumber }.prefix(3).compactMap { Int($0) }
        guard numbers.count >= 2, numbers[1] < 60, numbers.count < 3 || numbers[2] < 60 else { return nil }
        var hour = numbers[0]
        let meridiem = part.lowercased().filter(\.isLetter)
        if meridiem.hasPrefix("p") && hour < 12 { hour += 12 }
        if meridiem.hasPrefix("a") && hour == 12 { hour = 0 }
        guard hour < 24 else { return nil }
        return Double(hour * 3600 + numbers[1] * 60 + (numbers.count > 2 ? numbers[2] : 0))
    }

    /// A length of time in seconds: a time cell's fraction of a day, a number
    /// in `unit` (seconds without one), "1:05:30", "4:30", or "1h 5m 30s".
    static func duration(_ value: Spreadsheet.Value?, unit: Unit?) -> Double? {
        let scale = unit == .minutes ? 60.0 : 1
        switch value {
        case .date(let serial): return serial > 0 ? (serial * 86_400).rounded() : nil
        case .number(let number): return number > 0 ? number * scale : nil
        case .text(let text):
            if let number = number(text) { return number > 0 ? number * scale : nil }
            let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":")
            if (2...3).contains(parts.count), parts.allSatisfy({ Int($0) != nil }) {
                let seconds = parts.compactMap { Double($0) }.reduce(0) { $0 * 60 + $1 }
                return seconds > 0 ? seconds : nil
            }
            var seconds = 0.0
            for part in words(text) {
                guard let value = Double(part.prefix { $0.isNumber }) else { continue }
                switch part.drop(while: \.isNumber) {
                case "h", "hr", "hrs", "hour", "hours": seconds += value * 3600
                case "m", "min", "mins", "minute", "minutes": seconds += value * 60
                case "s", "sec", "secs", "second", "seconds": seconds += value
                default: break
                }
            }
            return seconds > 0 ? seconds : nil
        case .bool, nil: return nil
        }
    }

    /// The integer capture groups of a regular expression's first match.
    private static func groups(_ text: String, _ pattern: String) -> [Int]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            Range(match.range(at: index), in: text).flatMap { Int(text[$0]) }
        }
    }
}
