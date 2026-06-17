import SwiftUI

/// The watch home screen: poems synced from the phone.
struct WatchPoemListView: View {
    @EnvironmentObject private var store: PoemStore

    var body: some View {
        NavigationStack {
            Group {
                if store.poems.isEmpty {
                    ContentUnavailableView {
                        Label("No Poems", systemImage: "text.book.closed")
                    } description: {
                        Text("Add poems on your iPhone to see them here.")
                    }
                } else {
                    List(store.poems) { poem in
                        NavigationLink(value: poem.id) {
                            VStack(alignment: .leading) {
                                Text(poem.displayTitle)
                                    .font(.headline)
                                if !poem.preview.isEmpty {
                                    Text(poem.preview)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Line by Line")
            .navigationDestination(for: UUID.self) { id in
                WatchPoemDetailView(poemID: id)
            }
        }
    }
}
