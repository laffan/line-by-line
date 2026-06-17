# Line by Line

A small SwiftUI app for **iOS and watchOS** that helps you memorize poetry.

- **Editor** — add a poem with a title and its lines.
- **View mode** — read the whole poem, stanza breaks preserved.
- **Practice mode** — walk through the poem one line at a time: recall the next
  line, tap to reveal, then move on. Past lines stay visible, upcoming lines
  stay blurred.
- **Watch sync** — poems entered on iPhone automatically sync to the paired
  Apple Watch, which offers the same view and practice modes (read-only).

## Project layout

```
Shared/                      Code shared by both apps
  Poem.swift                 The poem model
  PoemStore.swift            Persistence + sync coordination
  WatchConnectivityManager.swift   WatchConnectivity bridge

LineByLine/                  iOS app
  LineByLineApp.swift
  PoemListView.swift         List of poems + add button
  PoemEditorView.swift       Title + content editor
  PoemDetailView.swift       View mode
  PracticeView.swift         Line-by-line practice

LineByLine Watch App/        watchOS app
  LineByLineWatchApp.swift
  WatchPoemListView.swift
  WatchPoemDetailView.swift  View mode
  WatchPracticeView.swift    Line-by-line practice
```

The iPhone is the source of truth. It persists poems to disk (JSON in the app's
Application Support directory) and pushes the full set to the watch via
`WatchConnectivity`. The watch caches what it receives and asks the phone to
resend on launch.

## Building

Open `LineByLine.xcodeproj` in **Xcode 16 or later** and run the `LineByLine`
scheme on an iOS simulator or device. The watch app is embedded in the iOS app
and installs alongside it.

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
