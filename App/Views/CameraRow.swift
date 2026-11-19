import AVKit
import CamCore
import SwiftUI

/// One camera site in the route list. Collapsed rows show a refreshing snapshot; the selected
/// row expands to the shared live player, with the snapshot as its poster, and lets you switch
/// between the site's views when it has more than one.
struct CameraRow: View {
    let site: RouteSite
    /// The view shown for this site.
    let view: RouteCamera
    let number: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onChooseView: (String) -> Void

    private var camera: Camera { view.camera }

    var body: some View {
        Group {
            if isSelected {
                // Tapping the media or details collapses the row; the picker keeps its own taps.
                VStack(alignment: .leading, spacing: 10) {
                    ExpandedMedia(camera: camera)
                        .onTapGesture(perform: onTap)
                    if site.views.count > 1 { viewPicker }
                    details
                        .contentShape(.rect)
                        .onTapGesture(perform: onTap)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    SnapshotView(url: camera.snapshotURL, refreshSeconds: max(camera.snapshotRefreshSeconds, 60))
                        .frame(width: 128, height: 72)
                        .clipShape(.rect(cornerRadius: 6))
                    details
                }
                .contentShape(.rect)
                .onTapGesture(perform: onTap)
            }
        }
        .padding(.horizontal).padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.08) : .clear)
    }

    private var viewPicker: some View {
        Picker("View", selection: Binding(get: { view.id }, set: onChooseView)) {
            ForEach(Array(site.views.enumerated()), id: \.element.id) { index, view in
                Text(Self.label(view, index: index)).tag(view.id)
            }
        }
        .pickerStyle(.segmented)
    }

    private static func label(_ view: RouteCamera, index: Int) -> String {
        switch view.facing {
        case .ahead: "Ahead"
        case .behind: "Behind"
        case .side: "Looking \(view.viewCompass ?? "")"
        case nil: "View \(index + 1)"
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number)").font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
                Text(camera.displayName).font(.subheadline.weight(.semibold)).lineLimit(2)
            }
            Text(metadata).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            HStack(spacing: 6) {
                if camera.hlsURL != nil {
                    Badge(text: "LIVE", color: .red)
                } else {
                    Badge(text: "SNAPSHOT", color: .gray)
                }
                if site.views.count > 1 {
                    Badge(text: "\(site.views.count) VIEWS", color: .blue)
                }
                Text(direction).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadata: String {
        var parts = [Format.distance(view.distanceAlong), "~\(Format.duration(view.eta))"]
        if let place = camera.place { parts.append(place) }
        return parts.joined(separator: " · ")
    }

    /// Which way the camera looks relative to the route, or the route's heading when unknown.
    private var direction: String {
        switch view.facing {
        case .ahead: "Looking ahead"
        case .behind: "Looking back"
        case .side: "Looking \(view.viewCompass ?? "")"
        case nil: "Heading \(view.travelCompass)"
        }
    }
}

private struct ExpandedMedia: View {
    let camera: Camera
    @Environment(LivePlayback.self) private var playback

    var body: some View {
        let isActive = playback.cameraID == camera.id
        ZStack {
            // Faster refresh while expanded; also the fallback when video can't play.
            SnapshotView(url: camera.snapshotURL, refreshSeconds: 30)
            if camera.hlsURL != nil, isActive, playback.status != .failed {
                VideoPlayer(player: playback.player)
                    .opacity(playback.status == .playing ? 1 : 0)
                if playback.status == .loading {
                    ProgressView().tint(.white).padding(8).background(.black.opacity(0.5), in: .circle)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(alignment: .bottomLeading) {
            if camera.hlsURL != nil && isActive && playback.status == .failed {
                Label("Live video unavailable — showing latest image", systemImage: "exclamationmark.triangle")
                    .font(.caption2).padding(6)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 6)).padding(6)
            }
        }
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color, in: .capsule)
    }
}
