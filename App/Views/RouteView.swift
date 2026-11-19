import CamCore
import MapKit
import SwiftUI

struct RouteView: View {
    let plan: PlannedRoute

    @Environment(CatalogStore.self) private var catalog
    @Environment(LivePlayback.self) private var playback
    @State private var optionID = 0
    @State private var selectedID: String?
    @State private var liveOnly = false
    @State private var position: MapCameraPosition = .automatic

    private var option: PlannedRoute.Option { plan.options[optionID] }

    private var cameras: [RouteCamera] {
        liveOnly ? option.cameras.filter { $0.camera.hlsURL != nil } : option.cameras
    }

    /// Stable 1-based numbers in route order, shared by map pins and rows.
    private var numbers: [String: Int] {
        Dictionary(uniqueKeysWithValues: option.cameras.enumerated().map { ($1.id, $0 + 1) })
    }

    var body: some View {
        VStack(spacing: 0) {
            map.frame(height: 240)
            if plan.options.count > 1 { routePicker }
            summary
            Divider()
            cameraList
        }
        .navigationTitle(plan.to)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: $liveOnly) { Label("Live only", systemImage: "video.fill") }
                    .toggleStyle(.button)
            }
        }
        .onChange(of: selectedID) { _, id in
            guard let id, let selected = option.cameras.first(where: { $0.id == id }) else {
                playback.stop()
                return
            }
            playback.play(selected.camera)
            withAnimation {
                position = .camera(MapCamera(centerCoordinate: selected.camera.clLocation, distance: 12_000))
            }
        }
        .onDisappear { playback.stop() }
    }

    private var routeLines: [RouteLine] {
        plan.options
            .map { RouteLine(option: $0, selected: $0.id == optionID) }
            .sorted { !$0.selected && $1.selected }
    }

    private var map: some View {
        let numbers = numbers
        return MapReader { proxy in
            Map(position: $position) {
                // The chosen route draws last, on top. Keying on selection too makes MapKit replace
                // lines whose style changed; it doesn't reliably restyle an existing overlay.
                ForEach(routeLines) { line in
                    MapPolyline(line.option.route.polyline)
                        .stroke(line.selected ? .blue : .gray.opacity(0.7), lineWidth: 5)
                }
                ForEach(cameras) { routeCamera in
                    Annotation("", coordinate: routeCamera.camera.clLocation, anchor: .center) {
                        CameraPin(number: numbers[routeCamera.id] ?? 0,
                                  live: routeCamera.camera.hlsURL != nil,
                                  selected: routeCamera.id == selectedID)
                            .onTapGesture { select(routeCamera.id) }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onTapGesture { point in
                if let tapped = alternative(near: point, proxy: proxy) { choose(tapped) }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button { withAnimation { position = .automatic } } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").padding(8)
            }
            .buttonStyle(.bordered).background(.thinMaterial, in: .rect(cornerRadius: 8)).padding(8)
        }
    }

    private var routePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(plan.options) { option in
                    RouteChip(option: option, selected: option.id == optionID) { choose(option.id) }
                }
            }
            .padding(.horizontal).padding(.top, 8)
        }
    }

    private var summary: some View {
        let live = option.cameras.filter { $0.camera.hlsURL != nil }.count
        return HStack {
            Text("\(option.cameras.count) cameras · \(live) live")
                .font(.subheadline.bold())
            Spacer()
            Text("\(Format.distance(option.route.distance)) · \(Format.duration(option.route.expectedTravelTime))")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    private var cameraList: some View {
        let numbers = numbers
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if cameras.isEmpty {
                        ContentUnavailableView(
                            "No cameras on this route",
                            systemImage: "video.slash",
                            description: Text("Camera coverage is California and Nevada for now.")
                        )
                        .padding(.top, 40)
                    }
                    ForEach(cameras) { routeCamera in
                        CameraRow(routeCamera: routeCamera,
                                  number: numbers[routeCamera.id] ?? 0,
                                  isSelected: routeCamera.id == selectedID) {
                            select(routeCamera.id == selectedID ? nil : routeCamera.id)
                        } onStep: { step(by: $0) }
                        .id(routeCamera.id)
                        Divider().padding(.leading)
                    }
                    attribution
                }
            }
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .top) }
            }
        }
    }

    private var attribution: some View {
        let sourceIDs = Set(option.cameras.map(\.camera.source))
        let lines = catalog.catalog?.sources.filter { sourceIDs.contains($0.id) }.map(\.attribution) ?? []
        return VStack(spacing: 2) {
            ForEach(lines, id: \.self) { Text($0) }
        }
        .font(.caption2).foregroundStyle(.secondary)
        .padding()
    }

    private func select(_ id: String?) {
        selectedID = id
    }

    /// Moves the selection to the neighboring camera in the visible list, stopping at either end.
    private func step(by offset: Int) {
        guard let index = cameras.firstIndex(where: { $0.id == selectedID }),
              cameras.indices.contains(index + offset) else { return }
        select(cameras[index + offset].id)
    }

    private func choose(_ id: Int) {
        guard id != optionID else { return }
        optionID = id
        selectedID = nil
        withAnimation { position = .automatic }
    }

    /// The unselected route whose line passes within a finger's width of a map tap, if any.
    private func alternative(near point: CGPoint, proxy: MapProxy) -> Int? {
        let tolerance: CGFloat = 22
        var best: (id: Int, distance: CGFloat)?
        for alternative in plan.options where alternative.id != optionID {
            let screen = alternative.route.polyline.clCoordinates.compactMap { proxy.convert($0, to: .local) }
            for (a, b) in zip(screen, screen.dropFirst()) {
                let distance = point.distance(toSegment: a, b)
                if distance <= tolerance, distance < best?.distance ?? .infinity {
                    best = (alternative.id, distance)
                }
            }
        }
        return best?.id
    }
}

private struct RouteLine: Identifiable {
    let option: PlannedRoute.Option
    let selected: Bool
    var id: String { "\(option.id)-\(selected)" }
}

/// One route choice: travel time, distance, and how many cameras it passes.
private struct RouteChip: View {
    let option: PlannedRoute.Option
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.duration(option.route.expectedTravelTime)).font(.subheadline.bold())
                Text(option.route.name.isEmpty ? Format.distance(option.route.distance)
                                               : "via \(option.route.name)")
                    .font(.caption).lineLimit(1)
                Label("\(option.cameras.count)", systemImage: "video.fill")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(minWidth: 96, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(selected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground),
                        in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private extension CGPoint {
    func distance(toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared == 0 ? 0 : max(0, min(1, ((x - a.x) * dx + (y - a.y) * dy) / lengthSquared))
        return hypot(x - (a.x + t * dx), y - (a.y + t * dy))
    }
}

private struct CameraPin: View {
    let number: Int
    let live: Bool
    let selected: Bool

    var body: some View {
        // Unselected cameras are dots so a long route stays legible; the selected one shows its number.
        Text(selected ? "\(number)" : "")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: selected ? 28 : 11, height: selected ? 28 : 11)
            .background(Circle().fill(live ? Color.red : Color.gray))
            .overlay(Circle().stroke(.white, lineWidth: selected ? 3 : 1.5))
            .shadow(radius: selected ? 4 : 1)
            .padding(selected ? 0 : 8) // keeps small dots tappable
            .contentShape(.circle)
    }
}

extension Camera {
    var clLocation: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}
