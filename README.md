# Line by Line

A small SwiftUI app for **iOS and watchOS** that helps you memorize poetry.

On iPhone the app is organized into three tabs:

- **Library** — every poem you've saved.
- **Memorize** — the poems you're currently practicing, ordered by most recent
  session (newest first) so the poem you're working on is always on top.
- **Search** — browse the full [PoetryDB](https://poetrydb.org) catalog of
  titles or authors, filter it with the search field, and preview and add any
  poem with one tap. A **Random** button pulls up a surprise poem, and the
  catalog is cached on disk so it downloads only once (pull to refresh to
  re-download).

Everything else works as before:

- **Editor** — add a poem with a title, author, its lines, and an optional
  audio **reading** (browse for an audio file).
- **View mode** — read the whole poem, stanza breaks preserved. If the poem has
  a reading, a minimal audio player appears beneath the Practice button.
- **Practice mode** — walk through the poem one line at a time: recall the next
  line, tap to reveal, then grade yourself with ✓ (remembered) or ✗ (forgot).
  Past lines stay visible, upcoming lines stay blurred.
- **Attempt tracking** — every grade is saved with its date. Each poem shows an
  "Attempts" card with the overall success rate, totals, and a per-line
  breakdown. Attempts persist across sessions.
- **Watch sync** — poems entered on iPhone automatically sync to the paired
  Apple Watch. Practice happens on either device, and attempts are merged
  together so success rates reflect practice from both.

## Project layout

```
Shared/                      Code shared by both apps
  Poem.swift                 The poem model
  LineAttempt.swift          Practice attempt record + stats types
  PoemStore.swift            Persistence + sync coordination
  WatchConnectivityManager.swift   WatchConnectivity bridge

LineByLine/                  iOS app
  LineByLineApp.swift
  RootView.swift             Library / Memorize / Search tab bar
  PoemListView.swift         Library: list of poems + add button
  MemorizeView.swift         Poems in progress, most recent session first
  SearchView.swift           PoetryDB catalog browser, Random, add buttons
  PoetryDBService.swift      PoetryDB API client + result model
  PoetryCatalogStore.swift   On-disk cache of the title/author catalogs
  PoemEditorView.swift       Title + content editor + reading picker
  PoemDetailView.swift       View mode + attempts card + reading player
  ReadingPlayerView.swift    Minimal audio player for a poem's reading
  PracticeView.swift         Line-by-line practice with grading
  StatsView.swift            Attempts card + per-line breakdown

LineByLine Watch App/        watchOS app
  LineByLineWatchApp.swift
  WatchPoemListView.swift
  WatchPoemDetailView.swift  View mode
  WatchPracticeView.swift    Line-by-line practice
```

The iPhone is the source of truth for poem *content*: it persists poems to disk
(JSON in the app's Application Support directory) and pushes them to the watch
via `WatchConnectivity`. Practice *attempts* are append-only records with unique
ids, so the phone and watch merge their logs by union — practice on either
device counts toward the same success rates. Each device echoes its merged state
back once when it learns something new, so the two converge.

Readings are stored as audio files in an `Application Support/Readings` folder,
named after each poem's id. They stay on the iPhone and are not synced to the
watch (audio files are large and playback is iOS-only).

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
