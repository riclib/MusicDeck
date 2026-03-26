# MusicDeck

## Project Overview

iPad-only SwiftUI app that controls Apple Music playback with a full-screen album art display. No third-party dependencies.

## Build & Run

- Open `MusicDeck.xcodeproj` in Xcode
- Target: iPadOS 17.0+, iPad only (`TARGETED_DEVICE_FAMILY = 2`)
- No SPM dependencies — just `MediaPlayer` and `AVFoundation` frameworks
- Bundle ID: `com.riclib.MusicDeck`

## Architecture

Three source files in `MusicDeck/`:

- **`MusicDeckApp.swift`** — App entry, audio session setup (`.playback` category), media library authorization
- **`MusicPlayer.swift`** — Singleton `ObservableObject`. Uses `MPMusicPlayerController.systemMusicPlayer` (not `applicationQueuePlayer`) so playback persists when switching to Apple Music. Handles playlist resolution, pinning (UserDefaults), artwork caching (disk), and queue tracking.
- **`ContentView.swift`** — Full-screen UI with blurred album art background, transport controls (always visible), slide-up playlist tray, and Up Next queue sidebar.

## Key Design Decisions

- **`systemMusicPlayer`** over `applicationQueuePlayer` — user can switch to Apple Music and controls still work
- **Random album start** — on playlist play, picks a random track then scans forward to the next album boundary. Gives album-level shuffle while playing tracks sequentially within albums.
- **Lazy artwork loading** — only pinned playlists load artwork (random sample of up to 10 tracks, 100x100). Cached as PNG in `Caches/PlaylistArtwork/`. This avoids memory crashes from loading artwork for hundreds of playlists.
- **No volume control** — user has external hardware (analog volume)
- **Double-tap to pin** (not long press) — long press conflicts with scroll gestures in the horizontal playlist tray

## File Layout

```
MusicDeck.xcodeproj/
MusicDeck/
  MusicDeckApp.swift
  MusicPlayer.swift
  ContentView.swift
  Info.plist
  Assets.xcassets/
    AppIcon.appiconset/
```

## Things to Watch

- SourceKit may show "unavailable in macOS" errors — these are false positives from the Mac toolchain. The app targets iPadOS only.
- `MPMediaQuery.playlists()` returns non-optional `MPMediaQuery`, not `MPMediaQuery?`
- Some playlists may have tracks where `MPMediaItemArtwork` exists but `.image(at:)` returns nil (artwork not downloaded). The random sampling handles this gracefully.
