import SwiftData
import SwiftUI

struct InventoryView: View {
    @Query(sort: \Product.name) private var products: [Product]
    @Query(sort: \StorageLocation.sortOrder) private var locations: [StorageLocation]

    @State private var selectedLocationID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var showNewProduct = false

    private var selectedLocation: StorageLocation? {
        locations.first { $0.persistentModelID == selectedLocationID }
    }

    private var matching: [Product] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return products }
        return products.filter { product in
            product.name.localizedStandardContains(query)
                || (product.brand?.localizedStandardContains(query) ?? false)
                || (product.barcode?.contains(query) ?? false)
        }
    }

    private var inStock: [Product] {
        if let location = selectedLocation {
            return matching.filter { $0.quantity(in: location) > 0 }
        }
        return matching.filter { !$0.isOutOfStock }
    }

    private var outOfStock: [Product] {
        selectedLocation == nil ? matching.filter(\.isOutOfStock) : []
    }

    var body: some View {
        NavigationStack {
            List {
                if inStock.isEmpty && outOfStock.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                }
                if !inStock.isEmpty {
                    Section(selectedLocation?.name ?? "At home") {
                        ForEach(inStock) { product in
                            NavigationLink(value: product) {
                                ProductRow(product: product, location: selectedLocation)
                            }
                        }
                    }
                }
                if !outOfStock.isEmpty {
                    Section("Out of stock") {
                        ForEach(outOfStock) { product in
                            NavigationLink(value: product) { ProductRow(product: product) }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { locationChips }
            .navigationTitle("Inventory")
            .searchable(text: $searchText, prompt: "Search items")
            .navigationDestination(for: Product.self) { ProductDetailView(product: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewProduct = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add item")
                }
            }
            .sheet(isPresented: $showNewProduct) {
                NewProductSheet(barcode: nil, initialLocation: selectedLocation)
            }
        }
    }

    private var locationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                LocationChip(title: "All", symbol: "square.grid.2x2", count: nil,
                             isSelected: selectedLocationID == nil) {
                    selectedLocationID = nil
                }
                ForEach(locations) { location in
                    LocationChip(title: location.name, symbol: location.symbol, count: location.itemCount,
                                 isSelected: selectedLocationID == location.persistentModelID) {
                        selectedLocationID = location.persistentModelID
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if let location = selectedLocation {
            ContentUnavailableView(
                "Nothing in \(location.name)",
                systemImage: location.symbol,
                description: Text("Scan items in with this spot selected to see them here.")
            )
        } else {
            ContentUnavailableView(
                "No items yet",
                systemImage: "barcode.viewfinder",
                description: Text("Use the Scan tab to add food as you put it away.")
            )
        }
    }
}

private struct LocationChip: View {
    let title: String
    let symbol: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .opacity(0.7)
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
