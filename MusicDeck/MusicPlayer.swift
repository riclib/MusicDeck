import Foundation
import MediaPlayer
import Combine

struct Playlist: Identifiable {
    let id: String
    let name: String
    var artwork: UIImage?
    let mediaPlaylist: MPMediaPlaylist?
}

class MusicPlayer: ObservableObject {
    static let shared = MusicPlayer()

    private let player = MPMusicPlayerController.systemMusicPlayer
    private static let pinnedKey = "pinnedPlaylistIDs"

    @Published var nowPlaying: MPMediaItem?
    @Published var isPlaying: Bool = false
    @Published var isShuffling: Bool = false
    @Published var playlists: [Playlist] = []
    @Published var pinnedIDs: Set<String> = []
    @Published var upNext: [MPMediaItem] = []

    private var currentPlaylistItems: [MPMediaItem] = []
    private var currentStartIndex: Int = 0

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
        loadPinnedArtwork()
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

    private static var artworkCacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PlaylistArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func cachedArtwork(for id: String) -> UIImage? {
        let file = artworkCacheDir.appendingPathComponent("\(id).png")
        guard let data = try? Data(contentsOf: file) else { return nil }
        return UIImage(data: data)
    }

    private static func cacheArtwork(_ image: UIImage, for id: String) {
        let file = artworkCacheDir.appendingPathComponent("\(id).png")
        if let data = image.pngData() {
            try? data.write(to: file)
        }
    }

    private static func randomAlbumArt(from playlist: MPMediaPlaylist, id: String) -> UIImage? {
        // Check disk cache first
        if let cached = cachedArtwork(for: id) { return cached }

        let items = playlist.items
        guard !items.isEmpty else { return nil }
        let size = CGSize(width: 100, height: 100)
        for _ in 0..<min(10, items.count) {
            let item = items[Int.random(in: 0..<items.count)]
            if let image = item.artwork?.image(at: size) {
                cacheArtwork(image, for: id)
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
            return Playlist(
                id: "\(mediaPlaylist.persistentID)",
                name: name,
                artwork: nil,
                mediaPlaylist: mediaPlaylist
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        DispatchQueue.main.async {
            self.playlists = resolved
            self.loadPinnedArtwork()
        }
    }

    func loadPinnedArtwork() {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var updates: [(Int, UIImage)] = []
            for (index, playlist) in playlists.enumerated() {
                guard pinnedIDs.contains(playlist.id),
                      playlist.artwork == nil,
                      let mediaPlaylist = playlist.mediaPlaylist else { continue }
                if let art = Self.randomAlbumArt(from: mediaPlaylist, id: playlist.id) {
                    updates.append((index, art))
                }
            }
            DispatchQueue.main.async {
                for (index, art) in updates {
                    guard index < self.playlists.count else { continue }
                    self.playlists[index].artwork = art
                }
            }
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

        // Build the play order: from startIndex to end, then wrap around
        var ordered: [MPMediaItem] = []
        for i in startIndex..<items.count { ordered.append(items[i]) }
        for i in 0..<startIndex { ordered.append(items[i]) }
        currentPlaylistItems = ordered
        currentStartIndex = 0

        let descriptor = MPMusicPlayerMediaItemQueueDescriptor(itemCollection: mediaPlaylist)
        descriptor.startItem = items[startIndex]
        player.setQueue(with: descriptor)
        player.shuffleMode = .off
        player.repeatMode = .all
        player.play()

        updateUpNext()
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

    func toggleShuffle() {
        if player.shuffleMode == .off {
            player.shuffleMode = .songs
        } else {
            player.shuffleMode = .off
        }
        isShuffling = player.shuffleMode != .off
    }

    func skipTo(_ item: MPMediaItem) {
        // Skip forward until we reach the target item
        guard let idx = currentPlaylistItems.firstIndex(where: { $0.persistentID == item.persistentID }) else { return }
        guard let currentIdx = currentPlaylistItems.firstIndex(where: { $0.persistentID == player.nowPlayingItem?.persistentID }) else { return }

        if idx > currentIdx {
            // Skip forward the right number of times
            let skips = idx - currentIdx
            for _ in 0..<skips {
                player.skipToNextItem()
            }
        }
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
        updateUpNext()
    }

    private func updateUpNext() {
        guard let current = player.nowPlayingItem,
              !currentPlaylistItems.isEmpty else {
            upNext = []
            return
        }

        // Find current song in our ordered list
        if let idx = currentPlaylistItems.firstIndex(where: { $0.persistentID == current.persistentID }) {
            let remaining = Array(currentPlaylistItems.dropFirst(idx + 1))
            upNext = Array(remaining.prefix(20))
        }
    }
}
