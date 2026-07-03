import Foundation
import Combine

/// A poem as returned by the PoetryDB API (https://poetrydb.org).
///
/// PoetryDB has no stable identifier for a poem, so we derive one from the
/// title and author, which is stable enough to key result rows.
struct PoetryDBPoem: Codable, Identifiable, Hashable {
    let title: String
    let author: String
    let lines: [String]
    let linecount: String

    var id: String { "\(title)|\(author)" }

    /// The lines rejoined into the newline-separated form our `Poem` stores.
    var content: String { lines.joined(separator: "\n") }

    /// Convert an API result into a poem the user can save and practice.
    func asPoem() -> Poem {
        Poem(title: title, author: author, content: content)
    }
}

/// A lightweight {title, author} pair used for browsing. PoetryDB has no
/// endpoint that lists titles with their authors, so we build an index of these
/// by asking each author for their titles.
struct PoemStub: Codable, Hashable, Identifiable {
    let title: String
    let author: String

    var id: String { "\(title)|\(author)" }
}

/// The field to search PoetryDB by.
enum PoetryDBField: String, CaseIterable, Identifiable {
    case title
    case author

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Placeholder text for the search field, which filters the catalog.
    var prompt: String {
        switch self {
        case .title: return "Filter titles"
        case .author: return "Filter authors"
        }
    }

    /// Plural noun for the catalog of this field.
    var plural: String {
        switch self {
        case .title: return "titles"
        case .author: return "authors"
        }
    }
}

enum PoetryDBError: LocalizedError {
    case notFound
    case network

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No poems found. Try a different search."
        case .network:
            return "Couldn't reach PoetryDB. Check your connection and try again."
        }
    }
}

/// A minimal client for the PoetryDB REST API.
///
/// PoetryDB matches partially and case-insensitively, so `search("dickinson",
/// by: .author)` returns every poem whose author contains "dickinson". When
/// nothing matches, the API replies with a `{ "status": 404 }` object rather
/// than an array, which we translate into ``PoetryDBError/notFound``.
enum PoetryDBService {
    private static let base = URL(string: "https://poetrydb.org")!

    /// Search for poems whose `field` contains `query` (partial, case-insensitive).
    static func search(_ query: String, by field: PoetryDBField) async throws -> [PoetryDBPoem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // e.g. https://poetrydb.org/title/Ozymandias
        //      https://poetrydb.org/author/Emily%20Dickinson
        let url = base
            .appendingPathComponent(field.rawValue)
            .appendingPathComponent(trimmed)
        return try await fetchPoems(from: url)
    }

    /// The full catalog for a field: every title, or every author.
    ///
    /// `GET /title` → `{ "titles": [...] }`, `GET /author` → `{ "authors": [...] }`.
    static func catalog(for field: PoetryDBField) async throws -> [String] {
        let url = base.appendingPathComponent(field.rawValue)
        let data = try await fetchData(from: url)
        guard let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else {
            throw PoetryDBError.network
        }
        return catalog.values(for: field)
    }

    /// A single random poem.
    static func random() async throws -> PoetryDBPoem {
        let url = base.appendingPathComponent("random")
        guard let poem = try await fetchPoems(from: url).first else {
            throw PoetryDBError.notFound
        }
        return poem
    }

    /// The {title, author} pairs for one author (title,author output only) —
    /// the building block of the title index.
    static func titles(byAuthor author: String) async throws -> [PoemStub] {
        let url = base
            .appendingPathComponent("author")
            .appendingPathComponent(author)
            .appendingPathComponent("author,title")
        let data = try await fetchData(from: url)
        if let stubs = try? JSONDecoder().decode([PoemStub].self, from: data) {
            return stubs
        }
        if (try? JSONDecoder().decode(PoetryDBStatus.self, from: data)) != nil {
            throw PoetryDBError.notFound
        }
        throw PoetryDBError.network
    }

    /// Fetch the full poem matching an exact title and author.
    static func poem(title: String, author: String) async throws -> PoetryDBPoem? {
        // Combined input: /title,author/<title>;<author>
        let url = base
            .appendingPathComponent("title,author")
            .appendingPathComponent("\(title);\(author)")
        return try await fetchPoems(from: url).first
    }

    // MARK: - Networking

    private static func fetchData(from url: URL) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw PoetryDBError.network
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw PoetryDBError.notFound
        }
        return data
    }

    private static func fetchPoems(from url: URL) async throws -> [PoetryDBPoem] {
        let data = try await fetchData(from: url)
        let decoder = JSONDecoder()
        if let poems = try? decoder.decode([PoetryDBPoem].self, from: data) {
            return poems
        }
        // No matches: PoetryDB returns a `{ "status": ..., "reason": ... }`
        // object instead of an array.
        if (try? decoder.decode(PoetryDBStatus.self, from: data)) != nil {
            throw PoetryDBError.notFound
        }
        throw PoetryDBError.network
    }

    /// The `{ "titles": [...] }` / `{ "authors": [...] }` catalog shape.
    private struct Catalog: Decodable {
        let titles: [String]?
        let authors: [String]?

        func values(for field: PoetryDBField) -> [String] {
            switch field {
            case .title: return titles ?? []
            case .author: return authors ?? []
            }
        }
    }

    /// The shape PoetryDB uses to signal "no results".
    private struct PoetryDBStatus: Decodable {
        let status: Int
        let reason: String?
    }
}

/// Caches PoetryDB's browse data on disk so it's fetched from the network only
/// once, then reused across launches until the user manually refreshes.
///
/// Two catalogs are cached in the Caches directory as plain JSON:
/// - `authors`: the list of every poet (a single request).
/// - `poems`: a {title, author} index for browsing titles. PoetryDB has no
///   endpoint that lists titles with their authors, so this index is built by
///   asking each author for their titles — a heavier, one-time download.
@MainActor
final class PoetryCatalogStore: ObservableObject {
    @Published private(set) var authors: [String] = []
    @Published private(set) var poems: [PoemStub] = []
    /// When each catalog was last downloaded, keyed by ``PoetryDBField/rawValue``.
    @Published private(set) var updatedAt: [String: Date] = [:]

    /// Progress (0...1) while the title index is being built.
    @Published private(set) var indexProgress: Double = 0
    @Published private(set) var isBuildingIndex = false

    private let directory: URL
    private let authorsURL: URL
    private let indexURL: URL
    private let updatedURL: URL

    init(directoryName: String = "PoetryCatalog") {
        let base = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        directory = base
        authorsURL = base.appendingPathComponent("authors.json")
        indexURL = base.appendingPathComponent("index.json")
        updatedURL = base.appendingPathComponent("updated.json")

        authors = decode([String].self, from: authorsURL) ?? []
        poems = decode([PoemStub].self, from: indexURL) ?? []
        updatedAt = decode([String: Date].self, from: updatedURL) ?? [:]
    }

    // MARK: - Reads

    func lastUpdated(_ field: PoetryDBField) -> Date? {
        updatedAt[field.rawValue]
    }

    // MARK: - Authors (cheap)

    func ensureAuthorsLoaded() async throws {
        guard authors.isEmpty else { return }
        try await refreshAuthors()
    }

    func refreshAuthors() async throws {
        let values = try await PoetryDBService.catalog(for: .author)
        authors = values
        write(values, to: authorsURL)
        markUpdated(.author)
    }

    // MARK: - Title index (expensive: one request per author)

    func ensurePoemIndexLoaded() async throws {
        guard poems.isEmpty else { return }
        try await refreshPoemIndex()
    }

    /// Rebuild the {title, author} index by fetching every author's titles.
    /// Individual author failures are skipped so one hiccup doesn't fail the
    /// whole build.
    func refreshPoemIndex() async throws {
        isBuildingIndex = true
        indexProgress = 0
        defer { isBuildingIndex = false }

        let names = authors.isEmpty
            ? try await PoetryDBService.catalog(for: .author)
            : authors
        if authors.isEmpty {
            authors = names
            write(names, to: authorsURL)
            markUpdated(.author)
        }

        var collected: [PoemStub] = []
        var completed = 0
        let total = max(names.count, 1)

        await withTaskGroup(of: [PoemStub].self) { group in
            var iterator = names.makeIterator()
            let maxConcurrent = 6
            for _ in 0..<maxConcurrent {
                guard let name = iterator.next() else { break }
                group.addTask { (try? await PoetryDBService.titles(byAuthor: name)) ?? [] }
            }
            for await stubs in group {
                collected.append(contentsOf: stubs)
                completed += 1
                indexProgress = Double(completed) / Double(total)
                if let name = iterator.next() {
                    group.addTask { (try? await PoetryDBService.titles(byAuthor: name)) ?? [] }
                }
            }
        }

        // Don't cache a half-built index if the build was cancelled (e.g. the
        // user navigated away); let it rebuild cleanly next time.
        if Task.isCancelled { return }

        poems = collected.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        write(poems, to: indexURL)
        markUpdated(.title)
    }

    // MARK: - Persistence

    private func markUpdated(_ field: PoetryDBField) {
        updatedAt[field.rawValue] = Date()
        write(updatedAt, to: updatedURL)
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
