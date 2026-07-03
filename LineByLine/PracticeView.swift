import SwiftUI

/// Practice mode: walks through the poem one line at a time.
///
/// For each line you try to recall it, tap to reveal, then grade yourself with
/// ✓ (remembered) or ✗ (forgot). Each grade is recorded as an attempt so the
/// poem's success rate builds up over time.
struct PracticeView: View {
    let poem: Poem
    @EnvironmentObject private var store: PoemStore
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var isRevealed = false
    @State private var finished = false
    @State private var sessionRemembered = 0
    @State private var sessionTotal = 0

    private var lines: [String] { poem.practiceLines }
    private var isLastLine: Bool { index >= lines.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(index + 1), total: Double(max(lines.count, 1)))
                .padding(.horizontal)
                .padding(.top, 8)

            Text("Line \(index + 1) of \(lines.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                            lineView(index: i, text: line)
                                .id(i)
                        }
                    }
                    .padding()
                }
                .onChange(of: index) { _, newValue in
                    withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                }
            }

            Divider()
            controls
                .padding()
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func lineView(index i: Int, text: String) -> some View {
        if i < index {
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        } else if i == index {
            Text(text)
                .font(.title3.weight(.semibold))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .blur(radius: isRevealed ? 0 : 8)
                .overlay {
                    if !isRevealed {
                        Text("Tap to reveal")
                            .font(.callout)
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { reveal() }
        } else {
            Text(text)
                .font(.body)
                .blur(radius: 8)
                .opacity(0.4)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if finished {
            completion
        } else if !isRevealed {
            Button(action: reveal) {
                Text("Reveal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            HStack(spacing: 16) {
                gradeButton(remembered: false, title: "Forgot",
                            systemImage: "xmark", tint: .red)
                gradeButton(remembered: true, title: "Remembered",
                            systemImage: "checkmark", tint: .green)
            }
        }
    }

    private func gradeButton(remembered: Bool, title: String,
                             systemImage: String, tint: Color) -> some View {
        Button {
            grade(remembered: remembered)
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(tint)
    }

    private var completion: some View {
        VStack(spacing: 12) {
            Text("Session complete")
                .font(.headline)
            Text("Remembered \(sessionRemembered) of \(sessionTotal)")
                .foregroundStyle(.secondary)
            HStack {
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Practice Again") { restart() }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
    }

    private func reveal() {
        withAnimation { isRevealed = true }
    }

    private func grade(remembered: Bool) {
        store.recordAttempt(poemID: poem.id, lineIndex: index, remembered: remembered)
        sessionTotal += 1
        if remembered { sessionRemembered += 1 }

        withAnimation {
            if isLastLine {
                finished = true
            } else {
                index += 1
                isRevealed = false
            }
        }
    }

    private func restart() {
        withAnimation {
            index = 0
            isRevealed = false
            finished = false
            sessionRemembered = 0
            sessionTotal = 0
        }
    }
}
