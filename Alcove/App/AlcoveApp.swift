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
            container = try AlcoveSchema.container(inMemory: inMemory)
        } catch {
            fatalError("Could not open the Alcove database: \(error)")
        }
        #if DEBUG
        DebugLaunch.prepare(container.mainContext)
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

/// Decides what to show: intro tour → sign in → set up your home → the app.
struct RootView: View {
    @State private var auth = AuthService()
    @AppStorage("intro.seen") private var hasSeenIntro = false
    @Query private var households: [Household]

    var body: some View {
        Group {
            if !hasSeenIntro {
                IntroTourView { withAnimation { hasSeenIntro = true } }
                    .transition(.opacity)
            } else {
                switch auth.state {
                case .checking:
                    LaunchView()
                case .signedOut:
                    SignInView()
                        .transition(.opacity)
                case .signedIn(let profile):
                    if households.isEmpty {
                        HomeSetupView(profile: profile)
                            .transition(.move(edge: .trailing))
                    } else {
                        MainTabView()
                            .transition(.opacity)
                    }
                }
            }
        }
        .animation(.snappy, value: auth.state)
        .animation(.snappy, value: households.isEmpty)
        .environment(auth)
        .task { await auth.restore() }
        .onOpenURL { auth.handle($0) }
    }
}

private struct LaunchView: View {
    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
    }
}

struct MainTabView: View {
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
            Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
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
