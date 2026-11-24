import CoreGraphics
import Foundation
import Vision

nonisolated struct ReceiptImages: @unchecked Sendable {
    let images: [CGImage]
}

/// On-device OCR for receipt photos. Text fragments that sit on the same
/// printed row (item name on the left, price on the right) are joined.
nonisolated enum ReceiptTextRecognizer {
    @concurrent
    static func recognizeLines(in batch: ReceiptImages) async -> [String] {
        var lines: [String] = []
        for image in batch.images {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continue
            }
            let fragments: [Fragment] = (request.results ?? []).compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return Fragment(text: candidate.string, box: observation.boundingBox)
            }
            lines += rows(from: fragments)
        }
        return lines
    }

    struct Fragment {
        let text: String
        let box: CGRect
    }

    static func rows(from fragments: [Fragment]) -> [String] {
        // Vision's origin is bottom-left, so higher midY = higher on the page.
        let sorted = fragments.sorted { $0.box.midY > $1.box.midY }
        var rows: [[Fragment]] = []
        for fragment in sorted {
            if let anchor = rows.last?.first,
               abs(anchor.box.midY - fragment.box.midY) < max(anchor.box.height, fragment.box.height) * 0.6 {
                rows[rows.count - 1].append(fragment)
            } else {
                rows.append([fragment])
            }
        }
        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
        }
    }
}

struct ParsedReceiptLine: Hashable {
    var rawText: String
    var name: String
    var quantity: Int
}

/// Turns OCR'd receipt rows into probable grocery items. Receipts vary wildly,
/// so this is deliberately forgiving; the user reviews everything before it's added.
nonisolated enum ReceiptParser {
    private static let skipWords: Set<String> = [
        "total", "subtotal", "tax", "taxes", "gst", "vat", "hst", "pst", "cgst", "sgst",
        "change", "cash", "visa", "mastercard", "amex", "discover", "debit", "credit",
        "balance", "tender", "tendered", "payment", "approved", "auth", "thank", "thanks",
        "receipt", "invoice", "tel", "phone", "cashier", "savings", "saved", "discount",
        "coupon", "member", "points", "terminal", "transaction", "account", "due",
        "rounding", "refund", "loyalty", "reward", "rewards", "survey", "www", "com",
        "http", "https", "upi", "paytm", "gpay",
    ]
    private static let skipPhrases = ["sub total", "you saved", "items sold", "number of items", "card #", "ref #"]

    static func parse(lines: [String]) -> [ParsedReceiptLine] {
        var items: [ParsedReceiptLine] = []
        // Many receipts print "2 @ 3.49" on its own line, just above or below the
        // item it belongs to. Attach it to the neighbour whose price matches.
        var pendingMultiple: (quantity: Int, unitPrice: Double)?
        var lastItemPrice: Double?

        for line in lines {
            if let multiple = standaloneMultiple(line) {
                if let last = items.indices.last, let price = lastItemPrice,
                   abs(price - Double(multiple.quantity) * multiple.unitPrice) < 0.02, items[last].quantity == 1 {
                    items[last].quantity = multiple.quantity
                } else {
                    pendingMultiple = multiple
                }
                continue
            }
            guard var item = parse(line: line) else { continue }
            let price = trailingPrice(line)
            if let pending = pendingMultiple, let price, item.quantity == 1,
               abs(price - Double(pending.quantity) * pending.unitPrice) < 0.02 {
                item.quantity = pending.quantity
            }
            pendingMultiple = nil
            lastItemPrice = price
            items.append(item)
        }
        return items
    }

    private static func standaloneMultiple(_ line: String) -> (quantity: Int, unitPrice: Double)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.wholeMatch(of: #/(\d{1,2})\s*[@xX]\s*[$₹€£]?(\d+[.,]\d{2})(\s*(ea|EA|each))?/#),
              let quantity = Int(match.1),
              let unit = Double(match.2.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return (quantity, unit)
    }

    private static func trailingPrice(_ line: String) -> Double? {
        guard let match = line.firstMatch(of: #/(\d{1,6})[.,](\d{2})\s*[A-Za-z*]{0,2}\s*$/#) else { return nil }
        return Double("\(match.1).\(match.2)")
    }

    static func parse(line raw: String) -> ParsedReceiptLine? {
        var text = raw
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let lower = text.lowercased()
        let words = Set(lower.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        if !words.isDisjoint(with: skipWords) { return nil }
        if skipPhrases.contains(where: lower.contains) { return nil }

        // An item row ends in a price, optionally followed by a tax flag ("3.99 F").
        guard let price = text.firstMatch(of: #/-?[$₹€£]?\s?\d{1,6}[.,]\d{2}\s*[A-Za-z*]{0,2}\s*$/#) else {
            return nil
        }
        if text[price.range].hasPrefix("-") { return nil } // discount line
        text = String(text[..<price.range.lowerBound])

        var quantity = 1
        // "2 @ 1.99" / "2 x 1.99" unit-price notation
        if let match = text.firstMatch(of: #/(\d{1,2})\s*[@xX]\s*[$₹€£]?\d+[.,]\d{2}/#) {
            quantity = Int(match.1) ?? 1
            text.removeSubrange(match.range)
        }
        // Leading "2 x " / "2X "
        if let match = text.firstMatch(of: #/^(\d{1,2})\s*[xX]\s+/#) {
            quantity = Int(match.1) ?? 1
            text.removeSubrange(match.range)
        }
        // Item codes / SKUs
        text = text.replacing(#/^\d{4,}\s+/#, with: "")
        text = text.replacing(#/\s+\d{6,}\s*$/#, with: "")
        text = text.trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))

        guard text.filter(\.isLetter).count >= 3 else { return nil }
        return ParsedReceiptLine(rawText: raw, name: prettify(text), quantity: max(1, min(quantity, 50)))
    }

    /// "AASH ATTA 10KG" → "Aash Atta 10kg"
    static func prettify(_ text: String) -> String {
        text.split(separator: " ").map { word in
            if word.contains(where: \.isNumber) { return word.lowercased() }
            return word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }
}

/// Matches receipt names (often abbreviated) to products the household already tracks.
enum ProductMatcher {
    static func aliasKey(_ text: String) -> String {
        text.lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .joined(separator: " ")
    }

    static func tokens(_ text: String) -> [String] {
        aliasKey(text).split(separator: " ").map(String.init).filter { $0.count >= 2 }
    }

    static func bestMatch(for name: String, in products: [Product]) -> Product? {
        let key = aliasKey(name)
        if let learned = products.first(where: { $0.receiptAliases.contains(key) }) {
            return learned
        }
        let receiptTokens = tokens(name)
        guard !receiptTokens.isEmpty else { return nil }

        var best: (product: Product, score: Double)?
        for product in products {
            let productTokens = tokens(product.name + " " + (product.brand ?? ""))
            guard !productTokens.isEmpty else { continue }
            let hits = receiptTokens.filter { r in
                productTokens.contains { t in
                    t == r || (min(t.count, r.count) >= 3 && (t.hasPrefix(r) || r.hasPrefix(t)))
                }
            }.count
            let score = Double(hits) / Double(receiptTokens.count)
            if score > (best?.score ?? 0) { best = (product, score) }
        }
        guard let best, best.score >= 0.5 else { return nil }
        return best.product
    }
}
