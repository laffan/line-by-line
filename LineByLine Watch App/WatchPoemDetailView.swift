import SwiftUI

/// Watch poem screen. Page 1 is the poem (view mode); swipe right-to-left to
/// reach practice mode.
struct WatchPoemDetailView: View {
    @EnvironmentObject private var store: PoemStore
    let poemID: UUID

    var body: some View {
        if let poem = store.poem(id: poemID) {
            TabView {
                poemPage(poem)
                if !poem.practiceLines.isEmpty {
                    WatchPracticeView(poem: poem)
                }
            }
            .tabViewStyle(.page)
            .navigationTitle(poem.displayTitle)
        } else {
            ContentUnavailableView("Not Found", systemImage: "questionmark")
        }
    }

    private func poemPage(_ poem: Poem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if !poem.displayAuthor.isEmpty {
                    Text(poem.displayAuthor)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(poem.rawLines.enumerated()), id: \.offset) { _, line in
                    if line.trimmingCharacters(in: .whitespaces).isEmpty {
                        Color.clear.frame(height: 8)
                    } else {
                        Text(line)
                            .font(.body)
                    }
                }

                let stats = store.stats(for: poem)
                if stats.hasData {
                    HStack {
                        Label("Success", systemImage: "chart.bar.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(stats.successRate, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
