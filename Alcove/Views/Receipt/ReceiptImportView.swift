import PhotosUI
import SwiftData
import SwiftUI
import VisionKit

/// Snap a grocery receipt, review the items Alcove found, add them in one go.
struct ReceiptImportView: View {
    var defaultLocation: StorageLocation?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Product.name) private var products: [Product]
    @Query(sort: \StorageLocation.sortOrder) private var locations: [StorageLocation]

    private enum Stage { case choose, reading, review }

    @State private var stage: Stage = .choose
    @State private var candidates: [ReceiptCandidate] = []
    @State private var location: StorageLocation?
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var message: String?

    private var includedCount: Int { candidates.filter(\.include).count }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .choose: chooser
                case .reading: ProgressView("Reading receipt…").frame(maxHeight: .infinity)
                case .review: review
                }
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if stage == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add \(includedCount)", action: commit)
                            .disabled(includedCount == 0)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                DocumentCameraView { images in
                    showCamera = false
                    if !images.isEmpty { read(images) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await loadPhoto(item) }
            }
            .onAppear { if location == nil { location = defaultLocation ?? locations.first } }
        }
    }

    // MARK: - Stages

    private var chooser: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "receipt")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            VStack(spacing: 6) {
                Text("Add a whole shopping trip").font(.title3.weight(.semibold))
                Text("Take a photo of your receipt. Alcove reads it on your phone, and you check the items before anything is added.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let message {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: 10) {
                if VNDocumentCameraViewController.isSupported {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Scan receipt", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Choose a photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(24)
    }

    private var review: some View {
        List {
            Section {
                LocationPicker(title: "Put away in", selection: $location, locations: locations)
            } footer: {
                Text("You can move individual items to other spots later.")
            }
            Section {
                ForEach($candidates) { $candidate in
                    ReceiptCandidateRow(candidate: $candidate, products: products)
                }
            } header: {
                Text("\(candidates.count) items found")
            } footer: {
                Text("Receipts use short names. Matching an item to one you already track teaches Alcove for next time.")
            }
        }
    }

    // MARK: - Actions

    private func loadPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)?.uprightCGImage() else {
            message = "Couldn't open that photo."
            return
        }
        read([image])
    }

    private func read(_ images: [CGImage]) {
        stage = .reading
        message = nil
        Task {
            let lines = await ReceiptTextRecognizer.recognizeLines(in: ReceiptImages(images: images))
            let parsed = ReceiptParser.parse(lines: lines)
            candidates = parsed.map { line in
                let match = ProductMatcher.bestMatch(for: line.name, in: products)
                return ReceiptCandidate(receiptName: line.name, name: match?.name ?? line.name,
                                        quantity: line.quantity, match: match)
            }
            if candidates.isEmpty {
                message = "Couldn't find any items on that receipt. Try a flatter, well-lit photo."
                stage = .choose
            } else {
                stage = .review
            }
        }
    }

    private func commit() {
        let service = InventoryService(context: context)
        var created: [String: Product] = [:]

        for candidate in candidates where candidate.include {
            let name = candidate.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let key = ProductMatcher.aliasKey(name)
            let product = candidate.match ?? created[key] ?? service.createProduct(name: name)
            created[key] = product

            let alias = ProductMatcher.aliasKey(candidate.receiptName)
            if !product.receiptAliases.contains(alias) {
                product.receiptAliases.append(alias)
            }
            service.add(product, quantity: candidate.quantity, to: location, source: .receipt)
        }
        Haptics.success()
        dismiss()
    }
}

struct ReceiptCandidate: Identifiable {
    let id = UUID()
    /// As printed (cleaned up), used to learn the alias.
    var receiptName: String
    var name: String
    var quantity: Int
    var include = true
    var match: Product?
}

private struct ReceiptCandidateRow: View {
    @Binding var candidate: ReceiptCandidate
    let products: [Product]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                candidate.include.toggle()
            } label: {
                Image(systemName: candidate.include ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(candidate.include ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Item name", text: $candidate.name)
                    .font(.body.weight(.medium))
                    .disabled(candidate.match != nil)

                Menu {
                    Button {
                        candidate.match = nil
                        candidate.name = candidate.receiptName
                    } label: {
                        Label("New item", systemImage: "plus")
                    }
                    Divider()
                    ForEach(products) { product in
                        Button(product.name) {
                            candidate.match = product
                            candidate.name = product.name
                        }
                    }
                } label: {
                    Label(
                        candidate.match == nil ? "New item" : "Matched to your item",
                        systemImage: candidate.match == nil ? "plus.circle" : "link"
                    )
                    .font(.caption)
                }

                if candidate.receiptName != candidate.name {
                    Text("On receipt: \(candidate.receiptName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Stepper("×\(candidate.quantity)", value: $candidate.quantity, in: 1...99)
                .font(.subheadline.monospacedDigit())
                .fixedSize()
        }
        .opacity(candidate.include ? 1 : 0.45)
    }
}

/// VisionKit's document camera: auto edge detection and perspective correction.
struct DocumentCameraView: UIViewControllerRepresentable {
    var onFinish: ([CGImage]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([CGImage]) -> Void

        init(onFinish: @escaping ([CGImage]) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).uprightCGImage() }
            onFinish(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish([])
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish([])
        }
    }
}
