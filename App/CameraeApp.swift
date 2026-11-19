import AVFoundation
import SwiftUI

@main
struct CameraeApp: App {
    @State private var catalog = CatalogStore()
    @State private var playback = LivePlayback()
    @State private var health = FeedHealth()
    @State private var access = VideoAccess()
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
                .environment(access)
                .sheet(isPresented: $access.isPaywallPresented) {
                    PaywallView().environment(access)
                }
                .task { await catalog.load() }
                .task { await access.refreshSubscription() }
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            Task { await catalog.refresh() }
            Task { await access.refresh() }
        }
    }
}
