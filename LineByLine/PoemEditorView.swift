import SwiftUI
import UniformTypeIdentifiers

/// Create or edit a poem's title and content.
struct PoemEditorView: View {
    @EnvironmentObject private var store: PoemStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var author: String
    @State private var content: String
    @State private var isImportingReading = false
    @State private var readingError: String?

    private let poem: Poem
    private let isNew: Bool

    init(poem: Poem, isNew: Bool) {
        self.poem = poem
        self.isNew = isNew
        _title = State(initialValue: poem.title)
        _author = State(initialValue: poem.author)
        _content = State(initialValue: poem.content)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $title)
                    .textInputAutocapitalization(.words)
            }
            Section("Author") {
                TextField("Author", text: $author)
                    .textInputAutocapitalization(.words)
            }
            Section("Lines") {
                TextEditor(text: $content)
                    .frame(minHeight: 260)
                    .font(.body)
            }
            Section("Reading") {
                readingRow
            }
        }
        .navigationTitle(isNew ? "New Poem" : "Edit Poem")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { cancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .fileImporter(isPresented: $isImportingReading,
                      allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                do {
                    try store.attachReading(from: url, to: poem.id)
                } catch {
                    readingError = "Couldn't add that audio file. Try another."
                }
            case .failure:
                readingError = "Couldn't add that audio file. Try another."
            }
        }
        .alert("Reading", isPresented: Binding(
            get: { readingError != nil },
            set: { if !$0 { readingError = nil } })) {
            Button("OK", role: .cancel) { readingError = nil }
        } message: {
            Text(readingError ?? "")
        }
    }

    @ViewBuilder
    private var readingRow: some View {
        if let url = store.reading(for: poem.id) {
            HStack {
                Label(url.lastPathComponent, systemImage: "waveform")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(role: .destructive) {
                    store.removeReading(for: poem.id)
                } label: {
                    Text("Remove")
                }
                .buttonStyle(.borderless)
            }
        } else {
            Button {
                isImportingReading = true
            } label: {
                Label("Add Reading", systemImage: "waveform.badge.plus")
            }
        }
    }

    private func save() {
        var edited = poem
        edited.title = title
        edited.author = author
        edited.content = content
        if isNew {
            store.add(edited)
        } else {
            store.update(edited)
        }
        dismiss()
    }

    private func cancel() {
        // A reading attached while composing a brand-new poem would otherwise be
        // orphaned, since the poem itself is never saved.
        if isNew {
            store.removeReading(for: poem.id)
        }
        dismiss()
    }
}
