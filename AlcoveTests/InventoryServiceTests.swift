import Foundation
import SwiftData
import Testing
@testable import Alcove

@MainActor
struct InventoryServiceTests {
    let container: ModelContainer
    let context: ModelContext
    let service: InventoryService
    let pantry: StorageLocation
    let garage: StorageLocation

    init() throws {
        container = try ModelContainer(
            for: Product.self, StorageLocation.self, StockLot.self, InventoryEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        service = InventoryService(context: context)
        pantry = StorageLocation(name: "Pantry", sortOrder: 0)
        garage = StorageLocation(name: "Garage", sortOrder: 1)
        context.insert(pantry)
        context.insert(garage)
    }

    @Test func addingSameSpotMergesIntoOneLot() {
        let dal = service.createProduct(name: "Toor Dal")
        service.add(dal, quantity: 1, to: pantry, source: .scan)
        service.add(dal, quantity: 2, to: pantry, source: .scan)
        #expect(dal.activeLots.count == 1)
        #expect(dal.totalQuantity == 3)
    }

    @Test func differentSpotsOrExpiryKeepSeparateLots() {
        let atta = service.createProduct(name: "Atta")
        service.add(atta, quantity: 1, to: pantry, source: .scan)
        service.add(atta, quantity: 2, to: garage, source: .scan)
        service.add(atta, quantity: 1, to: pantry, expiration: Date().adding(days: 10), source: .scan)
        #expect(atta.activeLots.count == 3)
        #expect(atta.quantity(in: pantry) == 2)
        #expect(atta.quantity(in: garage) == 2)
        #expect(atta.locationSummary == "Garage 2 · Pantry 2")
    }

    @Test func usingTakesSoonestExpiringFirst() {
        let paneer = service.createProduct(name: "Paneer")
        service.add(paneer, quantity: 1, to: pantry, expiration: Date().adding(days: 30), source: .scan)
        service.add(paneer, quantity: 1, to: garage, expiration: Date().adding(days: 3), source: .scan)
        service.add(paneer, quantity: 1, to: pantry, source: .scan)

        let event = service.use(paneer, quantity: 1, source: .scan)
        #expect(event?.location === garage)
        #expect(paneer.quantity(in: garage) == 0)
        #expect(paneer.totalQuantity == 2)
    }

    @Test func usingNothingReturnsNil() {
        let ghee = service.createProduct(name: "Ghee")
        #expect(service.use(ghee, source: .scan) == nil)
    }

    @Test func amendAndRevertAnAddRestoresStock() {
        let rice = service.createProduct(name: "Rice")
        service.add(rice, quantity: 1, to: garage, source: .scan)
        let event = service.add(rice, quantity: 1, to: pantry, source: .scan)!

        #expect(service.amend(event, by: 2))
        #expect(event.quantity == 3)
        #expect(rice.quantity(in: pantry) == 3)

        service.revert(event)
        #expect(rice.totalQuantity == 1)
        #expect(rice.quantity(in: garage) == 1)
        #expect((rice.events ?? []).filter { $0.kind == .added }.count == 1)
    }

    @Test func undoingAUseputsItBack() {
        let noodles = service.createProduct(name: "Noodles")
        service.add(noodles, quantity: 2, to: pantry, source: .scan)
        let used = service.use(noodles, quantity: 1, source: .scan)!
        #expect(noodles.totalQuantity == 1)
        let alive = service.amend(used, by: -1)
        #expect(!alive)
        #expect(noodles.totalQuantity == 2)
    }

    @Test func lowStockThreshold() {
        let biscuits = service.createProduct(name: "Biscuits", lowStockThreshold: 2)
        service.add(biscuits, quantity: 4, to: pantry, source: .scan)
        #expect(!biscuits.isLowStock)
        service.use(biscuits, quantity: 2, source: .scan)
        #expect(biscuits.isLowStock)

        biscuits.lowStockThreshold = 0
        #expect(!biscuits.isLowStock)
    }

    @Test func barcodeLookupTreatsUPCAndEANTheSame() {
        let product = service.createProduct(name: "Jif", barcode: "051500255162")
        #expect(service.product(forBarcode: "0051500255162") === product)
        #expect(service.product(forBarcode: "051500255162") === product)
        #expect(service.product(forBarcode: "999") == nil)
    }

    @Test func editingALotToZeroRemovesIt() {
        let oil = service.createProduct(name: "Oil")
        service.add(oil, quantity: 2, to: pantry, source: .manual)
        let lot = oil.activeLots[0]
        service.update(lot, quantity: 0, location: pantry, expiration: nil)
        #expect(oil.totalQuantity == 0)
        #expect((oil.events ?? []).contains { $0.kind == .adjusted && $0.quantity == -2 })
    }

    @Test func forecastNeedsHistoryThenPredicts() {
        let atta = service.createProduct(name: "Atta")
        service.add(atta, quantity: 3, to: pantry, source: .scan)
        #expect(UsageAnalyzer.forecast(for: atta) == nil)

        // Used 1 every 10 days for the last 40 days.
        for daysAgo in [40, 30, 20, 10] {
            let event = InventoryEvent(kind: .used, source: .scan, quantity: 1)
            context.insert(event)
            event.product = atta
            event.date = Date().adding(days: -daysAgo)
        }
        let forecast = try! #require(UsageAnalyzer.forecast(for: atta))
        #expect(abs(forecast.perDay - 0.1) < 0.001)
        #expect(abs(forecast.daysLeft - 30) < 0.5)
        #expect(forecast.paceDescription == "About 1 every 10 days")
    }
}
