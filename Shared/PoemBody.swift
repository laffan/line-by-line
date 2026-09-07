import SwiftUI

/// The poem set on the page.
///
/// One view serves both states of the poem screen. With no session it's simply
/// the poem; with one, the lines the session hasn't reached yet are struck out
/// under solid bars that lift as you go.
struct PoemBody: View {
    let poem: Poem
    /// `nil` while reading; a session while practising.
    let session: PracticeSession?
    let showLineNumbers: Bool
    /// How large the reader has asked for the poem, as a multiple of the size
    /// the app sets verse at. Only the verse moves with it: the app's own
    /// voice — titles, authors, labels — keeps its size.
    var textScale: Double = 1

    /// Dynamic Type's say in the size, before the reader's. A font built from
    /// an explicit point size doesn't scale itself, so the size is scaled
    /// here and ``textScale`` multiplies what comes out.
    @ScaledMetric(relativeTo: Theme.verseStyle) private var verseSize = Theme.verseSize
    @ScaledMetric(relativeTo: .caption2) private var numberSize = Theme.verseNumberSize

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.lineGap * scale) {
            ForEach(poem.lines) { line in
                if line.isBreak {
                    Color.clear.frame(height: Theme.lineGap * scale)
                } else {
                    LineRow(line: line,
                            state: state(for: line),
                            showLineNumbers: showLineNumbers,
                            verseFont: Theme.serif(size: verseSize * scale),
                            numberFont: Theme.serif(size: numberSize * scale).monospacedDigit(),
                            gutter: Theme.gutter * scale)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The reader's setting, held to a sane range: a stored value from another
    /// version of the app shouldn't be able to break the page.
    private var scale: CGFloat { CGFloat(min(max(textScale, 0.5), 2.5)) }

    private func state(for line: PoemLine) -> LineState {
        guard let session, let index = line.practiceIndex else { return .plain }
        if session.isContext(index) { return .context }
        if session.revealed.contains(index) { return .plain }
        return session.nextIndex == index ? .next : .concealed
    }
}

/// How a line is drawn at this moment.
private enum LineState {
    /// Legible: either not practising, or already uncovered.
    case plain
    /// Outside this session's range — kept legible but quiet, so you can still
    /// see where in the poem you are.
    case context
    /// Covered, and not the one you're working on.
    case concealed
    /// Covered, and the next to lift.
    case next
}

/// A single line of verse, in whichever of its four states applies.
private struct LineRow: View {
    let line: PoemLine
    let state: LineState
    let showLineNumbers: Bool
    /// The verse and the margin are set by ``PoemBody``, which is where the
    /// reader's text size is known.
    let verseFont: Font
    let numberFont: Font
    let gutter: CGFloat

    private var isCovered: Bool { state == .concealed || state == .next }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if showLineNumbers, let index = line.practiceIndex {
                Text("\(index + 1)")
                    .font(numberFont)
                    .foregroundStyle(state == .next ? Theme.accent : Theme.inkFaint)
                    .frame(width: gutter, alignment: .trailing)
                    .padding(.trailing, 10)
            }

            VerseText(text: line.text)
                .font(verseFont)
                .foregroundStyle(state == .context ? Theme.inkFaint : Theme.ink)
                .opacity(isCovered ? 0 : 1)
                .overlay {
                    if isCovered {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Theme.redaction)
                            .opacity(state == .next ? 1 : 0.4)
                            .padding(.vertical, 3)
                    }
                }

            Spacer(minLength: 0)
        }
    }
}

/// One line of verse, set so that its turnovers — the rows a long line spills
/// onto when the measure is too narrow — sit in by a few spaces, the way verse
/// is set in print. A wrapped line then reads as one line, not two.
private struct VerseText: View {
    let text: String

    /// How far a turnover sits in, in spaces of the verse font.
    private static let turnoverSpaces = 3
    /// The gap between the rows of one wrapped line.
    private static let rowGap: CGFloat = 6

    var body: some View {
        let (words, spacesBefore) = Self.tokens(from: text)
        TurnoverLayout(spacesBefore: spacesBefore,
                       indentSpaces: Self.turnoverSpaces,
                       rowGap: Self.rowGap) {
            // The probe: one non-breaking space the layout measures to learn
            // the width of a space in the current font. It draws nothing.
            Text("\u{00A0}")
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                Text(word)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    /// Split a line into words and the number of spaces before each, so
    /// deliberate spacing inside a line survives the trip through the layout.
    private static func tokens(from text: String) -> ([String], [Int]) {
        var words: [String] = []
        var spacesBefore: [Int] = []
        var word = ""
        var pending = 0
        for character in text {
            if character.isWhitespace {
                if !word.isEmpty {
                    words.append(word)
                    word = ""
                }
                pending += 1
            } else {
                if word.isEmpty {
                    spacesBefore.append(pending)
                    pending = 0
                }
                word.append(character)
            }
        }
        if !word.isEmpty { words.append(word) }
        return (words, spacesBefore)
    }
}

/// The typesetter behind ``VerseText``: words run left to right, break at
/// spaces, and every row after the first is pushed in by the indent.
///
/// The first subview must be the measuring probe; the rest are the words, in
/// order, matching `spacesBefore` index for index.
private struct TurnoverLayout: Layout {
    let spacesBefore: [Int]
    let indentSpaces: Int
    let rowGap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        typeset(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        // The probe is blank — park it in the corner.
        subviews[0].place(at: bounds.origin, proposal: .unspecified)
        let origins = typeset(subviews, width: bounds.width).origins
        for (word, origin) in zip(subviews.dropFirst(), origins) {
            word.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                       proposal: .unspecified)
        }
    }

    // The first word always sits on the first row, so its baseline is the
    // layout's. Without this the line-number gutter would align to the bottom
    // edge instead.
    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect,
                           proposal: ProposedViewSize, subviews: Subviews,
                           cache: inout Void) -> CGFloat? {
        guard guide == .firstTextBaseline, subviews.count > 1 else { return nil }
        return subviews[1].dimensions(in: .unspecified)[.firstTextBaseline]
    }

    private func typeset(_ subviews: Subviews, width: CGFloat) -> (origins: [CGPoint], size: CGSize) {
        let space = subviews[0].sizeThatFits(.unspecified).width
        let indent = CGFloat(indentSpaces) * space

        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        var isRowStart = true

        for (index, word) in subviews.dropFirst().enumerated() {
            let size = word.sizeThatFits(.unspecified)
            // One space unless the line asked for more. Read defensively: the
            // words are a ForEach, so a bad line should set oddly, not crash.
            let gap = index < spacesBefore.count ? spacesBefore[index] : 1
            // Spaces inside the line count; spaces eaten by a break do not.
            // A line's own leading spaces (index 0) always count.
            if !isRowStart || index == 0 {
                x += CGFloat(gap) * space
            }
            if !isRowStart, x + size.width > width {
                y += rowHeight + rowGap
                x = indent
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x)
            isRowStart = false
        }

        guard !origins.isEmpty else {
            return ([], CGSize(width: 0, height: subviews[0].sizeThatFits(.unspecified).height))
        }
        return (origins, CGSize(width: widest, height: y + rowHeight))
    }
}
