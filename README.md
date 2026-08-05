# Line by Line

A small SwiftUI app for **iOS and watchOS** that helps you memorize poetry.

- **Editor** — a poem's title, author, a recorded or imported reading of it, and
  its lines.
- **The poem screen** — the poem set on paper-toned ground in a serif, stanza
  breaks preserved, with an optional line-number margin.
- **Practice, in place** — practice isn't a separate screen. Press *Practice*
  and the poem blacks out where it sits; each tap (on the poem, or on *Next
  line*) lifts one more bar. Four modes:
  - **From the top** — down the page, the way you'd recite it.
  - **From line *n*** — start anywhere and run to the end.
  - **From the bottom** — learn the last line first and work backwards into it.
  - **Back from line *n*** — the same, starting where you choose.
- **Readings** — record yourself reading a poem, or import an audio file, and
  play it back from the poem screen.
- **Location cues** — pin a poem to a place and the app asks you to recall it
  when you arrive there or leave, the way Reminders does. Each cue becomes one
  repeating geofenced notification; tapping it opens that poem.
- **Watch sync** — poems entered on iPhone sync to the paired Apple Watch, which
  practises them the same way, on the same screen.

## Project layout

```
Shared/                      Code shared by both apps
  Poem.swift                 The poem model and its lines
  Practice.swift             Practice modes and session state
  PoemBody.swift             The poem as it's drawn, covered or uncovered
  PoemStore.swift            Persistence + sync coordination
  AppPaths.swift             Where things live on disk
  Theme.swift                Palette, type, rules, button styles
  WatchConnectivityManager.swift   WatchConnectivity bridge

LineByLine/                  iOS app
  LineByLineApp.swift
  PoemListView.swift         The library
  PoemEditorView.swift       Title, author, reading, lines
  PoemDetailView.swift       The poem, and practice in place
  AudioReading.swift         Recording, importing, and playing a reading
  AppSettings.swift          Settings model + store
  SettingsView.swift         Settings panel
  CueEditorView.swift        One location cue
  PlacePickerView.swift      MapKit place search
  LocationCueManager.swift   Permissions and geofenced notifications

LineByLine Watch App/        watchOS app
  LineByLineWatchApp.swift
  WatchPoemListView.swift
  WatchPoemDetailView.swift  The poem, and practice in place
```

The iPhone is the source of truth: it persists poems to disk (JSON in the app's
Application Support directory) and pushes them, plus the line-number preference,
to the watch via `WatchConnectivity`. Recorded readings stay on the phone —
audio doesn't travel over the connectivity session.

Location cues are rebuilt from scratch whenever settings change: each enabled cue
becomes one repeating `UNLocationNotificationTrigger`, so iOS does the monitoring
and the app holds no background execution of its own. iOS watches at most 20
regions per app, and the settings panel says so when you go past that.

## Design

The interface is built from one small set of tokens in `Theme.swift`: a warm
paper ground, deep ink text, hairline rules, small tracked capitals for anything
the app says, and a serif for the poem itself. No screen uses the system's
grouped-list chrome or default control tinting, so the phone and watch read as
the same printed object.

## Building

Open `LineByLine.xcodeproj` in **Xcode 16 or later** and run the `LineByLine`
scheme on an iOS simulator or device. The watch app is embedded in the iOS app
and installs alongside it.

Location cues need notification permission and **Always** location access;
recording needs the microphone. The usage strings are set as
`INFOPLIST_KEY_*` build settings on the iOS target.

The project uses Xcode's file-system-synchronized groups, so new files added to
the `Shared`, `LineByLine`, or `LineByLine Watch App` folders are picked up
automatically — no need to register them in the project file.

### Regenerating the project file

If you prefer to manage the project with [XcodeGen](https://github.com/yonaskolb/XcodeGen),
the spec lives in `project.yml`:

```sh
brew install xcodegen
xcodegen generate
```

## Customizing the bundle identifier

The identifiers default to `com.laffan.LineByLine` (iOS) and
`com.laffan.LineByLine.watchkitapp` (watch). To use your own team, change
`PRODUCT_BUNDLE_IDENTIFIER` for both targets in Xcode's build settings (and
`INFOPLIST_KEY_WKCompanionAppBundleIdentifier` on the watch target so it keeps
matching the iOS bundle id), then set your signing team.
