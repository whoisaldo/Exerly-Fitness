import Foundation

/// Every nutrient Exerly tracks: energy, macros, and the micronutrient columns
/// of MacroFactor's export. Raw values are stable IDs used in documents.
public enum Nutrient: String, Sendable, Codable, Hashable, CaseIterable, CodingKeyRepresentable {
    case energy, protein, carbohydrate, fat
    case fiber, sugars, addedSugars, starch
    case saturatedFat, monounsaturatedFat, polyunsaturatedFat, transFat
    case omega3, omega3ALA, omega3EPA, omega3DHA, omega6
    case cholesterol
    case sodium, potassium, calcium, iron, magnesium, phosphorus, zinc, copper, manganese, selenium
    case vitaminA, vitaminC, vitaminD, vitaminE, vitaminK
    case thiamin, riboflavin, niacin, pantothenicAcid, vitaminB6, vitaminB12, folate, choline
    case alcohol, caffeine, water
    case histidine, isoleucine, leucine, lysine, methionine, phenylalanine, threonine, tryptophan, valine
    case cystine, tyrosine

    public enum Unit: String, Sendable, Codable, Hashable {
        case kilocalories = "kcal", grams = "g", milligrams = "mg", micrograms = "mcg"
    }

    public enum Group: String, Sendable, Hashable, CaseIterable {
        case energy, macros, carbohydrates, fats, vitamins, minerals, aminoAcids, other
    }

    public var unit: Unit {
        switch self {
        case .energy: .kilocalories
        case .protein, .carbohydrate, .fat, .fiber, .sugars, .addedSugars, .starch, .saturatedFat, .monounsaturatedFat,
             .polyunsaturatedFat, .transFat, .omega3, .omega3ALA, .omega3EPA, .omega3DHA, .omega6, .alcohol, .water,
             .histidine, .isoleucine, .leucine, .lysine, .methionine, .phenylalanine, .threonine, .tryptophan, .valine,
             .cystine, .tyrosine:
            .grams
        case .vitaminA, .vitaminD, .vitaminK, .vitaminB12, .folate, .selenium: .micrograms
        default: .milligrams
        }
    }

    public var group: Group {
        switch self {
        case .energy: .energy
        case .protein, .carbohydrate, .fat: .macros
        case .fiber, .sugars, .addedSugars, .starch: .carbohydrates
        case .saturatedFat, .monounsaturatedFat, .polyunsaturatedFat, .transFat, .omega3, .omega3ALA, .omega3EPA,
             .omega3DHA, .omega6, .cholesterol:
            .fats
        case .vitaminA, .vitaminC, .vitaminD, .vitaminE, .vitaminK, .thiamin, .riboflavin, .niacin, .pantothenicAcid,
             .vitaminB6, .vitaminB12, .folate, .choline:
            .vitamins
        case .sodium, .potassium, .calcium, .iron, .magnesium, .phosphorus, .zinc, .copper, .manganese, .selenium: .minerals
        case .histidine, .isoleucine, .leucine, .lysine, .methionine, .phenylalanine, .threonine, .tryptophan, .valine,
             .cystine, .tyrosine:
            .aminoAcids
        case .alcohol, .caffeine, .water: .other
        }
    }

    /// Listed in every nutrient summary, reported or not: energy and the
    /// macros, fiber, sugars, saturated fat, and the vitamins and minerals.
    /// The rest appear once a food reports them or a goal names them.
    public var isStandard: Bool {
        switch group {
        case .energy, .macros, .vitamins, .minerals: true
        default: self == .fiber || self == .sugars || self == .saturatedFat
        }
    }

    public var name: String {
        switch self {
        case .energy: "Energy"
        case .addedSugars: "Added sugars"
        case .saturatedFat: "Saturated fat"
        case .monounsaturatedFat: "Monounsaturated fat"
        case .polyunsaturatedFat: "Polyunsaturated fat"
        case .transFat: "Trans fat"
        case .omega3: "Omega-3"
        case .omega3ALA: "Omega-3 ALA"
        case .omega3EPA: "Omega-3 EPA"
        case .omega3DHA: "Omega-3 DHA"
        case .omega6: "Omega-6"
        case .vitaminA: "Vitamin A"
        case .vitaminC: "Vitamin C"
        case .vitaminD: "Vitamin D"
        case .vitaminE: "Vitamin E"
        case .vitaminK: "Vitamin K"
        case .thiamin: "Thiamin (B1)"
        case .riboflavin: "Riboflavin (B2)"
        case .niacin: "Niacin (B3)"
        case .pantothenicAcid: "Pantothenic acid (B5)"
        case .vitaminB6: "Vitamin B6"
        case .vitaminB12: "Vitamin B12"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// An adult reference intake, from the US FDA's daily values (21 CFR 101.9)
    /// where they exist. Limits are maximums; the rest are amounts to reach.
    public var reference: ReferenceIntake? {
        switch self {
        case .energy: ReferenceIntake(2000, .target)
        case .protein: ReferenceIntake(50, .atLeast)
        case .carbohydrate: ReferenceIntake(275, .target)
        case .fat: ReferenceIntake(78, .target)
        case .fiber: ReferenceIntake(28, .atLeast)
        case .addedSugars: ReferenceIntake(50, .atMost)
        case .saturatedFat: ReferenceIntake(20, .atMost)
        case .cholesterol: ReferenceIntake(300, .atMost)
        case .sodium: ReferenceIntake(2300, .atMost)
        case .potassium: ReferenceIntake(4700, .atLeast)
        case .calcium: ReferenceIntake(1300, .atLeast)
        case .iron: ReferenceIntake(18, .atLeast)
        case .magnesium: ReferenceIntake(420, .atLeast)
        case .phosphorus: ReferenceIntake(1250, .atLeast)
        case .zinc: ReferenceIntake(11, .atLeast)
        case .copper: ReferenceIntake(0.9, .atLeast)
        case .manganese: ReferenceIntake(2.3, .atLeast)
        case .selenium: ReferenceIntake(55, .atLeast)
        case .vitaminA: ReferenceIntake(900, .atLeast)
        case .vitaminC: ReferenceIntake(90, .atLeast)
        case .vitaminD: ReferenceIntake(20, .atLeast)
        case .vitaminE: ReferenceIntake(15, .atLeast)
        case .vitaminK: ReferenceIntake(120, .atLeast)
        case .thiamin: ReferenceIntake(1.2, .atLeast)
        case .riboflavin: ReferenceIntake(1.3, .atLeast)
        case .niacin: ReferenceIntake(16, .atLeast)
        case .pantothenicAcid: ReferenceIntake(5, .atLeast)
        case .vitaminB6: ReferenceIntake(1.7, .atLeast)
        case .vitaminB12: ReferenceIntake(2.4, .atLeast)
        case .folate: ReferenceIntake(400, .atLeast)
        case .choline: ReferenceIntake(550, .atLeast)
        // FDA guidance for healthy adults, not a daily value.
        case .caffeine: ReferenceIntake(400, .atMost)
        default: nil
        }
    }

    /// Energy per gram for the macros that provide it (Atwater factors).
    public var kilocaloriesPerGram: Double? {
        switch self {
        case .protein, .carbohydrate: 4
        case .fat: 9
        case .alcohol: 7
        default: nil
        }
    }
}

public struct ReferenceIntake: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable {
        /// Reach at least this much.
        case atLeast
        /// Stay under this.
        case atMost
        /// A typical amount, for context.
        case target
    }

    public var amount: Double
    public var kind: Kind

    public init(_ amount: Double, _ kind: Kind) {
        self.amount = amount
        self.kind = kind
    }
}

/// Amounts of nutrients, in each nutrient's unit. Missing means unknown, not zero.
public struct NutrientAmounts: Sendable, Codable, Hashable {
    public var values: [Nutrient: Double]

    public init(_ values: [Nutrient: Double] = [:]) { self.values = values }

    public subscript(_ nutrient: Nutrient) -> Double? {
        get { values[nutrient] }
        set { values[nutrient] = newValue }
    }

    public var energy: Double { values[.energy] ?? 0 }
    public var protein: Double { values[.protein] ?? 0 }
    public var carbohydrate: Double { values[.carbohydrate] ?? 0 }
    public var fat: Double { values[.fat] ?? 0 }

    public func scaled(by factor: Double) -> NutrientAmounts {
        NutrientAmounts(values.mapValues { $0 * factor })
    }

    /// Sums every nutrient either side knows; unknowns stay out of the total.
    public static func + (lhs: NutrientAmounts, rhs: NutrientAmounts) -> NutrientAmounts {
        NutrientAmounts(lhs.values.merging(rhs.values, uniquingKeysWith: +))
    }

    public static func += (lhs: inout NutrientAmounts, rhs: NutrientAmounts) { lhs = lhs + rhs }

    public init(from decoder: Decoder) throws {
        values = try decoder.singleValueContainer().decode([Nutrient: Double].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    /// Problems: negative or non-finite amounts.
    var problems: [String] {
        values.compactMap { nutrient, amount in
            amount.isFinite && amount >= 0 ? nil : "\(nutrient.rawValue) must be a number of 0 or more"
        }.sorted()
    }
}
