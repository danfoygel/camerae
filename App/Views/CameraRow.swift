import AVKit
import CamCore
import SwiftUI

/// One camera in the route list. Collapsed rows show a refreshing snapshot; the selected row
/// expands to the shared live player, with the snapshot as its poster.
struct CameraRow: View {
    let routeCamera: RouteCamera
    let number: Int
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(FeedHealth.self) private var health
    @Environment(LivePlayback.self) private var playback

    private var camera: Camera { routeCamera.camera }

    /// A stream that is actually playing outranks a stale error snapshot.
    private var isOffline: Bool {
        health.isOffline(camera.id) && !(playback.cameraID == camera.id && playback.status == .playing)
    }

    var body: some View {
        Group {
            if isSelected {
                VStack(alignment: .leading, spacing: 10) {
                    ExpandedMedia(camera: camera)
                    details
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    SnapshotView(camera: camera, refreshSeconds: max(camera.snapshotRefreshSeconds, 60))
                        .frame(width: 128, height: 72)
                        .clipShape(.rect(cornerRadius: 6))
                    details
                }
            }
        }
        .padding(.horizontal).padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.08) : .clear)
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number)").font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
                Text(camera.displayName).font(.subheadline.weight(.semibold)).lineLimit(2)
            }
            Text(metadata).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            HStack(spacing: 6) {
                if isOffline {
                    Badge(text: "OFFLINE", color: .orange)
                } else if camera.hlsURL != nil {
                    Badge(text: "LIVE", color: .red)
                } else {
                    Badge(text: "SNAPSHOT", color: .gray)
                }
                Text("Heading \(routeCamera.travelCompass)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadata: String {
        var parts = [Format.distance(routeCamera.distanceAlong), "~\(Format.duration(routeCamera.eta))"]
        if let place = camera.place { parts.append(place) }
        return parts.joined(separator: " · ")
    }
}

private struct ExpandedMedia: View {
    let camera: Camera
    @Environment(FeedHealth.self) private var health
    @Environment(LivePlayback.self) private var playback

    var body: some View {
        let isActive = playback.cameraID == camera.id
        ZStack {
            // Faster refresh while expanded; also the fallback when video can't play.
            SnapshotView(camera: camera, refreshSeconds: 30, showsOfflineText: true)
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
            // An offline snapshot already says so; this is for a dead stream beside a working camera.
            if camera.hlsURL != nil && isActive && playback.status == .failed && !health.isOffline(camera.id) {
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
