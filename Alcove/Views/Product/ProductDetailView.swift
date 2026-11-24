import SwiftData
import SwiftUI

struct ProductDetailView: View {
    @Bindable var product: Product

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StorageLocation.sortOrder) private var locations: [StorageLocation]

    @State private var editingLot: StockLot?
    @State private var showAddStock = false
    @State private var confirmDelete = false
    @State private var showAllHistory = false

    private var service: InventoryService { InventoryService(context: context) }

    private var sortedLots: [StockLot] {
        product.activeLots.sorted { a, b in
            let sa = a.location?.sortOrder ?? .max, sb = b.location?.sortOrder ?? .max
            if sa != sb { return sa < sb }
            return (a.expirationDate ?? .distantFuture) < (b.expirationDate ?? .distantFuture)
        }
    }

    private var recentEvents: [InventoryEvent] {
        let all = (product.events ?? []).sorted { $0.date > $1.date }
        return showAllHistory ? all : Array(all.prefix(5))
    }

    private var historyCount: Int { product.events?.count ?? 0 }

    var body: some View {
        List {
            Section { header }

            Section("At home") {
                if sortedLots.isEmpty {
                    Text("None at home").foregroundStyle(.secondary)
                }
                ForEach(sortedLots) { lot in
                    Button {
                        editingLot = lot
                    } label: {
                        LotRow(lot: lot)
                    }
                    .tint(.primary)
                }
                Button {
                    showAddStock = true
                } label: {
                    Label("Add stock", systemImage: "plus.circle")
                }
            }

            if let forecast = UsageAnalyzer.forecast(for: product) {
                Section("How fast you use it") {
                    LabeledContent("Pace", value: forecast.paceDescription)
                    if !product.isOutOfStock {
                        LabeledContent(
                            "Runs out around",
                            value: forecast.runOutDate.formatted(.dateTime.month(.abbreviated).day())
                        )
                    }
                }
            }

            Section {
                LabeledField(label: "Name", text: $product.name, prompt: "Required")
                LabeledField(label: "Brand", text: optionalBinding(\.brand), prompt: "Optional")
                LabeledField(label: "Size", text: optionalBinding(\.packageSize), prompt: "e.g. 10 kg")
                Stepper(value: $product.lowStockThreshold, in: 0...50) {
                    LabeledContent(
                        "Low stock alert",
                        value: product.lowStockThreshold == 0 ? "Off" : "At \(product.lowStockThreshold) left"
                    )
                }
                if let barcode = product.barcode {
                    LabeledContent("Barcode", value: barcode)
                        .contextMenu {
                            Button("Remove barcode", role: .destructive) { product.barcode = nil }
                        }
                }
            } header: {
                Text("Details")
            } footer: {
                Text("You'll get a heads-up when you're down to the low-stock number.")
            }

            if !recentEvents.isEmpty {
                Section("History") {
                    ForEach(recentEvents) { event in
                        HStack {
                            Image(systemName: icon(for: event))
                                .foregroundStyle(color(for: event))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.summary)
                                Text(historyDetail(event)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(event.date.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if historyCount > 5 {
                        Button(showAllHistory ? "Show less" : "Show all \(historyCount)") {
                            withAnimation { showAllHistory.toggle() }
                        }
                        .font(.subheadline)
                    }
                }
            }

            Section {
                Button("Delete item", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingLot) { LotEditorSheet(lot: $0) }
        .sheet(isPresented: $showAddStock) {
            AddStockSheet(product: product, initialLocation: product.primaryLocation ?? locations.first)
        }
        .confirmationDialog("Delete \(product.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                service.delete(product)
                dismiss()
            }
        } message: {
            Text("This removes the item and its history from your home.")
        }
        .onDisappear { try? context.save() }
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ProductThumbnail(product: product, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name).font(.title3.weight(.semibold))
                    if let subtitle = product.subtitle {
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let expiry = product.nextExpiration {
                        Text(Expiry.text(expiry)).font(.caption).foregroundStyle(Expiry.color(expiry))
                    }
                }
                Spacer(minLength: 0)
            }

            HStack {
                Button {
                    withAnimation { _ = service.use(product, quantity: 1, source: .manual) }
                    Haptics.success()
                } label: {
                    Label("Used one", systemImage: "minus")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 32)
                }
                .buttonStyle(.bordered)
                .disabled(product.isOutOfStock)

                Spacer()
                VStack(spacing: 0) {
                    Text("\(product.totalQuantity)")
                        .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(product.isOutOfStock ? .red : product.isLowStock ? .orange : .primary)
                    Text("at home").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    withAnimation {
                        _ = service.add(product, quantity: 1, to: product.primaryLocation ?? locations.first,
                                        source: .manual)
                    }
                    Haptics.success()
                } label: {
                    Label("Add one", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 32)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func optionalBinding(_ keyPath: ReferenceWritableKeyPath<Product, String?>) -> Binding<String> {
        Binding(
            get: { product[keyPath: keyPath] ?? "" },
            set: { product[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func historyDetail(_ event: InventoryEvent) -> String {
        let how = switch (event.kind, event.source) {
        case (.added, .scan): "Scanned in"
        case (.added, .receipt): "From a receipt"
        case (.added, .manual): "Added by hand"
        case (.used, .scan): "Scanned out"
        case (.used, _): "Marked as used"
        case (.adjusted, _): "Count corrected"
        }
        if let location = event.location { return "\(how) · \(location.name)" }
        return how
    }

    private func icon(for event: InventoryEvent) -> String {
        switch event.kind {
        case .added: "arrow.down.to.line"
        case .used: "arrow.up.right"
        case .adjusted: "slider.horizontal.3"
        }
    }

    private func color(for event: InventoryEvent) -> Color {
        switch event.kind {
        case .added: .green
        case .used: .orange
        case .adjusted: .secondary
        }
    }
}

private struct LotRow: View {
    let lot: StockLot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: lot.location?.symbol ?? "questionmark.folder")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(lot.location?.name ?? "Unsorted")
                if let expiry = lot.expirationDate {
                    Text(Expiry.text(expiry)).font(.caption).foregroundStyle(Expiry.color(expiry))
                } else {
                    Text("No expiry date").font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            QuantityBadge(quantity: lot.quantity)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
