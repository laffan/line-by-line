import SwiftUI

/// The poem on the wrist, and — as on the phone — the only place you practise
/// it. There is no second page to swipe to: the button in the top corner covers
/// the poem in place, and a tap anywhere on it lifts the next line.
struct WatchPoemDetailView: View {
    @EnvironmentObject private var store: PoemStore
    let poemID: UUID

    @State private var plan = PracticePlan.fromTop
    @State private var session: PracticeSession?
    @State private var isChoosingMode = false
    @State private var scrollTask: Task<Void, Never>?

    /// How long an uncovered line holds still — long enough to read it — before
    /// the page moves on to the next one.
    private static let readingPause: Duration = .seconds(2)
    /// Scroll target for the head of the page, above the first line.
    private static let pageTop = "page-top"

    var body: some View {
        if let poem = store.poem(id: poemID) {
            content(for: poem)
        } else {
            Text("Not found")
                .font(Theme.serif(.body))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func content(for poem: Poem) -> some View {
        let lineCount = poem.practiceLines.count

        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let session {
                        practiceHeader(session: session, lineCount: lineCount)
                    } else if !poem.displayAuthor.isEmpty {
                        Text(poem.displayAuthor)
                            .sectionLabel(Theme.inkSoft)
                            .padding(.bottom, 10)
                    }

                    // No line-number gutter here: the margin is a phone
                    // affordance, and the wrist has no width to spare.
                    PoemBody(poem: poem, session: session, showLineNumbers: false)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture { if session != nil { revealNext() } }

                    if session?.isComplete == true {
                        completion(lineCount: lineCount)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(Self.pageTop)
            }
            .onChange(of: session?.step) { _, _ in
                scheduleScroll(in: poem, proxy: proxy)
            }
        }
        .navigationTitle(poem.displayTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                practiceButton(lineCount: lineCount)
            }
        }
        .sheet(isPresented: $isChoosingMode) {
            WatchPracticeSetup(lines: poem.practiceLines) { chosen in
                begin(chosen, lineCount: lineCount)
            }
        }
        .onDisappear { scrollTask?.cancel() }
    }

    /// The one control on the screen: it opens a practice session, and closes
    /// the one that's running.
    private func practiceButton(lineCount: Int) -> some View {
        Button {
            if session == nil {
                begin(plan, lineCount: lineCount)
            } else {
                end()
            }
        } label: {
            Image(systemName: session == nil ? "play.fill" : "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(session == nil ? Theme.ink : Theme.accent)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(lineCount == 0 ? 0.3 : 1)
        .disabled(lineCount == 0)
        .accessibilityLabel(session == nil ? "Practice" : "End practice")
    }

    /// While a session runs, the top of the page carries the practice type —
    /// tap it to work a different way — and how far through you are.
    private func practiceHeader(session: PracticeSession, lineCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button { isChoosingMode = true } label: {
                    HStack(spacing: 4) {
                        Text(session.plan.name(lineCount: lineCount))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .semibold))
                    }
                    .sectionLabel(Theme.inkSoft)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Text(session.isComplete ? "Done" : "\(session.step)/\(session.total)")
                    .font(Theme.label(.caption2, .regular).monospacedDigit())
                    .foregroundStyle(session.isComplete ? Theme.accent : Theme.inkFaint)
            }

            Hairline()

            if session.step == 0 {
                Text("Tap the poem to reveal")
                    .sectionLabel(Theme.inkFaint)
            }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func completion(lineCount: Int) -> some View {
        VStack(spacing: 8) {
            Hairline()
            HStack(spacing: 6) {
                Button { begin(plan, lineCount: lineCount) } label: { wide("Again") }
                    .buttonStyle(OutlineButtonStyle())
                Button { end() } label: { wide("Done") }
                    .buttonStyle(InkButtonStyle())
            }
        }
        .padding(.top, 14)
    }

    /// Watch buttons share the width they're given rather than hugging their text.
    private func wide(_ title: String) -> some View {
        Text(title).frame(maxWidth: .infinity)
    }

    // MARK: - Session

    private func begin(_ requested: PracticePlan, lineCount: Int) {
        guard lineCount > 0 else { return }
        var clamped = requested
        clamped.startIndex = min(max(clamped.startIndex, 0), lineCount - 1)
        plan = clamped
        withAnimation(.easeInOut(duration: 0.25)) {
            session = PracticeSession(plan: clamped, lineCount: lineCount)
        }
    }

    private func revealNext() {
        guard session?.isComplete == false else { return }
        withAnimation(.easeOut(duration: 0.28)) { session?.revealNext() }
    }

    private func end() {
        withAnimation(.easeInOut(duration: 0.25)) { session = nil }
    }

    // MARK: - Following the session down the page

    /// Bring the next line into view.
    ///
    /// The line you just uncovered stays where it is for ``readingPause`` first,
    /// so the page doesn't slide out from under you mid-line. Opening a session
    /// is the exception: it goes to its starting line at once.
    private func scheduleScroll(in poem: Poem, proxy: ScrollViewProxy) {
        scrollTask?.cancel()
        scrollTask = nil

        guard let session, let index = session.nextIndex else { return }

        guard session.step > 0 else {
            if session.plan.direction == .forward, index == 0 {
                // Starting at the first line means starting at the head of the
                // page, where the mode you're working in sits.
                scroll(to: Self.pageTop, anchor: .top, proxy: proxy)
            } else if let row = rowID(for: index, in: poem) {
                scroll(to: row, anchor: .center, proxy: proxy)
            }
            return
        }

        guard let row = rowID(for: index, in: poem) else { return }
        scrollTask = Task { @MainActor in
            try? await Task.sleep(for: Self.readingPause)
            guard !Task.isCancelled else { return }
            scroll(to: row, anchor: .center, proxy: proxy)
        }
    }

    private func rowID(for practiceIndex: Int, in poem: Poem) -> Int? {
        poem.lines.first { $0.practiceIndex == practiceIndex }?.id
    }

    private func scroll<ID: Hashable>(to id: ID, anchor: UnitPoint, proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(id, anchor: anchor)
        }
    }
}

/// Choose a mode — and, for the two that need one, a starting line. Both steps
/// live in one sheet so the second never has to wait for the first to close.
private struct WatchPracticeSetup: View {
    let lines: [String]
    let onChoose: (PracticePlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var path: [PracticeDirection] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 8) {
                    row("From the top") { choose(.fromTop) }
                    row("Start at a line") { path.append(.forward) }
                    row("From the bottom") { choose(.fromBottom(lineCount: lines.count)) }
                    row("Back from a line") { path.append(.backward) }
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("Mode")
            .navigationDestination(for: PracticeDirection.self) { direction in
                linePicker(direction)
            }
        }
    }

    private func linePicker(_ direction: PracticeDirection) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Button {
                        choose(PracticePlan(direction: direction, startIndex: index))
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            // Not the poem's line-number margin — the number is
                            // what tells two identical refrains apart here.
                            Text("\(index + 1)")
                                .font(.system(.caption2, design: .serif).monospacedDigit())
                                .foregroundStyle(Theme.inkFaint)
                            Text(line)
                                .font(Theme.serif(.footnote))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
        .navigationTitle("Line")
    }

    private func choose(_ plan: PracticePlan) {
        dismiss()
        onChoose(plan)
    }

    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.serif(.body))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
