import SwiftUI

/// The home screen: a list of saved poems with an add button.
struct PoemListView: View {
    @EnvironmentObject private var store: PoemStore
    @State private var newPoem: Poem?

    var body: some View {
        NavigationStack {
            Group {
                if store.poems.isEmpty {
                    ContentUnavailableView {
                        Label("No Poems Yet", systemImage: "text.book.closed")
                    } description: {
                        Text("Tap + to add a poem, or find one in the Search tab.")
                    }
                } else {
                    List {
                        ForEach(store.poems) { poem in
                            NavigationLink(value: poem.id) {
                                row(for: poem)
                            }
                        }
                        .onDelete { store.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: UUID.self) { id in
                PoemDetailView(poemID: id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newPoem = Poem()
                    } label: {
                        Label("Add Poem", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $newPoem) { poem in
                NavigationStack {
                    PoemEditorView(poem: poem, isNew: true)
                }
            }
        }
    }

    private func row(for poem: Poem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(poem.displayTitle)
                .font(.headline)
            if !poem.preview.isEmpty {
                Text(poem.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
