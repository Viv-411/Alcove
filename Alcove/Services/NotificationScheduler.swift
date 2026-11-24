import Foundation
import SwiftData
import UserNotifications

enum SettingsKey {
    static let lowStockAlerts = "lowStockAlerts"
    static let expiryAlerts = "expiryAlerts"
    static let restockAlerts = "restockAlerts"
    static let expiryLeadDays = "expiryLeadDays"
}

/// Local notifications for running low, expiry and predicted restocks.
/// Scheduled reminders are rebuilt from scratch after every inventory change.
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let delegate = NotificationDelegate()
    private let reminderHour = 9
    /// iOS allows 64 pending notifications per app; leave headroom.
    private let maxPending = 60

    private init() {
        center.delegate = delegate
    }

    private func isEnabled(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    private var expiryLeadDays: Int {
        UserDefaults.standard.object(forKey: SettingsKey.expiryLeadDays) as? Int ?? 3
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func notifyLowStock(_ product: Product) {
        guard isEnabled(SettingsKey.lowStockAlerts) else { return }
        let quantity = product.totalQuantity
        let content = UNMutableNotificationContent()
        content.title = quantity == 0 ? "Out of \(product.name)" : "Running low on \(product.name)"
        content.body = quantity == 0
            ? "That was the last one. Time to add it to the shopping list."
            : "Only \(quantity) left at home."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "low-\(UUID().uuidString)", content: content, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }

    func refresh(context: ModelContext) {
        let products = (try? context.fetch(FetchDescriptor<Product>())) ?? []
        let now = Date()
        let calendar = Calendar.current
        var scheduled: [(date: Date, request: UNNotificationRequest)] = []

        func at9(_ date: Date) -> Date {
            calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: date) ?? date
        }

        func request(_ id: String, title: String, body: String, fireAt date: Date) -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        }

        if isEnabled(SettingsKey.expiryAlerts) {
            for (index, product) in products.enumerated() {
                guard let expiry = product.nextExpiration else { continue }
                var fire = at9(calendar.date(byAdding: .day, value: -expiryLeadDays, to: expiry) ?? expiry)
                if fire <= now {
                    fire = at9(expiry)
                    if fire <= now { continue }
                }
                let days = fire.days(until: expiry)
                let body = switch days {
                case ...0: "Expires today."
                case 1: "Expires tomorrow."
                default: "Expires in \(days) days."
                }
                scheduled.append((fire, request("expiry-\(index)", title: "Use soon: \(product.name)",
                                                body: body, fireAt: fire)))
            }
        }

        if isEnabled(SettingsKey.restockAlerts) {
            for (index, product) in products.enumerated() where !product.isLowStock && !product.isOutOfStock {
                guard let forecast = UsageAnalyzer.forecast(for: product, now: now) else { continue }
                let fire = at9(calendar.date(byAdding: .day, value: -3, to: forecast.runOutDate) ?? forecast.runOutDate)
                guard fire > now else { continue }
                let when = forecast.runOutDate.formatted(.dateTime.month(.abbreviated).day())
                scheduled.append((fire, request("restock-\(index)", title: "Restock soon: \(product.name)",
                                                body: "At your usual pace you'll run out around \(when).",
                                                fireAt: fire)))
            }
        }

        center.removeAllPendingNotificationRequests()
        for item in scheduled.sorted(by: { $0.date < $1.date }).prefix(maxPending) {
            center.add(item.request, withCompletionHandler: nil)
        }
    }
}

/// Shows notifications as banners even while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
