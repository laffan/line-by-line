import Foundation

/// One line of a poem as it appears on the page.
///
/// Blank lines are kept so stanza breaks survive, but they carry no
/// `practiceIndex` — practice only ever walks the lines that have words on
/// them, and line numbers count only those too.
struct PoemLine: Identifiable, Hashable {
    /// Position in the poem's raw lines; stable enough to identify a row.
    let id: Int
    let text: String
    /// Index into ``Poem/practiceLines``, or `nil` for a stanza break.
    let practiceIndex: Int?

    var isBreak: Bool { practiceIndex == nil }
}

/// A single poem the user wants to memorize.
///
/// `content` stores the poem exactly as typed (including blank lines between
/// stanzas). ``lines`` derives the rows used for display and practice.
struct Poem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var author: String
    var content: String
    /// File name, inside the app's Readings folder, of a recorded or imported
    /// reading of the poem. Phone only — audio is not synced to the watch.
    var readingFileName: String?
    var dateModified: Date

    init(id: UUID = UUID(),
         title: String = "",
         author: String = "",
         content: String = "",
         readingFileName: String? = nil,
         dateModified: Date = Date()) {
        self.id = id
        self.title = title
        self.author = author
        self.content = content
        self.readingFileName = readingFileName
        self.dateModified = dateModified
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, author, content, readingFileName, dateModified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        // Older poems were saved before authors and readings existed.
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        content = try container.decode(String.self, forKey: .content)
        readingFileName = try container.decodeIfPresent(String.self, forKey: .readingFileName)
        dateModified = try container.decode(Date.self, forKey: .dateModified)
    }

    /// The poem split into raw lines, with trailing blanks trimmed so a stray
    /// newline at the end doesn't leave a gap under the last stanza.
    var rawLines: [String] {
        var split = content.components(separatedBy: .newlines)
        while let last = split.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            split.removeLast()
        }
        return split
    }

    /// Every row on the page, stanza breaks included.
    var lines: [PoemLine] {
        var result: [PoemLine] = []
        var practiceIndex = 0
        for (offset, raw) in rawLines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                result.append(PoemLine(id: offset, text: "", practiceIndex: nil))
            } else {
                result.append(PoemLine(id: offset, text: trimmed, practiceIndex: practiceIndex))
                practiceIndex += 1
            }
        }
        return result
    }

    /// Non-empty, trimmed lines — the ones practice walks through.
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
