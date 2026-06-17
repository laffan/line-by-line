import SwiftUI

/// A compact "Attempts" card summarizing practice success for a poem.
struct StatsCard: View {
    let stats: PoemStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Attempts", systemImage: "chart.bar.fill")
                    .font(.headline)
                Spacer()
                if stats.hasData {
                    Text(stats.successRate, format: .percent.precision(.fractionLength(0)))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(rateColor(stats.successRate))
                }
            }

            if stats.hasData {
                HStack(spacing: 16) {
                    metric(value: "\(stats.totalAttempts)", label: "Lines tried")
                    metric(value: "\(stats.rememberedCount)", label: "Remembered")
                    if let last = stats.lastAttempt {
                        metric(value: last.formatted(.relative(presentation: .named)),
                               label: "Last practiced")
                    }
                }
            } else {
                Text("No attempts yet. Practice this poem to track your progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A per-line breakdown of success rates.
struct StatsView: View {
    let poem: Poem
    @EnvironmentObject private var store: PoemStore

    private var stats: PoemStats { store.stats(for: poem) }

    var body: some View {
        List {
            Section {
                StatsCard(stats: stats)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if stats.hasData {
                Section("By Line") {
                    ForEach(stats.lineStats) { line in
                        lineRow(line)
                    }
                }
            }
        }
        .navigationTitle("Attempts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lineRow(_ line: LineStat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(line.text)
                .font(.subheadline)
                .lineLimit(2)
            HStack {
                ProgressView(value: line.successRate)
                    .tint(rateColor(line.successRate))
                if line.total > 0 {
                    Text("\(line.remembered)/\(line.total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

func rateColor(_ rate: Double) -> Color {
    switch rate {
    case ..<0.5: return .red
    case ..<0.8: return .orange
    default: return .green
    }
}
