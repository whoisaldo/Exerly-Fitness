import AppIntents
import ExerlyCore
import Foundation

// Logging without opening Exerly. These run in the app's process, launched in
// the background if needed; see IntentAccess. The intents that open the app
// are in Shared, so the controls in the widget extension can use them.

/// One of the meals Today lists.
enum IntentMeal: String, AppEnum {
    case breakfast = "Breakfast", lunch = "Lunch", dinner = "Dinner", snacks = "Snacks"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Meal"
    static let caseDisplayRepresentations: [IntentMeal: DisplayRepresentation] = [
        .breakfast: "Breakfast", .lunch: "Lunch", .dinner: "Dinner",
        .snacks: DisplayRepresentation(title: "Snacks", synonyms: ["Snack"]),
    ]
}

/// A food the person logs: usual at this time of day, recent, or saved.
struct FoodEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Food"
    static let defaultQuery = FoodEntityQuery()

    let id: String
    let name: String
    /// What logging it records: "1 cup (80 g) · 300 kcal".
    let portion: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(portion)") }

    init(_ portion: QuickPortion, unit: MassUnit) {
        id = portion.id
        name = portion.food.name
        self.portion = [portion.food.brand, FoodFormat.portion(portion, unit: unit), "\(FoodFormat.kcal(portion.nutrients.energy)) kcal"]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

struct FoodEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [FoodEntity] {
        try await IntentAccess().perform(changing: false) { account in
            identifiers.compactMap { LoggingActions.portion(of: $0, in: account).map { FoodEntity($0, unit: account.unit) } }
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [FoodEntity] {
        try await IntentAccess().perform(changing: false) { account in
            LoggingActions.usualFoods(in: account).map { FoodEntity($0, unit: account.unit) }
        }
    }

    @MainActor
    func entities(matching string: String) async throws -> [FoodEntity] {
        try await IntentAccess().perform(changing: false) { account in
            LoggingActions.foods(matching: string, in: account).map { FoodEntity($0, unit: account.unit) }
        }
    }
}

struct LogFoodIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a food"
    static let description = IntentDescription("Logs one of your usual or recent foods with the portion you last had.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Food", requestValueDialog: "Which food?") var food: FoodEntity
    @Parameter(title: "Servings", description: "Leave empty for your usual portion.") var servings: Double?

    static var parameterSummary: some ParameterSummary { Summary("Log \(\.$food)") { \.$servings } }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = try await IntentAccess().perform { try LoggingActions.logFood(food.id, servings: servings, in: $0) }
        return .result(dialog: "\(text)")
    }
}

struct QuickAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick add"
    static let description = IntentDescription("Logs calories, and any macros you know, to a meal.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Calories", requestValueDialog: "How many calories?") var calories: Double
    @Parameter(title: "Protein (g)") var protein: Double?
    @Parameter(title: "Carbs (g)") var carbs: Double?
    @Parameter(title: "Fat (g)") var fat: Double?
    @Parameter(title: "Meal", description: "Leave empty for the meal you usually log at this time.") var meal: IntentMeal?

    static var parameterSummary: some ParameterSummary {
        Summary("Quick add \(\.$calories) kcal to \(\.$meal)") {
            \.$protein
            \.$carbs
            \.$fat
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = try await IntentAccess().perform {
            try LoggingActions.quickAdd(calories: calories, protein: protein, carbs: carbs, fat: fat, meal: meal?.rawValue, in: $0)
        }
        return .result(dialog: "\(text)")
    }
}

struct RepeatMealIntent: AppIntent {
    static let title: LocalizedStringResource = "Repeat a meal"
    static let description = IntentDescription("Logs the last time you had a meal this week again today.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Meal", description: "Leave empty for the meal you usually log at this time.") var meal: IntentMeal?

    static var parameterSummary: some ParameterSummary { Summary("Repeat \(\.$meal)") }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = try await IntentAccess().perform { try LoggingActions.repeatMeal(meal?.rawValue, in: $0) }
        return .result(dialog: "\(text)")
    }
}

struct LogWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Log weight"
    static let description = IntentDescription("Logs a weigh-in in the units you use in Exerly.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Weight", description: "In the units you use in Exerly.", requestValueDialog: "What do you weigh?")
    var weight: Double

    static var parameterSummary: some ParameterSummary { Summary("Log \(\.$weight) as today's weight") }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = try await IntentAccess().perform { try LoggingActions.logWeight(weight, in: $0) }
        return .result(dialog: "\(text)")
    }
}

struct CaloriesLeftIntent: AppIntent {
    static let title: LocalizedStringResource = "Calories left"
    static let description = IntentDescription("Tells you what you've eaten today, what's left of your target, and your protein.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = try await IntentAccess().perform(changing: false) { LoggingActions.caloriesLeft(in: $0) }
        return .result(dialog: "\(text)")
    }
}

struct ExerlyShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogFoodIntent(), phrases: [
            "Log \(\.$food) in \(.applicationName)",
            "Log a food in \(.applicationName)",
            "Log my usual food in \(.applicationName)",
        ], shortTitle: "Log a food", systemImageName: "fork.knife")
        AppShortcut(intent: QuickAddIntent(), phrases: [
            "Quick add in \(.applicationName)",
            "Quick add calories in \(.applicationName)",
            "Quick add to \(\.$meal) in \(.applicationName)",
        ], shortTitle: "Quick add", systemImageName: "bolt.fill")
        AppShortcut(intent: LogWeightIntent(), phrases: [
            "Log my weight in \(.applicationName)",
            "Record my weight in \(.applicationName)",
            "Log a weigh-in in \(.applicationName)",
        ], shortTitle: "Log weight", systemImageName: "scalemass.fill")
        AppShortcut(intent: CaloriesLeftIntent(), phrases: [
            "How many calories do I have left in \(.applicationName)",
            "Calories left in \(.applicationName)",
            "How much can I still eat in \(.applicationName)",
        ], shortTitle: "Calories left", systemImageName: "flame.fill")
        AppShortcut(intent: RepeatMealIntent(), phrases: [
            "Repeat my \(\.$meal) in \(.applicationName)",
            "Repeat \(\.$meal) in \(.applicationName)",
            "Repeat my meal in \(.applicationName)",
        ], shortTitle: "Repeat a meal", systemImageName: "arrow.counterclockwise")
        AppShortcut(intent: StartWorkoutIntent(), phrases: [
            "Start my workout in \(.applicationName)",
            "Start today's workout in \(.applicationName)",
            "Start a workout in \(.applicationName)",
        ], shortTitle: "Start workout", systemImageName: "figure.strengthtraining.traditional")
        AppShortcut(intent: ScanBarcodeIntent(), phrases: [
            "Scan a barcode in \(.applicationName)",
            "Scan food in \(.applicationName)",
        ], shortTitle: "Scan barcode", systemImageName: "barcode.viewfinder")
        AppShortcut(intent: WeighInIntent(), phrases: [
            "Weigh in with \(.applicationName)",
            "Open a weigh-in in \(.applicationName)",
        ], shortTitle: "Weigh in", systemImageName: "scalemass")
        AppShortcut(intent: SearchFoodsIntent(), phrases: [
            "Search foods in \(.applicationName)",
            "Find a food in \(.applicationName)",
        ], shortTitle: "Search foods", systemImageName: "magnifyingglass")
    }
}
