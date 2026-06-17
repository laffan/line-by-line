import SwiftUI

@main
struct LineByLineApp: App {
    @StateObject private var store = PoemStore()

    var body: some Scene {
        WindowGroup {
            PoemListView()
                .environmentObject(store)
        }
    }
}
