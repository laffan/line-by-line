import SwiftUI
import UniformTypeIdentifiers

/// Create or edit a poem: its title, its author, a reading of it, and its lines.
struct PoemEditorView: View {
    @EnvironmentObject private var store: PoemStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var author: String
    @State private var content: String
    @State private var reading: String?
    @State private var isImporting = false

    @StateObject private var recorder = ReadingRecorder()
    @StateObject private var player = ReadingPlayer()

    private let poem: Poem
    private let isNew: Bool
    /// The reading the poem had when the editor opened. Anything else that
    /// appears here is provisional until Save.
    private let originalReading: String?

    init(poem: Poem, isNew: Bool) {
        self.poem = poem
        self.isNew = isNew
        self.originalReading = poem.readingFileName
        _title = State(initialValue: poem.title)
        _author = State(initialValue: poem.author)
        _content = State(initialValue: poem.content)
        _reading = State(initialValue: poem.readingFileName)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                field("Title") {
                    TextField("", text: $title, prompt: placeholder("Untitled"))
                        .font(Theme.serif(.title3))
                        .textInputAutocapitalization(.words)
                }

                field("Author") {
                    TextField("", text: $author, prompt: placeholder("Anonymous"))
                        .font(Theme.serif(.body))
                        .textInputAutocapitalization(.words)
                }

                field("Reading") { readingControls }

                field("Lines") {
                    // An invisible twin of the text sizes the field, so it is
                    // always exactly as tall as the poem and the page — not the
                    // editor — does the scrolling. The trailing space keeps the
                    // twin honest when the poem ends on an open line: `Text`
                    // drops a trailing newline the editor still gives a row to.
                    Text(content.hasSuffix("\n") ? content + " " : content)
                        .font(Theme.serif(.body))
                        .lineSpacing(5)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .opacity(0)
                        .accessibilityHidden(true)
                        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
                        .overlay {
                            TextEditor(text: $content)
                                .font(Theme.serif(.body))
                                .lineSpacing(5)
                                .scrollContentBackground(.hidden)
                                .scrollDisabled(true)
                                .padding(.horizontal, -5)
                        }
                }
            }
            .foregroundStyle(Theme.ink)
            .textFieldStyle(.plain)
            .tint(Theme.accent)
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 24)
        }
        .paperBackground()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isNew ? "New Poem" : "Edit Poem")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { cancel() }
                    .font(Theme.label(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .font(Theme.label(.footnote, .bold))
                    .foregroundStyle(canSave ? Theme.ink : Theme.inkFaint)
                    .disabled(!canSave)
            }
        }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.audio],
                      allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            if let name = importReading(from: url) { setReading(name) }
        }
        .onAppear { player.prepare(fileName: reading) }
    }

    // MARK: - Reading

    @ViewBuilder
    private var readingControls: some View {
        if recorder.isRecording {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 9, height: 9)
                Text(formatDuration(recorder.elapsed))
                    .font(Theme.serif(.body).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Stop") {
                    if let name = recorder.stop() { setReading(name) }
                }
                .buttonStyle(QuietButtonStyle(color: Theme.accent))
            }
            .padding(.bottom, 6)
        } else if let reading {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Button {
                        player.toggle(fileName: reading)
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.paper)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Theme.ink))
                    }
                    .buttonStyle(.plain)

                    ProgressRule(fraction: player.progress)

                    Text(formatDuration(player.duration))
                        .font(Theme.label(.caption2, .regular).monospacedDigit())
                        .foregroundStyle(Theme.inkFaint)
                }

                HStack(spacing: 22) {
                    Button("Record again") { startRecording() }
                        .buttonStyle(QuietButtonStyle())
                    Button("Choose file") { isImporting = true }
                        .buttonStyle(QuietButtonStyle())
                    Spacer(minLength: 0)
                    Button("Remove") { setReading(nil) }
                        .buttonStyle(QuietButtonStyle(color: Theme.accent))
                }
            }
            .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 22) {
                    Button("Record") { startRecording() }
                        .buttonStyle(QuietButtonStyle(color: Theme.ink))
                    Button("Choose file") { isImporting = true }
                        .buttonStyle(QuietButtonStyle())
                    Spacer(minLength: 0)
                }
                if recorder.isMicrophoneDenied {
                    Text("Microphone access is off. Turn it on in Settings to record.")
                        .font(Theme.serif(.caption))
                        .foregroundStyle(Theme.accent)
                        .padding(.bottom, 6)
                }
            }
        }
    }

    private func startRecording() {
        player.reset()
        recorder.start()
    }

    /// Swap in a new reading, throwing away any take made in this session that
    /// isn't the one the poem arrived with.
    private func setReading(_ name: String?) {
        if let current = reading, current != originalReading {
            AppPaths.removeReading(named: current)
        }
        player.reset()
        reading = name
        player.prepare(fileName: name)
    }

    // MARK: - Saving

    private func save() {
        var finalReading = reading
        // Saving mid-take keeps the take.
        if recorder.isRecording, let name = recorder.stop() {
            if let current = reading, current != originalReading {
                AppPaths.removeReading(named: current)
            }
            finalReading = name
        }
        // The reading the poem arrived with is only deleted once its
        // replacement is committed.
        if originalReading != finalReading {
            AppPaths.removeReading(named: originalReading)
        }

        var edited = poem
        edited.title = title
        edited.author = author
        edited.content = content
        edited.readingFileName = finalReading
        if isNew {
            store.add(edited)
        } else {
            store.update(edited)
        }
        dismiss()
    }

    private func cancel() {
        if recorder.isRecording { recorder.cancel() }
        if let reading, reading != originalReading {
            AppPaths.removeReading(named: reading)
        }
        dismiss()
    }

    // MARK: - Layout

    private func placeholder(_ text: String) -> Text {
        Text(text).font(Theme.serif(.body))
    }

    private func field<Content: View>(_ label: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).sectionLabel()
            content()
            Hairline()
        }
    }
}
