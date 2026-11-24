import Foundation
import SwiftData

/// A place food is kept: pantry, freezer, garage shelf…
@Model
final class StorageLocation {
    var name: String = ""
    var symbol: String = "cabinet"
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var household: Household?

    @Relationship(deleteRule: .nullify, inverse: \StockLot.location)
    var lots: [StockLot]? = []

    @Relationship(deleteRule: .nullify, inverse: \InventoryEvent.location)
    var events: [InventoryEvent]? = []

    init(name: String, symbol: String = "cabinet", sortOrder: Int = 0) {
        self.name = name
        self.symbol = symbol
        self.sortOrder = sortOrder
    }

    var activeLots: [StockLot] {
        (lots ?? []).filter { $0.quantity > 0 }
    }

    var itemCount: Int {
        activeLots.reduce(0) { $0 + $1.quantity }
    }

    static let symbolChoices = [
        "cabinet", "tray.2", "refrigerator", "snowflake", "door.garage.closed",
        "basket", "archivebox", "shippingbox", "house", "carrot",
        "cup.and.saucer", "takeoutbag.and.cup.and.straw", "leaf", "stairs",
        "snowflake.circle", "washer",
    ]
}
