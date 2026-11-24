import Foundation
import SwiftData
import Testing
import UIKit
@testable import Alcove

struct ReceiptParserTests {
    @Test(arguments: [
        ("AASHIRVAAD ATTA 10KG   12.99 F", "Aashirvaad Atta 10kg", 1),
        ("2 @ 3.49  TOOR DAL 4LB 6.98", "Toor Dal 4lb", 2),
        ("LAXMI BASMATI RICE 20LB $24.99", "Laxmi Basmati Rice 20lb", 1),
        ("123456789012 HALDIRAMS BHUJIA 3.29 N", "Haldirams Bhujia", 1),
        ("2 X PARLE G BISCUIT 1.98", "Parle G Biscuit", 2),
        ("CARDAMOM PODS 4.99", "Cardamom Pods", 1),
    ])
    func parsesItemLines(line: String, name: String, quantity: Int) throws {
        let parsed = try #require(ReceiptParser.parse(line: line))
        #expect(parsed.name == name)
        #expect(parsed.quantity == quantity)
    }

    @Test(arguments: [
        "SUBTOTAL 48.96", "TAX 1.20", "VISA ************1234 50.16", "COUPON SAVINGS -1.00",
        "Store #1234 Edison NJ", "Thank you for shopping 0.00", "TOTAL 81.92",
    ])
    func skipsNonItemLines(line: String) {
        #expect(ReceiptParser.parse(line: line) == nil)
    }

    @Test func quantityOnItsOwnLineAppliesToMatchingItem() {
        let lines = ["2 @ 3.49", "PARLE G 800G 6.98 F", "MAGGI NOODLES 9.49"]
        let parsed = ReceiptParser.parse(lines: lines)
        #expect(parsed.map(\.name) == ["Parle G 800g", "Maggi Noodles"])
        #expect(parsed.map(\.quantity) == [2, 1])
    }
}

@MainActor
struct ProductMatcherTests {
    @Test func matchesAbbreviatedReceiptNames() throws {
        let container = try ModelContainer(for: Product.self, StorageLocation.self, StockLot.self, InventoryEvent.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let atta = Product(name: "Whole Wheat Atta", brand: "Aashirvaad")
        let dal = Product(name: "Toor Dal", brand: "Laxmi")
        container.mainContext.insert(atta)
        container.mainContext.insert(dal)

        #expect(ProductMatcher.bestMatch(for: "Aash Atta 20lb", in: [atta, dal]) === atta)
        #expect(ProductMatcher.bestMatch(for: "Laxmi Toor Dal 4lb", in: [atta, dal]) === dal)
        #expect(ProductMatcher.bestMatch(for: "Mango Pickle", in: [atta, dal]) == nil)

        dal.receiptAliases = [ProductMatcher.aliasKey("LXM TD 4")]
        #expect(ProductMatcher.bestMatch(for: "Lxm Td 4", in: [atta, dal]) === dal)
    }
}

/// Runs the real on-device OCR on a rendered receipt photo.
struct ReceiptOCRTests {
    @Test func readsRenderedReceipt() async throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "receipt", withExtension: "png"))
        let image = try #require(UIImage(contentsOfFile: url.path)?.cgImage)
        let lines = await ReceiptTextRecognizer.recognizeLines(in: ReceiptImages(images: [image]))
        let parsed = ReceiptParser.parse(lines: lines)
        let names = parsed.map(\.name)

        #expect(parsed.count == 7, "Got: \(names)")
        #expect(names.contains("Aash Atta 20lb"))
        #expect(parsed.first { $0.name.hasPrefix("Parle") }?.quantity == 2)
        #expect(!names.contains { $0.localizedCaseInsensitiveContains("total") })
    }
}

private final class BundleToken {}

struct ProductLookupTests {
    @Test func cleansPackageSizes() {
        #expect(ProductLookup.cleanSize("400 g e") == "400 g")
        #expect(ProductLookup.cleanSize("1 kg ℮") == "1 kg")
        #expect(ProductLookup.cleanSize("2 lb") == "2 lb")
        #expect(ProductLookup.cleanSize("  ") == nil)
        #expect(ProductLookup.cleanSize(nil) == nil)
    }
}
