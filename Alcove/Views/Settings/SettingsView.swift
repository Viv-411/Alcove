import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.lowStockAlerts) private var lowStockAlerts = true
    @AppStorage(SettingsKey.expiryAlerts) private var expiryAlerts = true
    @AppStorage(SettingsKey.restockAlerts) private var restockAlerts = true
    @AppStorage(SettingsKey.expiryLeadDays) private var expiryLeadDays = 3

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Home") {
                    NavigationLink {
                        LocationsView()
                    } label: {
                        Label("Storage spots", systemImage: "cabinet")
                    }
                }

                Section {
                    Toggle("Running low", isOn: $lowStockAlerts)
                    Toggle("Expiring food", isOn: $expiryAlerts)
                    if expiryAlerts {
                        Stepper(value: $expiryLeadDays, in: 0...14) {
                            LabeledContent(
                                "Remind me",
                                value: expiryLeadDays == 0 ? "On the day" : "\(expiryLeadDays) days before"
                            )
                        }
                    }
                    Toggle("Restock reminders", isOn: $restockAlerts)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Restock reminders start once Alcove has seen you use something a few times over several days.")
                }

                Section("About") {
                    LabeledContent("Version", value: version)
                    Text("Product names and photos come from Open Food Facts (openfoodfacts.org), shared under the Open Database License.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: [lowStockAlerts, expiryAlerts, restockAlerts]) { refresh() }
            .onChange(of: expiryLeadDays) { refresh() }
        }
    }

    private func refresh() {
        NotificationScheduler.shared.refresh(context: context)
    }
}

struct LocationsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StorageLocation.sortOrder) private var locations: [StorageLocation]

    @State private var editing: StorageLocation?
    @State private var adding = false

    var body: some View {
        List {
            Section {
                ForEach(locations) { location in
                    Button {
                        editing = location
                    } label: {
                        HStack {
                            Label(location.name, systemImage: location.symbol)
                            Spacer()
                            Text("\(location.itemCount) items")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            } footer: {
                Text("Deleting a spot moves anything in it to the first remaining spot.")
            }
        }
        .navigationTitle("Storage spots")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    adding = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add storage spot")
            }
        }
        .sheet(item: $editing) { LocationEditorSheet(location: $0, nextSortOrder: locations.count) }
        .sheet(isPresented: $adding) { LocationEditorSheet(location: nil, nextSortOrder: locations.count) }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = locations
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, location) in ordered.enumerated() { location.sortOrder = index }
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let doomed = locations[index]
            guard let fallback = locations.first(where: { $0 !== doomed }) else { continue }
            for lot in doomed.lots ?? [] { lot.location = fallback }
            context.delete(doomed)
        }
        try? context.save()
    }
}

private struct LocationEditorSheet: View {
    let location: StorageLocation?
    let nextSortOrder: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var symbol: String

    init(location: StorageLocation?, nextSortOrder: Int) {
        self.location = location
        self.nextSortOrder = nextSortOrder
        _name = State(initialValue: location?.name ?? "")
        _symbol = State(initialValue: location?.symbol ?? "cabinet")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Basement shelf)", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(StorageLocation.symbolChoices, id: \.self) { choice in
                            Button {
                                symbol = choice
                            } label: {
                                Image(systemName: choice)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(symbol == choice ? Color.white : Color.accentColor)
                                    .background(
                                        symbol == choice ? Color.accentColor : Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(location == nil ? "New spot" : "Edit spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let location {
            location.name = trimmed
            location.symbol = symbol
        } else {
            context.insert(StorageLocation(name: trimmed, symbol: symbol, sortOrder: nextSortOrder))
        }
        try? context.save()
        dismiss()
    }
}
