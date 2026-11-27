import Foundation
import FoundationModels

/// Apple's on-device language model (Apple Intelligence). It runs on the
/// person's phone: free, private, and works offline. Older phones, or phones
/// with Apple Intelligence turned off, simply don't see the AI features.
enum KitchenAI {
    enum Status: Equatable {
        case ready
        /// iOS older than 26, or a phone without Apple Intelligence.
        case notSupported
        case turnedOff
        /// The model is still downloading after Apple Intelligence was turned on.
        case preparing
    }

    static var status: Status {
        #if DEBUG
        if DebugLaunch.isAIDisabled { return .notSupported }
        if DebugLaunch.usesAIFixture { return .ready }
        #endif
        #if targetEnvironment(simulator)
        // The Simulator reports the model as available but can't run it.
        return .notSupported
        #else
        guard #available(iOS 26.0, *) else { return .notSupported }
        switch SystemLanguageModel.default.availability {
        case .available: return .ready
        case .unavailable(.appleIntelligenceNotEnabled): return .turnedOff
        case .unavailable(.modelNotReady): return .preparing
        case .unavailable: return .notSupported
        }
        #endif
    }

    static var isReady: Bool { status == .ready }

    /// A friendly message for errors from the model.
    static func message(for error: Error) -> String {
        "Apple Intelligence couldn't come up with ideas just now. Try again in a moment."
    }
}

/// What's at home, flattened into plain values for a prompt.
struct PantryItem: Sendable, Hashable {
    var name: String
    var quantity: Int
    var daysToExpiry: Int?
    var location: String?

    @MainActor
    static func snapshot(of products: [Product]) -> [PantryItem] {
        products
            .filter { !$0.isOutOfStock }
            .map { product in
                PantryItem(
                    name: product.name,
                    quantity: product.totalQuantity,
                    daysToExpiry: product.nextExpiration.map(Expiry.daysLeft),
                    location: product.primaryLocation?.name
                )
            }
            .sorted { a, b in
                // Expiring food first, so it survives any trimming below.
                switch (a.daysToExpiry, b.daysToExpiry) {
                case let (x?, y?): x < y
                case (_?, nil): true
                case (nil, _?): false
                default: a.name < b.name
                }
            }
    }

    var isExpiringSoon: Bool { (daysToExpiry ?? .max) <= 3 && (daysToExpiry ?? .max) >= 0 }

    var promptLine: String {
        var parts = ["\(quantity)"]
        if let days = daysToExpiry {
            if days == 0 { parts.append("expires today") }
            else if days <= 7 { parts.append("expires in \(days) day\(days == 1 ? "" : "s")") }
        }
        if let location { parts.append(location) }
        return "- \(name) (\(parts.joined(separator: ", ")))"
    }
}
