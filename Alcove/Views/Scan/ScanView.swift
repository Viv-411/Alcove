import SwiftData
import SwiftUI

enum ScanMode: String, CaseIterable, Identifiable {
    case stockIn, stockOut

    var id: Self { self }
    var title: String { self == .stockIn ? "Scan in" : "Scan out" }
    var tint: Color { self == .stockIn ? .accentColor : .orange }
    var symbol: String { self == .stockIn ? "arrow.down.to.line" : "arrow.up.right" }
}

private struct ScanEntry: Identifiable {
    let id = UUID()
    let event: InventoryEvent
}

private struct PendingBarcode: Identifiable {
    let id = UUID()
    let code: String
}

struct ScanView: View {
    /// Whether the Scan tab is showing; the camera only runs while it is.
    var isSelected: Bool

    @Environment(\.modelContext) private var context
    @Query(sort: \StorageLocation.sortOrder) private var locations: [StorageLocation]
    @AppStorage("scan.askForExpiry") private var askForExpiry = false

    @State private var mode: ScanMode = .stockIn
    @State private var location: StorageLocation?
    @State private var entries: [ScanEntry] = []
    @State private var pendingBarcode: PendingBarcode?
    @State private var pendingExpiryProduct: Product?
    @State private var showReceipt = false
    @State private var showManualEntry = false
    @State private var manualCode = ""
    @State private var toast: Toast?

    private var service: InventoryService { InventoryService(context: context) }

    private var scannerActive: Bool {
        isSelected && pendingBarcode == nil && pendingExpiryProduct == nil && !showReceipt && !showManualEntry
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                controls
                camera
                recentScans
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(item: $pendingBarcode) { pending in
                NewProductSheet(barcode: pending.code, initialLocation: location) { event in
                    if let event { entries.insert(ScanEntry(event: event), at: 0) }
                }
            }
            .sheet(item: $pendingExpiryProduct) { product in
                ExpiryPromptSheet(product: product) { date in
                    pendingExpiryProduct = nil
                    stockIn(product, expiration: date)
                }
            }
            .sheet(isPresented: $showReceipt) {
                ReceiptImportView(defaultLocation: location)
            }
            .alert("Enter barcode", isPresented: $showManualEntry) {
                TextField("Barcode number", text: $manualCode)
                    .keyboardType(.numberPad)
                Button(mode == .stockIn ? "Add" : "Remove") {
                    let code = manualCode
                    manualCode = ""
                    handle(code)
                }
                Button("Cancel", role: .cancel) { manualCode = "" }
            }
            .task(id: toast?.id) {
                guard toast != nil else { return }
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation { toast = nil }
            }
            .onAppear { if location == nil { location = locations.first } }
        }
    }

    // MARK: - Sections

    private var controls: some View {
        VStack(spacing: 10) {
            ModeSwitch(mode: $mode)

            HStack {
                if mode == .stockIn {
                    Text("Putting away in").foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(locations) { spot in
                            Button {
                                location = spot
                            } label: {
                                Label(spot.name, systemImage: spot.symbol)
                            }
                        }
                    } label: {
                        Label(location?.name ?? "Choose", systemImage: location?.symbol ?? "cabinet")
                            .font(.subheadline.weight(.semibold))
                    }
                } else {
                        Text("Uses up whichever expires soonest")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .font(.subheadline)
            .frame(minHeight: 22)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var camera: some View {
        ZStack {
            if BarcodeScannerView.isAvailable {
                BarcodeScannerView(isActive: scannerActive, onScan: handle)
            } else {
                Color(.secondarySystemGroupedBackground)
                ContentUnavailableView {
                    Label("Camera scanning unavailable", systemImage: "barcode.viewfinder")
                } description: {
                    Text("Barcode scanning needs an iPhone camera. You can type a barcode instead.")
                } actions: {
                    Button("Enter barcode") { showManualEntry = true }
                        .buttonStyle(.borderedProminent)
                }
            }

            VStack {
                Spacer()
                if let toast {
                    ToastView(toast: toast)
                        .padding(10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(mode.tint.opacity(0.9), lineWidth: 3)
                .animation(.snappy, value: mode)
        }
        .padding(.horizontal)
        .frame(maxHeight: .infinity)
    }

    private var recentScans: some View {
        List {
            Section {
                if entries.isEmpty {
                    Text(mode == .stockIn
                         ? "Point the camera at a barcode as you put food away."
                         : "Scan the empty package when you finish something.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    ScanEntryRow(event: entry.event) { delta in
                        adjust(entry, by: delta)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { service.revert(entries[index].event) }
                    entries.remove(atOffsets: offsets)
                }
            } header: {
                HStack {
                    Text("This session")
                    Spacer()
                    if !entries.isEmpty {
                        Button("Clear") { withAnimation { entries.removeAll() } }
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            } footer: {
                if !entries.isEmpty {
                    Text("Swipe left to undo a scan.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .frame(height: 230)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showReceipt = true
            } label: {
                Label("Receipt", systemImage: "receipt")
                    .labelStyle(.titleAndIcon)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showManualEntry = true
                } label: {
                    Label("Enter barcode", systemImage: "keyboard")
                }
                Toggle(isOn: $askForExpiry) {
                    Label("Ask for expiry dates", systemImage: "calendar.badge.clock")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Scan options")
        }
    }

    // MARK: - Scan handling

    private func handle(_ raw: String) {
        let code = Barcode.normalize(raw)
        guard !code.isEmpty else { return }

        guard let product = service.product(forBarcode: code) else {
            if mode == .stockIn {
                pendingBarcode = PendingBarcode(code: code)
            } else {
                show(Toast(title: "Not in your inventory", subtitle: "Switch to Scan in to add it.", style: .warning))
                Haptics.warning()
            }
            return
        }

        switch mode {
        case .stockIn:
            if askForExpiry {
                pendingExpiryProduct = product
            } else {
                stockIn(product, expiration: nil)
            }
        case .stockOut:
            stockOut(product)
        }
    }

    private func stockIn(_ product: Product, expiration: Date?) {
        // Several bags of the same thing in a row collapse into one row (×3).
        if let latest = entries.first?.event,
           latest.kind == .added, latest.product === product,
           latest.location === location,
           latest.expirationDate == expiration?.startOfDay {
            service.amend(latest, by: 1)
        } else if let event = service.add(product, quantity: 1, to: location, expiration: expiration, source: .scan) {
            withAnimation { entries.insert(ScanEntry(event: event), at: 0) }
        }
        show(Toast(title: "+1 \(product.name)", subtitle: "\(product.totalQuantity) at home"))
        Haptics.success()
    }

    private func stockOut(_ product: Product) {
        guard !product.isOutOfStock else {
            show(Toast(title: product.name, subtitle: "Already at 0 at home.", style: .info))
            Haptics.warning()
            return
        }
        if let latest = entries.first?.event, latest.kind == .used, latest.product === product {
            service.amend(latest, by: 1)
        } else if let event = service.use(product, quantity: 1, source: .scan) {
            withAnimation { entries.insert(ScanEntry(event: event), at: 0) }
        }
        let left = product.totalQuantity
        show(Toast(
            title: "−1 \(product.name)",
            subtitle: left == 0 ? "That was the last one" : "\(left) left",
            style: product.isLowStock ? .warning : .success
        ))
        Haptics.success()
    }

    private func adjust(_ entry: ScanEntry, by delta: Int) {
        let stillThere = service.amend(entry.event, by: delta)
        if !stillThere {
            withAnimation { entries.removeAll { $0.id == entry.id } }
        }
    }

    private func show(_ newToast: Toast) {
        withAnimation(.snappy) { toast = newToast }
    }
}

/// Big two-way switch. The selected side fills with its colour so the mode
/// is obvious at a glance while you're juggling groceries.
private struct ModeSwitch: View {
    @Binding var mode: ScanMode
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ScanMode.allCases) { option in
                Button {
                    withAnimation(.snappy) { mode = option }
                } label: {
                    Label(option.title, systemImage: option.symbol)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(mode == option ? Color.white : Color.primary)
                        .background {
                            if mode == option {
                                Capsule().fill(option.tint.gradient)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemFill), in: Capsule())
        .sensoryFeedback(.selection, trigger: mode)
    }
}

private struct ScanEntryRow: View {
    let event: InventoryEvent
    var onAdjust: (Int) -> Void

    var body: some View {
        if let product = event.product {
            HStack(spacing: 10) {
                ProductThumbnail(product: product, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(product.name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Button { onAdjust(-1) } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
                Text("\(event.kind == .added ? "+" : "−")\(event.quantity)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(event.kind == .added ? Color.accentColor : .orange)
                    .frame(minWidth: 28)
                Button { onAdjust(1) } label: { Image(systemName: "plus.circle") }
                    .buttonStyle(.borderless)
            }
            .font(.title3)
        }
    }

    private var detail: String {
        let place = event.location?.name ?? "home"
        let total = event.product?.totalQuantity ?? 0
        if event.kind == .added {
            if let expiry = event.expirationDate {
                return "\(place) · \(Expiry.text(expiry).lowercased())"
            }
            return "\(place) · \(total) at home"
        }
        return total == 0 ? "None left" : "\(total) left · \(place)"
    }
}
