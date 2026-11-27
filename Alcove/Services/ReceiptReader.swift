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
            // Work in pixels so angles aren't distorted by the image's aspect ratio.
            let width = Double(image.width), height = Double(image.height)
            let fragments: [Fragment] = (request.results ?? []).compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let left = observation.bottomLeft, right = observation.bottomRight, top = observation.topLeft
                let dx = (right.x - left.x) * width, dy = (right.y - left.y) * height
                let box = observation.boundingBox
                return Fragment(
                    text: candidate.string,
                    x: box.midX * width,
                    y: box.midY * height,
                    height: max(1, hypot((top.x - left.x) * width, (top.y - left.y) * height)),
                    angle: atan2(dy, dx),
                    length: hypot(dx, dy)
                )
            }
            lines += rows(from: fragments)
        }
        return lines
    }

    struct Fragment {
        var text: String
        /// Centre and text height in pixels, origin bottom-left (Vision's convention).
        var x: Double
        var y: Double
        var height: Double
        /// Slope of the text baseline in radians, and its length in pixels.
        var angle: Double = 0
        var length: Double = 0
    }

    /// Groups fragments printed on the same row (item name on the left, price on
    /// the right). A receipt photographed at a slight angle has sloping rows, so
    /// positions are first rotated by the page's typical text angle; otherwise a
    /// price can land on the row above or below its item.
    static func rows(from fragments: [Fragment]) -> [String] {
        let longest = fragments.sorted { $0.length > $1.length }.prefix(max(3, fragments.count / 2))
        let angles = longest.map(\.angle).sorted()
        let skew = angles.isEmpty ? 0 : angles[angles.count / 2]
        let (sine, cosine) = (sin(skew), cos(skew))
        func level(_ f: Fragment) -> Double { f.y * cosine - f.x * sine }
        func across(_ f: Fragment) -> Double { f.x * cosine + f.y * sine }

        // Higher level = higher on the page.
        let sorted = fragments.sorted { level($0) > level($1) }
        var rows: [[Fragment]] = []
        for fragment in sorted {
            if let row = rows.last {
                let rowLevel = row.map(level).reduce(0, +) / Double(row.count)
                let rowHeight = row.map(\.height).max() ?? fragment.height
                if abs(rowLevel - level(fragment)) < max(rowHeight, fragment.height) * 0.6 {
                    rows[rows.count - 1].append(fragment)
                    continue
                }
            }
            rows.append([fragment])
        }
        return rows.map { row in
            row.sorted { across($0) < across($1) }.map(\.text).joined(separator: " ")
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
        "http", "https", "upi", "paytm", "gpay", "amount", "saving", "purchase", "sold", "aid", "seq",
        "tran", "resp", "whse", "trm", "approval", "signature", "verified", "chip", "contactless",
    ]
    private static let skipPhrases = ["sub total", "you saved", "items sold", "number of items", "card #", "ref #"]

    static func parse(lines: [String]) -> [ParsedReceiptLine] {
        var items: [ParsedReceiptLine] = []
        // Many receipts print "2 @ 3.49" on its own line, just above or below the
        // item it belongs to. Attach it to the neighbour whose price matches.
        var pendingMultiple: (quantity: Int, unitPrice: Double)?
        var lastItemPrice: Double?

        for line in lines.flatMap(splitMergedItems) {
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

    /// "KS XL PEANUT 7.79 E E 1097320 PREMIER STRW 31.99 E" → two lines, split
    /// after each price (and its tax flag) that has more words after it.
    static func splitMergedItems(_ line: String) -> [String] {
        var parts: [String] = []
        var rest = Substring(line)
        // A price is a number with two decimals, not a percentage ("8.00% Tax").
        while let match = rest.firstMatch(of: #/[$₹€£]?\d{1,6}[.,]\d{2}(?![\d%])-?(?:\s+[A-Z*]{1,2}\b)?(?=\s)/#) {
            let after = rest[match.range.upperBound...]
            guard after.filter(\.isLetter).count >= 3 else { break }
            parts.append(String(rest[..<match.range.upperBound]))
            rest = after
        }
        parts.append(String(rest))
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
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
        text = text.replacing(#/^(?:[A-Za-z]{1,2}\s+)?\d{4,}\s+/#, with: "")
        text = text.replacing(#/\s+\d{6,}\s*$/#, with: "")
        // Any other long number (item codes, "0000373857 / 3797974" discount references).
        text = text.replacing(#/(^|\s)[\d\/]{6,}(?=\s|$)/#, with: " ")
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
        var best: (product: Product, score: Double)?
        for product in products {
            guard let score = matchScore(receipt: name, name: product.name, brand: product.brand) else { continue }
            if score > (best?.score ?? 0) { best = (product, score) }
        }
        return best?.product
    }

    /// Whether a receipt line is this item, and how well it fits. Sharing one word
    /// isn't enough ("Asst Biscuit" isn't "Parle-G Biscuits", "Instant Saving" isn't
    /// "Instant Noodles"): either every word of the item's name is on the line
    /// ("Amul Pnr 200g" is "Paneer"), or every word on the line belongs to the item
    /// or its brand ("Aash Atta 20lb" is Aashirvaad "Whole Wheat Atta").
    static func matchScore(receipt: String, name: String, brand: String? = nil) -> Double? {
        let codes = words(receipt)
        let nameWords = words(name)
        let itemWords = nameWords + words(brand ?? "")
        guard !codes.isEmpty, !nameWords.isEmpty else { return nil }
        let codesCovered = codes.filter { code in itemWords.contains { covers(code, $0) } }.count
        let nameCovered = nameWords.filter { word in codes.contains { covers($0, word) } }.count
        guard codesCovered > 0 else { return nil }
        let wholeName = nameCovered == nameWords.count
        let wholeLine = codesCovered == codes.count
        guard wholeName || wholeLine else { return nil }
        return Double(codesCovered) / Double(codes.count) + Double(nameCovered) / Double(nameWords.count)
    }

    /// A receipt word stands for an item word: the same word, a plural or a cut-off
    /// ("biscuit" / "biscuits", "aash" / "aashirvaad"), or an abbreviation ("pnr" / "paneer").
    static func covers(_ code: String, _ word: String) -> Bool {
        if code == word { return true }
        guard min(code.count, word.count) >= 3 else { return false }
        return word.hasPrefix(code) || code.hasPrefix(word) || ReceiptAI.abbreviates(code, word)
    }

    private static let fillerWords: Set<String> = [
        "lb", "lbs", "oz", "kg", "ml", "ct", "pk", "pc", "pcs", "ea", "each", "pack", "count", "the", "and", "of",
    ]

    /// Letters-only words of two or more letters, without sizes and filler.
    static func words(_ text: String) -> [String] {
        tokens(text).filter { $0.allSatisfy(\.isLetter) && !fillerWords.contains($0) }
    }
}
