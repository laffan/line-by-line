import SwiftUI

/// Create or edit a poem's title and content.
struct PoemEditorView: View {
    @EnvironmentObject private var store: PoemStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var content: String

    private let poem: Poem
    private let isNew: Bool

    init(poem: Poem, isNew: Bool) {
        self.poem = poem
        self.isNew = isNew
        _title = State(initialValue: poem.title)
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
            Section("Lines") {
                TextEditor(text: $content)
                    .frame(minHeight: 260)
                    .font(.body)
            }
        }
        .navigationTitle(isNew ? "New Poem" : "Edit Poem")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
    }

    private func save() {
        var edited = poem
        edited.title = title
        edited.content = content
        if isNew {
            store.add(edited)
        } else {
            store.update(edited)
        }
        dismiss()
    }
}
