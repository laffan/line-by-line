import Foundation

/// A single poem the user wants to memorize.
///
/// `content` stores the poem exactly as typed (including blank lines between
/// stanzas). `lines` derives the non-empty lines used for practice and the
/// line-by-line walkthrough.
struct Poem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var content: String
    var dateModified: Date

    init(id: UUID = UUID(),
         title: String = "",
         content: String = "",
         dateModified: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.dateModified = dateModified
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

    /// A short preview of the first line, for list rows.
    var preview: String {
        practiceLines.first ?? ""
    }
}
