import SwiftData
import SwiftUI

/// After signing in: name the home, choose its spaces, see who's in it.
struct HomeSetupView: View {
    let profile: UserProfile
    /// Called when setup finishes. Editing an existing home from Settings
    /// reuses this flow, so it doesn't assume it's the first run.
    var onDone: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Query(sort: \StorageLocation.sortOrder) private var existingLocations: [StorageLocation]

    @State private var step = 0
    @State private var name = ""
    @State private var options: [SpaceDraft] = []
    @State private var selected: [SpaceDraft] = []
    @State private var customSpace = ""
    @FocusState private var nameFocused: Bool
    @FocusState private var customFocused: Bool

    private let stepCount = 3

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.top, 12)
                .padding(.horizontal, 24)

            ScrollView {
                Group {
                    switch step {
                    case 0: nameStep
                    case 1: spacesStep
                    default: peopleStep
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)
            }
            .scrollDismissesKeyboard(.interactively)

            buttons
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: prepare)
    }

    // MARK: - Steps

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header(symbol: "house.fill", tint: .accentColor,
                   title: "Name your home",
                   message: "This is what your family will see when they join.")
            TextField("Home name", text: $name)
                .font(.title3.weight(.semibold))
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($nameFocused)
                .onSubmit { advance() }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("setup.name")
        }
    }

    private var spacesStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header(symbol: "square.grid.2x2.fill", tint: .teal,
                   title: "Where do you keep food?",
                   message: "Pick the spaces in your home. You can rename, reorder or add more any time.")

            FlowLayout(spacing: 10) {
                ForEach(options) { space in
                    SpaceChip(space: space, isSelected: selected.contains(space)) {
                        toggle(space)
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                TextField("Add your own (e.g. Chest freezer)", text: $customSpace)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($customFocused)
                    .onSubmit(addCustom)
                if !customSpace.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: addCustom)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(selected.isEmpty ? "Pick at least one space." : "\(selected.count) spaces selected")
                .font(.footnote)
                .foregroundStyle(selected.isEmpty ? .orange : .secondary)
        }
    }

    private var peopleStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            header(symbol: "person.2.fill", tint: .pink,
                   title: "Who lives here?",
                   message: "Everyone in your home will see the same inventory, so nobody buys what you already have.")

            VStack(spacing: 0) {
                MemberRow(name: profile.name, detail: profile.email ?? "On this iPhone", imageURL: profile.imageURL,
                          badge: profile.isGuest ? "Owner" : "You · Owner")
                Divider().padding(.leading, 68)
                HStack(spacing: 14) {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 42, height: 42)
                        .background(Color(.tertiarySystemFill), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite family").foregroundStyle(.secondary)
                        Text("Coming soon").font(.caption).foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(14)
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Chrome

    private func header(symbol: String, tint: Color, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepCount, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(height: 5)
            }
        }
        .animation(.snappy, value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step + 1) of \(stepCount)")
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    withAnimation(.snappy) { step -= 1 }
                } label: {
                    Text("Back").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: 120)
            }
            Button(action: advance) {
                Text(step == stepCount - 1 ? "Finish" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canAdvance)
            .accessibilityIdentifier("setup.continue")
        }
    }

    // MARK: - Logic

    private var canAdvance: Bool {
        switch step {
        case 0: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: !selected.isEmpty
        default: true
        }
    }

    private func prepare() {
        guard options.isEmpty else { return }
        let current = HouseholdService(context: context).current()
        name = current?.name ?? "\(profile.isGuest ? "My" : profile.firstName + "'s") Home"

        var drafts = SpaceSuggestion.all.map { SpaceDraft(name: $0.name, symbol: $0.symbol) }
        for location in existingLocations where !drafts.contains(where: { $0.id == location.name.lowercased() }) {
            drafts.append(SpaceDraft(name: location.name, symbol: location.symbol))
        }
        options = drafts

        let preselected = existingLocations.isEmpty
            ? SpaceSuggestion.defaults
            : existingLocations.map(\.name)
        selected = preselected.compactMap { name in drafts.first { $0.id == name.lowercased() } }
        if step == 0 { nameFocused = true }
    }

    private func toggle(_ space: SpaceDraft) {
        withAnimation(.snappy) {
            if let index = selected.firstIndex(of: space) {
                selected.remove(at: index)
            } else {
                selected.append(space)
            }
        }
    }

    private func addCustom() {
        let trimmed = customSpace.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let draft = options.first { $0.id == trimmed.lowercased() }
            ?? SpaceDraft(name: trimmed, symbol: SpaceSuggestion.symbol(for: trimmed))
        withAnimation(.snappy) {
            if !options.contains(draft) { options.append(draft) }
            if !selected.contains(draft) { selected.append(draft) }
        }
        customSpace = ""
    }

    private func advance() {
        guard canAdvance else { return }
        nameFocused = false
        customFocused = false
        if step < stepCount - 1 {
            withAnimation(.snappy) { step += 1 }
        } else {
            HouseholdService(context: context).setUp(name: name, spaces: selected, owner: profile)
            Haptics.success()
            onDone()
        }
    }
}

private struct SpaceChip: View {
    let space: SpaceDraft
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? "checkmark" : space.symbol)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 18)
                Text(space.name)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay {
                Capsule().strokeBorder(isSelected ? Color.clear : Color(.separator), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MemberRow: View {
    let name: String
    let detail: String
    let imageURL: URL?
    var badge: String?

    var body: some View {
        HStack(spacing: 14) {
            Avatar(name: name, imageURL: imageURL, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
        }
        .padding(14)
    }
}

struct Avatar: View {
    let name: String
    let imageURL: URL?
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Color.accentColor.gradient)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    }
}

/// Lays children out left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
