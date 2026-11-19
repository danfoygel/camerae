import CamCore
import Foundation

/// The camera catalog. Starts from the newer of the copy bundled with the app and the last one
/// downloaded, then checks for the copy that .github/workflows/catalog.yml publishes daily.
@MainActor @Observable
final class CatalogStore {
    enum State {
        case loading
        case ready(CameraCatalog, RouteMatcher)
        case failed(String)
    }

    /// The path carries the schema version, so this build keeps reading v1 after a breaking
    /// change ships as v2.
    nonisolated static let remoteURL = URL(
        string: "https://raw.githubusercontent.com/danfoygel/camerae-catalog/main/v\(CameraCatalog.schemaVersion)/cameras.json")!

    /// The bundled copy is the fallback, so a purged cache costs only a download.
    nonisolated private static let cacheURL = URL.cachesDirectory.appending(path: "cameras-v\(CameraCatalog.schemaVersion).json")
    nonisolated private static let etagKey = "catalogETag"

    /// The catalog is rebuilt daily, so checking more often than this on foreground is waste.
    private static let refreshInterval: TimeInterval = 6 * 3600

    private(set) var state: State = .loading
    private var lastRefresh: Date?
    private var isRefreshing = false

    var catalog: CameraCatalog? {
        if case .ready(let catalog, _) = state { catalog } else { nil }
    }

    var matcher: RouteMatcher? {
        if case .ready(_, let matcher) = state { matcher } else { nil }
    }

    func load() async {
        guard case .loading = state else { return }
        do {
            let (catalog, matcher) = try await Task.detached(priority: .userInitiated) {
                let catalog = try Self.loadLocal()
                return (catalog, RouteMatcher(cameras: catalog.cameras))
            }.value
            state = .ready(catalog, matcher)
        } catch {
            state = .failed("Couldn't load the camera catalog: \(error.localizedDescription)")
        }
        await refresh()
    }

    /// Switches to the published catalog if it's newer than the one in use. Any failure keeps
    /// the current catalog and leaves the next call free to try again.
    func refresh() async {
        if case .loading = state { return }  // load() refreshes once the local copy is in
        if isRefreshing { return }
        if let lastRefresh, Date.now.timeIntervalSince(lastRefresh) < Self.refreshInterval { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let current = catalog
        do {
            let update = try await Task.detached(priority: .utility) {
                try await Self.download(newerThan: current)
            }.value
            if let update {
                state = .ready(update, RouteMatcher(cameras: update.cameras))
            }
            lastRefresh = .now
        } catch {
            // Offline, or GitHub is unreachable. The catalog in hand still works.
        }
    }

    nonisolated private static func loadLocal() throws -> CameraCatalog {
        // A cached copy that's corrupt or from another schema is simply passed over.
        let cached = try? CameraCatalog.decode(from: Data(contentsOf: cacheURL))
        let bundled = try Bundle.main.url(forResource: "cameras", withExtension: "json")
            .map { try CameraCatalog.decode(from: Data(contentsOf: $0)) }
        guard let newest = [cached, bundled].compactMap({ $0 }).max(by: { $1.isNewer(than: $0) }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return newest
    }

    /// Returns the published catalog when it's newer than `current`, and caches it.
    nonisolated private static func download(newerThan current: CameraCatalog?) async throws -> CameraCatalog? {
        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData)
        // The ETag describes the cached file, so it's only worth sending while that file exists.
        if FileManager.default.fileExists(atPath: cacheURL.path()),
           let etag = UserDefaults.standard.string(forKey: etagKey) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode
        if status == 304 { return nil }
        guard status == 200 else { throw URLError(.badServerResponse) }

        let catalog = try CameraCatalog.decode(from: data)
        if let current, !catalog.isNewer(than: current) { return nil }
        try data.write(to: cacheURL, options: .atomic)
        UserDefaults.standard.set((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag"), forKey: etagKey)
        return catalog
    }
}
