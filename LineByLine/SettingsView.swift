import SwiftUI

/// The settings panel: how a poem is set on the page, and where the app is
/// allowed to interrupt you.
struct SettingsView: View {
    @EnvironmentObject private var store: PoemStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var cues: LocationCueManager
    @Environment(\.dismiss) private var dismiss

    @State private var editingCue: LocationCue?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    pageSection
                    Hairline()
                    cueSection
                }
            }
            .paperBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.label(.footnote, .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .sheet(item: $editingCue) { cue in
                CueEditorView(cue: cue,
                              isNew: !settings.settings.cues.contains { $0.id == cue.id })
                    .environmentObject(store)
                    .environmentObject(settings)
            }
        }
        .tint(Theme.ink)
        .onAppear { cues.refreshNotificationStatus() }
    }

    // MARK: - The page

    private var pageSection: some View {
        section("The page") {
            Toggle(isOn: $settings.settings.showLineNumbers) {
                rowText("Line numbers",
                        detail: "Number the lines in the margin, so you can start practice anywhere.")
            }
            .toggleStyle(.switch)
            .tint(Theme.ink)
        }
    }

    // MARK: - Location cues

    private var cueSection: some View {
        section("Location cues") {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pin a poem to a place and Line by Line will ask you to recall it when you get there — on the platform, at the top of the hill, wherever it belongs.")
                    .font(Theme.serif(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $settings.settings.locationCuesEnabled) {
                    rowText("Cue me by place", detail: nil)
                }
                .toggleStyle(.switch)
                .tint(Theme.ink)

                if settings.settings.locationCuesEnabled {
                    if let blocker = cues.blocker {
                        permissionNote(blocker)
                    }

                    if settings.settings.cues.isEmpty {
                        Text("No places yet.")
                            .sectionLabel(Theme.inkFaint)
                    } else {
                        VStack(spacing: 0) {
                            Hairline()
                            ForEach(settings.settings.cues) { cue in
                                cueRow(cue)
                                Hairline()
                            }
                        }
                    }

                    Button("Add a place") { editingCue = LocationCue() }
                        .buttonStyle(OutlineButtonStyle())

                    if settings.settings.cues.count > LocationCueManager.maxCues {
                        Text("iOS watches at most \(LocationCueManager.maxCues) places at a time. The ones beyond that are kept but won't fire.")
                            .font(Theme.serif(.caption))
                            .foregroundStyle(Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func cueRow(_ cue: LocationCue) -> some View {
        HStack(spacing: 12) {
            Button { editingCue = cue } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(cue.displayName)
                        .font(Theme.serif(.body))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Text(subtitle(for: cue))
                        .sectionLabel(Theme.inkFaint)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: enabledBinding(for: cue))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Theme.ink)
                .scaleEffect(0.85)
        }
        .padding(.vertical, 14)
    }

    private func subtitle(for cue: LocationCue) -> String {
        let poem = cue.poemID.flatMap { store.poem(id: $0) }?.displayTitle ?? "Any poem"
        return "\(cue.trigger.shortLabel) · \(poem)"
    }

    private func permissionNote(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .font(Theme.serif(.subheadline))
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
            Button("Allow access") { cues.requestPermissions() }
                .buttonStyle(OutlineButtonStyle())
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Theme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Theme.rule, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    private func enabledBinding(for cue: LocationCue) -> Binding<Bool> {
        Binding(
            get: { settings.settings.cues.first { $0.id == cue.id }?.isEnabled ?? false },
            set: { newValue in
                guard let index = settings.settings.cues
                    .firstIndex(where: { $0.id == cue.id }) else { return }
                settings.settings.cues[index].isEnabled = newValue
            }
        )
    }

    // MARK: - Layout

    private func rowText(_ title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(Theme.serif(.body))
                .foregroundStyle(Theme.ink)
            if let detail {
                Text(detail)
                    .font(Theme.serif(.caption))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
