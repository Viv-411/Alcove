import SwiftData
import SwiftUI

/// Add stock of an existing product by hand.
struct AddStockSheet: View {
    let product: Product
    var initialLocation: StorageLocation?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StorageLocation.sortOrder) private var locations: [StorageLocation]

    @State private var quantity = 1
    @State private var location: StorageLocation?
    @State private var hasExpiry = false
    @State private var expiry = Date().adding(days: 30)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                    LocationPicker(selection: $location, locations: locations)
                }
                Section {
                    ExpiryField(hasExpiry: $hasExpiry, date: $expiry)
                }
            }
            .navigationTitle("Add \(product.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        InventoryService(context: context).add(
                            product, quantity: quantity, to: location,
                            expiration: hasExpiry ? expiry : nil, source: .manual
                        )
                        dismiss()
                    }
                }
            }
            .onAppear { if location == nil { location = initialLocation ?? locations.first } }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Edit one batch: fix the count, move it to another spot, set the expiry.
struct LotEditorSheet: View {
    let lot: StockLot

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StorageLocation.sortOrder) private var locations: [StorageLocation]

    @State private var quantity: Int
    @State private var location: StorageLocation?
    @State private var hasExpiry: Bool
    @State private var expiry: Date

    init(lot: StockLot) {
        self.lot = lot
        _quantity = State(initialValue: lot.quantity)
        _location = State(initialValue: lot.location)
        _hasExpiry = State(initialValue: lot.expirationDate != nil)
        _expiry = State(initialValue: lot.expirationDate ?? Date().adding(days: 30))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...999)
                    LocationPicker(selection: $location, locations: locations)
                }
                Section {
                    ExpiryField(hasExpiry: $hasExpiry, date: $expiry)
                }
                Section {
                    Button("Remove from home", role: .destructive) {
                        save(quantity: 0)
                    }
                } footer: {
                    Text("For items thrown out or given away. To record eating something, use the − button or Scan Out instead, so Alcove can learn your usage.")
                }
            }
            .navigationTitle(lot.product?.name ?? "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(quantity: quantity) }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save(quantity: Int) {
        InventoryService(context: context).update(
            lot, quantity: quantity, location: location, expiration: hasExpiry ? expiry : nil
        )
        dismiss()
    }
}

/// Quick expiry prompt shown while scanning when "Ask for expiry dates" is on.
struct ExpiryPromptSheet: View {
    let product: Product
    var onDone: (Date?) -> Void

    @State private var date = Date().adding(days: 30)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker("Expires", selection: $date, in: Date().adding(days: -30)..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
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
            .padding()
            .navigationTitle(product.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("No date") { onDone(nil) } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { onDone(date) } }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
}
