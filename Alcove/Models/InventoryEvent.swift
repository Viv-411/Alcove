import Foundation
import SwiftData

enum EventKind: String, Codable {
    /// Stock came in (scan in, receipt, manual add).
    case added
    /// Stock was consumed. These drive usage forecasts.
    case used
    /// A manual correction (editing a count, throwing something out).
    case adjusted
}

enum EventSource: String, Codable {
    case scan, receipt, manual
}

/// An append-only log of stock changes. Used for history and to learn how
/// fast the household goes through each product.
@Model
final class InventoryEvent {
    var kindRaw: String = EventKind.added.rawValue
    var sourceRaw: String = EventSource.manual.rawValue
    /// Positive count for `.added` / `.used`; signed delta for `.adjusted`.
    var quantity: Int = 0
    var date: Date = Date()
    var expirationDate: Date?
    var product: Product?
    var location: StorageLocation?

    init(kind: EventKind, source: EventSource, quantity: Int, expirationDate: Date? = nil) {
        self.kindRaw = kind.rawValue
        self.sourceRaw = source.rawValue
        self.quantity = quantity
        self.expirationDate = expirationDate
    }

    var kind: EventKind {
        get { EventKind(rawValue: kindRaw) ?? .adjusted }
        set { kindRaw = newValue.rawValue }
    }

    var source: EventSource {
        get { EventSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var summary: String {
        switch kind {
        case .added: "Added \(quantity)"
        case .used: "Used \(quantity)"
        case .adjusted: quantity >= 0 ? "Adjusted +\(quantity)" : "Adjusted \(quantity)"
        }
    }
}
