import AVFoundation
import SwiftUI

@main
struct CameraeApp: App {
    @State private var catalog = CatalogStore()
    @State private var playback = LivePlayback()

    init() {
        // Muted camera video should never interrupt the user's own audio.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            SearchView()
                .environment(catalog)
                .environment(playback)
                .task { await catalog.load() }
        }
    }
}
