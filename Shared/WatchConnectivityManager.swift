import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// The data exchanged between the phone and the watch.
///
/// `poems` is only sent by the phone (the source of truth for poem content).
/// `attempts` flows in both directions and is merged by union on each device.
struct SyncPayload: Codable {
    var poems: [Poem]?
    var attempts: [LineAttempt]?
}

/// Bridges the iOS and watchOS apps using `WatchConnectivity`.
///
/// Poem content is owned by the phone and pushed to the watch. Practice
/// attempts are recorded on either device and merged together, so success
/// rates reflect practice from both.
final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()

    /// Called when a payload arrives from the counterpart device.
    var onReceive: ((SyncPayload) -> Void)?
    /// Called when the counterpart asks us to resend our current state.
    var onRequestSync: (() -> Void)?
    /// Called once the session has finished activating.
    var onActivated: (() -> Void)?

    private let payloadKey = "payload"
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

    /// Send the current state to the counterpart device.
    func send(_ payload: SyncPayload) {
        #if canImport(WatchConnectivity)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        // Application context keeps the latest full state for a fresh launch.
        try? session.updateApplicationContext([payloadKey: data])
        // A queued transfer guarantees delivery even when not reachable.
        _ = session.transferUserInfo([payloadKey: data])
        #endif
    }

    /// Ask the counterpart device to resend its current state.
    func requestSync() {
        #if canImport(WatchConnectivity)
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([requestKey: "sync"], replyHandler: nil, errorHandler: nil)
        #endif
    }

    private func decodeAndDeliver(_ message: [String: Any]) {
        guard let data = message[payloadKey] as? Data,
              let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) else { return }
        onReceive?(payload)
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
