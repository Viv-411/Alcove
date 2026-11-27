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
        // Costco: tax flag and item number before the name.
        ("E 222490 KS XL PEANUT 7.79 E", "Ks Xl Peanut", 1),
        ("3797974 DAWN POWERWS 13.29 A", "Dawn Powerws", 1),
    ])
    func parsesItemLines(line: String, name: String, quantity: Int) throws {
        let parsed = try #require(ReceiptParser.parse(line: line))
        #expect(parsed.name == name)
        #expect(parsed.quantity == quantity)
    }

    @Test(arguments: [
        "SUBTOTAL 48.96", "TAX 1.20", "VISA ************1234 50.16", "COUPON SAVINGS -1.00",
        "Store #1234 Edison NJ", "Thank you for shopping 0.00", "TOTAL 81.92",
        // From a real Costco receipt that used to add these as items.
        "AMOUNT: $56.66", "INSTANT SAVING- $3.00", "0000373857 / 3797974 3.00-A",
    ])
    func skipsNonItemLines(line: String) {
        #expect(ReceiptParser.parse(line: line) == nil)
    }

    @Test func splitsRowsThatHoldTwoItems() {
        let lines = ["E 222490 KS XL PEANUT 7.79 E E 1097320 PREMIER STRW 31.99 E"]
        #expect(ReceiptParser.parse(lines: lines).map(\.name) == ["Ks Xl Peanut", "Premier Strw"])
        // A unit price before the item still sets the quantity.
        let multiple = ReceiptParser.parse(lines: ["2 @ 3.49 TOOR DAL 4LB 6.98"])
        #expect(multiple.map(\.name) == ["Toor Dal 4lb"])
        #expect(multiple.map(\.quantity) == [2])
        // Percentages aren't prices.
        #expect(ReceiptParser.parse(lines: ["L TA A 8.00% Tax 0.32"]).isEmpty)
    }

    @Test func tiltedPhotoKeepsPricesOnTheirRows() {
        // Rows slope up by 4° to the right, so each price sits higher than its own
        // item's name: about as high as the next row's name.
        let angle = 4.0 * .pi / 180
        func at(_ x: Double, _ row: Double) -> Double { 1000 - row * 40 + x * tan(angle) }
        let items = [("DAWN POWERWS", "13.29 A"), ("KS XL PEANUT", "7.79 E"), ("PREMIER STRW", "31.99 E"), ("MANDARINS", "4.99 E")]
        var fragments: [ReceiptTextRecognizer.Fragment] = []
        for (row, item) in items.enumerated() {
            fragments.append(.init(text: item.0, x: 200, y: at(200, Double(row)), height: 24, angle: angle, length: 300))
            fragments.append(.init(text: item.1, x: 900, y: at(900, Double(row)), height: 24, angle: angle, length: 120))
        }
        let rows = ReceiptTextRecognizer.rows(from: fragments)
        #expect(rows == items.map { "\($0.0) \($0.1)" })
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
        let container = try AlcoveSchema.container(inMemory: true)
        let atta = Product(name: "Whole Wheat Atta", brand: "Aashirvaad")
        let dal = Product(name: "Toor Dal", brand: "Laxmi")
        container.mainContext.insert(atta)
        container.mainContext.insert(dal)

        #expect(ProductMatcher.bestMatch(for: "Aash Atta 20lb", in: [atta, dal]) === atta)
        #expect(ProductMatcher.bestMatch(for: "Laxmi Toor Dal 4lb", in: [atta, dal]) === dal)
        #expect(ProductMatcher.bestMatch(for: "Mango Pickle", in: [atta, dal]) == nil)

        // Sharing one word isn't a match (both used to be).
        let biscuits = Product(name: "Parle-G Biscuits", brand: "Parle")
        let noodles = Product(name: "Instant Noodles", brand: "Maggi")
        let paneer = Product(name: "Paneer", brand: "Nanak")
        let peanutButter = Product(name: "Peanut Butter", brand: "Jif")
        for product in [biscuits, noodles, paneer, peanutButter] { container.mainContext.insert(product) }
        let all = [atta, dal, biscuits, noodles, paneer, peanutButter]
        #expect(ProductMatcher.bestMatch(for: "Asst Biscuit", in: all) == nil)
        #expect(ProductMatcher.bestMatch(for: "Instant Saving", in: all) == nil)
        #expect(ProductMatcher.bestMatch(for: "Ks Xl Peanut", in: all) == nil)
        #expect(ProductMatcher.bestMatch(for: "Parle G 800g", in: all) === biscuits)
        #expect(ProductMatcher.bestMatch(for: "Maggi Noodles 12pk", in: all) === noodles)
        #expect(ProductMatcher.bestMatch(for: "Amul Pnr 200g", in: all) === paneer)

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
