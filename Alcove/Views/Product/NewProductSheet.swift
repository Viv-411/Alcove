import SwiftData
import SwiftUI

/// Create a product (from an unknown barcode or by hand) and add its first stock.
struct NewProductSheet: View {
    let barcode: String?
    var initialLocation: StorageLocation?
    var onSave: (InventoryEvent?) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StorageLocation.sortOrder) private var locations: [StorageLocation]
    @Query(filter: #Predicate<Product> { $0.barcode == nil }, sort: \Product.name)
    private var productsWithoutBarcode: [Product]

    private enum LookupState { case idle, loading, found, notFound }

    @State private var lookupState: LookupState = .idle
    @State private var name = ""
    @State private var brand = ""
    @State private var packageSize = ""
    @State private var imageURL: String?
    @State private var threshold = 1
    @State private var quantity = 1
    @State private var location: StorageLocation?
    @State private var hasExpiry = false
    @State private var expiry = Date().adding(days: 30)
    @State private var linkTarget: Product?

    private var canSave: Bool {
        linkTarget != nil || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if let barcode {
                    Section {
                        lookupStatus(barcode)
                    }
                }

                if barcode != nil && !productsWithoutBarcode.isEmpty {
                    Section {
                        Picker("Already tracking it?", selection: $linkTarget) {
                            Text("No, it's new").tag(Product?.none)
                            ForEach(productsWithoutBarcode) { product in
                                Text(product.name).tag(Optional(product))
                            }
                        }
                    } footer: {
                        Text("If you added this from a receipt or by hand, link it so future scans find it.")
                    }
                }

                if linkTarget == nil {
                    Section("Item") {
                        LabeledField(label: "Name", text: $name, prompt: "e.g. Toor Dal")
                        LabeledField(label: "Brand", text: $brand, prompt: "Optional")
                        LabeledField(label: "Size", text: $packageSize, prompt: "e.g. 4 lb")
                    }
                    Section {
                        Stepper(value: $threshold, in: 0...50) {
                            LabeledContent("Low stock alert", value: threshold == 0 ? "Off" : "At \(threshold) left")
                        }
                    }
                }

                Section("Adding now") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...99)
                    LocationPicker(selection: $location, locations: locations)
                    ExpiryField(hasExpiry: $hasExpiry, date: $expiry)
                }
            }
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onSave(nil)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear { if location == nil { location = initialLocation ?? locations.first } }
            .task { await lookUp() }
        }
    }

    @ViewBuilder
    private func lookupStatus(_ barcode: String) -> some View {
        HStack(spacing: 12) {
            switch lookupState {
            case .idle, .loading:
                ProgressView()
                Text("Looking up \(barcode)…").foregroundStyle(.secondary)
            case .found:
                if let imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color(.tertiarySystemFill)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading) {
                    Text("Found it").font(.subheadline.weight(.semibold))
                    Text("Check the name looks right.").font(.caption).foregroundStyle(.secondary)
                }
            case .notFound:
                Image(systemName: "questionmark.circle").foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("Not in the product database").font(.subheadline.weight(.semibold))
                    Text("Type a name. Alcove will remember it for next time.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func lookUp() async {
        guard let barcode, lookupState == .idle else { return }
        lookupState = .loading
        if let info = await ProductLookup.lookup(barcode: barcode) {
            if name.isEmpty { name = info.name }
            if brand.isEmpty { brand = info.brand ?? "" }
            if packageSize.isEmpty { packageSize = info.packageSize ?? "" }
            imageURL = info.imageURL
            lookupState = .found
        } else {
            lookupState = .notFound
        }
    }

    private func save() {
        let service = InventoryService(context: context)
        let product: Product
        if let linkTarget {
            linkTarget.barcode = barcode.map(Barcode.normalize)
            if linkTarget.imageURL == nil { linkTarget.imageURL = imageURL }
            product = linkTarget
        } else {
            product = service.createProduct(
                name: name.trimmingCharacters(in: .whitespaces),
                barcode: barcode,
                brand: brand.isEmpty ? nil : brand,
                packageSize: packageSize.isEmpty ? nil : packageSize,
                imageURL: imageURL,
                lowStockThreshold: threshold
            )
        }

        var event: InventoryEvent?
        if quantity > 0 {
            event = service.add(product, quantity: quantity, to: location,
                                expiration: hasExpiry ? expiry : nil,
                                source: barcode == nil ? .manual : .scan)
        } else {
            service.commit()
        }
        onSave(event)
        dismiss()
    }
}
