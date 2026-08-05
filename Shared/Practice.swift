import Foundation

/// Which way a practice session walks through a poem.
enum PracticeDirection: String, Codable, CaseIterable, Identifiable {
    /// Down the page, the way you'd recite it.
    case forward
    /// Up the page — learn the ending first, then work backwards into it.
    case backward

    var id: String { rawValue }
}

/// Where a session starts and which way it goes.
///
/// The four modes the app offers are just the two directions crossed with
/// "from the end of the poem" and "from a line you pick":
///
/// - forward from line 0 — from the top
/// - forward from line *n* — start at a line
/// - backward from the last line — from the bottom
/// - backward from line *n* — back from a line
struct PracticePlan: Equatable, Hashable {
    var direction: PracticeDirection
    /// Index into ``Poem/practiceLines`` where the session begins.
    var startIndex: Int

    static let fromTop = PracticePlan(direction: .forward, startIndex: 0)

    static func fromBottom(lineCount: Int) -> PracticePlan {
        PracticePlan(direction: .backward, startIndex: max(lineCount - 1, 0))
    }

    /// The line indices this session covers, in the order they're revealed.
    func order(lineCount: Int) -> [Int] {
        guard lineCount > 0 else { return [] }
        let start = min(max(startIndex, 0), lineCount - 1)
        switch direction {
        case .forward:  return Array(start..<lineCount)
        case .backward: return Array((0...start).reversed())
        }
    }

    /// How the mode reads in the interface, e.g. "Back from line 12".
    func name(lineCount: Int) -> String {
        let atEdge = direction == .forward
            ? startIndex <= 0
            : startIndex >= lineCount - 1
        switch (direction, atEdge) {
        case (.forward, true):   return "From the top"
        case (.forward, false):  return "From line \(startIndex + 1)"
        case (.backward, true):  return "From the bottom"
        case (.backward, false): return "Back from line \(startIndex + 1)"
        }
    }
}

/// A practice session in progress: which lines are uncovered so far, and which
/// one comes next.
struct PracticeSession: Equatable {
    let plan: PracticePlan
    /// Line indices in reveal order.
    let order: [Int]
    /// Every index the plan covers — anything else is context, shown faintly.
    let covered: Set<Int>

    private(set) var revealed: Set<Int> = []
    private(set) var step = 0

    init(plan: PracticePlan, lineCount: Int) {
        self.plan = plan
        let order = plan.order(lineCount: lineCount)
        self.order = order
        self.covered = Set(order)
    }

    var isComplete: Bool { step >= order.count }
    var total: Int { order.count }

    /// The line about to be uncovered, or `nil` once the session is done.
    var nextIndex: Int? { isComplete ? nil : order[step] }

    /// True for lines the plan doesn't touch — the ones before a forward start
    /// point, or after a backward one. They stay legible as context.
    func isContext(_ index: Int) -> Bool { !covered.contains(index) }

    mutating func revealNext() {
        guard let next = nextIndex else { return }
        revealed.insert(next)
        step += 1
    }

    mutating func revealAll() {
        revealed.formUnion(order)
        step = order.count
    }
}
