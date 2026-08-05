import Foundation

/// Where the app keeps things on disk.
///
/// Poems and settings are small JSON files in Application Support; recorded
/// readings are audio files in a `Readings` folder beside them.
enum AppPaths {
    static var support: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static var poems: URL { support.appendingPathComponent("poems.json") }

    static var settings: URL { support.appendingPathComponent("settings.json") }

    /// The folder holding recorded and imported readings, created on demand.
    static var readings: URL {
        let url = support.appendingPathComponent("Readings", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func reading(named name: String) -> URL {
        readings.appendingPathComponent(name)
    }

    /// Delete a reading, ignoring the case where it's already gone.
    static func removeReading(named name: String?) {
        guard let name, !name.isEmpty else { return }
        try? FileManager.default.removeItem(at: reading(named: name))
    }
}
