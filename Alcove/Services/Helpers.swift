import SwiftData
import SwiftUI
import UIKit

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    /// Whole calendar days from this date to `other` (negative if in the past).
    func days(until other: Date) -> Int {
        Calendar.current.dateComponents([.day], from: startOfDay, to: other.startOfDay).day ?? 0
    }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}

enum Expiry {
    static func daysLeft(_ date: Date) -> Int { Date().days(until: date) }

    static func text(_ date: Date) -> String {
        let days = daysLeft(date)
        switch days {
        case ..<(-1): return "Expired \(-days) days ago"
        case -1: return "Expired yesterday"
        case 0: return "Expires today"
        case 1: return "Expires tomorrow"
        case 2...30: return "Expires in \(days) days"
        default: return "Expires \(date.formatted(.dateTime.month(.abbreviated).day().year()))"
        }
    }

    static func color(_ date: Date) -> Color {
        let days = daysLeft(date)
        if days < 0 { return .red }
        if days <= 3 { return .orange }
        return .secondary
    }
}

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

extension UIImage {
    /// Redraws the image upright so Vision reads it the right way round.
    func uprightCGImage() -> CGImage? {
        if imageOrientation == .up { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
