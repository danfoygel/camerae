import AVFoundation
import SwiftUI

@main
struct CameraeApp: App {
    @State private var catalog = CatalogStore()
    @State private var playback = LivePlayback()
    @State private var health = FeedHealth()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Muted camera video should never interrupt the user's own audio.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            NearbyMapView()
                .environment(catalog)
                .environment(playback)
                .environment(health)
                .task { await catalog.load() }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await catalog.refresh() } }
        }
    }
}
