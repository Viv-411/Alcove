import Foundation

struct UsageForecast {
    /// Units consumed per day.
    let perDay: Double
    let daysLeft: Double
    let runOutDate: Date

    var paceDescription: String {
        let perWeek = perDay * 7
        if perDay >= 1 {
            return "About \(Int(perDay.rounded())) a day"
        } else if perWeek >= 1.5 {
            return "About \(Int(perWeek.rounded())) a week"
        } else {
            let days = max(2, Int((1 / perDay).rounded()))
            return days >= 14 && days % 7 <= 1
                ? "About 1 every \(days / 7) weeks"
                : "About 1 every \(days) days"
        }
    }
}

/// Learns how fast the household goes through a product from its `.used` events.
enum UsageAnalyzer {
    /// Only look at recent history so the forecast adapts to changing habits.
    static let windowDays: Double = 120
    static let minimumUses = 2
    static let minimumSpanDays: Double = 3

    static func forecast(for product: Product, now: Date = Date()) -> UsageForecast? {
        let cutoff = now.addingTimeInterval(-windowDays * 86_400)
        let uses = (product.events ?? [])
            .filter { $0.kind == .used && $0.date >= cutoff }
            .sorted { $0.date < $1.date }
        guard uses.count >= minimumUses, let first = uses.first else { return nil }

        let spanDays = now.timeIntervalSince(first.date) / 86_400
        guard spanDays >= minimumSpanDays else { return nil }

        let consumed = uses.reduce(0) { $0 + $1.quantity }
        let perDay = Double(consumed) / spanDays
        guard perDay > 0 else { return nil }

        let daysLeft = Double(product.totalQuantity) / perDay
        return UsageForecast(
            perDay: perDay,
            daysLeft: daysLeft,
            runOutDate: now.addingTimeInterval(daysLeft * 86_400)
        )
    }
}
