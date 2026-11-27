import Foundation
import FoundationModels
import Observation

/// A dish suggestion, checked against what's really at home.
struct Recipe: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var summary: String
    var minutes: Int
    /// Inventory names, exactly as the household tracks them.
    var have: [String]
    var need: [String]
    var steps: [String]
}

@available(iOS 26.0, *)
@Generable(description: "A dish the household can cook at home")
struct RecipeIdea {
    @Guide(description: "Dish name, 2 to 5 words")
    var title: String
    @Guide(description: "One short sentence on why this dish suits what's at home today")
    var summary: String
    @Guide(description: "Total cooking time in minutes", .range(5...120))
    var minutes: Int
    @Guide(description: "Every ingredient the steps use, except salt, oil, water and dry spices. Use the inventory's names for inventory items", .count(2...10))
    var ingredients: [String]
    @Guide(description: "Short, clear cooking steps that use only the listed ingredients, salt, oil, water and dry spices", .count(3...7))
    var steps: [String]
}

@available(iOS 26.0, *)
@Generable
struct RecipeIdeaList {
    @Guide(description: "Three different dishes", .count(3))
    var ideas: [RecipeIdea]
}

struct RecipePreferences: Equatable {
    var quick = false
    var vegetarian = false
    var note = ""
}

/// Asks the on-device model for meal ideas built around what's at home,
/// using up food that expires soon first.
@available(iOS 26.0, *)
@MainActor
@Observable
final class RecipeGenerator {
    enum Phase: Equatable {
        case idle, thinking, done
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// Ideas as they stream in, before they're checked.
    private(set) var partial: [RecipeIdea.PartiallyGenerated] = []
    private(set) var recipes: [Recipe] = []
    private var shownTitles: [String] = []
    private var task: Task<Void, Never>?

    /// Lower values gave steadier, more ordinary dishes in testing (see Evaluation/).
    nonisolated static let temperature = 0.4

    nonisolated static let instructions = """
        You suggest home-cooked meals using food a household already has.
        Suggest well-known dishes that families really cook, like dal tadka, matar paneer, jeera rice, \
        vegetable pulao, omelette or pasta. Never invent strange combinations.
        Build each dish around the inventory's main ingredients, and use food that expires soon first.
        A spice mix such as "Chana Masala" is only a seasoning; a dish that uses it still needs its main ingredient.
        Prefer dishes that need at most two ingredients the household doesn't have.
        The kitchen already has salt, cooking oil, water and dry spices.

        Example of a good dish for an inventory with Paneer, Green Peas and Basmati Rice:
        title: Matar Paneer; minutes: 30; ingredients: Paneer, Green Peas, Onion, Tomato;
        steps: Fry the paneer cubes until golden. Cook chopped onion and tomato with spices into a thick sauce. \
        Add the peas and a splash of water and simmer for 5 minutes. Stir in the paneer and serve with rice.
        """

    func generate(pantry: [PantryItem], preferences: RecipePreferences, freshBatch: Bool) {
        task?.cancel()
        if freshBatch { shownTitles = [] }
        phase = .thinking
        partial = []
        recipes = []
        let usable = RecipeGeneratorPrompt.usable(pantry)
        let prompt = RecipeGeneratorPrompt.make(pantry: usable, preferences: preferences, avoid: shownTitles)
        let pantryNames = usable.map(\.name)

        #if DEBUG
        if DebugLaunch.usesAIFixture {
            task = Task {
                try? await Task.sleep(for: .seconds(1.5))
                recipes = DebugLaunch.fixtureRecipes
                phase = .done
            }
            return
        }
        #endif

        task = Task {
            do {
                let session = LanguageModelSession(instructions: Self.instructions)
                let stream = session.streamResponse(
                    to: prompt,
                    generating: RecipeIdeaList.self,
                    options: GenerationOptions(temperature: Self.temperature)
                )
                for try await snapshot in stream {
                    if Task.isCancelled { return }
                    partial = snapshot.content.ideas ?? []
                }
                let result = try await stream.collect().content
                if Task.isCancelled { return }
                recipes = RecipeCheck.recipes(from: result.ideas, pantry: pantryNames, preferences: preferences)
                shownTitles += recipes.map(\.title)
                phase = recipes.isEmpty ? .failed("Couldn't come up with anything from what's at home. Try again.") : .done
            } catch is CancellationError {
                return
            } catch {
                phase = .failed(KitchenAI.message(for: error))
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

enum RecipeGeneratorPrompt {
    /// Expired food is never suggested (it counts as something to buy), and the
    /// most urgent food comes first so it survives the prompt's item limit.
    static func usable(_ pantry: [PantryItem]) -> [PantryItem] {
        PantryItem.urgentFirst(pantry.filter { ($0.daysToExpiry ?? 0) >= 0 && !isSnack($0.name) })
    }

    /// Ready-to-eat snacks aren't cooking ingredients, but the small on-device
    /// model can't tell that "Aloo Bhujia" is a snack and kept cooking with it.
    /// They're left out of the prompt instead.
    static let snackWords: Set<String> = [
        "biscuit", "biscuits", "cookie", "cookies", "oreo", "oreos", "chips", "crisps", "bhujia", "namkeen",
        "mixture", "chocolate", "chocolates", "candy", "candies", "popcorn", "pretzels", "crackers", "gummies",
        "cereal", "granola", "wafers", "rusk", "chakli", "sev", "soda", "juice",
    ]

    static func isSnack(_ name: String) -> Bool {
        ProductMatcher.tokens(name).contains { snackWords.contains($0) }
    }

    static func make(pantry: [PantryItem], preferences: RecipePreferences, avoid: [String]) -> String {
        // The on-device model has a small context window; the most urgent food is listed first.
        let lines = pantry.prefix(60).map(\.promptLine).joined(separator: "\n")
        var asks = ["Suggest 3 different dishes to cook from this inventory. Give each dish a different main ingredient."]
        // Named again here: in a long inventory the model otherwise tends to overlook them.
        let urgent = pantry.filter(\.isExpiringSoon).prefix(4).map(\.name)
        if !urgent.isEmpty { asks.append("Use these first because they expire soon: \(urgent.joined(separator: ", ")).") }
        if preferences.quick { asks.append("Each dish must take 20 minutes or less.") }
        if preferences.vegetarian { asks.append("All dishes must be vegetarian: no meat, chicken or fish.") }
        let note = preferences.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { asks.append("The household asked for: \(note.prefix(120))") }
        if !avoid.isEmpty { asks.append("Don't repeat these dishes: \(avoid.joined(separator: ", ")).") }
        return "Inventory:\n\(lines)\n\n" + asks.joined(separator: "\n")
    }
}

/// The model lists ingredients; the app, not the model, decides what's at home.
/// That way a suggestion never claims you have something you don't.
enum RecipeCheck {
    static let basics: Set<String> = [
        "salt", "water", "oil", "cooking oil", "vegetable oil", "olive oil", "pepper",
        "black pepper", "sugar", "ice", "spices", "salt and pepper",
    ]

    /// Turns the model's ideas into what the app shows. Ideas that use nothing
    /// from home are dropped, and so are ideas that break what the household asked
    /// for (meat when vegetarian, over 20 minutes when quick).
    @available(iOS 26.0, *)
    static func recipes(from ideas: [RecipeIdea], pantry: [String], preferences: RecipePreferences = .init()) -> [Recipe] {
        ideas
            .filter { !preferences.vegetarian || !containsMeat($0.ingredients + [$0.title]) }
            .filter { !preferences.quick || $0.minutes <= 20 }
            .map { idea in
            let checked = reconcile(idea.ingredients, pantry: pantry)
            return Recipe(title: idea.title, summary: idea.summary, minutes: idea.minutes,
                          have: checked.have, need: checked.need, steps: idea.steps)
        }
        .filter { !$0.have.isEmpty }
    }

    static let meatWords: Set<String> = [
        "chicken", "beef", "pork", "lamb", "mutton", "goat", "fish", "shrimp", "prawn", "bacon", "ham",
        "turkey", "sausage", "tuna", "salmon", "keema", "pepperoni", "anchovy", "crab", "meat",
    ]

    static func containsMeat(_ texts: [String]) -> Bool {
        texts.contains { text in
            ProductMatcher.tokens(text).contains { meatWords.contains($0) || meatWords.contains(String($0.dropLast())) }
        }
    }

    /// Splits a dish's ingredients into what's at home (by its inventory name) and what to buy.
    static func reconcile(_ ingredients: [String], pantry: [String]) -> (have: [String], need: [String]) {
        var have: [String] = []
        var need: [String] = []
        for ingredient in ingredients {
            let key = ProductMatcher.aliasKey(ingredient)
            guard !key.isEmpty, !basics.contains(key) else { continue }
            if let match = pantryMatch(for: ingredient, in: pantry) {
                if !have.contains(match) { have.append(match) }
            } else {
                let cleaned = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
                if !need.contains(where: { ProductMatcher.aliasKey($0) == key }) { need.append(cleaned.capitalizedFirst) }
            }
        }
        return (have, need)
    }

    /// The inventory name this ingredient refers to, if any.
    static func pantryMatch(for ingredient: String, in pantry: [String]) -> String? {
        let wanted = Set(ProductMatcher.tokens(ingredient).map(singular)).subtracting(descriptors)
        guard !wanted.isEmpty else { return nil }
        var best: (name: String, score: Double)?
        for name in pantry {
            let tokens = Set(ProductMatcher.tokens(name).map(singular)).subtracting(descriptors)
            guard !tokens.isEmpty else { continue }
            let shared = Double(wanted.intersection(tokens).count)
            // Most of the ingredient's words must appear in the product name:
            // "paneer" matches "Amul Paneer", "green chillies" doesn't match "Green tea".
            let score = shared / Double(wanted.count)
            if score >= 0.6, score > (best?.score ?? 0) { best = (name, score) }
        }
        return best?.name
    }

    /// Words that describe how food is sold or prepared, not what it is.
    private static let descriptors: Set<String> = [
        "frozen", "fresh", "dried", "dry", "chopped", "sliced", "diced", "minced", "grated", "organic",
        "large", "small", "whole", "ground", "cooked", "boiled", "canned", "raw", "ripe", "leftover",
    ]

    private static func singular(_ word: String) -> String {
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss") { return String(word.dropLast()) }
        return word
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
