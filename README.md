# MusicDeck

A full-screen iPad Apple Music controller built with SwiftUI. Designed to sit on a desk or stand and act as a dedicated music display — large album art, minimal controls, and a playlist picker that stays out of the way.

![MusicDeck screenshot](https://github.com/riclib/MusicDeck/assets/screenshot.png)

## Features

- **Full-screen album art** with blurred background, track title, and artist
- **Up Next queue sidebar** — tap a song to skip to it, album boundaries marked
- **Dynamic playlist management** — all Apple Music playlists available, double-tap to pin favorites
- **Random album start** — when starting a playlist, jumps to a random album boundary so you get variety without shuffle
- **Shuffle toggle** — switch between sequential and shuffled playback
- **Pinned playlist artwork** — randomly sampled album art from playlist contents, cached to disk
- **Controls Apple Music directly** — uses `systemMusicPlayer`, so you can switch to Apple Music and everything stays in sync
- **Screen stays awake** — idle timer disabled, perfect for a desk display

## Requirements

- iPad with iPadOS 17.0+
- Apple Music library with playlists
- Xcode 15+
- Apple Developer account (free works, paid avoids 7-day expiry)

## Setup

1. Clone the repo and open `MusicDeck.xcodeproj` in Xcode
2. Set your Development Team in Signing & Capabilities
3. Connect your iPad and hit Run (Cmd+R)
4. Grant Apple Music access when prompted

## Usage

- **Tap the screen** to reveal the playlist tray
- **Tap a playlist** to start playback from a random album
- **Tap `>>`** to expand and see all playlists
- **Double-tap a playlist** (in expanded view) to pin/unpin it
- **Tap outside the tray** to dismiss it
- **Tap the list icon** (right of transport controls) to show the Up Next queue
- **Tap a song in the queue** to skip to it

## Architecture

Three source files:

| File | Purpose |
|------|---------|
| `MusicDeckApp.swift` | App entry point, audio session, media library auth |
| `MusicPlayer.swift` | `ObservableObject` singleton wrapping `MPMusicPlayerController.systemMusicPlayer` — playback, playlist resolution, pinning, artwork caching |
| `ContentView.swift` | Full-screen UI — album art, transport controls, playlist tray, queue sidebar |

## License

MIT
