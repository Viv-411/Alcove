import Foundation
import SwiftData

struct SpaceDraft: Identifiable, Hashable {
    var name: String
    var symbol: String
    var id: String { name.lowercased() }
}

/// Creating and editing the home and its spaces.
struct HouseholdService {
    let context: ModelContext

    func current() -> Household? {
        try? context.fetch(FetchDescriptor<Household>(sortBy: [SortDescriptor(\.createdAt)])).first
    }

    /// Creates the home (or updates the existing one) with these spaces, in order.
    /// Existing spaces that weren't picked are removed if empty, kept if they hold food.
    @discardableResult
    func setUp(name: String, spaces: [SpaceDraft], owner: UserProfile) -> Household {
        let household = current() ?? {
            let new = Household(name: name, ownerID: owner.id)
            context.insert(new)
            return new
        }()
        household.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? "My Home" : name.trimmingCharacters(in: .whitespaces)
        household.ownerID = owner.id
        ensureOwner(owner, in: household)

        let existing = (try? context.fetch(FetchDescriptor<StorageLocation>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        var kept: [StorageLocation] = []
        for (index, draft) in spaces.enumerated() {
            let location = existing.first { $0.name.caseInsensitiveCompare(draft.name) == .orderedSame } ?? {
                let new = StorageLocation(name: draft.name, symbol: draft.symbol)
                context.insert(new)
                return new
            }()
            location.sortOrder = index
            location.household = household
            kept.append(location)
        }
        var next = kept.count
        for location in existing where !kept.contains(where: { $0 === location }) {
            if location.itemCount == 0 {
                context.delete(location)
            } else {
                location.sortOrder = next
                location.household = household
                next += 1
            }
        }
        try? context.save()
        return household
    }

    func ensureOwner(_ owner: UserProfile, in household: Household) {
        let members = household.members ?? []
        if let existing = members.first(where: { $0.role == .owner }) {
            existing.name = owner.name
            existing.email = owner.email
            existing.userID = owner.id
            existing.imageURL = owner.imageURL?.absoluteString
        } else {
            let member = HouseholdMember(name: owner.name, email: owner.email, userID: owner.id,
                                         imageURL: owner.imageURL?.absoluteString, role: .owner)
            context.insert(member)
            member.household = household
        }
    }

    func addSpace(name: String, symbol: String, to household: Household?) {
        let count = (try? context.fetchCount(FetchDescriptor<StorageLocation>())) ?? 0
        let location = StorageLocation(name: name, symbol: symbol, sortOrder: count)
        context.insert(location)
        location.household = household
        try? context.save()
    }
}
