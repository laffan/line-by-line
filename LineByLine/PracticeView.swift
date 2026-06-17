import SwiftUI

/// Practice mode: walks through the poem one line at a time.
///
/// Lines you've already passed stay visible. The current line is hidden until
/// you try to recall it and tap to reveal. Upcoming lines stay blurred.
struct PracticeView: View {
    let poem: Poem
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var isRevealed = false

    private var lines: [String] { poem.practiceLines }
    private var isLastLine: Bool { index >= lines.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(index + 1),
                         total: Double(max(lines.count, 1)))
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

            controls
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
            // Already practiced — shown plainly.
            Text(text)
                .font(.title3)
                .foregroundStyle(.secondary)
        } else if i == index {
            // Current line: reveal on tap.
            Text(text)
                .font(.title2.weight(.semibold))
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
                .onTapGesture {
                    withAnimation { isRevealed = true }
                }
        } else {
            // Upcoming — kept hidden.
            Text(text)
                .font(.title3)
                .blur(radius: 8)
                .opacity(0.4)
        }
    }

    private var controls: some View {
        HStack {
            Button {
                previous()
            } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(index == 0)

            Spacer()

            Button(action: advance) {
                Text(primaryButtonTitle)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private var primaryButtonTitle: String {
        if !isRevealed { return "Reveal" }
        return isLastLine ? "Start Over" : "Next Line"
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

    private func previous() {
        guard index > 0 else { return }
        withAnimation {
            index -= 1
            isRevealed = true
        }
    }
}
