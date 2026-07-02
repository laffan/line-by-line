import SwiftUI

/// The poems currently being memorized: every poem that has been practiced at
/// least once, ordered by its most recent session (newest first).
struct MemorizeView: View {
    @EnvironmentObject private var store: PoemStore

    var body: some View {
        NavigationStack {
            Group {
                let poems = store.poemsInProgress
                if poems.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing in Progress", systemImage: "brain.head.profile")
                    } description: {
                        Text("Practice a poem from your library and it will show up here, most recent first.")
                    }
                } else {
                    List {
                        ForEach(poems) { poem in
                            NavigationLink(value: poem.id) {
                                row(for: poem)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Memorize")
            .navigationDestination(for: UUID.self) { id in
                PoemDetailView(poemID: id)
            }
        }
    }

    private func row(for poem: Poem) -> some View {
        let stats = store.stats(for: poem)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(poem.displayTitle)
                    .font(.headline)
                Spacer()
                if stats.hasData {
                    Text(stats.successRate, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(rateColor(stats.successRate))
                }
            }
            if let last = stats.lastAttempt {
                Text("Last practiced \(last.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
