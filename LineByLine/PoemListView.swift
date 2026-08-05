import SwiftUI

/// The library: everything you're carrying around, oldest edits last.
struct PoemListView: View {
    @EnvironmentObject private var store: PoemStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var cues: LocationCueManager

    @State private var path: [UUID] = []
    @State private var newPoem: Poem?
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.poems.isEmpty {
                    VStack(spacing: 0) {
                        masthead
                            .padding(.horizontal, Theme.margin)
                            .padding(.top, 8)
                        EmptyState(title: "Nothing on the shelf",
                                   message: "Add a poem you'd like to carry around in your head.")
                    }
                } else {
                    library
                }
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                PoemDetailView(poemID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { isShowingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .regular))
                    }
                    .foregroundStyle(Theme.inkSoft)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { newPoem = Poem() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .regular))
                    }
                    .foregroundStyle(Theme.inkSoft)
                }
            }
            .sheet(item: $newPoem) { poem in
                NavigationStack { PoemEditorView(poem: poem, isNew: true) }
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(settings)
                    .environmentObject(cues)
            }
        }
        .tint(Theme.ink)
        .onChange(of: cues.poemToOpen) { _, id in
            // A location cue was tapped: go straight to the poem it named.
            guard let id, store.poem(id: id) != nil else { return }
            path = [id]
            cues.poemToOpen = nil
        }
    }

    private var library: some View {
        List {
            masthead
                .listRowBackground(Theme.paper)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: Theme.margin,
                                          bottom: 22, trailing: Theme.margin))

            ForEach(store.poems) { poem in
                Button { path.append(poem.id) } label: { row(for: poem) }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.paper)
                    .listRowSeparatorTint(Theme.rule)
                    .listRowInsets(EdgeInsets(top: 15, leading: Theme.margin,
                                              bottom: 15, trailing: Theme.margin))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.delete(poem)
                        } label: {
                            Text("Delete")
                        }
                        .tint(Theme.accent)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Line by Line")
                .font(Theme.serif(.largeTitle))
                .foregroundStyle(Theme.ink)
            Text(store.poems.count == 1 ? "One poem" : "\(store.poems.count) poems")
                .sectionLabel()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(for poem: Poem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(poem.displayTitle)
                .font(Theme.serif(.title3))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                if !poem.preview.isEmpty {
                    Text(poem.preview)
                        .sectionLabel(Theme.inkSoft)
                        .lineLimit(1)
                }
                if poem.readingFileName != nil {
                    Image(systemName: "waveform")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
