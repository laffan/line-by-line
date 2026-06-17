import SwiftUI

/// Watch view mode plus an entry point into practice.
struct WatchPoemDetailView: View {
    @EnvironmentObject private var store: PoemStore
    let poemID: UUID

    var body: some View {
        if let poem = store.poem(id: poemID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(poem.rawLines.enumerated()), id: \.offset) { _, line in
                        if line.trimmingCharacters(in: .whitespaces).isEmpty {
                            Color.clear.frame(height: 8)
                        } else {
                            Text(line)
                                .font(.body)
                        }
                    }

                    NavigationLink {
                        WatchPracticeView(poem: poem)
                    } label: {
                        Label("Practice", systemImage: "brain.head.profile")
                    }
                    .disabled(poem.practiceLines.isEmpty)
                    .padding(.top, 8)

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
            .navigationTitle(poem.displayTitle)
        } else {
            ContentUnavailableView("Not Found", systemImage: "questionmark")
        }
    }
}
