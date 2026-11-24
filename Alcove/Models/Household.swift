import Foundation
import SwiftData

/// A home: its name, the people in it, and its storage spots.
/// There is one per device for now; sharing it with family comes with sync.
@Model
final class Household {
    var name: String = "My Home"
    var createdAt: Date = Date()
    /// Google account ID of the person who created it.
    var ownerID: String?

    @Relationship(deleteRule: .cascade, inverse: \HouseholdMember.household)
    var members: [HouseholdMember]? = []

    @Relationship(deleteRule: .nullify, inverse: \StorageLocation.household)
    var locations: [StorageLocation]? = []

    init(name: String, ownerID: String? = nil) {
        self.name = name
        self.ownerID = ownerID
    }

    var sortedMembers: [HouseholdMember] {
        (members ?? []).sorted { a, b in
            if a.role != b.role { return a.role == .owner }
            return a.joinedAt < b.joinedAt
        }
    }

    var sortedLocations: [StorageLocation] {
        (locations ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}

enum MemberRole: String, Codable {
    case owner, member

    var title: String { self == .owner ? "Owner" : "Member" }
}

@Model
final class HouseholdMember {
    var name: String = ""
    var email: String?
    var userID: String?
    var imageURL: String?
    var roleRaw: String = MemberRole.member.rawValue
    var joinedAt: Date = Date()
    var household: Household?

    init(name: String, email: String? = nil, userID: String? = nil, imageURL: String? = nil, role: MemberRole) {
        self.name = name
        self.email = email
        self.userID = userID
        self.imageURL = imageURL
        self.roleRaw = role.rawValue
    }

    var role: MemberRole {
        get { MemberRole(rawValue: roleRaw) ?? .member }
        set { roleRaw = newValue.rawValue }
    }
}

/// Every model type, in one place so the app, tests and previews agree.
enum AlcoveSchema {
    static let models: [any PersistentModel.Type] = [
        Product.self, StorageLocation.self, StockLot.self, InventoryEvent.self,
        Household.self, HouseholdMember.self,
    ]

    static func container(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}

/// Suggested storage spots offered when setting up a home.
struct SpaceSuggestion: Identifiable, Hashable {
    let name: String
    let symbol: String
    var id: String { name }

    static let all: [SpaceSuggestion] = [
        .init(name: "Pantry", symbol: "cabinet"),
        .init(name: "Kitchen cabinets", symbol: "tray.2"),
        .init(name: "Fridge", symbol: "refrigerator"),
        .init(name: "Freezer", symbol: "snowflake"),
        .init(name: "Garage", symbol: "door.garage.closed"),
        .init(name: "Spice rack", symbol: "leaf"),
        .init(name: "Basement", symbol: "stairs"),
        .init(name: "Garage freezer", symbol: "snowflake.circle"),
        .init(name: "Snack drawer", symbol: "takeoutbag.and.cup.and.straw"),
        .init(name: "Laundry room", symbol: "washer"),
    ]

    static let defaults = ["Pantry", "Kitchen cabinets", "Fridge", "Freezer", "Garage"]

    static func symbol(for name: String) -> String {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.symbol ?? "archivebox"
    }
}
