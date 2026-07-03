import Foundation

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
