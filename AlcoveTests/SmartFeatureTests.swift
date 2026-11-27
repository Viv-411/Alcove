import Foundation
import SwiftData
import Testing
@testable import Alcove

struct RecipeCheckTests {
    let pantry = ["Amul Paneer", "Baby Spinach", "Sona Masoori Rice", "Tomatoes", "Toor Dal"]

    @Test func keepsRealIngredientsUnderTheirInventoryNames() {
        let result = RecipeCheck.reconcile(["paneer", "spinach", "tomato"], pantry: pantry)
        #expect(result.have == ["Amul Paneer", "Baby Spinach", "Tomatoes"])
        #expect(result.need.isEmpty)
    }

    @Test func movesMadeUpIngredientsToTheShoppingList() {
        let result = RecipeCheck.reconcile(["Paneer", "Heavy cream"], pantry: pantry)
        #expect(result.have == ["Amul Paneer"])
        #expect(result.need == ["Heavy cream"])
    }

    @Test func doesNotTellYouToBuyWhatYouHave() {
        let result = RecipeCheck.reconcile(["Toor dal", "rice", "Ginger"], pantry: pantry)
        #expect(result.have == ["Toor Dal", "Sona Masoori Rice"])
        #expect(result.need == ["Ginger"])
    }

    @Test func ignoresKitchenBasicsAndDuplicates() {
        let result = RecipeCheck.reconcile(["Salt", "oil", "Paneer", "paneer", "Water", "ginger", "Ginger"], pantry: pantry)
        #expect(result.have == ["Amul Paneer"])
        #expect(result.need == ["Ginger"])
    }

    @Test func spotsMeatForVegetarians() {
        #expect(RecipeCheck.containsMeat(["Chicken breast", "Spinach"]))
        #expect(RecipeCheck.containsMeat(["Keema Matar"]))
        #expect(!RecipeCheck.containsMeat(["Paneer", "Green Peas", "Eggs"]))
    }

    @Test func needsMostWordsToMatch() {
        #expect(RecipeCheck.pantryMatch(for: "green chillies", in: ["Green Tea"]) == nil)
        #expect(RecipeCheck.pantryMatch(for: "tomatoes", in: ["Tomato"]) == "Tomato")
        #expect(RecipeCheck.pantryMatch(for: "Frozen peas", in: ["Green Peas"]) == "Green Peas")
    }
}

struct ReceiptAITests {
    let household = ["Paneer", "Toor Dal", "Aloo Bhujia"]

    @Test func acceptsFaithfulExpansionsOnly() {
        let originals = ["Grn Bns 2lb", "Amul Pnr 200g", "Chkn Thgh Bnls", "Lg Brn Eggs 18ct", "Haldiram Aloo Bhj"]
        let fixes = ReceiptAI.apply(
            [
                (1, "Green Beans 2lb", ""),
                (2, "Amul Butter 200g", ""),            // pnr isn't butter
                (3, "Chicken Thighs with Beans", ""),   // bnls isn't beans
                (4, "Large Brown Eggs 18 Count", ""),
                (5, "Haldiram's Aloo Bhujia", "aloo bhujia"),
                (9, "Ghost Item", ""),                  // no line 9
                (1, "Duplicate", ""),                   // line 1 already handled
            ],
            originals: originals,
            householdItems: household
        )
        #expect(fixes[0] == .init(name: "Green Beans 2lb", sameAs: nil))
        #expect(fixes[1] == nil)
        #expect(fixes[2] == nil)
        #expect(fixes[3] == .init(name: "Large Brown Eggs 18 Count", sameAs: nil))
        #expect(fixes[4] == .init(name: "Aloo Bhujia", sameAs: "Aloo Bhujia"))
        #expect(fixes.count == 3)
    }

    @Test func matchesNeedARealConnection() {
        // The model claims "Org Bananas" is the household's Toor Dal: ignored, but the tidy name is kept.
        let fixes = ReceiptAI.apply([(1, "Organic Bananas", "Toor Dal")], originals: ["Org Bananas"], householdItems: household)
        #expect(fixes[0] == .init(name: "Organic Bananas", sameAs: nil))
        let paneer = ReceiptAI.apply([(1, "Amul Paneer", "Paneer")], originals: ["Amul Pnr 200g"], householdItems: household)
        #expect(paneer[0] == .init(name: "Paneer", sameAs: "Paneer"))
    }

    @Test func abbreviations() {
        #expect(ReceiptAI.abbreviates("pnr", "paneer"))
        #expect(ReceiptAI.abbreviates("bnls", "boneless"))
        #expect(!ReceiptAI.abbreviates("pnr", "butter"))
        #expect(!ReceiptAI.abbreviates("bnls", "beans"))
        #expect(!ReceiptAI.isFaithful("Kirkland Extra Virgin Olive Oil 2L", to: "Kirk Olv Oil 2l"))
        #expect(ReceiptAI.isFaithful("Kirkland Olive Oil 2 Liters", to: "Kirk Olv Oil 2l"))
        #expect(ReceiptAI.isFaithful("Roma Tomatoes", to: "Tom Roma"))
        // Found by the evaluation: a lone letter used to match any word.
        #expect(!ReceiptAI.isFaithful("Parle Granola 800g", to: "Parle G 800g"))
    }

    @Test func tidiesShoutingAndSkipsNoOps() {
        let fixes = ReceiptAI.apply([(1, "MAGGI NOODLES 12 PK", ""), (2, "GREEN BEANS", "")],
                                    originals: ["Maggi Noodles 12pk", "Grn Bns"], householdItems: [])
        #expect(fixes[0] == nil)
        #expect(fixes[1] == .init(name: "Green Beans", sameAs: nil))
    }
}

@MainActor
struct ShoppingPlannerTests {
    let container: ModelContainer
    let context: ModelContext
    let service: InventoryService

    init() throws {
        container = try AlcoveSchema.container(inMemory: true)
        context = container.mainContext
        service = InventoryService(context: context)
    }

    private func logUses(_ product: Product, daysAgo: [Int]) {
        for days in daysAgo {
            let event = InventoryEvent(kind: .used, source: .scan, quantity: 1)
            context.insert(event)
            event.product = product
            event.date = Date().adding(days: -days)
        }
    }

    @Test func lowStockIsBuyNowAndAmountsLastTwoWeeks() {
        let milk = service.createProduct(name: "Milk", lowStockThreshold: 1)
        service.add(milk, quantity: 1, to: nil, source: .scan)
        logUses(milk, daysAgo: [10, 8, 6, 4, 2]) // 1 every 2 days → 7 for 2 weeks

        let plan = ShoppingPlanner.plan(for: [milk])
        let item = try! #require(plan.first)
        #expect(item.urgency == .now)
        #expect(item.buy == 6)
        #expect(item.reason.hasSuffix("· buy 6"))
    }

    @Test func forecastPutsItOnThisWeek() {
        let rice = service.createProduct(name: "Rice", lowStockThreshold: 1)
        service.add(rice, quantity: 3, to: nil, source: .scan)
        logUses(rice, daysAgo: [12, 9, 6, 3]) // 1 every 3 days → 3 left lasts ~9 days

        let soon = service.createProduct(name: "Atta", lowStockThreshold: 1)
        service.add(soon, quantity: 2, to: nil, source: .scan)
        logUses(soon, daysAgo: [8, 6, 4, 2]) // 1 every 2 days → 2 left lasts ~4 days

        let plan = ShoppingPlanner.plan(for: [rice, soon])
        #expect(plan.map(\.product.name) == ["Atta"])
        #expect(plan.first?.urgency == .thisWeek)
    }

    @Test func noHistoryJustRefillsAboveTheLowLine() {
        let ghee = service.createProduct(name: "Ghee", lowStockThreshold: 2)
        service.add(ghee, quantity: 1, to: nil, source: .scan)
        let item = try! #require(ShoppingPlanner.plan(for: [ghee]).first)
        #expect(item.buy == 2)
        #expect(item.reason == "Last one · buy 2")

        let out = service.createProduct(name: "Salt", lowStockThreshold: 1)
        #expect(ShoppingPlanner.plan(for: [out]).first?.reason == "Out · buy 2")
    }
}

struct RecipePromptTests {
    @Test func leavesOutExpiredFoodAndSnacks() {
        let items = [
            PantryItem(name: "Aloo Bhujia", quantity: 1, daysToExpiry: 5, location: nil),
            PantryItem(name: "Parle-G Biscuits", quantity: 2, daysToExpiry: nil, location: nil),
            PantryItem(name: "Greek Yogurt", quantity: 1, daysToExpiry: -1, location: nil),
            PantryItem(name: "Toor Dal", quantity: 1, daysToExpiry: nil, location: nil),
            PantryItem(name: "Paneer", quantity: 1, daysToExpiry: 2, location: nil),
        ]
        #expect(RecipeGeneratorPrompt.usable(items).map(\.name) == ["Paneer", "Toor Dal"])
    }

    @Test func listsExpiringFoodFirstAndIncludesPreferences() {
        let items = [
            PantryItem(name: "Rice", quantity: 2, daysToExpiry: nil, location: "Pantry"),
            PantryItem(name: "Paneer", quantity: 1, daysToExpiry: 1, location: "Fridge"),
        ]
        var prefs = RecipePreferences()
        prefs.vegetarian = true
        prefs.note = "something spicy"
        let prompt = RecipeGeneratorPrompt.make(pantry: items, preferences: prefs, avoid: ["Dal tadka"])
        #expect(prompt.contains("- Rice (2, Pantry)"))
        #expect(prompt.contains("- Paneer (1, expires in 1 day, Fridge)"))
        #expect(prompt.contains("Use these first because they expire soon: Paneer."))
        #expect(prompt.contains("vegetarian"))
        #expect(prompt.contains("something spicy"))
        #expect(prompt.contains("Don't repeat these dishes: Dal tadka."))
    }
}
