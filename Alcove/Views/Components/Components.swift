import SwiftUI

struct ProductThumbnail: View {
    let product: Product
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if let string = product.imageURL, let url = URL(string: string) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().padding(size * 0.06)
                            .background(Color.white)
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(tint.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Text(initials)
            .font(.system(size: size * (initials.count > 1 ? 0.36 : 0.42), weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
    }

    /// "Toor Dal" → "TD", "Ghee" → "G"
    private var initials: String {
        let words = product.name.split(separator: " ").filter { $0.first?.isLetter == true }
        return words.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    }

    /// A stable colour per product so lists are easy to scan.
    private var tint: Color {
        let palette: [Color] = [.green, .orange, .teal, .indigo, .pink, .brown, .cyan, .purple, .red, .mint]
        let hash = product.name.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[hash % palette.count]
    }
}

struct QuantityBadge: View {
    let quantity: Int
    var isLow: Bool = false

    var body: some View {
        Text("\(quantity)")
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(minWidth: 34)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        if quantity == 0 { return .red }
        return isLow ? .orange : .primary
    }

    private var background: Color {
        if quantity == 0 { return .red.opacity(0.14) }
        return isLow ? .orange.opacity(0.16) : Color(.tertiarySystemFill)
    }
}

struct ProductRow: View {
    let product: Product
    /// When set, the count shown is for this spot only.
    var location: StorageLocation?
    /// Replaces the automatic subtitle.
    var detail: Text?

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(product: product)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                subtitle
                    .font(.caption)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            QuantityBadge(
                quantity: location.map { product.quantity(in: $0) } ?? product.totalQuantity,
                isLow: product.isLowStock
            )
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if let detail {
            detail
        } else if let expiry = product.nextExpiration, Expiry.daysLeft(expiry) <= 7 {
            Text(Expiry.text(expiry)).foregroundStyle(Expiry.color(expiry))
        } else if location == nil, !product.locationSummary.isEmpty {
            Text(product.locationSummary).foregroundStyle(.secondary)
        } else if let subtitle = product.subtitle {
            Text(subtitle).foregroundStyle(.secondary)
        } else if product.isOutOfStock {
            Text("None at home").foregroundStyle(.secondary)
        }
    }
}

/// Compact − 2 + control that fits inside a list row.
struct CountStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...99

    var body: some View {
        HStack(spacing: 2) {
            Button {
                value = max(range.lowerBound, value - 1)
            } label: {
                Image(systemName: "minus").frame(width: 30, height: 30)
            }
            .disabled(value <= range.lowerBound)
            .accessibilityLabel("Fewer")

            Text("\(value)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(minWidth: 22)

            Button {
                value = min(range.upperBound, value + 1)
            } label: {
                Image(systemName: "plus").frame(width: 30, height: 30)
            }
            .disabled(value >= range.upperBound)
            .accessibilityLabel("More")
        }
        .font(.footnote.weight(.semibold))
        .buttonStyle(.borderless)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }
}

/// A form row with the label on the left and an editable value on the right.
struct LabeledField: View {
    let label: String
    @Binding var text: String
    var prompt: String

    var body: some View {
        LabeledContent(label) {
            TextField(label, text: $text, prompt: Text(prompt))
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.words)
        }
    }
}

struct LocationPicker: View {
    var title: String = "Space"
    @Binding var selection: StorageLocation?
    let locations: [StorageLocation]

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(locations) { location in
                Label(location.name, systemImage: location.symbol)
                    .tag(Optional(location))
            }
        }
    }
}

struct ExpiryField: View {
    @Binding var hasExpiry: Bool
    @Binding var date: Date

    var body: some View {
        Toggle("Expiry date", isOn: $hasExpiry.animation())
        if hasExpiry {
            DatePicker("Expires", selection: $date, displayedComponents: .date)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(ExpiryShortcut.all, id: \.label) { shortcut in
                        Button(shortcut.label) { date = shortcut.date() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}

struct ExpiryShortcut {
    let label: String
    let days: Int
    func date() -> Date { Date().adding(days: days) }

    static let all = [
        ExpiryShortcut(label: "1 week", days: 7),
        ExpiryShortcut(label: "1 month", days: 30),
        ExpiryShortcut(label: "3 months", days: 90),
        ExpiryShortcut(label: "6 months", days: 182),
        ExpiryShortcut(label: "1 year", days: 365),
    ]
}

struct Toast: Identifiable, Equatable {
    enum Style { case success, warning, info }
    let id = UUID()
    var title: String
    var subtitle: String?
    var style: Style = .success

    var symbol: String {
        switch style {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    var tint: Color {
        switch style {
        case .success: .green
        case .warning: .orange
        case .info: .blue
        }
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.symbol)
                .font(.title3)
                .foregroundStyle(toast.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                if let subtitle = toast.subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}
