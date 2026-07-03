import SwiftUI

/// The app's home: three tabs.
///
/// - **Library** lists every saved poem (``PoemListView``).
/// - **Memorize** lists the poems currently being practiced, most recent
///   session first (``MemorizeView``).
/// - **Search** finds poems on PoetryDB and adds them to the library
///   (``SearchView``).
struct RootView: View {
    var body: some View {
        TabView {
            PoemListView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }

            MemorizeView()
                .tabItem {
                    Label("Memorize", systemImage: "brain.head.profile")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .fontDesign(.serif)
    }
}
