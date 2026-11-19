import CamCore
import CoreLocation
import MapKit
import SwiftUI

/// The home screen: a map of the cameras around you. Tap a camera to watch it; "Where to?"
/// opens the route planner.
struct NearbyMapView: View {
    private enum Screen: Hashable { case planner }

    /// California and Nevada, shown until (or unless) the current location is known. Positions
    /// are cameras rather than regions: a region is re-fit whenever the camera card changes the
    /// map's safe area, which would zoom the map out from under the user.
    private static let coverage = MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 37.6, longitude: -118.6), distance: 2_200_000)
    /// Cameras this close to a tapped one are offered as other views of the same site.
    private static let siteRadius: CLLocationDistance = 70

    @Environment(CatalogStore.self) private var catalog
    @Environment(LivePlayback.self) private var playback
    // The `-from … -to …` development shortcut goes straight to the planner, which runs it.
    @State private var path: [Screen] = UserDefaults.standard.string(forKey: "to") != nil ? [.planner] : []
    @State private var position: MapCameraPosition = .camera(Self.coverage)
    @State private var region: MKCoordinateRegion?
    @State private var pins: [Camera] = []
    /// All cameras in view, including the ones thinned out of `pins`.
    @State private var inView = 0
    /// The tapped camera's site, nearest view first; the card switches between them.
    @State private var site: [Camera] = []
    @State private var selected: Camera?

    var body: some View {
        NavigationStack(path: $path) {
            map
                .safeAreaInset(edge: .top) { whereTo }
                .safeAreaInset(edge: .bottom) {
                    if let selected {
                        NearbyCameraCard(camera: selected, site: site,
                                         onChoose: { self.selected = $0 },
                                         onClose: { select(nil) })
                            .padding(.horizontal).padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationTitle("Map")
                .navigationDestination(for: Screen.self) { _ in SearchView() }
                .onAppear { if let selected { playback.play(selected) } }
                .onDisappear { playback.stop() }
        }
        .onChange(of: selected) { _, camera in
            if let camera { playback.play(camera) } else { playback.stop() }
        }
        .onChange(of: catalog.catalog == nil) { updatePins() }
        .task { await centerOnUser() }
    }

    private var map: some View {
        Map(position: $position) {
            ForEach(pins) { camera in
                Annotation("", coordinate: camera.clLocation, anchor: .center) {
                    CameraPin(live: camera.hlsURL != nil, selected: site.contains(camera))
                        .onTapGesture { select(camera) }
                }
                .annotationTitles(.hidden)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            region = context.region
            updatePins()
        }
    }

    private var whereTo: some View {
        Button { path.append(.planner) } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                Text("Where to?").foregroundStyle(.primary)
                Spacer()
                status
            }
            .font(.body)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.regularMaterial, in: .capsule)
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal).padding(.top, 4)
    }

    @ViewBuilder private var status: some View {
        switch catalog.state {
        case .loading:
            ProgressView().controlSize(.small)
        case .failed:
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
        case .ready:
            Label(inView.formatted(), systemImage: "video.fill")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .accessibilityLabel("\(inView) cameras in view")
        }
    }

    /// Cameras in view, at most one per grid cell so a zoomed-out map stays legible and fast.
    /// Cells snap to powers of two so small pans and zooms don't reshuffle the pins; a cell
    /// shows a camera with live video when it has one.
    private func updatePins() {
        guard let cameras = catalog.catalog?.cameras, let region else { return }
        let halfLat = region.span.latitudeDelta * 0.6, halfLon = region.span.longitudeDelta * 0.6
        let latRange = (region.center.latitude - halfLat)...(region.center.latitude + halfLat)
        let lonRange = (region.center.longitude - halfLon)...(region.center.longitude + halfLon)
        let cell = pow(2, (log2(max(region.span.latitudeDelta, region.span.longitudeDelta) / 24)).rounded(.up))
        var cells: [SIMD2<Int>: Camera] = [:]
        var count = 0
        // Pins extend a little past the edges so panning doesn't reveal an empty border.
        for camera in cameras where latRange.contains(camera.lat) && lonRange.contains(camera.lon) {
            if abs(camera.lat - region.center.latitude) <= region.span.latitudeDelta / 2,
               abs(camera.lon - region.center.longitude) <= region.span.longitudeDelta / 2 { count += 1 }
            let key = SIMD2(Int((camera.lat / cell).rounded(.down)), Int((camera.lon / cell).rounded(.down)))
            if let kept = cells[key], kept.hlsURL != nil || camera.hlsURL == nil { continue }
            cells[key] = camera
        }
        var visible = Array(cells.values)
        // The tapped pin stays put even if thinning would pick a neighbor for its cell.
        if let tapped = site.first, !visible.contains(tapped) { visible.append(tapped) }
        pins = visible
        inView = count
    }

    private func select(_ camera: Camera?) {
        withAnimation(.snappy) {
            guard let camera, let cameras = catalog.catalog?.cameras else {
                site = []
                selected = nil
                return
            }
            let center = CLLocation(latitude: camera.lat, longitude: camera.lon)
            site = cameras
                .map { ($0, CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: center)) }
                .filter { $0.1 <= Self.siteRadius }
                .sorted { $0.1 < $1.1 }
                .map(\.0)
            selected = camera
        }
    }

    /// Moves to the current location once it's known, unless the user has already moved the map.
    private func centerOnUser() async {
        guard let coordinate = try? await CurrentLocation.shared.coordinate(),
              !position.positionedByUser else { return }
        withAnimation {
            position = .camera(MapCamera(centerCoordinate: coordinate, distance: 50_000))
        }
    }
}

/// The tapped camera: live video when it has a stream, otherwise a refreshing snapshot.
private struct NearbyCameraCard: View {
    let camera: Camera
    /// Every view at the camera's site, including `camera`.
    let site: [Camera]
    let onChoose: (Camera) -> Void
    let onClose: () -> Void

    @Environment(FeedHealth.self) private var health
    @Environment(LivePlayback.self) private var playback

    /// A stream that is actually playing outranks a stale error snapshot.
    private var isOffline: Bool {
        health.isOffline(camera.id) && !(playback.cameraID == camera.id && playback.status == .playing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ExpandedMedia(camera: camera)
            if site.count > 1 { viewPicker }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(camera.displayName).font(.subheadline.weight(.semibold)).lineLimit(2)
                    HStack(spacing: 6) {
                        if isOffline {
                            Badge(text: "OFFLINE", color: .orange)
                        } else if camera.hlsURL != nil {
                            Badge(text: "LIVE", color: .red)
                        } else {
                            Badge(text: "SNAPSHOT", color: .gray)
                        }
                        if let place = camera.place {
                            Text(place).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).symbolRenderingMode(.hierarchical).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            Text(SearchView.drivingNotice).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private var viewPicker: some View {
        Picker("View", selection: Binding(get: { camera }, set: onChoose)) {
            ForEach(Array(site.enumerated()), id: \.element.id) { index, view in
                Text(view.viewCompass.map { "Looking \($0)" } ?? "View \(index + 1)").tag(view)
            }
        }
        .pickerStyle(.segmented)
    }
}
