import SwiftUI
import AVFoundation
import MediaPlayer

@main
struct MusicDeckApp: App {
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }

        MPMediaLibrary.requestAuthorization { status in
            if status != .authorized {
                print("Media library access not authorized: \(status.rawValue)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(MusicPlayer.shared)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
