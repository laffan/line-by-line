import Foundation
import Combine

/// Whether a cue fires on the way in or the way out.
enum CueTrigger: String, Codable, CaseIterable, Identifiable {
    case arrive, leave

    var id: String { rawValue }

    var label: String {
        switch self {
        case .arrive: return "When I arrive"
        case .leave:  return "When I leave"
        }
    }

    var shortLabel: String {
        switch self {
        case .arrive: return "Arriving"
        case .leave:  return "Leaving"
        }
    }
}

/// A place that asks you to recall a poem when you reach it — the same idea as
/// a location reminder, pointed at a poem instead of a to-do.
struct LocationCue: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    /// What the place is called, e.g. "Prospect Park".
    var placeName = ""
    /// The street or locality under the name, purely for display.
    var placeDetail = ""
    var latitude = 0.0
    var longitude = 0.0
    /// Geofence radius in metres. Below ~100m iOS gets unreliable.
    var radius = 150.0
    var trigger = CueTrigger.arrive
    /// The poem to recall, or `nil` to simply be nudged to pick one.
    var poemID: UUID?
    var isEnabled = true

    var hasLocation: Bool { latitude != 0 || longitude != 0 }

    var displayName: String {
        placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled place"
            : placeName
    }
}

/// Everything the settings panel controls.
struct AppSettings: Codable, Equatable {
    /// Number the lines of a poem in the margin.
    var showLineNumbers = false
    /// Master switch for the whole location-cue system.
    var locationCuesEnabled = false
    var cues: [LocationCue] = []

    private enum CodingKeys: String, CodingKey {
        case showLineNumbers, locationCuesEnabled, cues
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? false
        locationCuesEnabled = try container.decodeIfPresent(Bool.self, forKey: .locationCuesEnabled) ?? false
        cues = try container.decodeIfPresent([LocationCue].self, forKey: .cues) ?? []
    }
}

/// Persists ``AppSettings`` to disk and publishes changes.
///
/// The settings file is the source of truth on iOS. ``PoemStore`` mirrors the
/// one setting the watch cares about so it can travel with the poems.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { save() }
    }

    init() {
        if let data = try? Data(contentsOf: AppPaths.settings),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    // MARK: - Cues

    func upsert(_ cue: LocationCue) {
        if let index = settings.cues.firstIndex(where: { $0.id == cue.id }) {
            settings.cues[index] = cue
        } else {
            settings.cues.append(cue)
        }
    }

    func removeCues(at offsets: IndexSet) {
        settings.cues.remove(atOffsets: offsets)
    }

    func remove(_ cue: LocationCue) {
        settings.cues.removeAll { $0.id == cue.id }
    }

    /// Drop cues pointing at poems that no longer exist, so a deleted poem
    /// can't leave a cue that fires with nothing to show.
    func pruneCues(against poems: [Poem]) {
        let ids = Set(poems.map(\.id))
        for index in settings.cues.indices {
            if let poemID = settings.cues[index].poemID, !ids.contains(poemID) {
                settings.cues[index].poemID = nil
            }
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: AppPaths.settings, options: .atomic)
    }
}
