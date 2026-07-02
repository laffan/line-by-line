import SwiftUI

/// PoetryDB-powered search. Look up poems by title or author, preview them, and
/// add any result straight into your library with one tap.
struct SearchView: View {
    @EnvironmentObject private var store: PoemStore

    @State private var query = ""
    @State private var field: PoetryDBField = .title
    @State private var results: [PoetryDBPoem] = []
    @State private var phase: Phase = .idle
    @State private var previewed: PoetryDBPoem?
    @State private var searchTask: Task<Void, Never>?

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Search by", selection: $field) {
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
            .onSubmit(of: .search) { runSearch() }
            .onChange(of: field) { _, _ in
                // Re-run against the other field so results match the toggle.
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    runSearch()
                }
            }
            .sheet(item: $previewed) { poem in
                NavigationStack {
                    SearchPreviewView(poem: poem)
                }
                .environmentObject(store)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            ContentUnavailableView {
                Label("Find a Poem", systemImage: "magnifyingglass")
            } description: {
                Text("Search PoetryDB by \(field.label.lowercased()) and add poems to your library.")
            }
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView.search
        case .failed(let message):
            ContentUnavailableView {
                Label("Search Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { runSearch() }
            }
        case .loaded:
            List(results) { poem in
                resultRow(poem)
            }
            .listStyle(.plain)
        }
    }

    private func resultRow(_ poem: PoetryDBPoem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(poem.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(poem.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(poem.linecount) lines")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { previewed = poem }

            addButton(for: poem)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func addButton(for poem: PoetryDBPoem) -> some View {
        if store.containsPoem(title: poem.title, author: poem.author) {
            Label("Added", systemImage: "checkmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.green)
                .accessibilityLabel("Already in library")
        } else {
            Button {
                store.add(poem.asPoem())
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Add \(poem.title) to library")
        }
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()

        guard !trimmed.isEmpty else {
            results = []
            phase = .idle
            return
        }

        phase = .loading
        let field = field
        searchTask = Task { @MainActor in
            do {
                let found = try await PoetryDBService.search(trimmed, by: field)
                if Task.isCancelled { return }
                results = found
                phase = found.isEmpty ? .empty : .loaded
            } catch let error as PoetryDBError {
                if Task.isCancelled { return }
                results = []
                switch error {
                case .notFound:
                    phase = .empty
                case .network:
                    phase = .failed(error.localizedDescription)
                }
            } catch {
                if Task.isCancelled { return }
                results = []
                phase = .failed("Something went wrong. Try again.")
            }
        }
    }
}

/// A read-only preview of a PoetryDB search result, with an Add button.
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
