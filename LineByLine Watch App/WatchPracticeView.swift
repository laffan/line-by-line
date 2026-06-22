import SwiftUI

/// Practice mode on the watch: one line at a time, tap to reveal, then grade
/// yourself with ✓ / ✗. Grades are recorded and synced back to the phone.
///
/// Shown as the second page of ``WatchPoemDetailView`` (swipe right-to-left).
struct WatchPracticeView: View {
    let poem: Poem
    @EnvironmentObject private var store: PoemStore

    @State private var index = 0
    @State private var isRevealed = false
    @State private var finished = false
    @State private var sessionRemembered = 0
    @State private var sessionTotal = 0

    private var lines: [String] { poem.practiceLines }
    private var isLastLine: Bool { index >= lines.count - 1 }

    var body: some View {
        if finished {
            completion
        } else {
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ScrollView {
                        Text(lines.isEmpty ? "" : lines[index])
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: geo.size.height)
                            .blur(radius: isRevealed ? 0 : 7)
                            .overlay {
                                if !isRevealed {
                                    Text("Tap to reveal")
                                        .font(.caption2)
                                        .foregroundStyle(.tint)
                                }
                            }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { reveal() }
                }

                if isRevealed {
                    HStack(spacing: 16) {
                        gradeButton(remembered: false, systemImage: "xmark", tint: .red)
                        gradeButton(remembered: true, systemImage: "checkmark", tint: .green)
                    }
                    .padding(.bottom, 2)
                }
            }
        }
    }

    private func gradeButton(remembered: Bool, systemImage: String, tint: Color) -> some View {
        Button {
            grade(remembered: remembered)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .frame(height: 22)
    }

    private var completion: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Complete")
                    .font(.headline)
                Text("\(sessionRemembered) / \(sessionTotal)")
                    .foregroundStyle(.secondary)
                Button("Again") { restart() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
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
