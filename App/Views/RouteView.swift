import CamCore
import MapKit
import SwiftUI

struct RouteView: View {
    let plan: PlannedRoute

    @Environment(CatalogStore.self) private var catalog
    @Environment(LivePlayback.self) private var playback
    /// The expanded site.
    @State private var selectedID: String?
    /// The view picked in each site, by site id; other sites show their best view.
    @State private var chosenViews: [String: String] = [:]
    @State private var liveOnly = false
    @State private var position: MapCameraPosition = .automatic

    private var sites: [RouteSite] {
        liveOnly ? plan.sites.compactMap { site in site.filter { $0.camera.hlsURL != nil } } : plan.sites
    }

    private func view(of site: RouteSite) -> RouteCamera {
        site.views.first { $0.id == chosenViews[site.id] } ?? site.primary
    }

    /// The view playing in the expanded row.
    private var selectedView: RouteCamera? {
        sites.first { $0.id == selectedID }.map(view(of:))
    }

    /// Stable 1-based numbers in route order, shared by map pins and rows.
    private var numbers: [String: Int] {
        Dictionary(uniqueKeysWithValues: plan.sites.enumerated().map { ($1.id, $0 + 1) })
    }

    var body: some View {
        VStack(spacing: 0) {
            map.frame(height: 240)
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
            guard id != nil, let selected = selectedView else { return }
            withAnimation {
                position = .camera(MapCamera(centerCoordinate: selected.camera.clLocation, distance: 12_000))
            }
        }
        .onChange(of: selectedView?.id) { _, _ in
            if let selected = selectedView {
                playback.play(selected.camera)
            } else {
                playback.stop()
            }
        }
        .onDisappear { playback.stop() }
    }

    private var map: some View {
        let numbers = numbers
        return Map(position: $position) {
            MapPolyline(plan.route.polyline).stroke(.blue, lineWidth: 5)
            ForEach(sites) { site in
                Annotation("", coordinate: view(of: site).camera.clLocation, anchor: .center) {
                    CameraPin(number: numbers[site.id] ?? 0,
                              live: site.views.contains { $0.camera.hlsURL != nil },
                              selected: site.id == selectedID)
                        .onTapGesture { select(site.id) }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .overlay(alignment: .bottomTrailing) {
            Button { withAnimation { position = .automatic } } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").padding(8)
            }
            .buttonStyle(.bordered).background(.thinMaterial, in: .rect(cornerRadius: 8)).padding(8)
        }
    }

    private var summary: some View {
        let live = plan.sites.filter { site in site.views.contains { $0.camera.hlsURL != nil } }.count
        return HStack {
            Text("\(plan.sites.count) \(plan.sites.count == 1 ? "camera" : "cameras") · \(live) live")
                .font(.subheadline.bold())
            Spacer()
            Text("\(Format.distance(plan.route.distance)) · \(Format.duration(plan.route.expectedTravelTime))")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    private var cameraList: some View {
        let numbers = numbers
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if sites.isEmpty {
                        ContentUnavailableView(
                            "No cameras on this route",
                            systemImage: "video.slash",
                            description: Text("Camera coverage is California and Nevada for now.")
                        )
                        .padding(.top, 40)
                    }
                    ForEach(sites) { site in
                        CameraRow(site: site,
                                  view: view(of: site),
                                  number: numbers[site.id] ?? 0,
                                  isSelected: site.id == selectedID,
                                  onTap: { select(site.id == selectedID ? nil : site.id) },
                                  onChooseView: { chosenViews[site.id] = $0 })
                        .id(site.id)
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
        let sourceIDs = Set(plan.sites.flatMap(\.views).map(\.camera.source))
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
