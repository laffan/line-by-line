import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Bridges the iOS and watchOS apps using `WatchConnectivity`.
///
/// The phone is the source of truth: it owns editing and pushes the full set
/// of poems to the watch. The watch is read-only and never sends poems back —
/// it only asks the phone to (re)send the current set when it launches.
final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()

    /// Called when a new set of poems arrives from the counterpart device.
    var onReceivePoems: (([Poem]) -> Void)?
    /// Called when the counterpart asks us to resend the current poems.
    var onRequestSync: (() -> Void)?
    /// Called once the session has finished activating.
    var onActivated: (() -> Void)?

    private let poemsKey = "poems"
    private let requestKey = "request"

    private override init() { super.init() }

    func activate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        #endif
    }

    /// Push the full set of poems to the counterpart device.
    func sendPoems(_ poems: [Poem]) {
        #if canImport(WatchConnectivity)
        guard let data = try? JSONEncoder().encode(poems) else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        do {
            // Application context always reflects the latest full state.
            try session.updateApplicationContext([poemsKey: data])
        } catch {
            // Fall back to a queued transfer if the context update fails.
            _ = session.transferUserInfo([poemsKey: data])
        }
        #endif
    }

    /// Ask the counterpart device to resend its current poems.
    func requestSync() {
        #if canImport(WatchConnectivity)
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([requestKey: "sync"], replyHandler: nil, errorHandler: nil)
        #endif
    }

    private func decodeAndDeliver(_ payload: [String: Any]) {
        guard let data = payload[poemsKey] as? Data,
              let poems = try? JSONDecoder().decode([Poem].self, from: data) else { return }
        onReceivePoems?(poems)
    }
}

#if canImport(WatchConnectivity)
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated {
            onActivated?()
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so the session keeps working after switching watches.
        session.activate()
    }
    #endif

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        decodeAndDeliver(applicationContext)
    }

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        decodeAndDeliver(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message[requestKey] != nil {
            onRequestSync?()
        } else {
            decodeAndDeliver(message)
        }
    }
}
#endif
