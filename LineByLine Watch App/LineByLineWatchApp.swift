import SwiftUI

@main
struct LineByLineWatchApp: App {
    @StateObject private var store = PoemStore()

    var body: some Scene {
        WindowGroup {
            WatchPoemListView()
                .environmentObject(store)
        }
    }
}
