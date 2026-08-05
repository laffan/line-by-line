import SwiftUI
import MapKit
import CoreLocation
import Combine

/// Search-as-you-type over MapKit's place database, plus wherever you are now.
final class PlaceSearch: NSObject, ObservableObject {
    @Published var query = "" {
        didSet { completer.queryFragment = query }
    }
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    @Published private(set) var isLocating = false

    private let completer = MKLocalSearchCompleter()
    private let locationManager = CLLocationManager()
    private var whenLocated: ((CLLocationCoordinate2D?) -> Void)?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        locationManager.delegate = self
    }

    /// Turn a search suggestion into a real coordinate.
    func resolve(_ completion: MKLocalSearchCompletion,
                 then handler: @escaping (MKMapItem?) -> Void) {
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            handler(response?.mapItems.first)
        }
    }

    /// One-shot fix for "here".
    func locateMe(then handler: @escaping (CLLocationCoordinate2D?) -> Void) {
        whenLocated = handler
        isLocating = true
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.requestLocation()
    }

    private func finishLocating(_ coordinate: CLLocationCoordinate2D?) {
        isLocating = false
        whenLocated?(coordinate)
        whenLocated = nil
    }
}

extension PlaceSearch: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

extension PlaceSearch: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finishLocating(locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finishLocating(nil)
    }
}

/// Choose the place a cue watches.
struct PlacePickerView: View {
    /// Called with the place's name, the line under it, and its coordinate.
    let onPick: (String, String, CLLocationCoordinate2D) -> Void

    @StateObject private var search = PlaceSearch()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("", text: $search.query, prompt: Text("Search for a place"))
                    .textFieldStyle(.plain)
                    .font(Theme.serif(.title3))
                    .foregroundStyle(Theme.ink)
                    .tint(Theme.accent)
                    .autocorrectionDisabled()
                    .padding(.horizontal, Theme.margin)
                    .padding(.vertical, 18)

                Hairline()

                ScrollView {
                    VStack(spacing: 0) {
                        currentLocationRow
                        Hairline()

                        ForEach(search.results, id: \.self) { result in
                            Button { pick(result) } label: {
                                rowLabel(title: result.title, detail: result.subtitle)
                            }
                            .buttonStyle(.plain)
                            Hairline()
                        }
                    }
                }
            }
            .paperBackground()
            .navigationTitle("Add a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.label(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .tint(Theme.ink)
    }

    private var currentLocationRow: some View {
        Button {
            search.locateMe { coordinate in
                guard let coordinate else { return }
                onPick("Here", "Your current location", coordinate)
                dismiss()
            }
        } label: {
            HStack {
                rowLabel(title: search.isLocating ? "Finding you…" : "Current location",
                         detail: "Use where you are right now")
                Image(systemName: "location")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.trailing, Theme.margin)
            }
        }
        .buttonStyle(.plain)
        .disabled(search.isLocating)
    }

    private func rowLabel(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.serif(.body))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
            if !detail.isEmpty {
                Text(detail)
                    .sectionLabel(Theme.inkFaint)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.margin)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func pick(_ result: MKLocalSearchCompletion) {
        search.resolve(result) { item in
            guard let item else { return }
            let name = item.name ?? result.title
            onPick(name, result.subtitle, item.placemark.coordinate)
            dismiss()
        }
    }
}
