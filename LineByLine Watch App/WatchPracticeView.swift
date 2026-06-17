import SwiftUI

/// Practice mode on the watch: one line at a time, tap to reveal, then grade
/// yourself with ✓ / ✗. Grades are recorded and synced back to the phone.
struct WatchPracticeView: View {
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
        VStack(spacing: 8) {
            if finished {
                completion
            } else {
                ProgressView(value: Double(index + 1), total: Double(max(lines.count, 1)))
                Text("\(index + 1) / \(lines.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
                currentLine
                Spacer(minLength: 0)

                controls
            }
        }
        .padding(.horizontal, 4)
        .navigationTitle("Practice")
    }

    private var currentLine: some View {
        Text(lines.isEmpty ? "" : lines[index])
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .blur(radius: isRevealed ? 0 : 7)
            .overlay {
                if !isRevealed {
                    Text("Tap to reveal")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { reveal() }
    }

    @ViewBuilder
    private var controls: some View {
        if !isRevealed {
            Button(action: reveal) {
                Text("Reveal").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } else {
            HStack(spacing: 8) {
                Button { grade(remembered: false) } label: {
                    Image(systemName: "xmark").frame(maxWidth: .infinity)
                }
                .tint(.red)

                Button { grade(remembered: true) } label: {
                    Image(systemName: "checkmark").frame(maxWidth: .infinity)
                }
                .tint(.green)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var completion: some View {
        VStack(spacing: 8) {
            Text("Complete")
                .font(.headline)
            Text("\(sessionRemembered) / \(sessionTotal)")
                .foregroundStyle(.secondary)
            Button("Again") { restart() }
                .buttonStyle(.borderedProminent)
            Button("Done") { dismiss() }
                .buttonStyle(.bordered)
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
