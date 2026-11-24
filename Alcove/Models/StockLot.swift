import Foundation
import SwiftData

/// A batch of one product in one storage spot, optionally with an expiry date.
/// Scanning the same product into the same spot (same expiry) bumps the count
/// instead of creating a new lot.
@Model
final class StockLot {
    var quantity: Int = 0
    var expirationDate: Date?
    var addedAt: Date = Date()
    var product: Product?
    var location: StorageLocation?

    init(quantity: Int, expirationDate: Date? = nil) {
        self.quantity = quantity
        self.expirationDate = expirationDate
    }
}
