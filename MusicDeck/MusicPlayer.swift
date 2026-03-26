import Foundation
import MediaPlayer
import Combine

struct Playlist: Identifiable {
    let id: String
    let name: String
    let artwork: UIImage?
    let mediaPlaylist: MPMediaPlaylist?
}

class MusicPlayer: ObservableObject {
    static let shared = MusicPlayer()

    private let player = MPMusicPlayerController.systemMusicPlayer
    private static let pinnedKey = "pinnedPlaylistIDs"

    @Published var nowPlaying: MPMediaItem?
    @Published var isPlaying: Bool = false
    @Published var playlists: [Playlist] = []
    @Published var pinnedIDs: Set<String> = []

    var pinnedPlaylists: [Playlist] {
        playlists
            .filter { pinnedIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var streamDeckPlaylists: [Playlist] {
        Array(pinnedPlaylists.prefix(6))
    }

    private var observers: [NSObjectProtocol] = []

    private init() {
        loadPinnedIDs()
        setupNotifications()
        resolvePlaylists()
        player.beginGeneratingPlaybackNotifications()
    }

    deinit {
        player.endGeneratingPlaybackNotifications()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Pinning

    func isPinned(_ playlist: Playlist) -> Bool {
        pinnedIDs.contains(playlist.id)
    }

    func togglePin(_ playlist: Playlist) {
        if pinnedIDs.contains(playlist.id) {
            pinnedIDs.remove(playlist.id)
        } else {
            pinnedIDs.insert(playlist.id)
        }
        savePinnedIDs()
    }

    private func loadPinnedIDs() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.pinnedKey) {
            pinnedIDs = Set(saved)
        }
    }

    private func savePinnedIDs() {
        UserDefaults.standard.set(Array(pinnedIDs), forKey: Self.pinnedKey)
    }

    // MARK: - Playlist Resolution

    private static func randomAlbumArt(from playlist: MPMediaPlaylist) -> UIImage? {
        let size = CGSize(width: 200, height: 200)
        var items = playlist.items
        items.shuffle()
        // Find the first item where artwork actually renders to an image
        for item in items {
            if let image = item.artwork?.image(at: size) {
                return image
            }
        }
        return nil
    }

    func resolvePlaylists() {
        let query = MPMediaQuery.playlists()
        guard let collections = query.collections as? [MPMediaPlaylist] else {
            print("Could not query playlists")
            return
        }

        let resolved: [Playlist] = collections.compactMap { mediaPlaylist in
            guard let name = mediaPlaylist.name, !name.isEmpty else { return nil }
            let art = Self.randomAlbumArt(from: mediaPlaylist)
            return Playlist(
                id: "\(mediaPlaylist.persistentID)",
                name: name,
                artwork: art,
                mediaPlaylist: mediaPlaylist
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        DispatchQueue.main.async {
            self.playlists = resolved
        }
    }

    // MARK: - Playback Controls

    func play(playlist: Playlist) {
        guard let mediaPlaylist = playlist.mediaPlaylist else {
            print("Playlist '\(playlist.name)' not found in library")
            return
        }

        let items = mediaPlaylist.items
        guard !items.isEmpty else { return }

        // Pick a random point, then find the next album boundary
        let randomIndex = Int.random(in: 0..<items.count)
        let albumAtRandom = items[randomIndex].albumPersistentID
        var startIndex = randomIndex
        for i in (randomIndex + 1)..<items.count {
            if items[i].albumPersistentID != albumAtRandom {
                startIndex = i
                break
            }
        }
        if startIndex == randomIndex {
            startIndex = 0
        }

        let descriptor = MPMusicPlayerMediaItemQueueDescriptor(itemCollection: mediaPlaylist)
        descriptor.startItem = items[startIndex]
        player.setQueue(with: descriptor)
        player.shuffleMode = .off
        player.repeatMode = .all
        player.play()
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func next() {
        player.skipToNextItem()
    }

    func prev() {
        player.skipToPreviousItem()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        let playbackChanged = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            self?.updatePlaybackState()
        }

        let nowPlayingChanged = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            self?.updateNowPlaying()
        }

        observers = [playbackChanged, nowPlayingChanged]
    }

    private func updatePlaybackState() {
        isPlaying = player.playbackState == .playing
    }

    private func updateNowPlaying() {
        nowPlaying = player.nowPlayingItem
    }
}
