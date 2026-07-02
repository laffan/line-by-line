import SwiftUI
import AVFoundation

/// Drives playback of a single reading audio file, exposing just enough state
/// for a minimal transport: play/pause, a scrubber, and elapsed/total time.
@MainActor
final class ReadingPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    private var player: AVAudioPlayer?
    private var ticker: Timer?

    /// Prepare a file for playback. No-op if the same file is already loaded.
    func load(_ url: URL) {
        if player?.url == url { return }
        teardown()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            duration = player.duration
        } catch {
            player = nil
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTicker()
        } else {
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            startTicker()
        }
    }

    func seek(to time: Double) {
        guard let player else { return }
        let clamped = min(max(0, time), duration)
        player.currentTime = clamped
        currentTime = clamped
    }

    /// Stop playback and release the player.
    func teardown() {
        stopTicker()
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let player, player.isPlaying else { return }
        currentTime = player.currentTime
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopTicker()
        }
    }
}

/// A minimal reading player: a play/pause button and a scrubber with times.
struct ReadingPlayerView: View {
    let url: URL
    @StateObject private var player = ReadingPlayer()

    var body: some View {
        HStack(spacing: 14) {
            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause reading" : "Play reading")

            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }),
                    in: 0...max(player.duration, 0.01))
                HStack {
                    Text(timeString(player.currentTime))
                    Spacer()
                    Text(timeString(player.duration))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .onAppear { player.load(url) }
        .onDisappear { player.teardown() }
        .onChange(of: url) { _, newURL in
            player.teardown()
            player.load(newURL)
        }
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
