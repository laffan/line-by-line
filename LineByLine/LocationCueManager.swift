import Foundation
import Combine
import CoreLocation
import UserNotifications

/// Turns ``LocationCue`` values into real geofenced notifications.
///
/// Each enabled cue becomes one repeating `UNLocationNotificationTrigger`, so
/// iOS does the monitoring and we hold no background execution of our own —
/// the same machinery Reminders uses for "remind me here".
///
/// The whole set is torn down and rebuilt whenever settings change. Cues are
/// few and rebuilding is cheap, and it keeps us from tracking which individual
/// requests drifted out of date.
final class LocationCueManager: NSObject, ObservableObject {

    /// iOS monitors at most 20 regions per app. Cues beyond that are skipped
    /// rather than silently failing, and the panel says so.
    static let maxCues = 20

    private static let identifierPrefix = "cue."

    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var locationStatus: CLAuthorizationStatus = .notDetermined
    /// Set when a cue's notification is tapped, so the app can open that poem.
    @Published var poemToOpen: UUID?

    private let center = UNUserNotificationCenter.current()
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        center.delegate = self
        locationStatus = locationManager.authorizationStatus
        refreshNotificationStatus()
    }

    // MARK: - Permissions

    /// True once both halves are granted and cues can actually fire.
    var isAuthorized: Bool {
        (notificationStatus == .authorized || notificationStatus == .provisional)
            && locationStatus == .authorizedAlways
    }

    /// What still stands between the user and a working cue, in plain words.
    var blocker: String? {
        if notificationStatus == .denied {
            return "Notifications are off for Line by Line. Turn them on in Settings to be cued."
        }
        if locationStatus == .denied || locationStatus == .restricted {
            return "Location access is off. Turn it on in Settings so cues know where you are."
        }
        if locationStatus == .authorizedWhenInUse {
            return "Set location access to Always so a cue can reach you when the app is closed."
        }
        if notificationStatus == .notDetermined || locationStatus == .notDetermined {
            return "Line by Line needs permission to notify you and to notice where you are."
        }
        return nil
    }

    /// Ask for notifications, then location. Location has to be requested in
    /// two steps: iOS only offers "Always" after "When In Use" is granted.
    func requestPermissions() {
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            self?.refreshNotificationStatus()
            DispatchQueue.main.async { self?.requestLocationPermission() }
        }
    }

    private func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func refreshNotificationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationStatus = settings.authorizationStatus
            }
        }
    }

    // MARK: - Scheduling

    /// Rebuild every scheduled cue from the current settings.
    func sync(cues: [LocationCue], enabled: Bool, poems: [Poem]) {
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let ours = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.identifierPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)

            guard enabled else { return }
            let live = cues
                .filter { $0.isEnabled && $0.hasLocation }
                .prefix(Self.maxCues)
            for cue in live {
                self.schedule(cue, poems: poems)
            }
        }
    }

    private func schedule(_ cue: LocationCue, poems: [Poem]) {
        let content = UNMutableNotificationContent()
        content.title = cue.displayName
        content.sound = .default
        content.threadIdentifier = "line-by-line.cues"

        if let poemID = cue.poemID, let poem = poems.first(where: { $0.id == poemID }) {
            let author = poem.displayAuthor
            content.body = author.isEmpty
                ? "Recall “\(poem.displayTitle)”."
                : "Recall “\(poem.displayTitle)” — \(author)."
            content.userInfo = ["poemID": poemID.uuidString]
        } else {
            content.body = "Take a moment with a poem."
        }

        // `CLCircularRegion` is soft-deprecated in iOS 17, but it remains the
        // only region type `UNLocationNotificationTrigger` accepts.
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: cue.latitude, longitude: cue.longitude),
            radius: max(cue.radius, 100),
            identifier: Self.identifierPrefix + cue.id.uuidString
        )
        region.notifyOnEntry = cue.trigger == .arrive
        region.notifyOnExit = cue.trigger == .leave

        let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.identifierPrefix + cue.id.uuidString,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationCueManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            self.locationStatus = status
            // Once "When In Use" lands, ask again for the upgrade to "Always" —
            // cues are useless if they only work with the app open.
            if status == .authorizedWhenInUse {
                manager.requestAlwaysAuthorization()
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension LocationCueManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let raw = info["poemID"] as? String, let id = UUID(uuidString: raw) {
            DispatchQueue.main.async { self.poemToOpen = id }
        }
        completionHandler()
    }
}
