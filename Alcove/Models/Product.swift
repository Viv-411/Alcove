import Foundation
import SwiftData

/// Something the household buys: "Aashirvaad Atta 10kg", "Toor Dal 2lb".
/// Stock is held in `StockLot`s (one per storage spot + expiry date).
///
/// All properties have defaults and relationships are optional so the schema
/// stays compatible with CloudKit sync when shared households arrive.
@Model
final class Product {
    var barcode: String?
    var name: String = ""
    var brand: String?
    var packageSize: String?
    var imageURL: String?
    /// Alert when the total count drops to this number or below. 0 turns alerts off.
    var lowStockThreshold: Int = 1
    /// Normalized receipt line names that map to this product, learned when the
    /// user confirms a receipt import.
    var receiptAliases: [String] = []
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \StockLot.product)
    var lots: [StockLot]? = []

    @Relationship(deleteRule: .cascade, inverse: \InventoryEvent.product)
    var events: [InventoryEvent]? = []

    init(
        name: String,
        barcode: String? = nil,
        brand: String? = nil,
        packageSize: String? = nil,
        imageURL: String? = nil,
        lowStockThreshold: Int = 1
    ) {
        self.name = name
        self.barcode = barcode
        self.brand = brand
        self.packageSize = packageSize
        self.imageURL = imageURL
        self.lowStockThreshold = lowStockThreshold
    }

    var activeLots: [StockLot] {
        (lots ?? []).filter { $0.quantity > 0 }
    }

    var totalQuantity: Int {
        activeLots.reduce(0) { $0 + $1.quantity }
    }

    func quantity(in location: StorageLocation) -> Int {
        activeLots.filter { $0.location === location }.reduce(0) { $0 + $1.quantity }
    }

    var isOutOfStock: Bool { totalQuantity == 0 }

    var isLowStock: Bool {
        lowStockThreshold > 0 && totalQuantity <= lowStockThreshold
    }

    var nextExpiration: Date? {
        activeLots.compactMap(\.expirationDate).min()
    }

    /// The storage spot holding the most of this product.
    var primaryLocation: StorageLocation? {
        var totals: [PersistentIdentifier: (location: StorageLocation, count: Int)] = [:]
        for lot in activeLots {
            guard let location = lot.location else { continue }
            let id = location.persistentModelID
            totals[id] = (location, (totals[id]?.count ?? 0) + lot.quantity)
        }
        return totals.values.max { $0.count < $1.count }?.location
    }

    /// "Pantry 3 · Garage 2"
    var locationSummary: String {
        var totals: [String: Int] = [:]
        for lot in activeLots {
            totals[lot.location?.name ?? "Unsorted", default: 0] += lot.quantity
        }
        let ordered = totals.sorted { a, b in
            a.value == b.value ? a.key < b.key : a.value > b.value
        }
        return ordered.map { "\($0.key) \($0.value)" }.joined(separator: " · ")
    }

    var subtitle: String? {
        let parts = [brand, packageSize].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
