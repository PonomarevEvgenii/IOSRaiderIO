import SwiftUI

struct RootTabView: View {
    /// Navigation paths, owned here so the breadcrumb bar can pop to any level.
    @State private var classesPath: [Route] = []
    @State private var favoritesPath: [Route] = []

    var body: some View {
        TabView {
            NavigationStack(path: $classesPath) {
                ClassGridView()
                    .breadcrumbHeader()
                    .navigationDestination(for: Route.self) { route in
                        route.destination
                            .breadcrumbHeader()
                    }
            }
            .breadcrumbOverlay(rootTitle: "Classes", path: $classesPath)
            .tabItem { Label("Classes", systemImage: "square.grid.2x2") }

            NavigationStack(path: $favoritesPath) {
                FavoritesView()
                    .breadcrumbHeader()
                    .navigationDestination(for: Route.self) { route in
                        route.destination
                            .breadcrumbHeader()
                    }
            }
            .breadcrumbOverlay(rootTitle: "Favorites", path: $favoritesPath)
            .tabItem { Label("Favorites", systemImage: "star") }

            NavigationStack {
                SettingsView()
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootTabView()
        .environment(BuildStore.preview())
}
