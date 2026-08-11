import AVFoundation
import Combine
import Foundation

/// Records a spoken reading of a poem straight into the app's Readings folder.
///
/// Recording writes to a fresh file immediately; the editor keeps the name and
/// throws the file away if the edit is cancelled, so a scrapped take never
/// lingers on disk.
final class ReadingRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    /// Set when the microphone has been refused, so the panel can explain.
    @Published var isMicrophoneDenied = false

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileName: String?

    /// Ask for the microphone, then start a new take.
    func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.isMicrophoneDenied = true
                    return
                }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return
        }

        let name = "\(UUID().uuidString).m4a"
        let url = AppPaths.reading(named: name)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else { return }
        recorder.record()

        self.recorder = recorder
        fileName = name
        elapsed = 0
        isRecording = true

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            self.elapsed = recorder.currentTime
        }
    }

    /// Finish the take and hand back the file name to store on the poem.
    @discardableResult
    func stop() -> String? {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let name = fileName
        fileName = nil
        return name
    }

    /// Abandon the take and delete what was captured.
    func cancel() {
        let name = stop()
        AppPaths.removeReading(named: name)
        elapsed = 0
    }
}

/// Plays a stored reading. One instance per screen; playing a second reading
/// replaces the first.
final class ReadingPlayer: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    /// Load a reading without playing it, so the duration can be shown.
    func prepare(fileName: String?) {
        guard let fileName, player == nil else { return }
        guard let loaded = Self.load(fileName) else { return }
        player = loaded
        loaded.delegate = self
        duration = loaded.duration
    }

    func toggle(fileName: String) {
        if isPlaying {
            pause()
        } else {
            play(fileName: fileName)
        }
    }

    func play(fileName: String) {
        if player == nil, let loaded = Self.load(fileName) {
            player = loaded
            loaded.delegate = self
            duration = loaded.duration
        }
        guard let player else { return }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        isPlaying = true

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.player, player.duration > 0 else { return }
            self.progress = player.currentTime / player.duration
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    /// Jump back a few seconds — for catching a line you missed. Works while
    /// paused too, so you can set up before pressing play.
    func skipBack(_ seconds: TimeInterval) {
        guard let player else { return }
        player.currentTime = max(0, player.currentTime - seconds)
        if player.duration > 0 {
            progress = player.currentTime / player.duration
        }
    }

    /// Stop and forget the current file — used when the reading is replaced.
    func reset() {
        pause()
        player = nil
        progress = 0
        duration = 0
    }

    private static func load(_ fileName: String) -> AVAudioPlayer? {
        let url = AppPaths.reading(named: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }
}

extension ReadingPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.progress = 0
            self.timer?.invalidate()
            self.timer = nil
            player.currentTime = 0
        }
    }
}

/// Copy a file the user picked in the document browser into the Readings
/// folder and return its new name.
func importReading(from url: URL) -> String? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
    let name = "\(UUID().uuidString).\(ext)"
    let destination = AppPaths.reading(named: name)
    do {
        try FileManager.default.copyItem(at: url, to: destination)
        return name
    } catch {
        return nil
    }
}

/// Format a duration as m:ss.
func formatDuration(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}
