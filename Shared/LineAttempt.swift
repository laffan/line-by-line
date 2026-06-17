import Foundation

/// A single graded recall of one line during practice.
///
/// Attempts are append-only events with a globally unique `id`, which lets the
/// phone and watch merge their logs by simple union — no conflicts.
struct LineAttempt: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let poemID: UUID
    let lineIndex: Int
    let remembered: Bool
    let date: Date

    init(id: UUID = UUID(),
         poemID: UUID,
         lineIndex: Int,
         remembered: Bool,
         date: Date = Date()) {
        self.id = id
        self.poemID = poemID
        self.lineIndex = lineIndex
        self.remembered = remembered
        self.date = date
    }
}

/// Aggregated practice statistics for a single line of a poem.
struct LineStat: Identifiable {
    let lineIndex: Int
    let text: String
    let total: Int
    let remembered: Int

    var id: Int { lineIndex }
    var successRate: Double { total == 0 ? 0 : Double(remembered) / Double(total) }
}

/// Aggregated practice statistics for a whole poem.
struct PoemStats {
    let totalAttempts: Int
    let rememberedCount: Int
    let lastAttempt: Date?
    let lineStats: [LineStat]

    var successRate: Double {
        totalAttempts == 0 ? 0 : Double(rememberedCount) / Double(totalAttempts)
    }

    var hasData: Bool { totalAttempts > 0 }

    static let empty = PoemStats(totalAttempts: 0,
                                 rememberedCount: 0,
                                 lastAttempt: nil,
                                 lineStats: [])
}
