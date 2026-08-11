import SwiftUI

/// The poem, and the only place you practise it.
///
/// There is no separate practice screen: pressing *Practice* covers the poem
/// where it sits and the bar at the foot of the page starts lifting lines, one
/// tap at a time. Tapping the poem itself does the same thing.
struct PoemDetailView: View {
    @EnvironmentObject private var store: PoemStore
    @EnvironmentObject private var settings: SettingsStore
    let poemID: UUID

    @State private var isEditing = false
    @State private var plan = PracticePlan.fromTop
    @State private var session: PracticeSession?
    @State private var isPickingLine = false
    @State private var pendingDirection = PracticeDirection.forward
    @StateObject private var player = ReadingPlayer()

    var body: some View {
        Group {
            if let poem = store.poem(id: poemID) {
                page(for: poem)
            } else {
                EmptyState(title: "Poem not found",
                           message: "It may have been deleted on another device.")
                    .paperBackground()
            }
        }
    }

    // MARK: - Page

    private func page(for poem: Poem) -> some View {
        let lineCount = poem.practiceLines.count

        return VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        titleBlock(for: poem)
                            .padding(.horizontal, Theme.margin)
                        Section {
                            PoemBody(poem: poem,
                                     session: session,
                                     showLineNumbers: settings.settings.showLineNumbers)
                                .padding(.top, 28)
                                .padding(.bottom, 40)
                                .padding(.horizontal, Theme.margin)
                                .contentShape(Rectangle())
                                .onTapGesture { if session != nil { revealNext() } }
                        } header: {
                            // The reading rides at the head of the poem, then
                            // pins to the top of the screen while it scrolls by.
                            if let reading = poem.readingFileName {
                                readingHeader(fileName: reading)
                            }
                        }
                    }
                }
                .onChange(of: session?.step) { _, _ in
                    guard let index = session?.nextIndex,
                          let row = rowID(forPracticeIndex: index, in: poem) else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(row, anchor: .center)
                    }
                }
            }

            Hairline()
            footer(lineCount: lineCount)
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                practiceToolbarButton(lineCount: lineCount)
                editToolbarButton
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack { PoemEditorView(poem: poem, isNew: false) }
                .environmentObject(store)
        }
        .sheet(isPresented: $isPickingLine) {
            LinePickerView(lines: poem.practiceLines,
                           direction: pendingDirection) { index in
                plan = PracticePlan(direction: pendingDirection, startIndex: index)
            }
        }
        .onAppear { player.prepare(fileName: poem.readingFileName) }
        .onChange(of: poem.readingFileName) { _, newValue in
            // The reading may have been recorded, replaced, or removed in the editor.
            player.reset()
            player.prepare(fileName: newValue)
        }
        .onDisappear { player.reset() }
    }

    private func titleBlock(for poem: Poem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(poem.displayTitle)
                .font(Theme.serif(.largeTitle))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !poem.displayAuthor.isEmpty {
                Text(poem.displayAuthor)
                    .sectionLabel(Theme.inkSoft)
            }

            Rectangle()
                .fill(Theme.ink)
                .frame(width: 28, height: 1)
                .padding(.top, 6)
        }
        .padding(.top, 12)
    }

    /// The player dressed as a shelf: paper behind it and a hairline under it,
    /// so the poem slides beneath while it's pinned.
    private func readingHeader(fileName: String) -> some View {
        VStack(spacing: 12) {
            readingRow(fileName: fileName)
                .padding(.horizontal, Theme.margin)
            Hairline()
        }
        .padding(.top, 10)
        .background(Theme.paper)
    }

    private func readingRow(fileName: String) -> some View {
        HStack(spacing: 10) {
            Button {
                player.toggle(fileName: fileName)
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Theme.ink))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause reading" : "Play reading")

            skipBackButton(seconds: 5, symbol: "gobackward.5")
            skipBackButton(seconds: 15, symbol: "gobackward.15")

            Text("Reading").sectionLabel(Theme.inkSoft)

            ProgressRule(fraction: player.progress)
                .frame(maxWidth: .infinity)

            Text(formatDuration(player.duration))
                .font(Theme.label(.caption2, .regular).monospacedDigit())
                .foregroundStyle(Theme.inkFaint)
        }
    }

    private func skipBackButton(seconds: TimeInterval, symbol: String) -> some View {
        Button {
            player.skipBack(seconds)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back \(Int(seconds)) seconds")
    }

    // MARK: - Toolbar

    /// The same corner control the watch has: it opens a practice session, and
    /// closes the one that's running.
    private func practiceToolbarButton(lineCount: Int) -> some View {
        Button {
            if session == nil {
                begin(plan, lineCount: lineCount)
            } else {
                end()
            }
        } label: {
            Image(systemName: session == nil ? "play.fill" : "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(session == nil ? Theme.ink : Theme.accent)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(lineCount == 0 ? 0.3 : 1)
        .disabled(lineCount == 0)
        .accessibilityLabel(session == nil ? "Practice" : "End practice")
    }

    private var editToolbarButton: some View {
        Button { isEditing = true } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit")
    }

    // MARK: - Footer

    private func footer(lineCount: Int) -> some View {
        VStack(spacing: 14) {
            if let session {
                practiceStatus(session: session, lineCount: lineCount)
            }

            HStack(spacing: 16) {
                if let session {
                    if session.isComplete {
                        Button("Again") { begin(plan, lineCount: lineCount) }
                            .buttonStyle(OutlineButtonStyle())
                        Spacer(minLength: 0)
                        Button("Done") { end() }
                            .buttonStyle(InkButtonStyle())
                    } else {
                        Button("Show all") { revealAll() }
                            .buttonStyle(QuietButtonStyle())
                        Spacer(minLength: 0)
                        Button("Next line") { revealNext() }
                            .buttonStyle(InkButtonStyle())
                    }
                } else {
                    modeMenu(lineCount: lineCount)
                    Spacer(minLength: 0)
                    Button("Practice") { begin(plan, lineCount: lineCount) }
                        .buttonStyle(InkButtonStyle(isEnabled: lineCount > 0))
                        .disabled(lineCount == 0)
                }
            }
        }
        .padding(.horizontal, Theme.margin)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(Theme.paper)
    }

    private func practiceStatus(session: PracticeSession, lineCount: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(session.plan.name(lineCount: lineCount)).sectionLabel(Theme.inkSoft)
                Spacer()
                Text(session.isComplete
                     ? "Complete"
                     : "\(session.step) of \(session.total)")
                    .font(Theme.label(.caption2, .regular).monospacedDigit())
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(session.isComplete ? Theme.accent : Theme.inkFaint)
            }
            ProgressRule(fraction: session.total == 0
                         ? 0
                         : Double(session.step) / Double(session.total))
        }
    }

    private func modeMenu(lineCount: Int) -> some View {
        Menu {
            Button("From the top") {
                plan = .fromTop
            }
            Button("Start at a line…") {
                pendingDirection = .forward
                isPickingLine = true
            }
            Divider()
            Button("From the bottom") {
                plan = .fromBottom(lineCount: lineCount)
            }
            Button("Back from a line…") {
                pendingDirection = .backward
                isPickingLine = true
            }
        } label: {
            HStack(spacing: 6) {
                Text(plan.name(lineCount: lineCount))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .sectionLabel(Theme.inkSoft)
        }
        .disabled(lineCount == 0)
    }

    // MARK: - Session

    private func begin(_ requested: PracticePlan, lineCount: Int) {
        guard lineCount > 0 else { return }
        // The poem may have been edited since the mode was chosen.
        var clamped = requested
        clamped.startIndex = min(max(clamped.startIndex, 0), lineCount - 1)
        plan = clamped
        withAnimation(.easeInOut(duration: 0.25)) {
            session = PracticeSession(plan: clamped, lineCount: lineCount)
        }
    }

    private func revealNext() {
        guard session?.isComplete == false else { return }
        withAnimation(.easeOut(duration: 0.28)) {
            session?.revealNext()
        }
    }

    private func revealAll() {
        withAnimation(.easeOut(duration: 0.35)) {
            session?.revealAll()
        }
    }

    private func end() {
        withAnimation(.easeInOut(duration: 0.25)) {
            session = nil
        }
    }

    private func rowID(forPracticeIndex index: Int, in poem: Poem) -> Int? {
        poem.lines.first { $0.practiceIndex == index }?.id
    }
}

/// A hairline that fills from the left as something progresses.
struct ProgressRule: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.rule)
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 1.5)
    }
}

/// Pick the line a session should start from.
private struct LinePickerView: View {
    let lines: [String]
    let direction: PracticeDirection
    let onPick: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(direction == .forward
                         ? "Practice runs from the line you pick to the end of the poem."
                         : "Practice runs from the line you pick back up to the beginning.")
                        .font(Theme.serif(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, Theme.margin)
                        .padding(.vertical, 18)

                    Hairline()

                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Button {
                            onPick(index)
                            dismiss()
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(.caption2, design: .serif).monospacedDigit())
                                    .foregroundStyle(Theme.inkFaint)
                                    .frame(width: Theme.gutter, alignment: .trailing)
                                Text(line)
                                    .font(Theme.serif(.body))
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, Theme.margin)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Hairline()
                    }
                }
            }
            .paperBackground()
            .navigationTitle("Choose a line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.label(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }
}

/// The app's one empty-state treatment.
struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(Theme.serif(.title3))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(Theme.serif(.subheadline))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.margin)
    }
}
