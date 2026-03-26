import SwiftUI
import MediaPlayer

struct ContentView: View {
    @EnvironmentObject var musicPlayer: MusicPlayer
    @State private var showTray = false
    @State private var trayExpanded = false
    @State private var showQueue = false

    private let queueWidth: CGFloat = 320
    private let queuePadding: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let contentOffset: CGFloat = showQueue ? -(queueWidth + queuePadding) / 2 : 0

            ZStack {
                // Background — always full screen
                backgroundBlur(geometry: geometry)

                // Album art + controls — shift when queue is open
                VStack {
                    Spacer()
                    albumArt(geometry: geometry)
                    Spacer()
                    transportControls
                        .padding(.bottom, showTray ? 0 : 40)
                }
                .offset(x: contentOffset)
                .onTapGesture {
                    if showTray {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTray = false
                            trayExpanded = false
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTray = true
                        }
                    }
                }

                // Slide-up playlist tray
                if showTray {
                    VStack {
                        Spacer()
                        playlistTray
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .offset(x: contentOffset)
                }

                // Up Next queue sidebar
                if showQueue {
                    HStack {
                        Spacer()
                        queueSidebar
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundBlur(geometry: GeometryProxy) -> some View {
        if let item = musicPlayer.nowPlaying,
           let artwork = item.artwork?.image(at: CGSize(width: geometry.size.width, height: geometry.size.height)) {
            Image(uiImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .blur(radius: 20)
                .overlay(Color.black.opacity(0.4))
        } else {
            LinearGradient(
                colors: [.black, Color(white: 0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func albumArt(geometry: GeometryProxy) -> some View {
        if let item = musicPlayer.nowPlaying,
           let artwork = item.artwork?.image(at: CGSize(width: geometry.size.width, height: geometry.size.height)) {
            Image(uiImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: geometry.size.width * 0.6, maxHeight: geometry.size.height * 0.65)
                .shadow(radius: 30)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "music.note")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                Text("No Track Playing")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        VStack(spacing: 8) {
            if let item = musicPlayer.nowPlaying {
                Text(item.title ?? "Unknown Title")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(item.artist ?? "Unknown Artist")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }

            HStack(spacing: 50) {
                Button(action: { musicPlayer.toggleShuffle() }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 22))
                        .foregroundColor(musicPlayer.isShuffling ? .accentColor : .white.opacity(0.6))
                }

                Button(action: { musicPlayer.prev() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 28))
                }

                Button(action: { musicPlayer.togglePlayPause() }) {
                    Image(systemName: musicPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 54))
                }

                Button(action: { musicPlayer.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 28))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showQueue.toggle()
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 22))
                        .foregroundColor(showQueue ? .accentColor : .white.opacity(0.6))
                }
            }
            .foregroundColor(.white)
            .padding(.top, 4)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Playlist Tray

    private var playlistTray: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)

            if trayExpanded {
                expandedTray
            } else {
                collapsedTray
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }

    private var collapsedTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(musicPlayer.pinnedPlaylists) { playlist in
                    PlaylistButton(playlist: playlist) {
                        musicPlayer.play(playlist: playlist)
                    }
                }

                // Expand button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        trayExpanded = true
                    }
                } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "chevron.right.2")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.6))
                            )
                        Text("All")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 80)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var expandedTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("All Playlists")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        trayExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)

            Text("Double tap to pin/unpin")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(musicPlayer.playlists) { playlist in
                        PlaylistButton(
                            playlist: playlist,
                            isPinned: musicPlayer.isPinned(playlist),
                            onTap: {
                                musicPlayer.play(playlist: playlist)
                            },
                            onDoubleTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    musicPlayer.togglePin(playlist)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Queue Sidebar

    private var queueSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Up Next")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showQueue = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if musicPlayer.upNext.isEmpty {
                VStack {
                    Spacer()
                    Text("No queue")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(musicPlayer.upNext.enumerated()), id: \.element.persistentID) { index, item in
                            QueueRow(item: item, isFirstOfAlbum: isAlbumBoundary(at: index))
                                .onTapGesture {
                                    musicPlayer.skipTo(item)
                                }
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .padding(.vertical, 20)
        .padding(.trailing, 16)
    }

    private func isAlbumBoundary(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return musicPlayer.upNext[index].albumPersistentID != musicPlayer.upNext[index - 1].albumPersistentID
    }
}

struct QueueRow: View {
    let item: MPMediaItem
    var isFirstOfAlbum: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if let artwork = item.artwork?.image(at: CGSize(width: 44, height: 44)) {
                Image(uiImage: artwork)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? "Unknown")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(item.artist ?? "Unknown")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .overlay(alignment: .top) {
            if isFirstOfAlbum {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }
        }
    }
}

struct PlaylistButton: View {
    let playlist: Playlist
    var isPinned: Bool = false
    var onTap: () -> Void = {}
    var onDoubleTap: () -> Void = {}

    // Legacy init for collapsed tray (single tap only)
    init(playlist: Playlist, isPinned: Bool = false, action: @escaping () -> Void) {
        self.playlist = playlist
        self.isPinned = isPinned
        self.onTap = action
        self.onDoubleTap = {}
    }

    init(playlist: Playlist, isPinned: Bool = false, onTap: @escaping () -> Void, onDoubleTap: @escaping () -> Void) {
        self.playlist = playlist
        self.isPinned = isPinned
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if let artwork = playlist.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .foregroundColor(.gray)
                        )
                }

                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(Color.accentColor))
                        .offset(x: 4, y: -4)
                }
            }

            Text(playlist.name)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 80)
        }
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            onTap()
        }
    }
}
