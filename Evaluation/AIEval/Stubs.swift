import Foundation

// Just enough of the app's model types for the AI source files to compile
// outside the app. The AI code itself is the app's real code.
final class StorageLocation { var name = "" }
final class Product {
    var name = ""
    var brand: String?
    var receiptAliases: [String] = []
    var totalQuantity = 0
    var nextExpiration: Date?
    var primaryLocation: StorageLocation?
    var isOutOfStock: Bool { totalQuantity == 0 }
}
enum Expiry { static func daysLeft(_ date: Date) -> Int { 0 } }
