import SwiftUI

/// The watch home screen: poems synced from the phone.
struct WatchPoemListView: View {
    @EnvironmentObject private var store: PoemStore

    var body: some View {
        NavigationStack {
            Group {
                if store.poems.isEmpty {
                    VStack(spacing: 8) {
                        Text("Nothing here yet")
                            .font(Theme.serif(.body))
                            .foregroundStyle(Theme.ink)
                        Text("Add poems on your iPhone")
                            .sectionLabel(Theme.inkFaint)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(store.poems) { poem in
                        NavigationLink(value: poem.id) { row(for: poem) }
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("Line by Line")
            .navigationDestination(for: UUID.self) { id in
                WatchPoemDetailView(poemID: id)
            }
        }
        .tint(Theme.accent)
    }

    private func row(for poem: Poem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(poem.displayTitle)
                .font(Theme.serif(.body))
                .foregroundStyle(Theme.ink)
            if !poem.preview.isEmpty {
                Text(poem.preview)
                    .sectionLabel(Theme.inkFaint)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
