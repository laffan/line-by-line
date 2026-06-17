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
                    .navigationTitle(poem.displayTitle)
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
                    }
                    .fullScreenCover(isPresented: $isPracticing) {
                        NavigationStack {
                            PracticeView(poem: poem)
                        }
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
                    ForEach(Array(poem.rawLines.enumerated()), id: \.offset) { _, line in
                        if line.trimmingCharacters(in: .whitespaces).isEmpty {
                            // Preserve stanza breaks with a little vertical space.
                            Color.clear.frame(height: 12)
                        } else {
                            Text(line)
                                .font(.title3)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            Divider()

            Button {
                isPracticing = true
            } label: {
                Label("Practice", systemImage: "brain.head.profile")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .disabled(poem.practiceLines.isEmpty)
        }
    }
}
