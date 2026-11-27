import SwiftData
import SwiftUI

/// "What can I cook?": meal ideas from what's at home, made on the phone by
/// Apple Intelligence. Food that expires soon is used first.
@available(iOS 26.0, *)
struct CookView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Product.name) private var products: [Product]

    @State private var generator = RecipeGenerator()
    @State private var preferences = RecipePreferences()
    @State private var lastAsked: RecipePreferences?
    @FocusState private var noteFocused: Bool

    private var pantry: [PantryItem] { PantryItem.snapshot(of: products) }
    private var expiring: [String] { pantry.filter(\.isExpiringSoon).map(\.name) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !expiring.isEmpty { useFirst }
                    preferencesBar
                    results
                    footnote
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("What can I cook?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe, expiring: Set(expiring))
            }
        }
        .onAppear {
            if generator.phase == .idle { suggest(fresh: true) }
        }
        .onDisappear { generator.cancel() }
        .sensoryFeedback(.success, trigger: generator.phase == .done)
    }

    private func suggest(fresh: Bool) {
        noteFocused = false
        lastAsked = preferences
        generator.generate(pantry: pantry, preferences: preferences, freshBatch: fresh)
    }

    // MARK: - Sections

    private var useFirst: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Use these first", systemImage: "clock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            FlowLayout(spacing: 6) {
                ForEach(expiring, id: \.self) { name in
                    IngredientChip(name: name, style: .expiring)
                }
            }
        }
        .padding(.top, 8)
    }

    private var preferencesBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ToggleChip(title: "Under 20 min", symbol: "timer", isOn: $preferences.quick)
                ToggleChip(title: "Vegetarian", symbol: "leaf", isOn: $preferences.vegetarian)
            }
            HStack(spacing: 8) {
                TextField("Craving anything? e.g. something spicy", text: $preferences.note)
                    .focused($noteFocused)
                    .submitLabel(.go)
                    .onSubmit { suggest(fresh: true) }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .accessibilityIdentifier("cook.note")
                if preferences != lastAsked, generator.phase != .thinking {
                    Button {
                        suggest(fresh: true)
                    } label: {
                        Image(systemName: "arrow.forward")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Suggest meals")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy, value: preferences != lastAsked)
        }
    }

    @ViewBuilder
    private var results: some View {
        switch generator.phase {
        case .idle:
            EmptyView()
        case .thinking:
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    let idea = i < generator.partial.count ? generator.partial[i] : nil
                    StreamingCard(title: idea?.title, summary: idea?.summary, minutes: idea?.minutes)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Thinking of meals")
        case .done:
            VStack(spacing: 12) {
                ForEach(generator.recipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeCard(recipe: recipe, expiring: Set(expiring))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    suggest(fresh: false)
                } label: {
                    Label("More ideas", systemImage: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("cook.more")
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again") { suggest(fresh: true) }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private var footnote: some View {
        Label("Made on your iPhone by Apple Intelligence, using only what's in Alcove. Double-check ingredients for allergies.",
              systemImage: "apple.intelligence")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Cards

private struct StreamingCard: View {
    var title: String?
    var summary: String?
    var minutes: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title ?? "Thinking of a dish")
                    .font(.headline)
                    .redacted(reason: title == nil ? .placeholder : [])
                Spacer()
                if let minutes { MinutesBadge(minutes: minutes) }
            }
            Text(summary ?? "Looking through what's at home for something good to cook.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .redacted(reason: summary == nil ? .placeholder : [])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .phaseAnimator([0.55, 1]) { view, opacity in
            view.opacity(title == nil ? opacity : 1)
        } animation: { _ in .easeInOut(duration: 0.8) }
    }
}

private struct RecipeCard: View {
    let recipe: Recipe
    let expiring: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                MinutesBadge(minutes: recipe.minutes)
            }
            Text(recipe.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 6) {
                ForEach(recipe.have, id: \.self) { name in
                    IngredientChip(name: name, style: expiring.contains(name) ? .expiring : .have)
                }
                ForEach(recipe.need, id: \.self) { name in
                    IngredientChip(name: name, style: .need)
                }
            }
            HStack(spacing: 4) {
                Text(recipe.need.isEmpty ? "Everything's at home" : "Need \(recipe.need.count) more")
                Spacer()
                Text("Steps")
                Image(systemName: "chevron.right").imageScale(.small)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

@available(iOS 26.0, *)
private struct RecipeDetailView: View {
    let recipe: Recipe
    let expiring: Set<String>

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    MinutesBadge(minutes: recipe.minutes)
                    Text(recipe.summary)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            Section("From home") {
                ForEach(recipe.have, id: \.self) { name in
                    Label {
                        Text(name)
                    } icon: {
                        Image(systemName: expiring.contains(name) ? "clock.fill" : "checkmark.circle.fill")
                            .foregroundStyle(expiring.contains(name) ? .orange : .green)
                    }
                }
            }
            if !recipe.need.isEmpty {
                Section("To buy") {
                    ForEach(recipe.need, id: \.self) { name in
                        Label(name, systemImage: "cart")
                    }
                }
            }
            Section("Steps") {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 20)
                        Text(step)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(recipe.title)
    }
}

// MARK: - Small pieces

private struct MinutesBadge: View {
    let minutes: Int
    var body: some View {
        Label("\(minutes) min", systemImage: "clock")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }
}

private struct IngredientChip: View {
    enum Style { case have, expiring, need }
    let name: String
    let style: Style

    var body: some View {
        Label(name, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .lineLimit(1)
    }

    private var symbol: String {
        switch style {
        case .have: "checkmark"
        case .expiring: "clock"
        case .need: "cart"
        }
    }

    private var tint: Color {
        switch style {
        case .have: .green
        case .expiring: .orange
        case .need: .secondary
        }
    }
}

private struct ToggleChip: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .background(isOn ? Color.accentColor : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
