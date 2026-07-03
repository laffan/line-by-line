import SwiftUI

/// View mode: shows the whole poem, with entry points into editing and practice.
struct PoemDetailView: View {
    @EnvironmentObject private var store: PoemStore
    let poemID: UUID

    @State private var isEditing = false
    @State private var isPracticing = false

    var body: some View {
        Group {
            if let poem = store.poem(id: poemID) {
                content(for: poem)
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button { isEditing = true } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                    .sheet(isPresented: $isEditing) {
                        NavigationStack {
                            PoemEditorView(poem: poem, isNew: false)
                        }
                        .environmentObject(store)
                    }
                    .fullScreenCover(isPresented: $isPracticing) {
                        NavigationStack {
                            PracticeView(poem: poem)
                        }
                        .environmentObject(store)
                    }
            } else {
                ContentUnavailableView("Poem Not Found",
                                       systemImage: "questionmark.folder")
            }
        }
    }

    private func content(for poem: Poem) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    PoemHeader(title: poem.displayTitle, author: poem.displayAuthor)

                    ForEach(Array(poem.rawLines.enumerated()), id: \.offset) { _, line in
                        if line.trimmingCharacters(in: .whitespaces).isEmpty {
                            // Preserve stanza breaks with a little vertical space.
                            Color.clear.frame(height: 12)
                        } else {
                            Text(line)
                                .font(.body)
                        }
                    }

                    // Practice lives at the foot of the poem, so you scroll
                    // through the whole thing to reach it.
                    Button {
                        isPracticing = true
                    } label: {
                        Label("Practice", systemImage: "brain.head.profile")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 28)
                    .disabled(poem.practiceLines.isEmpty)

                    NavigationLink {
                        StatsView(poem: poem)
                    } label: {
                        StatsCard(stats: store.stats(for: poem))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            if let readingURL = store.reading(for: poem.id) {
                Divider()
                ReadingPlayerView(url: readingURL)
                    .padding(.vertical, 10)
            }
        }
    }
}

/// The centered heading shown atop a poem: the full title (wrapping, a little
/// larger) with the author centered beneath it.
struct PoemHeader: View {
    let title: String
    let author: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            if !author.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }
}
