import SwiftData
import SwiftUI

struct HomeView: View {
    var onStartScanning: () -> Void
    var onShowShoppingList: () -> Void = {}

    @Query(sort: \Product.name) private var products: [Product]
    @State private var showSettings = false
    @State private var showCook = false
    @State private var aiStatus = KitchenAI.status

    var body: some View {
        NavigationStack {
            Group {
                if products.isEmpty {
                    emptyState
                } else {
                    dashboard
                }
            }
            .navigationTitle("Alcove")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showCook) {
                if #available(iOS 26.0, *) { CookView() }
            }
            .onAppear { aiStatus = KitchenAI.status }
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
        }
    }

    // MARK: - Derived lists

    private var runningLow: [Product] {
        products.filter(\.isLowStock).sorted { $0.totalQuantity < $1.totalQuantity }
    }

    private var expiringSoon: [StockLot] {
        products.flatMap(\.activeLots)
            .filter { lot in lot.expirationDate.map { Expiry.daysLeft($0) <= 7 } ?? false }
            .sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
    }

    private var restockSoon: [(product: Product, forecast: UsageForecast)] {
        products
            .filter { !$0.isLowStock && !$0.isOutOfStock }
            .compactMap { product in UsageAnalyzer.forecast(for: product).map { (product, $0) } }
            .filter { $0.forecast.daysLeft <= 10 }
            .sorted { $0.forecast.daysLeft < $1.forecast.daysLeft }
    }

    private func lowDetail(_ product: Product) -> Text {
        if product.isOutOfStock {
            return Text("Out").foregroundStyle(.red)
        }
        let left = product.totalQuantity == 1 ? "Last one" : "\(product.totalQuantity) left"
        return Text("\(left) · \(product.locationSummary)").foregroundStyle(.secondary)
    }

    /// Distinct foods that expire within 3 days, soonest first.
    private var expiringNames: [String] {
        var names: [String] = []
        for lot in expiringSoon {
            guard let expiry = lot.expirationDate, (0...3).contains(Expiry.daysLeft(expiry)),
                  let name = lot.product?.name, !names.contains(name) else { continue }
            names.append(name)
        }
        return names
    }

    private var totalItems: Int {
        products.reduce(0) { $0 + $1.totalQuantity }
    }

    // MARK: - Views

    private var dashboard: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    StatTile(value: totalItems, label: "Items at home", symbol: "shippingbox.fill", tint: .accentColor)
                    StatTile(value: runningLow.count, label: "To buy", symbol: "cart.fill", tint: .orange)
                    StatTile(value: expiringSoon.count, label: "Use soon", symbol: "clock.fill", tint: .red)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if aiStatus != .notSupported {
                Section {
                    CookCard(status: aiStatus, useFirst: expiringNames) {
                        if aiStatus == .ready { showCook = true }
                    }
                }
            }

            if !runningLow.isEmpty {
                Section {
                    ForEach(runningLow.prefix(5)) { product in
                        NavigationLink(value: product) {
                            ProductRow(product: product, detail: lowDetail(product))
                        }
                    }
                    if runningLow.count > 5 {
                        Button("See all \(runningLow.count)", action: onShowShoppingList)
                            .font(.subheadline)
                    }
                } header: {
                    Text("To buy")
                }
            }

            if !expiringSoon.isEmpty {
                Section("Use soon") {
                    ForEach(expiringSoon) { lot in
                        if let product = lot.product, let expiry = lot.expirationDate {
                            NavigationLink(value: product) {
                                HStack(spacing: 12) {
                                    ProductThumbnail(product: product)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(product.name).font(.body.weight(.medium)).lineLimit(1)
                                        Text("\(Expiry.text(expiry)) · \(lot.location?.name ?? "Unsorted")")
                                            .font(.caption)
                                            .foregroundStyle(Expiry.color(expiry))
                                    }
                                    Spacer()
                                    QuantityBadge(quantity: lot.quantity)
                                }
                            }
                        }
                    }
                }
            }

            if !restockSoon.isEmpty {
                Section {
                    ForEach(restockSoon, id: \.product.id) { item in
                        NavigationLink(value: item.product) {
                            HStack(spacing: 12) {
                                ProductThumbnail(product: item.product)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.product.name).font(.body.weight(.medium)).lineLimit(1)
                                    Text("Runs out around \(item.forecast.runOutDate.formatted(.dateTime.month(.abbreviated).day()))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                QuantityBadge(quantity: item.product.totalQuantity)
                            }
                        }
                    }
                } header: {
                    Text("Restock soon")
                } footer: {
                    Text("Based on how fast your household has been using these.")
                }
            }

            if runningLow.isEmpty && expiringSoon.isEmpty && restockSoon.isEmpty {
                Section {
                    Label("All stocked up. Nothing needs attention.", systemImage: "checkmark.seal")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your home is empty", systemImage: "house")
        } description: {
            Text("Scan the barcodes on food as you put it away, or snap a photo of a grocery receipt.")
        } actions: {
            Button("Start scanning", action: onStartScanning)
                .buttonStyle(.borderedProminent)
        }
    }
}

/// Entry point for meal ideas from Apple Intelligence.
private struct CookCard: View {
    let status: KitchenAI.Status
    let useFirst: [String]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "frying.pan.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("What can I cook?").font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                if status == .ready {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .tint(.primary)
        .disabled(status != .ready)
        .accessibilityIdentifier("home.cook")
    }

    private var subtitle: String {
        switch status {
        case .ready:
            switch useFirst.count {
            case 0: return "Meal ideas from what's already at home."
            case 1: return "Ideas that use up your \(useFirst[0]) first."
            default: return "Ideas that use up your \(useFirst[0]) and \(useFirst[1]) first."
            }
        case .turnedOff:
            return "Turn on Apple Intelligence in Settings to get meal ideas."
        case .preparing:
            return "Apple Intelligence is still downloading. Check back soon."
        case .notSupported:
            return ""
        }
    }
}

private struct StatTile: View {
    let value: Int
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title2.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
