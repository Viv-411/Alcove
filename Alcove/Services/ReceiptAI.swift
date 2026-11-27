import Foundation
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct ReceiptNameFix {
    @Guide(description: "The line number from the list")
    var line: Int
    @Guide(description: "What a person would call this grocery item, in Title Case, without the price, weight codes or store codes. Keep the brand if it's clear. Example: 'GRN BNS 2LB' becomes 'Green Beans 2lb'")
    var name: String
    @Guide(description: "If this is one of the household's items, its exact name from that list. Otherwise an empty string")
    var sameAs: String
}

@available(iOS 26.0, *)
@Generable
struct ReceiptNameFixes {
    var items: [ReceiptNameFix]
}

/// Receipts print short codes like "GRN BNS 2LB" or "AMUL PNR 200G". The
/// on-device model expands them into names people recognise and spots items
/// the household already tracks. The parser still decides which lines are
/// items, so the model can't invent anything that isn't on the receipt.
enum ReceiptAI {
    struct Fix: Equatable {
        var name: String
        var sameAs: String?
    }

    static let instructions = """
        You tidy up item names printed on grocery receipts.
        Receipts shorten words by dropping letters, for example grn means green, bns means beans, \
        chkn means chicken, thgh means thigh, bnls means boneless, org means organic, pnr means paneer, \
        lg means large, brn means brown.
        Give each line the plain English name a shopper would say, in Title Case. \
        Keep the brand and the pack size. Never invent items.
        """

    /// Returns a fix for each line it could tidy, keyed by its position in `names`.
    @available(iOS 26.0, *)
    static func clean(_ names: [String], householdItems: [String]) async throws -> [Int: Fix] {
        let raw = try await suggest(names, householdItems: householdItems)
        return apply(raw, originals: names, householdItems: householdItems)
    }

    /// The model's unchecked suggestions. Use `clean`, which filters them.
    @available(iOS 26.0, *)
    static func suggest(_ names: [String], householdItems: [String]) async throws -> [(line: Int, name: String, sameAs: String)] {
        guard !names.isEmpty else { return [] }
        // Quoted and lowercased: bare receipt codes can make the model decide the
        // text isn't English and refuse the whole request.
        let list = names.enumerated()
            .map { "Line \($0.offset + 1): \"\($0.element.lowercased())\"" }
            .joined(separator: "\n")
        let known = householdItems.prefix(80).joined(separator: "; ")
        let prompt = """
            Item names copied from a grocery store receipt. Please rewrite each one as the \
            plain English name a shopper would say.

            \(list)

            Items the household already tracks: \(known.isEmpty ? "none yet" : known)

            Give one entry for every line.
            """
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: prompt,
            generating: ReceiptNameFixes.self,
            options: GenerationOptions(temperature: 0)
        )
        return response.content.items.map { ($0.line, $0.name, $0.sameAs) }
    }

    /// Keeps only fixes that are faithful to the receipt: each fix must point at
    /// a real line, every abbreviation on that line must fit a word in the new
    /// name ("pnr" fits "Paneer", not "Butter"), and a match must be a real item.
    static func apply(_ raw: [(line: Int, name: String, sameAs: String)], originals: [String], householdItems: [String]) -> [Int: Fix] {
        var fixes: [Int: Fix] = [:]
        for entry in raw {
            let index = entry.line - 1
            guard originals.indices.contains(index), fixes[index] == nil else { continue }
            let original = originals[index]
            var name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.filter(\.isLetter).count >= 3, name.count <= 60 else { continue }
            // The model sometimes shouts; receipts already do enough of that.
            if name == name.uppercased() { name = ReceiptParser.prettify(name) }

            let wanted = entry.sameAs.trimmingCharacters(in: .whitespacesAndNewlines)
            let same = wanted.isEmpty ? nil : householdItems.first {
                $0.caseInsensitiveCompare(wanted) == .orderedSame && sharesAWord(original, $0)
            }
            if same == nil {
                guard isFaithful(name, to: original), compact(name) != compact(original) else { continue }
            }
            fixes[index] = Fix(name: same ?? name, sameAs: same)
        }
        return fixes
    }

    /// Every word on the receipt line is an abbreviation of a word in `expanded`,
    /// and `expanded` adds nothing but unit words ("Extra Virgin" from nowhere fails).
    static func isFaithful(_ expanded: String, to original: String) -> Bool {
        let words = letterWords(expanded)
        let codes = letterWords(original)
        guard !codes.isEmpty else { return false }
        let everyCodeUsed = codes.allSatisfy { code in words.contains { abbreviates(code, $0) } }
        let nothingInvented = words.allSatisfy { word in
            unitWords.contains(word) || codes.contains { abbreviates($0, word) }
        }
        return everyCodeUsed && nothingInvented
    }

    private static let unitWords: Set<String> = [
        "lb", "lbs", "pound", "pounds", "oz", "ounce", "ounces", "g", "gram", "grams", "kg", "l", "liter",
        "liters", "litre", "litres", "ml", "ct", "count", "pack", "pk", "dozen", "each", "ea", "bunch", "and", "of",
    ]

    /// At least one real word on the receipt line abbreviates a word in the item's name.
    static func sharesAWord(_ original: String, _ item: String) -> Bool {
        let words = letterWords(item)
        return letterWords(original).contains { code in code.count >= 3 && words.contains { abbreviates(code, $0) } }
    }

    /// Letters and digits only, so "12pk" and "12 PK" compare equal.
    private static func compact(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// "pnr" → "paneer": same first letter, and the rest appear in order.
    /// A lone letter ("Parle G") stands for itself; it could start any word.
    static func abbreviates(_ code: String, _ word: String) -> Bool {
        if code.count == 1 { return word == code }
        guard let first = code.first, word.first == first, code.count <= word.count else { return false }
        var rest = word.dropFirst()[...]
        for letter in code.dropFirst() {
            guard let found = rest.firstIndex(of: letter) else { return false }
            rest = rest[rest.index(after: found)...]
        }
        return true
    }

    /// Lowercased words made only of letters; numbers and sizes ("2lb", "18ct") are ignored.
    private static func letterWords(_ text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" }
            .map { $0.replacingOccurrences(of: "'", with: "") }
            .filter { !$0.isEmpty && $0.allSatisfy(\.isLetter) }
    }
}
