import SwiftUI

/// Practice mode on the watch: one line at a time, tap to reveal.
struct WatchPracticeView: View {
    let poem: Poem
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var isRevealed = false

    private var lines: [String] { poem.practiceLines }
    private var isLastLine: Bool { index >= lines.count - 1 }

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(index + 1),
                         total: Double(max(lines.count, 1)))

            Text("\(index + 1) / \(lines.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            currentLine

            Spacer(minLength: 0)

            Button(action: advance) {
                Text(primaryButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
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
            .onTapGesture {
                withAnimation { isRevealed = true }
            }
    }

    private var primaryButtonTitle: String {
        if !isRevealed { return "Reveal" }
        return isLastLine ? "Start Over" : "Next"
    }

    private func advance() {
        withAnimation {
            if !isRevealed {
                isRevealed = true
            } else if isLastLine {
                index = 0
                isRevealed = false
            } else {
                index += 1
                isRevealed = false
            }
        }
    }
}
