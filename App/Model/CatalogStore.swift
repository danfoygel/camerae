import CamCore
import Foundation

/// Loads the camera catalog bundled with the app (built by tools/build_catalog.py).
@MainActor @Observable
final class CatalogStore {
    enum State {
        case loading
        case ready(CameraCatalog, RouteMatcher)
        case failed(String)
    }

    private(set) var state: State = .loading

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
                guard let url = Bundle.main.url(forResource: "cameras", withExtension: "json") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                let catalog = try CameraCatalog.decode(from: Data(contentsOf: url))
                return (catalog, RouteMatcher(cameras: catalog.cameras))
            }.value
            state = .ready(catalog, matcher)
        } catch {
            state = .failed("Couldn't load the camera catalog: \(error.localizedDescription)")
        }
    }
}
