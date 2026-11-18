import SwiftUI
import UIKit

/// A camera still that re-downloads every `refreshSeconds` while it is on screen.
/// SwiftUI cancels the task when the view disappears, so off-screen rows stop polling.
struct SnapshotView: View {
    let url: URL?
    let refreshSeconds: Int

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if failed || url == nil {
                Image(systemName: "video.slash").foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task(id: url) { await refreshLoop() }
    }

    private func refreshLoop() async {
        guard let url else { return }
        while !Task.isCancelled {
            await load(url)
            try? await Task.sleep(for: .seconds(refreshSeconds))
        }
    }

    private func load(_ url: URL) async {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let fresh = UIImage(data: data) else {
                failed = image == nil
                return
            }
            image = fresh
            failed = false
        } catch {
            failed = image == nil
        }
    }
}
