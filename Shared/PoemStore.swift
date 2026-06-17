import Foundation
import Combine

/// Holds all poems, persists them to disk, and keeps the phone and watch in
/// sync via ``WatchConnectivityManager``.
///
/// Editing happens on iOS. The watch app receives the full set of poems and
/// treats them as read-only, so it never broadcasts changes back.
@MainActor
final class PoemStore: ObservableObject {
    @Published private(set) var poems: [Poem] = []

    private let fileURL: URL
    private let connectivity = WatchConnectivityManager.shared

    init(filename: String = "poems.json") {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent(filename)

        load()

        connectivity.onReceivePoems = { [weak self] incoming in
            Task { @MainActor in self?.applyRemote(incoming) }
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
        poems.removeAll { $0.id == poem.id }
        didChange()
    }

    func delete(at offsets: IndexSet) {
        poems.remove(atOffsets: offsets)
        didChange()
    }

    // MARK: - Internal

    private func didChange() {
        sort()
        save()
        broadcast()
    }

    private func sort() {
        poems.sort { $0.dateModified > $1.dateModified }
    }

    /// Replace local poems with a set received from the counterpart device.
    private func applyRemote(_ incoming: [Poem]) {
        poems = incoming.sorted { $0.dateModified > $1.dateModified }
        save()
    }

    private func broadcast() {
        // Only the phone publishes poems; the watch is read-only.
        #if os(iOS)
        connectivity.sendPoems(poems)
        #endif
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Poem].self, from: data) else { return }
        poems = decoded.sorted { $0.dateModified > $1.dateModified }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(poems) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
