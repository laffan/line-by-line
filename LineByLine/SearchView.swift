import SwiftUI

/// PoetryDB browser. Pick Titles or Authors to see the full catalog, filter it
/// with the search field, tap through to preview and add poems, or hit Random
/// for a surprise.
struct SearchView: View {
    @EnvironmentObject private var store: PoemStore

    // The full title/author catalogs, cached on disk and downloaded only once.
    @StateObject private var catalog = PoetryCatalogStore()

    @State private var field: PoetryDBField = .title
    @State private var query = ""
    @State private var phase: Phase = .loading

    // Single-poem fetches (tapping a title, or Random) surface here.
    @State private var previewed: PoetryDBPoem?
    @State private var isFetchingPoem = false
    @State private var fetchError: String?

    private enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private var names: [String] {
        catalog.values(for: field)
    }

    private var filtered: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return names }
        return names.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Browse by", selection: $field) {
                    ForEach(PoetryDBField.allCases) { field in
                        Text(field.label).tag(field)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                content
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: field.prompt)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        fetchRandom()
                    } label: {
                        Label("Random", systemImage: "dice")
                    }
                    .disabled(isFetchingPoem)
                }
            }
            .navigationDestination(for: String.self) { author in
                AuthorPoemsView(author: author)
            }
            .sheet(item: $previewed) { poem in
                NavigationStack {
                    SearchPreviewView(poem: poem)
                }
                .environmentObject(store)
            }
            .overlay { if isFetchingPoem { loadingOverlay } }
            .alert("Couldn't Load Poem", isPresented: Binding(
                get: { fetchError != nil },
                set: { if !$0 { fetchError = nil } })) {
                Button("OK", role: .cancel) { fetchError = nil }
            } message: {
                Text(fetchError ?? "")
            }
            .task(id: field) { await loadCatalogIfNeeded() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await refresh() }
                }
            }
        case .loaded:
            if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                catalogList
            }
        }
    }

    private var catalogList: some View {
        List(filtered, id: \.self) { name in
            switch field {
            case .author:
                NavigationLink(value: name) {
                    Text(name)
                }
            case .title:
                Button {
                    fetchTitle(name)
                } label: {
                    HStack {
                        Text(name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await refresh() }
        .safeAreaInset(edge: .bottom) { updatedFooter }
    }

    @ViewBuilder
    private var updatedFooter: some View {
        if let updated = catalog.lastUpdated(field) {
            Text("\(filtered.count) \(field.plural) · updated \(updated.formatted(.relative(presentation: .named))) · pull to refresh")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.bar)
        }
    }

    private var loadingOverlay: some View {
        ProgressView()
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Loading

    private func loadCatalogIfNeeded() async {
        guard !catalog.isCached(field) else {
            phase = .loaded
            return
        }
        phase = .loading
        do {
            try await catalog.ensureLoaded(field)
            phase = .loaded
        } catch {
            phase = .failed(message(for: error))
        }
    }

    /// Force a re-download of the current catalog (pull-to-refresh / Try Again).
    private func refresh() async {
        do {
            try await catalog.refresh(field)
            phase = .loaded
        } catch {
            // Keep showing any cached list; only fall back to the error state
            // when there's nothing to show.
            if !catalog.isCached(field) {
                phase = .failed(message(for: error))
            }
        }
    }

    private func fetchTitle(_ title: String) {
        runSingleFetch { try await PoetryDBService.search(title, by: .title).first }
    }

    private func fetchRandom() {
        runSingleFetch { try await PoetryDBService.random() }
    }

    /// Run a one-poem fetch with a loading overlay, then present it or surface
    /// an error.
    private func runSingleFetch(_ work: @escaping () async throws -> PoetryDBPoem?) {
        guard !isFetchingPoem else { return }
        isFetchingPoem = true
        Task { @MainActor in
            defer { isFetchingPoem = false }
            do {
                if let poem = try await work() {
                    previewed = poem
                } else {
                    fetchError = "That poem couldn't be found."
                }
            } catch {
                fetchError = message(for: error)
            }
        }
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Try again."
    }
}

/// The poems written by one author, each with a preview and Add button.
private struct AuthorPoemsView: View {
    let author: String
    @EnvironmentObject private var store: PoemStore

    @State private var poems: [PoetryDBPoem] = []
    @State private var phase: Phase = .loading
    @State private var previewed: PoetryDBPoem?

    private enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await load() } }
                }
            case .loaded:
                List(poems) { poem in
                    PoetryDBResultRow(poem: poem, showsAuthor: false) {
                        previewed = poem
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(author)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewed) { poem in
            NavigationStack {
                SearchPreviewView(poem: poem)
            }
            .environmentObject(store)
        }
        .task { await load() }
    }

    private func load() async {
        phase = .loading
        do {
            poems = try await PoetryDBService.search(author, by: .author)
            phase = .loaded
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "Something went wrong. Try again."
            phase = .failed(message)
        }
    }
}

/// A poem row with a tap-to-preview area and an Add/Added button.
private struct PoetryDBResultRow: View {
    let poem: PoetryDBPoem
    var showsAuthor: Bool = true
    let onTap: () -> Void

    @EnvironmentObject private var store: PoemStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(poem.title)
                    .font(.headline)
                    .lineLimit(2)
                if showsAuthor {
                    Text(poem.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(poem.linecount) lines")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            addButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var addButton: some View {
        if store.containsPoem(title: poem.title, author: poem.author) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .accessibilityLabel("Already in library")
        } else {
            Button {
                store.add(poem.asPoem())
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Add \(poem.title) to library")
        }
    }
}

/// A read-only preview of a PoetryDB poem, with an Add button.
private struct SearchPreviewView: View {
    let poem: PoetryDBPoem
    @EnvironmentObject private var store: PoemStore
    @Environment(\.dismiss) private var dismiss

    private var alreadyAdded: Bool {
        store.containsPoem(title: poem.title, author: poem.author)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(poem.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                    ForEach(Array(poem.lines.enumerated()), id: \.offset) { _, line in
                        if line.trimmingCharacters(in: .whitespaces).isEmpty {
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
                store.add(poem.asPoem())
                dismiss()
            } label: {
                Label(alreadyAdded ? "Already in Library" : "Add to Library",
                      systemImage: alreadyAdded ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .disabled(alreadyAdded)
        }
        .navigationTitle(poem.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
