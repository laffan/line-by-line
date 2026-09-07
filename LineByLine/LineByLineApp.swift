import SwiftUI

@main
struct LineByLineApp: App {
    @StateObject private var store = PoemStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var cues = LocationCueManager()

    var body: some Scene {
        WindowGroup {
            PoemListView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(cues)
                .tint(Theme.ink)
                .onAppear {
                    store.setShowLineNumbers(settings.settings.showLineNumbers)
                    syncCues()
                }
                .onChange(of: settings.settings.showLineNumbers) { _, value in
                    store.setShowLineNumbers(value)
                }
                // Only the settings a cue is actually built from rebuild the
                // cues. The text-size slider changes settings by the tenth as
                // it moves, and tearing every scheduled notification down and
                // back up on each step is no way to treat them.
                .onChange(of: settings.settings.locationCuesEnabled) { _, _ in syncCues() }
                .onChange(of: settings.settings.cues) { _, _ in syncCues() }
                .onChange(of: store.poems) { _, poems in
                    // A deleted poem shouldn't leave a cue pointing at nothing.
                    settings.pruneCues(against: poems)
                    syncCues()
                }
        }
    }

    /// Rebuild the scheduled location cues from the current settings.
    @MainActor
    private func syncCues() {
        cues.sync(cues: settings.settings.cues,
                  enabled: settings.settings.locationCuesEnabled,
                  poems: store.poems)
    }
}
