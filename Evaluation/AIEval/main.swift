import CoreGraphics
import Foundation
import FoundationModels
import ImageIO

// Runs Alcove's real AI code (prompts, settings and checks from Alcove/Services)
// against Apple's on-device model and prints a Markdown report.

let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "all"
let fixturePath = args.count > 2 ? args[2] : nil

func words(_ text: String) -> Set<String> {
    Set(ProductMatcher.tokens(text).map { word in
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss") { return String(word.dropLast()) }
        return word
    })
}

func cell(_ text: String) -> String { text.replacingOccurrences(of: "|", with: "/") }
func pct(_ n: Int, _ d: Int) -> String { d == 0 ? "–" : "\(n)/\(d) (\(Int((Double(n) / Double(d) * 100).rounded()))%)" }

// MARK: - Receipts

enum Outcome: String {
    case correct = "✅ correct", clear = "✅ already clear", wrong = "❌ wrong", kept = "↩︎ abbreviation left as is"
}

/// Judges the name a person would see: the tidied name, or the receipt's own text when there's none.
func outcome(_ name: String?, _ c: ReceiptCase) -> Outcome {
    guard let name else {
        return Set(c.mustContain).isSubset(of: words(c.line)) ? .clear : .kept
    }
    return Set(c.mustContain).isSubset(of: words(name)) ? .correct : .wrong
}

func evaluateReceipts() async throws {
    print("## Receipt names (`ReceiptAI`)\n")
    print("\(receiptCases.count) hand-labelled receipt lines. A name counts as correct when it contains every labelled word (for example *GRN BNS 2LB* must contain *green* and *bean*); a match to one of the household's items counts as correct when it's the right item. The **raw model** column is the model's own answer; the **app** column is what Alcove shows after its faithfulness check.\n")
    let lines = receiptCases.map(\.line)
    let start = Date()
    let raw = try await ReceiptAI.suggest(lines, householdItems: receiptHousehold)
    let seconds = Date().timeIntervalSince(start)
    let checked = ReceiptAI.apply(raw, originals: lines, householdItems: receiptHousehold)
    var rawByLine: [Int: String] = [:]
    for entry in raw where rawByLine[entry.line - 1] == nil { rawByLine[entry.line - 1] = entry.name }

    var rawCount: [Outcome: Int] = [:], appCount: [Outcome: Int] = [:]
    print("| Receipt line | Raw model | | Alcove shows | |")
    print("|---|---|---|---|---|")
    for (i, c) in receiptCases.enumerated() {
        let r = outcome(rawByLine[i], c)
        let shown = checked[i]?.name
        // A match to one of the household's items is right when it's the right item:
        // "GRK YGRT PLN" shown as your "Greek Yogurt" is correct even without "plain".
        let a: Outcome = checked[i]?.sameAs.map { words($0).isSubset(of: Set(c.mustContain)) ? .correct : .wrong } ?? outcome(shown, c)
        rawCount[r, default: 0] += 1
        appCount[a, default: 0] += 1
        print("| `\(c.line)` | \(cell(rawByLine[i] ?? "–")) | \(r == .correct ? "✅" : r == .wrong ? "❌" : "–") | \(cell(shown ?? c.line)) | \(a.rawValue) |")
    }
    let n = receiptCases.count
    let good = { (c: [Outcome: Int]) in (c[.correct] ?? 0) + (c[.clear] ?? 0) }
    print("\n| | Clear, correct name shown | Wrong name shown | Abbreviation left for the person to fix |")
    print("|---|---|---|---|")
    print("| Raw model (if trusted) | \(pct(good(rawCount), n)) | \(pct(rawCount[.wrong] ?? 0, n)) | \(pct(rawCount[.kept] ?? 0, n)) |")
    print("| Alcove (with check) | \(pct(good(appCount), n)) | \(pct(appCount[.wrong] ?? 0, n)) | \(pct(appCount[.kept] ?? 0, n)) |")
    print("| No AI (receipt text only) | \(pct(receiptCases.filter { outcome(nil, $0) == .clear }.count, n)) | 0/\(n) (0%) | \(pct(receiptCases.filter { outcome(nil, $0) == .kept }.count, n)) |")
    print("\nOne request for all \(n) lines took \(String(format: "%.1f", seconds)) s.\n")

    // Repeatability: temperature 0 should give the same names again.
    let again = ReceiptAI.apply(try await ReceiptAI.suggest(lines, householdItems: receiptHousehold),
                                originals: lines, householdItems: receiptHousehold)
    let same = (0..<n).filter { checked[$0]?.name == again[$0]?.name }.count
    print("**Repeat run:** \(pct(same, n)) of lines got the same result the second time.\n")
}

// MARK: - Full receipt pipeline on a photo

func evaluatePipeline() async throws {
    guard let fixturePath, let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: fixturePath) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        print("_Receipt photo not found._\n"); return
    }
    print("## Whole receipt: photo → text → items → names\n")
    print("`AlcoveTests/Fixtures/receipt.png`, run through the same steps as the app: Vision text recognition, `ReceiptParser`, then `ReceiptAI`.\n")
    let ocr = await ReceiptTextRecognizer.recognizeLines(in: ReceiptImages(images: [image]))
    let items = ReceiptParser.parse(lines: ocr)
    let names = items.map(\.name)
    let fixes = try await ReceiptAI.clean(names, householdItems: receiptHousehold)
    print("Text recognition found \(ocr.count) lines; the parser kept \(items.count) items and skipped totals, tax and payment lines.\n")
    print("| Parsed item | Qty | Alcove shows |")
    print("|---|---|---|")
    for (i, item) in items.enumerated() {
        let fix = fixes[i]
        let shown = fix.map { $0.sameAs.map { "\($0) (matched to your item)" } ?? $0.name } ?? "\(item.name) (unchanged)"
        print("| \(cell(item.name)) | \(item.quantity) | \(cell(shown)) |")
    }
    print("")
}

/// Prints every step for one receipt photo: the text rows, the items kept, and what Alcove shows.
func debugReceipt(household: [String]) async throws {
    guard let fixturePath, let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: fixturePath) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        print("Photo not found."); return
    }
    let ocr = await ReceiptTextRecognizer.recognizeLines(in: ReceiptImages(images: [image]))
    print("## Text rows\n")
    for row in ocr { print("- `\(row)` → \(ReceiptParser.parse(line: row).map { "item: \($0.name)" } ?? "skipped")") }
    let items = ReceiptParser.parse(lines: ocr)
    let products = household.map { name in let p = Product(); p.name = name; return p }
    print("\n## Items\n")
    for item in items {
        print("- \(item.name) ×\(item.quantity) — matched: \(ProductMatcher.bestMatch(for: item.name, in: products)?.name ?? "none")")
    }
    let start = Date()
    let raw = try await ReceiptAI.suggest(items.map(\.name), householdItems: household)
    let fixes = ReceiptAI.apply(raw, originals: items.map(\.name), householdItems: household)
    print("\n## Model (\(String(format: "%.1f", Date().timeIntervalSince(start))) s)\n")
    for r in raw { print("- line \(r.line): \(r.name) | sameAs: \(r.sameAs) → \(fixes[r.line - 1].map { "\($0.name)\($0.sameAs == nil ? "" : " (match)")" } ?? "rejected")") }
}

// MARK: - Meal ideas

struct RecipeRun {
    var recipes: [Recipe]
    var ingredients: [[String]]
    var minutes: [Int]
    var seconds: Double
    var titles: [String]
    var meatSuggested: Int
}

func runRecipes(_ pantry: [PantryItem], _ prefs: RecipePreferences) async throws -> RecipeRun {
    let usable = RecipeGeneratorPrompt.usable(pantry)
    let prompt = RecipeGeneratorPrompt.make(pantry: usable, preferences: prefs, avoid: [])
    let start = Date()
    let session = LanguageModelSession(instructions: RecipeGenerator.instructions)
    let result = try await session.respond(to: prompt, generating: RecipeIdeaList.self,
                                           options: GenerationOptions(temperature: RecipeGenerator.temperature))
    let ideas = result.content.ideas
    return RecipeRun(recipes: RecipeCheck.recipes(from: ideas, pantry: usable.map(\.name), preferences: prefs),
                     ingredients: ideas.map(\.ingredients), minutes: ideas.map(\.minutes),
                     seconds: Date().timeIntervalSince(start),
                     titles: ideas.map(\.title),
                     meatSuggested: ideas.filter { idea in (idea.ingredients + [idea.title]).contains { !meatWords.isDisjoint(with: words($0)) } }.count)
}

struct Tally {
    var runs = 0, failures = 0, shown = 0, usedExpiring = 0, expiredFromHome = 0
    var snackDishes = 0, meatDishes = 0, slowDishes = 0, seconds: [Double] = []
    var hasExpiring = true
    var meatSuggested = 0
    var slowSuggested = 0
}

func evaluateScenario(_ title: String, _ pantry: [PantryItem], _ prefs: RecipePreferences = .init(), runs: Int, showDishes: Bool = true) async -> Tally {
    var t = Tally()
    let expiring = Set(pantry.filter(\.isExpiringSoon).map(\.name))
    t.hasExpiring = !expiring.isEmpty
    let expired = Set(pantry.filter { ($0.daysToExpiry ?? 0) < 0 }.map(\.name))
    var dishes: [String] = []
    for _ in 0..<runs {
        t.runs += 1
        do {
            let run = try await runRecipes(pantry, prefs)
            t.seconds.append(run.seconds)
            t.shown += run.recipes.count
            if run.recipes.contains(where: { !expiring.isDisjoint(with: $0.have) }) { t.usedExpiring += 1 }
            t.expiredFromHome += run.recipes.filter { !expired.isDisjoint(with: $0.have) }.count
            t.snackDishes += run.recipes.filter { !snackNames.isDisjoint(with: $0.have) }.count
            t.meatDishes += run.recipes.filter { r in (r.have + r.need).contains { !meatWords.isDisjoint(with: words($0)) } }.count
            t.slowDishes += run.recipes.filter { $0.minutes > 20 }.count
            t.slowSuggested += run.minutes.filter { $0 > 20 }.count
            t.meatSuggested += run.meatSuggested
            dishes += run.recipes.map { r in
                let listed = run.ingredients[run.titles.firstIndex(of: r.title) ?? 0]
                return "\(r.title) (\(r.minutes) min): from home \(r.have.joined(separator: ", "))"
                    + (r.need.isEmpty ? "" : "; to buy \(r.need.joined(separator: ", "))")
                    + " — model listed: \(listed.joined(separator: ", "))"
            }
        } catch {
            t.failures += 1
            dishes.append("⚠️ request failed: \(error)")
        }
    }
    print("### \(title)\n")
    if showDishes {
        print("<details><summary>All \(dishes.count) dishes</summary>\n")
        for d in dishes { print("- \(cell(d))") }
        print("\n</details>\n")
    }
    return t
}

func evaluateRecipes() async {
    print("## Meal ideas (`RecipeGenerator`)\n")
    print("Each run asks for 3 dishes with the app's real instructions, prompt and temperature (\(RecipeGenerator.temperature)), then applies the app's ingredient check. Expiring = good for 3 days or less.\n")
    var rows: [(String, Tally)] = []
    rows.append(("Sample family pantry (15 items, paneer expiring, yogurt expired)", await evaluateScenario("Sample family pantry", indianPantry, runs: 20)))
    rows.append(("Different household (12 items, spinach/eggs/milk expiring)", await evaluateScenario("Different household", westernPantry, runs: 5)))
    var veg = RecipePreferences(); veg.vegetarian = true
    rows.append(("Vegetarian request, chicken at home", await evaluateScenario("Vegetarian request with chicken in the freezer", westernPantry, veg, runs: 5)))
    var quick = RecipePreferences(); quick.quick = true
    rows.append(("Under 20 minutes request", await evaluateScenario("Under 20 minutes", indianPantry, quick, runs: 5)))
    rows.append(("Large pantry (81 items, expiring item sorts last A–Z)", await evaluateScenario("Large pantry", largePantry, runs: 5)))
    rows.append(("Sparse pantry (3 items)", await evaluateScenario("Sparse pantry", sparsePantry, runs: 3)))

    print("### Summary\n")
    print("| Scenario | Runs | Failed | Dishes shown | Runs using expiring food | Expired food shown as \"from home\" | Snack used as an ingredient | Meat dishes (model → shown) | Over 20 min (model → shown) | Avg time |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for (name, t) in rows {
        let avg = t.seconds.isEmpty ? 0 : t.seconds.reduce(0, +) / Double(t.seconds.count)
        print("| \(name) | \(t.runs) | \(t.failures) | \(t.shown) | \(t.hasExpiring ? "\(t.usedExpiring)/\(t.runs - t.failures)" : "n/a (none expiring)") | \(t.expiredFromHome) | \(t.snackDishes) | \(t.meatSuggested) → \(t.meatDishes) | \(t.slowSuggested) → \(t.slowDishes) | \(String(format: "%.1f", avg)) s |")
    }
    print("")
}

// MARK: - Earlier design, for comparison

@Generable
struct OriginalRecipeIdea {
    var title: String
    var summary: String
    @Guide(.range(5...120)) var minutes: Int
    @Guide(description: "Main ingredients taken from the inventory, written exactly as they appear in the inventory", .maximumCount(8))
    var fromHome: [String]
    @Guide(description: "Ingredients that are not in the inventory and must be bought. Leave out salt, oil, water and common spices", .maximumCount(4))
    var toBuy: [String]
    @Guide(.count(3...7)) var steps: [String]
}

@Generable
struct OriginalRecipeList {
    @Guide(.count(3)) var ideas: [OriginalRecipeIdea]
}

/// The first version: the model itself said what was "from home", expired food
/// was listed (marked expired), and the temperature was 0.7.
func evaluateOriginalDesign() async {
    print("## Comparison: first design vs. shipped design\n")
    let instructions = """
        You suggest home-cooked meals using food a household already has.
        Build each dish around items from the inventory, and use items that expire soon first.
        Only put an ingredient in fromHome if it is in the inventory.
        The kitchen already has salt, cooking oil, water and common spices.
        Suggest realistic dishes that a home cook can make, with simple steps.
        """
    let lines = PantryItem.urgentFirst(indianPantry).map { item -> String in
        var parts = ["\(item.quantity)"]
        if let d = item.daysToExpiry { if d < 0 { parts.append("expired") } else if d <= 7 { parts.append("expires in \(d) days") } }
        if let l = item.location { parts.append(l) }
        return "- \(item.name) (\(parts.joined(separator: ", ")))"
    }.joined(separator: "\n")
    let prompt = "Inventory:\n\(lines)\n\nSuggest 3 different dishes to cook from this inventory."
    let pantryNames = indianPantry.map(\.name)
    var t = Tally(), falseHave = 0, claimed = 0
    for _ in 0..<20 {
        t.runs += 1
        do {
            let session = LanguageModelSession(instructions: instructions)
            let r = try await session.respond(to: prompt, generating: OriginalRecipeList.self, options: GenerationOptions(temperature: 0.7))
            for idea in r.content.ideas {
                t.shown += 1
                let have = idea.fromHome.compactMap { RecipeCheck.pantryMatch(for: $0, in: pantryNames) }
                claimed += idea.fromHome.count
                falseHave += idea.fromHome.count - have.count
                if have.contains("Greek Yogurt") { t.expiredFromHome += 1 }
                if !snackNames.isDisjoint(with: have) { t.snackDishes += 1 }
            }
        } catch { t.failures += 1 }
    }
    print("20 runs each on the sample family pantry.\n")
    print("| Design | Dishes | Uses expired yogurt | Snack used as an ingredient | \"From home\" items that aren't at home |")
    print("|---|---|---|---|---|")
    print("| First: model decides what's at home, expired food listed, temperature 0.7 | \(t.shown) | \(t.expiredFromHome) | \(t.snackDishes) | \(falseHave) of \(claimed) |")
    var s = Tally()
    for _ in 0..<20 {
        s.runs += 1
        if let run = try? await runRecipes(indianPantry, .init()) {
            s.shown += run.recipes.count
            s.expiredFromHome += run.recipes.filter { $0.have.contains("Greek Yogurt") }.count
            s.snackDishes += run.recipes.filter { !snackNames.isDisjoint(with: $0.have) }.count
        } else { s.failures += 1 }
    }
    print("| Shipped: app decides what's at home, expired food left out, tuned instructions, temperature \(RecipeGenerator.temperature) | \(s.shown) | \(s.expiredFromHome) | \(s.snackDishes) | 0 (by design) |")
    print("")
}

// MARK: - Main

print("# Alcove AI evaluation\n")
print("Generated \(Date().formatted(date: .abbreviated, time: .shortened)) on a Mac running Apple's on-device model (\(SystemLanguageModel.default.availability == .available ? "available" : "unavailable")). The iPhone uses the same Foundation Models framework; speeds on a phone will differ.\n")
do {
    if mode == "all" || mode == "receipts" { try await evaluateReceipts() }
    if mode == "all" || mode == "pipeline" { try await evaluatePipeline() }
    if mode == "all" || mode == "recipes" { await evaluateRecipes() }
    if mode == "all" || mode == "compare" { await evaluateOriginalDesign() }
    if mode == "debug" { try await debugReceipt(household: sampleHousehold) }
} catch {
    print("Evaluation stopped: \(error)")
}
