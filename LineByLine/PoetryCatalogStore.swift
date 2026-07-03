import Foundation

/// Caches PoetryDB's full title and author catalogs on disk so they're fetched
/// from the network only once, then reused across launches until the user
/// manually refreshes.
///
/// The catalogs are large but static, so they live in the Caches directory as
/// plain JSON. If the cache is ever evicted, it's simply re-fetched on demand.
@MainActor
final class PoetryCatalogStore: ObservableObject {
    @Published private(set) var titles: [String] = []
    @Published private(set) var authors: [String] = []
    /// When each catalog was last downloaded, keyed by ``PoetryDBField/rawValue``.
    @Published private(set) var updatedAt: [String: Date] = [:]

    private let directory: URL
    private let updatedURL: URL

    init(directoryName: String = "PoetryCatalog") {
        let base = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        directory = base
        updatedURL = base.appendingPathComponent("updated.json")

        titles = loadDisk(for: .title)
        authors = loadDisk(for: .author)
        if let data = try? Data(contentsOf: updatedURL),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            updatedAt = decoded
        }
    }

    // MARK: - Reads

    func values(for field: PoetryDBField) -> [String] {
        field == .title ? titles : authors
    }

    func isCached(_ field: PoetryDBField) -> Bool {
        !values(for: field).isEmpty
    }

    func lastUpdated(_ field: PoetryDBField) -> Date? {
        updatedAt[field.rawValue]
    }

    // MARK: - Loading

    /// Fetch a catalog from the network only if nothing is cached yet.
    func ensureLoaded(_ field: PoetryDBField) async throws {
        guard !isCached(field) else { return }
        try await refresh(field)
    }

    /// Force a fresh download of a catalog and overwrite the cache.
    func refresh(_ field: PoetryDBField) async throws {
        let values = try await PoetryDBService.catalog(for: field)
        switch field {
        case .title: titles = values
        case .author: authors = values
        }
        saveDisk(values, for: field)
        updatedAt[field.rawValue] = Date()
        saveUpdated()
    }

    // MARK: - Persistence

    private func fileURL(for field: PoetryDBField) -> URL {
        directory.appendingPathComponent("\(field.rawValue).json")
    }

    private func loadDisk(for field: PoetryDBField) -> [String] {
        guard let data = try? Data(contentsOf: fileURL(for: field)),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveDisk(_ values: [String], for field: PoetryDBField) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        try? data.write(to: fileURL(for: field), options: .atomic)
    }

    private func saveUpdated() {
        guard let data = try? JSONEncoder().encode(updatedAt) else { return }
        try? data.write(to: updatedURL, options: .atomic)
    }
}
