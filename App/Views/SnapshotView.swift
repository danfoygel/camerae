import CamCore
import SwiftUI
import UIKit

/// A camera still that re-downloads every `refreshSeconds` while it is on screen.
/// SwiftUI cancels the task when the view disappears, so off-screen rows stop polling.
struct SnapshotView: View {
    let camera: Camera
    let refreshSeconds: Int
    /// Spell out "Camera offline" beside the icon; thumbnails are too small for it.
    var showsOfflineText = false

    @Environment(FeedHealth.self) private var health
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if health.isOffline(camera.id) {
                // Never show the DOT's error image itself: it reads like a live frame.
                VStack(spacing: 6) {
                    Image(systemName: "video.slash")
                    if showsOfflineText { Text("Camera offline").font(.subheadline) }
                }
                .foregroundStyle(.secondary)
            } else if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if failed || camera.snapshotURL == nil {
                Image(systemName: "video.slash").foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task(id: camera.snapshotURL) { await refreshLoop() }
    }

    private func refreshLoop() async {
        guard let url = camera.snapshotURL else { return }
        while !Task.isCancelled {
            await load(url)
            try? await Task.sleep(for: .seconds(refreshSeconds))
        }
    }

    private func load(_ url: URL) async {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let (fresh, isPlaceholder) = await Self.decode(data)
            else {
                failed = image == nil
                return
            }
            health.record(camera.id, offline: isPlaceholder)
            image = fresh
            failed = false
        } catch {
            failed = image == nil
        }
    }

    /// Decodes and classifies off the main actor.
    private nonisolated static func decode(_ data: Data) async -> (UIImage, Bool)? {
        guard let image = UIImage(data: data) else { return nil }
        return (image, PlaceholderDetector.standard.isPlaceholder(data))
    }
}
