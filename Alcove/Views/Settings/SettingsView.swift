import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Query(sort: \Household.createdAt) private var households: [Household]

    @AppStorage(SettingsKey.lowStockAlerts) private var lowStockAlerts = true
    @AppStorage(SettingsKey.expiryAlerts) private var expiryAlerts = true
    @AppStorage(SettingsKey.restockAlerts) private var restockAlerts = true
    @AppStorage(SettingsKey.expiryLeadDays) private var expiryLeadDays = 3

    @State private var showTour = false
    @State private var confirmSignOut = false

    private var household: Household? { households.first }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        NavigationStack {
            Form {
                if let profile = auth.profile {
                    Section {
                        HStack(spacing: 14) {
                            Avatar(name: profile.name, imageURL: profile.imageURL, size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name).font(.headline)
                                Text(profile.isGuest ? "Not signed in · this iPhone only" : (profile.email ?? "Google account"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let household {
                    Section("Home") {
                        NavigationLink {
                            HomeDetailView(household: household)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "house.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(household.name).font(.body.weight(.medium))
                                    Text(homeSummary(household)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("settings.home")
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

                Section {
                    Button {
                        showTour = true
                    } label: {
                        Label("Take the tour again", systemImage: "sparkles")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: version)
                    Text("Product names and photos come from Open Food Facts (openfoodfacts.org), shared under the Open Database License.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Sign out", role: .destructive) { confirmSignOut = true }
                } footer: {
                    Text("Your home stays on this iPhone when you sign out.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: [lowStockAlerts, expiryAlerts, restockAlerts]) { refresh() }
            .onChange(of: expiryLeadDays) { refresh() }
            .fullScreenCover(isPresented: $showTour) {
                IntroTourView(finishTitle: "Done") { showTour = false }
            }
            .confirmationDialog("Sign out of Alcove?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    dismiss()
                    auth.signOut()
                }
            }
        }
    }

    private func homeSummary(_ household: Household) -> String {
        let spaces = household.locations?.count ?? 0
        let people = household.members?.count ?? 0
        return "\(spaces) \(spaces == 1 ? "space" : "spaces") · \(people) \(people == 1 ? "person" : "people")"
    }

    private func refresh() {
        NotificationScheduler.shared.refresh(context: context)
    }
}

/// Edit the home: its name, spaces and people.
struct HomeDetailView: View {
    @Bindable var household: Household
    @Environment(\.modelContext) private var context
    @Query(sort: \StorageLocation.sortOrder) private var locations: [StorageLocation]

    var body: some View {
        Form {
            Section("Name") {
                TextField("Home name", text: $household.name)
                    .textInputAutocapitalization(.words)
            }

            Section {
                NavigationLink {
                    LocationsView()
                } label: {
                    LabeledContent("Manage spaces") {
                        Text("\(locations.count)")
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(locations) { location in
                            Label(location.name, systemImage: location.symbol)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Text("Spaces")
            }

            Section {
                ForEach(household.sortedMembers) { member in
                    MemberRow(
                        name: member.name,
                        detail: member.email ?? "On this iPhone",
                        imageURL: member.imageURL.flatMap(URL.init(string:)),
                        badge: member.role.title
                    )
                    .listRowInsets(EdgeInsets())
                }
                HStack {
                    Label("Invite family", systemImage: "person.badge.plus")
                    Spacer()
                    Text("Coming soon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
                .foregroundStyle(.secondary)
            } header: {
                Text("People")
            } footer: {
                Text("Soon you'll be able to invite family so everyone sees the same inventory.")
            }
        }
        .navigationTitle(household.name.isEmpty ? "Home" : household.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
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
                Text("Drag to reorder. Deleting a space moves anything in it to the first remaining space.")
            }
        }
        .navigationTitle("Spaces")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    adding = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add space")
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
            .navigationTitle(location == nil ? "New space" : "Edit space")
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
            let new = StorageLocation(name: trimmed, symbol: symbol, sortOrder: nextSortOrder)
            context.insert(new)
            new.household = HouseholdService(context: context).current()
        }
        try? context.save()
        dismiss()
    }
}
