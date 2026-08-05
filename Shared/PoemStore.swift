import Foundation
import Combine

/// Holds all poems, persists them to disk, and keeps the phone and watch in
/// sync via ``WatchConnectivityManager``.
///
/// Poems are edited on iOS; the phone is the source of truth and pushes state
/// to the watch. Nothing flows the other way except a request to resend.
@MainActor
final class PoemStore: ObservableObject {
    @Published private(set) var poems: [Poem] = []

    /// Mirrors the line-number preference so the watch can honour it too. On
    /// iOS the settings panel owns this value and pushes it here; on watchOS it
    /// arrives with the poems and is what the watch reads.
    @Published private(set) var showLineNumbers = false

    private let connectivity = WatchConnectivityManager.shared

    init() {
        load()

        connectivity.onReceive = { [weak self] payload in
            Task { @MainActor in self?.receive(payload) }
        }
        connectivity.onRequestSync = { [weak self] in
            Task { @MainActor in self?.broadcast() }
        }
        connectivity.onActivated = { [weak self] in
            Task { @MainActor in self?.broadcast() }
        }
        connectivity.activate()

        #if os(watchOS)
        // Ask the phone for the latest poems as soon as we launch.
        connectivity.requestSync()
        #endif
    }

    // MARK: - Lookup

    func poem(id: UUID) -> Poem? {
        poems.first { $0.id == id }
    }

    // MARK: - Mutations (iOS)

    func add(_ poem: Poem) {
        poems.append(poem)
        didChange()
    }

    func update(_ poem: Poem) {
        var updated = poem
        updated.dateModified = Date()
        if let index = poems.firstIndex(where: { $0.id == poem.id }) {
            poems[index] = updated
        } else {
            poems.append(updated)
        }
        didChange()
    }

    func delete(_ poem: Poem) {
        AppPaths.removeReading(named: poem.readingFileName)
        poems.removeAll { $0.id == poem.id }
        didChange()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets where poems.indices.contains(index) {
            AppPaths.removeReading(named: poems[index].readingFileName)
        }
        poems.remove(atOffsets: offsets)
        didChange()
    }

    /// Called by the settings panel on iOS so the watch stays in step.
    func setShowLineNumbers(_ value: Bool) {
        guard showLineNumbers != value else { return }
        showLineNumbers = value
        broadcast()
    }

    // MARK: - Sync

    private func didChange() {
        poems.sort { $0.dateModified > $1.dateModified }
        save()
        broadcast()
    }

    private func broadcast() {
        #if os(iOS)
        connectivity.send(SyncPayload(poems: poems, showLineNumbers: showLineNumbers))
        #endif
    }

    private func receive(_ payload: SyncPayload) {
        // Only the watch adopts incoming state; the phone is the source of truth.
        #if os(watchOS)
        if let incoming = payload.poems {
            poems = incoming.sorted { $0.dateModified > $1.dateModified }
            save()
        }
        if let lineNumbers = payload.showLineNumbers {
            showLineNumbers = lineNumbers
        }
        #endif
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: AppPaths.poems),
              let decoded = try? JSONDecoder().decode([Poem].self, from: data) else { return }
        poems = decoded.sorted { $0.dateModified > $1.dateModified }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(poems) else { return }
        try? data.write(to: AppPaths.poems, options: .atomic)
    }
}
