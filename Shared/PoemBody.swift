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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.lineGap) {
            ForEach(poem.lines) { line in
                if line.isBreak {
                    Color.clear.frame(height: Theme.lineGap)
                } else {
                    LineRow(line: line,
                            state: state(for: line),
                            showLineNumbers: showLineNumbers)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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

    private var isCovered: Bool { state == .concealed || state == .next }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if showLineNumbers, let index = line.practiceIndex {
                Text("\(index + 1)")
                    .font(.system(.caption2, design: .serif).monospacedDigit())
                    .foregroundStyle(state == .next ? Theme.accent : Theme.inkFaint)
                    .frame(width: Theme.gutter, alignment: .trailing)
                    .padding(.trailing, 10)
            }

            Text(line.text)
                .font(Theme.verse)
                .lineSpacing(6)
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
