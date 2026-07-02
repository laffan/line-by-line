import Foundation
import Combine

/// Holds all poems and practice attempts, persists them to disk, and keeps the
/// phone and watch in sync via ``WatchConnectivityManager``.
///
/// Poem content is edited on iOS; the phone is its source of truth. Practice
/// attempts are recorded on either device and merged by union, so success
/// rates combine practice from the phone and the watch.
@MainActor
final class PoemStore: ObservableObject {
    @Published private(set) var poems: [Poem] = []
    @Published private(set) var attempts: [UUID: LineAttempt] = [:]

    private let poemsURL: URL
    private let attemptsURL: URL
    private let connectivity = WatchConnectivityManager.shared

    init(directoryName: String = "LineByLineData") {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        poemsURL = base.appendingPathComponent("poems.json")
        attemptsURL = base.appendingPathComponent("attempts.json")

        load()

        connectivity.onReceive = { [weak self] payload in
            Task { @MainActor in self?.receive(payload) }
        }
        connectivity.onRequestSync = { [weak self] in
            Task { @MainActor in self?.broadcast() }
        }
        connectivity.onActivated = { [weak self] in
            Task { @MainActor in self?.broadcast() }
        }
        connectivity.activate()

        #if os(watchOS)
        // Ask the phone for the latest poems and attempts as soon as we launch.
        connectivity.requestSync()
        #endif
    }

    // MARK: - Lookup

    func poem(id: UUID) -> Poem? {
        poems.first { $0.id == id }
    }

    /// The most recent practice attempt for a poem, if it has ever been
    /// practiced.
    func lastPracticed(for poemID: UUID) -> Date? {
        attempts.values
            .filter { $0.poemID == poemID }
            .map(\.date)
            .max()
    }

    /// Poems the user is currently memorizing: every poem that has at least one
    /// practice attempt, ordered by its most recent session (newest first).
    var poemsInProgress: [Poem] {
        poems
            .compactMap { poem in lastPracticed(for: poem.id).map { (poem, $0) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// Whether a poem with the same title and author is already saved. Used to
    /// avoid adding the same PoetryDB result twice.
    func containsPoem(title: String, author: String) -> Bool {
        poems.contains {
            $0.title.caseInsensitiveCompare(title) == .orderedSame &&
            $0.author.caseInsensitiveCompare(author) == .orderedSame
        }
    }

    // MARK: - Poem mutations (iOS)

    func add(_ poem: Poem) {
        poems.append(poem)
        didChangePoems()
    }

    func update(_ poem: Poem) {
        var updated = poem
        updated.dateModified = Date()
        if let index = poems.firstIndex(where: { $0.id == poem.id }) {
            poems[index] = updated
        } else {
            poems.append(updated)
        }
        didChangePoems()
    }

    func delete(_ poem: Poem) {
        poems.removeAll { $0.id == poem.id }
        attempts = attempts.filter { $0.value.poemID != poem.id }
        didChangePoems()
        saveAttempts()
    }

    func delete(at offsets: IndexSet) {
        let removed = offsets.map { poems[$0].id }
        poems.remove(atOffsets: offsets)
        attempts = attempts.filter { !removed.contains($0.value.poemID) }
        didChangePoems()
        saveAttempts()
    }

    // MARK: - Practice attempts (iOS + watchOS)

    /// Record whether a line was successfully recalled during practice.
    func recordAttempt(poemID: UUID, lineIndex: Int, remembered: Bool) {
        let attempt = LineAttempt(poemID: poemID, lineIndex: lineIndex, remembered: remembered)
        attempts[attempt.id] = attempt
        saveAttempts()
        broadcast()
    }

    func history(for poemID: UUID) -> [LineAttempt] {
        attempts.values
            .filter { $0.poemID == poemID }
            .sorted { $0.date < $1.date }
    }

    /// Aggregated statistics for a poem, keyed to its current lines.
    func stats(for poem: Poem) -> PoemStats {
        let relevant = history(for: poem.id)
        guard !relevant.isEmpty else { return .empty }

        let lines = poem.practiceLines
        var totals = Array(repeating: 0, count: lines.count)
        var remembered = Array(repeating: 0, count: lines.count)
        var rememberedTotal = 0

        for attempt in relevant {
            if attempt.remembered { rememberedTotal += 1 }
            guard lines.indices.contains(attempt.lineIndex) else { continue }
            totals[attempt.lineIndex] += 1
            if attempt.remembered { remembered[attempt.lineIndex] += 1 }
        }

        let lineStats = lines.indices.map { i in
            LineStat(lineIndex: i, text: lines[i], total: totals[i], remembered: remembered[i])
        }

        return PoemStats(totalAttempts: relevant.count,
                         rememberedCount: rememberedTotal,
                         lastAttempt: relevant.last?.date,
                         lineStats: lineStats)
    }

    // MARK: - Sync

    private func didChangePoems() {
        sortPoems()
        savePoems()
        broadcast()
    }

    private func sortPoems() {
        poems.sort { $0.dateModified > $1.dateModified }
    }

    /// Build and send the current state to the counterpart device. The watch
    /// never sends poem content (the phone owns it).
    private func broadcast() {
        #if os(iOS)
        connectivity.send(SyncPayload(poems: poems, attempts: Array(attempts.values)))
        #else
        connectivity.send(SyncPayload(poems: nil, attempts: Array(attempts.values)))
        #endif
    }

    private func receive(_ payload: SyncPayload) {
        var attemptsChanged = false

        // Only the watch adopts incoming poems; the phone is the source of truth.
        #if os(watchOS)
        if let incoming = payload.poems {
            poems = incoming.sorted { $0.dateModified > $1.dateModified }
            savePoems()
        }
        #endif

        if let incoming = payload.attempts {
            for attempt in incoming where attempts[attempt.id] == nil {
                attempts[attempt.id] = attempt
                attemptsChanged = true
            }
            if attemptsChanged { saveAttempts() }
        }

        // If we learned something new, echo our merged state back so the other
        // device converges too. The counterpart finds nothing new and stops.
        if attemptsChanged {
            broadcast()
        }
    }

    // MARK: - Persistence

    private func load() {
        if let data = try? Data(contentsOf: poemsURL),
           let decoded = try? JSONDecoder().decode([Poem].self, from: data) {
            poems = decoded.sorted { $0.dateModified > $1.dateModified }
        }
        if let data = try? Data(contentsOf: attemptsURL),
           let decoded = try? JSONDecoder().decode([LineAttempt].self, from: data) {
            attempts = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        }
    }

    private func savePoems() {
        guard let data = try? JSONEncoder().encode(poems) else { return }
        try? data.write(to: poemsURL, options: .atomic)
    }

    private func saveAttempts() {
        guard let data = try? JSONEncoder().encode(Array(attempts.values)) else { return }
        try? data.write(to: attemptsURL, options: .atomic)
    }
}
