import Foundation

/// A single poem the user wants to memorize.
///
/// `content` stores the poem exactly as typed (including blank lines between
/// stanzas). `lines` derives the non-empty lines used for practice and the
/// line-by-line walkthrough.
struct Poem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var author: String
    var content: String
    var dateModified: Date

    init(id: UUID = UUID(),
         title: String = "",
         author: String = "",
         content: String = "",
         dateModified: Date = Date()) {
        self.id = id
        self.title = title
        self.author = author
        self.content = content
        self.dateModified = dateModified
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, author, content, dateModified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        // Older poems were saved before authors existed.
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        content = try container.decode(String.self, forKey: .content)
        dateModified = try container.decode(Date.self, forKey: .dateModified)
    }

    /// The poem split into raw lines, preserving blank lines so stanza breaks
    /// can be rendered in view mode.
    var rawLines: [String] {
        content.components(separatedBy: .newlines)
    }

    /// Non-empty, trimmed lines used for the practice walkthrough.
    var practiceLines: [String] {
        rawLines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    /// The trimmed author, or empty if none was entered.
    var displayAuthor: String {
        author.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A short preview line for list rows: the author if present, else the
    /// first line of the poem.
    var preview: String {
        displayAuthor.isEmpty ? (practiceLines.first ?? "") : displayAuthor
    }
}
