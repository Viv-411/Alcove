import Foundation
import SwiftData

/// All stock changes go through here so counts, the event log and
/// notifications stay consistent.
struct InventoryService {
    let context: ModelContext

    // MARK: - Lookup

    func product(forBarcode raw: String) -> Product? {
        let code: String? = Barcode.normalize(raw)
        var descriptor = FetchDescriptor<Product>(predicate: #Predicate { $0.barcode == code })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func createProduct(
        name: String,
        barcode: String? = nil,
        brand: String? = nil,
        packageSize: String? = nil,
        imageURL: String? = nil,
        lowStockThreshold: Int = 1
    ) -> Product {
        let product = Product(
            name: name,
            barcode: barcode.map(Barcode.normalize),
            brand: brand,
            packageSize: packageSize,
            imageURL: imageURL,
            lowStockThreshold: lowStockThreshold
        )
        context.insert(product)
        return product
    }

    // MARK: - Logged operations

    @discardableResult
    func add(
        _ product: Product,
        quantity: Int,
        to location: StorageLocation?,
        expiration: Date? = nil,
        source: EventSource
    ) -> InventoryEvent? {
        guard quantity > 0 else { return nil }
        addStock(product, quantity: quantity, to: location, expiration: expiration)
        let event = log(.added, product: product, quantity: quantity, location: location,
                        expiration: expiration, source: source)
        commit()
        return event
    }

    /// Consumes stock, soonest-expiring first. Returns nil if there was nothing to take.
    @discardableResult
    func use(
        _ product: Product,
        quantity: Int = 1,
        preferring location: StorageLocation? = nil,
        source: EventSource
    ) -> InventoryEvent? {
        let wasLow = product.isLowStock
        let result = removeStock(product, quantity: quantity, preferring: location)
        guard result.removed > 0 else { return nil }
        let event = log(.used, product: product, quantity: result.removed,
                        location: result.firstLocation ?? location, expiration: nil, source: source)
        commit()
        if !wasLow && product.isLowStock {
            NotificationScheduler.shared.notifyLowStock(product)
        }
        return event
    }

    /// Changes the quantity recorded by an `.added` or `.used` event and moves
    /// stock to match. Used for the +/− buttons and undo on the scan screen.
    /// Returns false if the event dropped to zero and was removed.
    @discardableResult
    func amend(_ event: InventoryEvent, by delta: Int) -> Bool {
        guard delta != 0, let product = event.product else { return event.quantity > 0 }
        let wasLow = product.isLowStock

        switch event.kind {
        case .added:
            if delta > 0 {
                addStock(product, quantity: delta, to: event.location, expiration: event.expirationDate)
                event.quantity += delta
            } else {
                // If some of this stock was already used elsewhere, removeStock takes
                // what's left; the undo still shrinks the event by the full amount.
                let amount = min(-delta, event.quantity)
                _ = removeStock(product, quantity: amount, preferring: event.location,
                                expiration: event.expirationDate)
                event.quantity -= amount
            }
        case .used:
            if delta > 0 {
                let result = removeStock(product, quantity: delta, preferring: event.location)
                event.quantity += result.removed
            } else {
                let amount = min(-delta, event.quantity)
                addStock(product, quantity: amount, to: event.location, expiration: nil)
                event.quantity -= amount
            }
        case .adjusted:
            return true
        }

        let alive = event.quantity > 0
        if !alive { context.delete(event) }
        commit()
        if !wasLow && product.isLowStock {
            NotificationScheduler.shared.notifyLowStock(product)
        }
        return alive
    }

    func revert(_ event: InventoryEvent) {
        amend(event, by: -event.quantity)
    }

    /// Direct edit of a lot from the product screen.
    func update(_ lot: StockLot, quantity: Int, location: StorageLocation?, expiration: Date?) {
        guard let product = lot.product else { return }
        let newQuantity = max(0, quantity)
        let delta = newQuantity - lot.quantity
        lot.location = location
        lot.expirationDate = expiration?.startOfDay
        lot.quantity = newQuantity
        if delta != 0 {
            log(.adjusted, product: product, quantity: delta, location: location,
                expiration: expiration, source: .manual)
        }
        if newQuantity == 0 { context.delete(lot) }
        commit()
    }

    func delete(_ product: Product) {
        context.delete(product)
        commit()
    }

    func commit() {
        try? context.save()
        NotificationScheduler.shared.refresh(context: context)
    }

    // MARK: - Stock primitives (no logging)

    private func addStock(_ product: Product, quantity: Int, to location: StorageLocation?, expiration: Date?) {
        let day = expiration?.startOfDay
        if let lot = (product.lots ?? []).first(where: {
            $0.quantity > 0 && $0.location === location && $0.expirationDate == day
        }) {
            lot.quantity += quantity
            return
        }
        let lot = StockLot(quantity: quantity, expirationDate: day)
        context.insert(lot)
        lot.product = product
        lot.location = location
    }

    private func removeStock(
        _ product: Product,
        quantity: Int,
        preferring location: StorageLocation?,
        expiration: Date? = nil
    ) -> (removed: Int, firstLocation: StorageLocation?) {
        let day = expiration?.startOfDay
        func rank(_ lot: StockLot) -> Int {
            guard let location, lot.location === location else { return 2 }
            return lot.expirationDate == day ? 0 : 1
        }
        let ordered = product.activeLots.sorted { a, b in
            let ra = rank(a), rb = rank(b)
            if ra != rb { return ra < rb }
            switch (a.expirationDate, b.expirationDate) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.addedAt < b.addedAt
            }
        }

        var remaining = quantity
        var firstLocation: StorageLocation?
        for lot in ordered where remaining > 0 {
            let take = min(lot.quantity, remaining)
            if firstLocation == nil { firstLocation = lot.location }
            lot.quantity -= take
            remaining -= take
            if lot.quantity == 0 { context.delete(lot) }
        }
        return (quantity - remaining, firstLocation)
    }

    @discardableResult
    private func log(
        _ kind: EventKind,
        product: Product,
        quantity: Int,
        location: StorageLocation?,
        expiration: Date?,
        source: EventSource
    ) -> InventoryEvent {
        let event = InventoryEvent(kind: kind, source: source, quantity: quantity,
                                   expirationDate: expiration?.startOfDay)
        context.insert(event)
        event.product = product
        event.location = location
        return event
    }
}

enum Barcode {
    /// Treat UPC-A (12 digits) and its EAN-13 form (leading 0) as the same code.
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 12, trimmed.allSatisfy(\.isNumber) {
            return "0" + trimmed
        }
        return trimmed
    }
}
