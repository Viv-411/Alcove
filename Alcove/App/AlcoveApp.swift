import SwiftData
import SwiftUI

@main
struct AlcoveApp: App {
    let container: ModelContainer

    init() {
        var inMemory = false
        #if DEBUG
        inMemory = DebugLaunch.isUITesting
        #endif
        do {
            container = try ModelContainer(
                for: Product.self, StorageLocation.self, StockLot.self, InventoryEvent.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
        } catch {
            fatalError("Could not open the Alcove database: \(error)")
        }
        SeedData.ensureDefaultLocations(in: container.mainContext)
        #if DEBUG
        if DebugLaunch.wantsSampleData { SampleData.populate(container.mainContext) }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

enum AppTab: Hashable {
    case home, inventory, scan, search
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView(
                    onStartScanning: { selection = .scan },
                    onShowShoppingList: { selection = .search }
                )
            }
            Tab("Inventory", systemImage: "square.stack.3d.up", value: AppTab.inventory) {
                InventoryView()
            }
            Tab("Scan", systemImage: "barcode.viewfinder", value: AppTab.scan) {
                ScanView(isSelected: selection == .scan)
            }
            Tab("Do I have this?", systemImage: "magnifyingglass", value: AppTab.search) {
                SearchView()
            }
        }
        .task {
            #if DEBUG
            if DebugLaunch.isUITesting { return }
            #endif
            await NotificationScheduler.shared.requestAuthorization()
            NotificationScheduler.shared.refresh(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            // Expiry wording ("expires tomorrow") depends on today's date.
            if phase == .active { NotificationScheduler.shared.refresh(context: context) }
        }
    }
}
