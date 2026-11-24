import SwiftData
import SwiftUI

struct HomeView: View {
    var onStartScanning: () -> Void

    @Query(sort: \Product.name) private var products: [Product]
    @State private var showSettings = false

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

    private var totalItems: Int {
        products.reduce(0) { $0 + $1.totalQuantity }
    }

    // MARK: - Views

    private var dashboard: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    StatTile(value: totalItems, label: "Items at home", symbol: "shippingbox.fill", tint: .accentColor)
                    StatTile(value: runningLow.count, label: "Running low", symbol: "arrow.down.circle.fill", tint: .orange)
                    StatTile(value: expiringSoon.count, label: "Expiring soon", symbol: "clock.fill", tint: .red)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if !runningLow.isEmpty {
                Section("Running low") {
                    ForEach(runningLow) { product in
                        NavigationLink(value: product) { ProductRow(product: product) }
                    }
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
