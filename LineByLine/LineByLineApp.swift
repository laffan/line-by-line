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
                .onAppear { syncEverything() }
                .onChange(of: settings.settings) { _, _ in syncEverything() }
                .onChange(of: store.poems) { _, poems in
                    // A deleted poem shouldn't leave a cue pointing at nothing.
                    settings.pruneCues(against: poems)
                    syncEverything()
                }
        }
    }

    /// Push the settings that live elsewhere: the watch's copy of the
    /// line-number preference, and the scheduled location cues.
    @MainActor
    private func syncEverything() {
        store.setShowLineNumbers(settings.settings.showLineNumbers)
        cues.sync(cues: settings.settings.cues,
                  enabled: settings.settings.locationCuesEnabled,
                  poems: store.poems)
    }
}
