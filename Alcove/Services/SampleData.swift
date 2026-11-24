#if DEBUG
import Foundation
import SwiftData

/// Launch flags used by UI tests and for poking around in the Simulator.
/// Compiled out of release builds.
enum DebugLaunch {
    static var arguments: [String] { ProcessInfo.processInfo.arguments }
    /// Fresh in-memory database, no notification permission prompt.
    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    /// Fill the house with a realistic set of groceries.
    static var wantsSampleData: Bool { arguments.contains("-sampleData") }
    /// Path to a receipt photo to load straight into the receipt importer.
    static var receiptFixturePath: String? {
        guard let index = arguments.firstIndex(of: "-receiptFixture"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
    /// Start like a brand-new install: intro tour, sign-in, home setup.
    static var isFreshInstall: Bool { arguments.contains("-freshInstall") }

    /// UI tests skip straight into a set-up home unless they ask for a fresh install.
    static func prepare(_ context: ModelContext) {
        guard isUITesting else { return }
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "auth.guestProfile")
        if isFreshInstall {
            defaults.set(false, forKey: "intro.seen")
            return
        }
        defaults.set(true, forKey: "intro.seen")
        let owner = UserProfile(id: "guest-ui-test", name: "Priya Sharma", email: "priya@example.com", isGuest: true)
        if let data = try? JSONEncoder().encode(owner) { defaults.set(data, forKey: "auth.guestProfile") }
        let spaces = SpaceSuggestion.defaults.map { SpaceDraft(name: $0, symbol: SpaceSuggestion.symbol(for: $0)) }
        HouseholdService(context: context).setUp(name: "Sharma Home", spaces: spaces, owner: owner)
        if wantsSampleData { SampleData.populate(context) }
    }
}

/// A believable household: bulk staples, snacks, freezer food, some usage history.
enum SampleData {
    static let knownBarcode = "8901063010017"

    static func populate(_ context: ModelContext) {
        let locations = (try? context.fetch(FetchDescriptor<StorageLocation>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        func spot(_ name: String) -> StorageLocation? { locations.first { $0.name == name } }
        let now = Date()

        struct Item {
            var name: String
            var brand: String?
            var size: String?
            var barcode: String?
            var threshold = 1
            var stock: [(String, Int, Int?)] // location, quantity, expires in days
            var usedEveryDays: Double? = nil
        }

        let items: [Item] = [
            Item(name: "Whole Wheat Atta", brand: "Aashirvaad", size: "20 lb", barcode: "8901725181222",
                 stock: [("Garage", 2, 160), ("Pantry", 1, 120)], usedEveryDays: 12),
            Item(name: "Toor Dal", brand: "Laxmi", size: "4 lb", barcode: "0011433121019",
                 stock: [("Pantry", 1, 200)], usedEveryDays: 9),
            Item(name: "Sona Masoori Rice", brand: "Deer", size: "20 lb", barcode: "0071334003207", threshold: 1,
                 stock: [("Garage", 1, 300), ("Pantry", 1, nil)], usedEveryDays: 20),
            Item(name: "Basmati Rice", brand: "Royal", size: "10 lb", stock: [("Pantry", 2, nil)]),
            Item(name: "Parle-G Biscuits", brand: "Parle", size: "800 g", barcode: knownBarcode, threshold: 2,
                 stock: [("Kitchen cabinets", 2, 45)], usedEveryDays: 3),
            Item(name: "Aloo Bhujia", brand: "Haldiram's", size: "400 g", threshold: 1,
                 stock: [("Kitchen cabinets", 1, 5)], usedEveryDays: 4),
            Item(name: "Moong Dal", brand: "Swad", size: "2 lb", stock: [("Pantry", 3, 240)]),
            Item(name: "Frozen Parathas", brand: "Haldiram's", size: "5 pack", threshold: 1,
                 stock: [("Freezer", 4, 90)], usedEveryDays: 5),
            Item(name: "Green Peas", brand: "Deep", size: "2 lb", stock: [("Freezer", 2, 200)]),
            Item(name: "Paneer", brand: "Nanak", size: "14 oz", threshold: 1,
                 stock: [("Fridge", 1, 2)], usedEveryDays: 6),
            Item(name: "Greek Yogurt", brand: "Chobani", size: "32 oz", stock: [("Fridge", 1, -1)]),
            Item(name: "Ghee", brand: "Amul", size: "1 L", stock: [("Pantry", 1, 180)]),
            Item(name: "Chana Masala", brand: "MDH", size: "100 g", threshold: 0, stock: [("Kitchen cabinets", 2, 400)]),
            Item(name: "Peanut Butter", brand: "Jif", size: "40 oz", stock: [], usedEveryDays: 14),
            Item(name: "Olive Oil", brand: "Kirkland", size: "2 L", stock: [("Pantry", 1, 300)]),
            Item(name: "Instant Noodles", brand: "Maggi", size: "12 pack", threshold: 2,
                 stock: [("Kitchen cabinets", 1, 150), ("Garage", 1, 150)], usedEveryDays: 2.5),
        ]

        for item in items {
            let product = Product(name: item.name, barcode: item.barcode, brand: item.brand,
                                  packageSize: item.size, lowStockThreshold: item.threshold)
            context.insert(product)
            product.createdAt = now.adding(days: -60)

            for (spotName, quantity, expiresIn) in item.stock {
                let lot = StockLot(quantity: quantity, expirationDate: expiresIn.map { now.adding(days: $0).startOfDay })
                context.insert(lot)
                lot.product = product
                lot.location = spot(spotName)
                lot.addedAt = now.adding(days: -20)
            }

            // Usage history so the restock forecasts have something to learn from.
            if let every = item.usedEveryDays {
                var daysAgo = 50.0
                while daysAgo > 0.5 {
                    let event = InventoryEvent(kind: .used, source: .scan, quantity: 1)
                    context.insert(event)
                    event.product = product
                    event.date = now.addingTimeInterval(-daysAgo * 86_400)
                    daysAgo -= every
                }
            }
            let added = InventoryEvent(kind: .added, source: .receipt, quantity: max(1, item.stock.reduce(0) { $0 + $1.1 }))
            context.insert(added)
            added.product = product
            added.date = now.adding(days: -20)
        }
        try? context.save()
    }
}
#endif
