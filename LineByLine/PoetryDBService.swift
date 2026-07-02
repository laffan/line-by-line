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

    /// Placeholder text for the search field.
    var prompt: String {
        switch self {
        case .title: return "Search by title"
        case .author: return "Search by author"
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

    static func search(_ query: String, by field: PoetryDBField) async throws -> [PoetryDBPoem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // e.g. https://poetrydb.org/title/Ozymandias
        //      https://poetrydb.org/author/Emily%20Dickinson
        let url = base
            .appendingPathComponent(field.rawValue)
            .appendingPathComponent(trimmed)

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

    /// The shape PoetryDB uses to signal "no results".
    private struct PoetryDBStatus: Decodable {
        let status: Int
        let reason: String?
    }
}
