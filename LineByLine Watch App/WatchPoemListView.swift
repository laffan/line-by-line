import SwiftUI

/// The watch home screen: poems synced from the phone, one under the next with
/// a hairline between them and no title above them.
struct WatchPoemListView: View {
    @EnvironmentObject private var store: PoemStore

    var body: some View {
        NavigationStack {
            Group {
                if store.poems.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationDestination(for: UUID.self) { id in
                WatchPoemDetailView(poemID: id)
            }
        }
        .tint(Theme.accent)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing here yet")
                .font(Theme.serif(.body))
                .foregroundStyle(Theme.ink)
            Text("Add poems on your iPhone")
                .sectionLabel(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var list: some View {
        List {
            ForEach(Array(store.poems.enumerated()), id: \.element.id) { index, poem in
                NavigationLink(value: poem.id) {
                    row(for: poem, ruled: index < store.poems.count - 1)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    /// One poem, ruled off from the one below it.
    private func row(for poem: Poem, ruled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(poem.displayTitle)
                .font(Theme.serif(.body))
                .foregroundStyle(Theme.ink)
            if !poem.preview.isEmpty {
                Text(poem.preview)
                    .sectionLabel(Theme.inkFaint)
                    .lineLimit(1)
            }
            if ruled {
                Hairline().padding(.top, 8)
            }
        }
        .padding(.vertical, 2)
    }
}
