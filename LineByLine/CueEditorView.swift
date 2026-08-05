import SwiftUI
import MapKit

/// Set up one location cue: where, which way, and which poem.
struct CueEditorView: View {
    @EnvironmentObject private var store: PoemStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var cue: LocationCue
    @State private var camera: MapCameraPosition = .automatic
    @State private var isPickingPlace = false

    private let isNew: Bool

    init(cue: LocationCue, isNew: Bool) {
        _cue = State(initialValue: cue)
        self.isNew = isNew
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: cue.latitude, longitude: cue.longitude)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    placeSection
                    Hairline()
                    cueSection
                    Hairline()
                    if !isNew {
                        Button("Delete this cue") {
                            settings.remove(cue)
                            dismiss()
                        }
                        .buttonStyle(QuietButtonStyle(color: Theme.accent))
                        .padding(.horizontal, Theme.margin)
                        .padding(.vertical, 24)
                    }
                }
            }
            .paperBackground()
            .navigationTitle(isNew ? "New cue" : "Cue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.label(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings.upsert(cue)
                        dismiss()
                    }
                    .font(Theme.label(.footnote, .bold))
                    .foregroundStyle(cue.hasLocation ? Theme.ink : Theme.inkFaint)
                    .disabled(!cue.hasLocation)
                }
            }
            .sheet(isPresented: $isPickingPlace) {
                PlacePickerView { name, detail, place in
                    cue.placeName = name
                    cue.placeDetail = detail
                    cue.latitude = place.latitude
                    cue.longitude = place.longitude
                }
            }
            .onAppear { focusMap() }
            .onChange(of: cue) { _, _ in focusMap() }
        }
        .tint(Theme.ink)
    }

    // MARK: - Place

    private var placeSection: some View {
        section("Place") {
            VStack(alignment: .leading, spacing: 18) {
                if cue.hasLocation {
                    Map(position: $camera, interactionModes: []) {
                        MapCircle(center: coordinate, radius: cue.radius)
                            .foregroundStyle(Theme.accent.opacity(0.14))
                            .stroke(Theme.accent.opacity(0.55), lineWidth: 1)
                    }
                    .mapStyle(.standard(emphasis: .muted))
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(cue.displayName)
                            .font(Theme.serif(.title3))
                            .foregroundStyle(Theme.ink)
                        if !cue.placeDetail.isEmpty {
                            Text(cue.placeDetail).sectionLabel(Theme.inkSoft)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Radius").sectionLabel()
                            Spacer()
                            Text("\(Int(cue.radius)) m")
                                .font(Theme.label(.caption2, .regular).monospacedDigit())
                                .foregroundStyle(Theme.inkFaint)
                        }
                        Slider(value: $cue.radius, in: 100...1000, step: 25)
                            .tint(Theme.ink)
                    }

                    Button("Change place") { isPickingPlace = true }
                        .buttonStyle(QuietButtonStyle())
                } else {
                    Button("Choose a place") { isPickingPlace = true }
                        .buttonStyle(OutlineButtonStyle())
                }
            }
        }
    }

    // MARK: - Cue

    private var cueSection: some View {
        section("Cue") {
            VStack(alignment: .leading, spacing: 24) {
                triggerPicker

                VStack(alignment: .leading, spacing: 10) {
                    Text("Poem").sectionLabel()
                    Menu {
                        Button("Any poem") { cue.poemID = nil }
                        if !store.poems.isEmpty { Divider() }
                        ForEach(store.poems) { poem in
                            Button(poem.displayTitle) { cue.poemID = poem.id }
                        }
                    } label: {
                        HStack {
                            Text(poemLabel)
                                .font(Theme.serif(.body))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        .padding(.bottom, 10)
                        .overlay(alignment: .bottom) { Hairline() }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
    }

    private var poemLabel: String {
        guard let id = cue.poemID, let poem = store.poem(id: id) else { return "Any poem" }
        return poem.displayTitle
    }

    private var triggerPicker: some View {
        HStack(spacing: 0) {
            ForEach(CueTrigger.allCases) { trigger in
                Button { cue.trigger = trigger } label: {
                    Text(trigger.shortLabel)
                        .font(Theme.label(.caption, .semibold))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(cue.trigger == trigger ? Theme.paper : Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(cue.trigger == trigger ? Theme.ink : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        }
    }

    // MARK: - Helpers

    private func focusMap() {
        guard cue.hasLocation else { return }
        let span = max(cue.radius * 5, 500)
        camera = .region(MKCoordinateRegion(center: coordinate,
                                            latitudinalMeters: span,
                                            longitudinalMeters: span))
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).sectionLabel()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.margin)
        .padding(.vertical, 26)
    }
}
