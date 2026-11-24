import SwiftData
import SwiftUI

/// "Do I have this?": built for standing in a grocery aisle.
struct SearchView: View {
    @Query(sort: \Product.name) private var products: [Product]
    @State private var query = ""
    @State private var showScanner = false

    private var results: [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return products
            .filter { $0.name.localizedStandardContains(trimmed) || ($0.brand?.localizedStandardContains(trimmed) ?? false) }
            .sorted { $0.totalQuantity > $1.totalQuantity }
    }

    private var shoppingList: [Product] {
        products.filter(\.isLowStock).sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section {
                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan a barcode in the store", systemImage: "barcode.viewfinder")
                                .font(.body.weight(.medium))
                        }
                    } footer: {
                        Text("Or type above to search everything at home.")
                    }

                    if !shoppingList.isEmpty {
                        Section {
                            ForEach(shoppingList) { product in
                                NavigationLink(value: product) { SearchResultRow(product: product) }
                            }
                        } header: {
                            Text("Running low")
                        } footer: {
                            Text("Your shopping list, built from what's running low.")
                        }
                    }
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "No \"\(query)\" at home",
                        systemImage: "cart.badge.plus",
                        description: Text("Nothing in your inventory matches, so it's probably safe to buy.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(results) { product in
                        NavigationLink(value: product) { SearchResultRow(product: product) }
                    }
                }
            }
            .navigationTitle("Do I have this?")
            .searchable(text: $query, prompt: "Atta, rice, chips…")
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
            .sheet(isPresented: $showScanner) { CheckBarcodeSheet() }
        }
    }
}

private struct SearchResultRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(product: product)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.body.weight(.medium)).lineLimit(1)
                if product.isOutOfStock {
                    Text("None at home").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(product.locationSummary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            HaveBadge(quantity: product.totalQuantity, isLow: product.isLowStock)
        }
    }
}

private struct HaveBadge: View {
    let quantity: Int
    let isLow: Bool

    var body: some View {
        Text(quantity == 0 ? "Buy" : "Have \(quantity)")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(.white)
            .background(color, in: Capsule())
    }

    private var color: Color {
        if quantity == 0 { return .red }
        return isLow ? .orange : .green
    }
}

/// Scan a product on the store shelf to see if it's already at home.
struct CheckBarcodeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private enum Result: Equatable {
        case found(Product)
        case unknown(String)
    }

    @State private var result: Result?
    @State private var typedCode = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if BarcodeScannerView.isAvailable {
                    BarcodeScannerView(isActive: true, onScan: check)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    Form {
                        Section {
                            TextField("Barcode number", text: $typedCode)
                                .keyboardType(.numberPad)
                            Button("Check") { check(typedCode) }
                        } footer: {
                            Text("Camera scanning needs a real iPhone.")
                        }
                    }
                }

                if let result {
                    resultCard(result)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Do I have this?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private func resultCard(_ result: Result) -> some View {
        HStack(spacing: 14) {
            switch result {
            case .found(let product):
                ProductThumbnail(product: product, size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name).font(.headline).lineLimit(2)
                    if product.isOutOfStock {
                        Text("You're out. Buy it.").foregroundStyle(.red).font(.subheadline.weight(.semibold))
                    } else {
                        Text("You have \(product.totalQuantity) at home")
                            .foregroundStyle(product.isLowStock ? .orange : .green)
                            .font(.subheadline.weight(.semibold))
                        Text(product.locationSummary).font(.caption).foregroundStyle(.secondary)
                        if let expiry = product.nextExpiration {
                            Text(Expiry.text(expiry)).font(.caption).foregroundStyle(Expiry.color(expiry))
                        }
                    }
                }
            case .unknown(let code):
                Image(systemName: "questionmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Not in your inventory").font(.headline)
                    Text("You haven't scanned \(code) at home before.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private func check(_ raw: String) {
        let code = Barcode.normalize(raw)
        guard !code.isEmpty else { return }
        let product = InventoryService(context: context).product(forBarcode: code)
        withAnimation(.snappy) {
            result = product.map(Result.found) ?? .unknown(code)
        }
        Haptics.success()
    }
}
