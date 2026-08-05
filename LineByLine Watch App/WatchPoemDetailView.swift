import SwiftUI

/// The poem on the wrist, and — as on the phone — the only place you practise
/// it. There is no second page to swipe to: pressing *Practice* covers the poem
/// in place, and a tap anywhere on it lifts the next line.
struct WatchPoemDetailView: View {
    @EnvironmentObject private var store: PoemStore
    let poemID: UUID

    @State private var plan = PracticePlan.fromTop
    @State private var session: PracticeSession?
    @State private var isChoosingMode = false

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

        return VStack(spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !poem.displayAuthor.isEmpty {
                            Text(poem.displayAuthor)
                                .sectionLabel(Theme.inkSoft)
                                .padding(.bottom, 10)
                        }
                        PoemBody(poem: poem,
                                 session: session,
                                 showLineNumbers: store.showLineNumbers)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { if session != nil { revealNext() } }
                }
                .onChange(of: session?.step) { _, _ in
                    guard let index = session?.nextIndex,
                          let row = poem.lines.first(where: { $0.practiceIndex == index })?.id
                    else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(row, anchor: .center)
                    }
                }
            }

            footer(lineCount: lineCount)
        }
        .navigationTitle(poem.displayTitle)
        .sheet(isPresented: $isChoosingMode) {
            WatchPracticeSetup(lines: poem.practiceLines) { chosen in
                plan = chosen
            }
        }
    }

    @ViewBuilder
    private func footer(lineCount: Int) -> some View {
        if let session {
            if session.isComplete {
                HStack(spacing: 6) {
                    Button { begin(plan, lineCount: lineCount) } label: { wide("Again") }
                        .buttonStyle(OutlineButtonStyle())
                    Button { end() } label: { wide("Done") }
                        .buttonStyle(InkButtonStyle())
                }
            } else {
                HStack(spacing: 8) {
                    Text("\(session.step)/\(session.total)")
                        .font(Theme.label(.caption2, .regular).monospacedDigit())
                        .foregroundStyle(Theme.inkFaint)
                    Button { revealNext() } label: { wide("Next") }
                        .buttonStyle(InkButtonStyle())
                }
            }
        } else if lineCount > 0 {
            VStack(spacing: 2) {
                Button { isChoosingMode = true } label: {
                    wide(plan.name(lineCount: lineCount))
                }
                .buttonStyle(QuietButtonStyle())

                Button { begin(plan, lineCount: lineCount) } label: { wide("Practice") }
                    .buttonStyle(InkButtonStyle())
            }
        }
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
