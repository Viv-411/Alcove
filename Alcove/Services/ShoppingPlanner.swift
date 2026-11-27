import Foundation
import SwiftData

/// When to buy what, from how fast the household actually uses things.
/// Plain arithmetic on the scan history; no guessing.
struct ShoppingSuggestion: Identifiable {
    enum Urgency { case now, thisWeek }

    let product: Product
    let urgency: Urgency
    /// How many to buy so it lasts until about `ShoppingPlanner.coverDays` from now.
    let buy: Int
    let reason: String

    var id: PersistentIdentifier { product.persistentModelID }
}

enum ShoppingPlanner {
    /// Things that will run out within this many days go on "this week".
    static let horizonDays: Double = 7
    /// Suggested amounts aim to last about this long.
    static let coverDays: Double = 14
    static let maxSuggested = 12

    static func plan(for products: [Product], now: Date = Date()) -> [ShoppingSuggestion] {
        var suggestions: [ShoppingSuggestion] = []
        for product in products {
            let forecast = UsageAnalyzer.forecast(for: product, now: now)
            let urgency: ShoppingSuggestion.Urgency
            if product.isLowStock {
                urgency = .now
            } else if let forecast, forecast.daysLeft <= horizonDays {
                urgency = .thisWeek
            } else {
                continue
            }
            let buy = amount(for: product, forecast: forecast)
            suggestions.append(ShoppingSuggestion(
                product: product, urgency: urgency, buy: buy,
                reason: reason(for: product, forecast: forecast, buy: buy, now: now)
            ))
        }
        return suggestions.sorted { a, b in
            if a.urgency != b.urgency { return a.urgency == .now }
            if a.product.totalQuantity != b.product.totalQuantity { return a.product.totalQuantity < b.product.totalQuantity }
            return a.product.name < b.product.name
        }
    }

    static func amount(for product: Product, forecast: UsageForecast?) -> Int {
        let have = product.totalQuantity
        if let forecast {
            let needed = Int((forecast.perDay * coverDays).rounded(.up)) - have
            return min(max(1, needed), maxSuggested)
        }
        // No history yet: just get back above the low-stock line.
        return max(1, product.lowStockThreshold + 1 - have)
    }

    static func reason(for product: Product, forecast: UsageForecast?, buy: Int, now: Date) -> String {
        var parts: [String] = []
        let have = product.totalQuantity
        if have == 0 {
            parts.append("Out")
        } else if let forecast, forecast.daysLeft < 1 {
            parts.append("Runs out today")
        } else if let forecast {
            let day = forecast.runOutDate.formatted(.dateTime.weekday(.abbreviated))
            parts.append(forecast.daysLeft < 7 ? "Runs out \(day)" : "Runs out around \(forecast.runOutDate.formatted(.dateTime.month(.abbreviated).day()))")
        } else {
            parts.append(have == 1 ? "Last one" : "\(have) left")
        }
        if forecast != nil || buy > 1 {
            parts.append("buy \(buy)")
        }
        return parts.joined(separator: " · ")
    }
}
