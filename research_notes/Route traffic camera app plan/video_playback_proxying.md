# Video Playback and Proxying for Inline Traffic Camera Media (HLS, MJPEG, JPEG refresh, MP4, RTSP/RTMP)

Research date: 2026-11-18. Budget-limited pass (about 17 tool calls). Several sources returned HTTP 403 (VertiGIS community thread, ipcamtalk thread), so some DOT-specific URL patterns could not be verified. Items labeled "general engineering knowledge" in Inferences were NOT verified against a source in this session. The report writer should treat them as reasoned defaults, not cited facts.

## 1. Formats seen on US DOT/511 traffic cameras, with latencies and bitrates

### Takeaway
US DOT cameras come in two main forms: periodically refreshed JPEG snapshots (the most common and simplest) and HLS (.m3u8), usually served from Wowza-style origins and sometimes with short-lived tokens. RTMP and RTSP exist upstream, inside agency or vendor pipelines, but are rarely exposed to the public. MJPEG is uncommon in public 511 feeds. I found no source documenting "skyvdn" as a vendor or host name. Figures for latency and bitrate are almost entirely undocumented.

### Cited Findings
- The OpenTrafficCamMap project classifies US DOT feeds as `IMAGE_STREAM` (each request returns the latest image), `IMAGE_STREAM_BY_EPOCH_IN_MILLISECONDS`, `M3U8` (a playlist that points to a chunklist, which points to media chunks), and state-specific "UNIQUE_*" formats. Its listed encodings are H.264, VP8, VP9 and JPEG. MJPEG is not mentioned. — [OpenTrafficCamMap README](https://github.com/AidanWelch/OpenTrafficCamMap)
- Texas: TxDOT images are fetched by POSTing a camera identifier to an `its.txdot.gov` web service. The response is comma-separated text with a Base64 image after a "data" marker, so these are not plain image URLs. — [OpenTrafficCamMap README](https://github.com/AidanWelch/OpenTrafficCamMap)
- Colorado: the project calls streaming "not worth pursuing" because of DRM. — [OpenTrafficCamMap README](https://github.com/AidanWelch/OpenTrafficCamMap)
- New Jersey: streams are M3U8 and "require WOWZA keys", meaning tokenized Wowza URLs. — [OpenTrafficCamMap README](https://github.com/AidanWelch/OpenTrafficCamMap)
- Pennsylvania 511: a search-result summary describes a `playlist.m3u8` URL on a Wowza-style host under a `/live/CAM-...stream/` path, carrying a short-lived `wmsAuthSign` token (Wowza SecureToken/hotlink-style signing), and says the m3u8 "keeps expiring". I could not fetch the source page (403). — [VertiGIS community thread (search snippet only)](https://support.vertigis.com/hc/fr/community/posts/11499060344850-Traffic-Cameras-of-m3u8-file-type-Anyone-embedded)
- Pennsylvania (511PA/Turnpike): source cameras are VBrick; the Distributed Media Engine outputs RTMP. AWS MediaLive encodes and pushes via RTMP, CloudFront delivers, and AWS WAF is set to "allow only authorized URL links and IP addresses" (hot-link protection). Flowplayer is the web player. The pilot covered "up to 10" cameras. The Turnpike has 90+ cameras. — [CloudHesive case study](https://www.cloudhesive.com/case-study/goverment/commonwealth-of-pennsylvania-helps-travelers-get-to-destinations-faster-by-securely-delivering-traffic-video-streams-online/)
- North Dakota DOT: per a search summary of an ipcamtalk thread, the cameras use .m3u8. A URL pulled from Chrome DevTools played in VLC at 30 fps. Direct fetch returned 403. — [ipcamtalk thread (search snippet)](https://www.ipcamtalk.com/threads/bringing-in-external-https-webcamera-ndot-traffic-cameras-into-blue-iris-just-a-hair-away-from-being-happy-with-it.48201)
- Iowa DOT moved to a new camera video system on 2026-05-20 with no advance notice, which changed both image and video URLs. A load-balanced server change followed about three weeks later, changing only the domain prefix, e.g. `video4.iowadot.gov` to `video.iowadot.gov`. Integrators are told to pull current URLs from the ESRI feature service / open-data dataset "traffic-cameras-3" rather than hardcoding them. The advisory names no vendor or format. — [Iowa DOT media advisory, 2026-05-28](https://iowadot.gov/news/2026-05-28/media-advisory-iowa-dot-updates-traffic-camera-video-system-data-feed-usersdevelopers)
- Caltrans publishes a per-camera index of `cwwp2.dot.ca.gov/vm/loc/dNN/*.htm` pages that embed the video, plus CWWP2 CCTV JSON data. The index page carries no direct stream URLs. Caltrans states that video and stills "are neither retained nor archived" and points users to Conditions of Use. — [Caltrans stream list](https://cwwp2.dot.ca.gov/vm/streamlist.htm); [CWWP2 portal](https://cwwp2.dot.ca.gov)
- Caltrans District 7 uses RTSP into a Red5 Pro cluster and reports latency reduced "by up to 29 seconds", which implies prior HLS-era latency of roughly 30 s. — [Red5 case study (search snippet)](https://www.red5.net/?p=67725)
- Tennessee: a news item describes the private company hosting TDOT's camera feeds blocking third-party access in a dispute. This is evidence that hosted DOT feeds can be cut off from third-party apps. — [Yahoo News (search snippet)](https://www.yahoo.com/news/private-companies-clash-over-tdot-090551143.html)
- AR DOT (ARDOT) uses CamStreamer (on-camera Axis apps) for streaming. I did not read the case study. — [CamStreamer ARDOT case study](https://camstreamer.com/resources/ardot-case-study-pdf)

### Inferences
- The playback layer should treat the per-camera media descriptor as one of: `jpeg_refresh` (URL plus refresh interval), `hls` (URL, possibly tokenized or needing server minting), `mjpeg`, `mp4_clip`, `rtsp`/`rtmp` (server-side only), or `custom` (TxDOT-style POST/Base64). It should also expect URLs to change without notice, as Iowa's did.
- Standard HLS with 2–10 s segments and a three-segment hold-back typically gives 10–30 s glass-to-glass latency. The Caltrans "up to 29 seconds" figure is consistent with this. For traffic viewing this is acceptable, and LL-HLS or WebRTC is not required.
- I did not verify that "skyvdn" (or Skyline/Iteris) is a host used by DOT HLS. Treat it as an unverified lead. The report writer should not assert it.

### Gaps
- No primary source gave typical bitrates or resolutions for DOT HLS streams. Practitioner lore suggests 240p–480p at about 200–1000 kbps, but this is unverified.
- I could not confirm the vendor or host names "skyvdn", Skyline, Iteris or Wowza per state beyond NJ ("WOWZA keys") and the PA token pattern.
- No source quantified snapshot refresh intervals. Commonly 1–5 minutes, but unverified.

## 2. Web playback (hls.js, Video.js, Shaka, native HLS, MSE/ManagedMediaSource, MJPEG, autoplay, concurrency, lazy attach)

### Takeaway
The recommended web stack is hls.js 1.7.x (stable since Aug 2026) on MSE/ManagedMediaSource, with a fallback to native HLS where `canPlayType('application/vnd.apple.mpegurl')` succeeds. MJPEG and JPEG snapshots go in plain `<img>` tags. Keep one, or at most a few, active `<video>` elements, attaching and detaching them with IntersectionObserver. Hardware decoders, not element counts, are the real constraint.

### Cited Findings
- **hls.js versions:** latest stable is **v1.7.4 (28 Oct 2026)**, with LL-HLS part-loading fixes, DRM key reuse and interstitial fixes. **v1.7.0 (12 Aug 2026)** added I-frame playlist support, CMCD v2, parallel init-segment loading and smoother audio switching. v1.7.1 added a ManagedMediaSource "startstreaming" workaround when seeking. The 1.6.x line is still patched (v1.6.19, 19 Aug 2026, backports an MMS workaround for a "macOS/iOS 27 beta regression"). — [hls.js releases](https://github.com/video-dev/hls.js/releases)
- hls.js lists Safari for iOS 17.1+ as supported via ManagedMediaSource (MMS) since hls.js 1.5.0. — [hls.js README](https://github.com/video-dev/hls.js/); [DEV: MMS on iPhone with hls.js](https://dev.to/masonwritescode/playing-hls-through-managed-media-source-on-iphone-with-hlsjs-3cn8)
- MMS shipped on iPhone in Safari 17.1, after Safari 17.0 on iPad and Mac. — [WebKit: Safari 17.1 features](https://webkit.org/blog/14735/); [Radiant Media Player blog](https://www.radiantmediaplayer.com/blog/at-last-safari-17.1-now-brings-the-new-managed-media-source-api-to-iphone.html)
- hls.js 1.6.x uses the `ManagedMediaSource` global by default when present. Gotcha: with MMS the browser can evict your buffer, which is a common source of bugs. — [DEV: MMS on iPhone with hls.js](https://dev.to/masonwritescode/playing-hls-through-managed-media-source-on-iphone-with-hlsjs-3cn8)
- The iOS simulator (17.2) did not support MP4 media sources for MSE/MMS, so hls.js on MMS must be tested on physical iPhones. — [WebKit Bugzilla 266764](https://bugs.webkit.org/show_bug.cgi?id=266764)
- Background on MMS (Apple's power-aware MSE variant, its `startstreaming`/`endstreaming` events, and the requirement for an AirPlay alternative source or `disableRemotePlayback`). — [Bitmovin community: Everything about MMS](https://community.bitmovin.com/t/everything-you-need-to-know-about-apple-s-new-managed-media-source/2076)
- Video.js 10 has been in beta through 2026 (e.g. 10.0.0-beta.12 on Apr 1, 2026; beta.27 with breaking changes on Aug 17, 2026). It is not yet stable as of these sources. — [Video.js changelog beta.27](https://videojs.org/changelog/10.0.0-beta.27.md); [beta.12](https://videojs.org/changelog/10.0.0-beta.12.md)
- Chromium once capped pages at 75 concurrent WebMediaPlayers (Chrome 92), throwing errors beyond that. The cap was later raised high enough to be effectively disabled. It existed because each WebMediaPlayer allocates many heavy objects, so memory per element remains a real concern. — [webrtcHacks](https://webrtchacks.com/?p=3575)
- Chromium renderers are sandboxed. Hardware decode goes over IPC to the GPU process, so decoders are a shared, finite, process-external resource. — [Chrome dev blog: hardware decoding](https://developer.chrome.com/blog/high-performance-video-with-hardware-decoding); [Qt wiki on WebEngine video acceleration](https://wiki.qt.io/QtWebEngine/VideoAcceleration)
- WebKit bug: "Multiple playing videos pool needs to be managed by browser". A paused video still occupies a hardware decoder in WebKit. — [WebKit Bugzilla 193449](https://bugs.webkit.org/show_bug.cgi?id=193449)

### Inferences
- **Player choice:** use hls.js directly as a thin wrapper rather than a full UI framework. A camera tile needs no ABR menus, captions or DRM. Shaka Player is a good choice if DASH or DRM ever matters. Video.js 10 is still in beta. Vidstack and Plyr add UI only. On Safari, prefer native HLS (`video.src = m3u8`) on iOS, which is more power-efficient. hls.js-on-MMS is acceptable when custom loaders are needed, e.g. token refresh via `xhrSetup`/`fetchSetup` or playlist rewriting in the client.
- **Autoplay** (general engineering knowledge, not re-verified): browsers allow autoplay only when the element is `muted`. iOS also requires `playsinline` to avoid forced fullscreen. Traffic streams have no audio, so always set `muted playsinline autoplay` plus a `poster` (the latest JPEG snapshot).
- **Concurrency pattern:** mount a `<video>` (or hls.js instance) only for the selected or centered tile. Use IntersectionObserver with a threshold of about 0.6–0.75 to pick the most-visible tile. On exit, call `hls.destroy()`, then `video.removeAttribute('src'); video.load()` to release the decoder (the WebKit bug above shows paused is not enough). Cap at 1 active player on mobile and 2–4 on desktop.
- **MJPEG on web:** `<img src="...mjpeg">` renders `multipart/x-mixed-replace` natively in Chrome, Firefox and Safari (general knowledge). To stop the stream and save bandwidth, remove or replace the `src`, since off-screen `<img>` MJPEG keeps downloading. Never render dozens of MJPEG `<img>` simultaneously. Also, HTTP/1.1 allows about 6 connections per host, so multiple long-lived MJPEG connections to one host will starve other requests unless served over HTTP/2 via a proxy.
- **JPEG refresh:** add a `?t=<epoch>` cache-buster, or better, a proxy with short `Cache-Control: max-age=N` so that all clients share one fetch. Swap only after `img.decode()` resolves to avoid flicker, and pause timers for off-screen tiles.
- **MP4 clips:** use plain `<video src preload="none">` with a poster. Only set `preload="metadata"` when the tile is near the viewport.

### Gaps
- I found no current, authoritative per-browser numbers for concurrent hardware-decoded video on mobile Safari or Chrome Android.
- I did not verify Shaka Player's current version or Vidstack/Plyr status as of late 2026.
- I did not verify whether iOS Safari's native HLS and MMS share the same decoder pool limits.

## 3. Native playback (iOS AVPlayer, Android Media3, React Native, Flutter) and MJPEG handling

### Takeaway
Native platforms play HLS and MP4 well: AVPlayer on iOS, Media3 ExoPlayer on Android. Neither plays MJPEG natively, so MJPEG needs a small custom multipart parser or a WebView, or should be converted server-side to snapshots or HLS. Both platforms limit simultaneous decoders, though Apple publishes no number, so a pool of 1–3 reusable players is the standard design for scrolling lists.

### Cited Findings
- Apple publishes no limit on simultaneous AVPlayers. Developers have reported limits of 4 concurrent on iPhone 5s/iOS 8 and 7 on tvOS 9.1, and failures on the 19th video in a feed with error -11800. One answer notes the limit is on active decoding (render pipelines), not object count. — [Apple Dev Forums 28714](https://developer.apple.com/forums/thread/28714); [Apple Dev Forums 67382](https://developer.apple.com/forums/thread/67382); [SO archive: AVPlayerItemStatusFailed with too many instances](https://kaweah.freedombox.rocks/kiwix/content/stackoverflow.com_en_all_2023-11/questions/34009913/avplayeritemstatusfailed-error-when-too-many-avplayer-instances-created)
- Recommended workaround: call `replaceCurrentItem(with: nil)` for off-screen players and keep concurrent AVPlayer instances as low as possible. — [SO archive: how many AVPlayers](https://kaweah.freedombox.rocks/kiwix/content/stackoverflow.com_en_all_2023-11/questions/40474480/how-many-avplayers-are-allowed-to-be-created-at-the-same-time)
- Media3 1.8.0 (Aug 2025) added ExoPlayer scrubbing mode, `MetadataRetriever` duration without playback, and partial downloads via `PreCacheHelper`. Scrubbing integration into `DefaultPreloadManager` was announced for Media3 1.9.0. — [Android Developers Blog: Media3 1.8.0](https://android-developers.googleblog.com/2025/08/media3-180-whats-new.html?hl=en)
- `DefaultPreloadManager` (since Media3 1.4.0) supports feed-style preloading of upcoming list items with rank-based preload durations (`DefaultPreloadControl`). — [ProAndroidDev: Preloading Media with ExoPlayer](https://proandroiddev.com/preloading-media-a-future-forward-approach-with-exoplayer-877ca6b0873d) (third-party)
- React Native: community reports say react-native-video does not play MJPEG, and WebView is the common workaround. `react-native-mjpeg` (v0.5.0, GPL-3.0) wraps a WebView. — [GitHub gist thread](https://gist.github.com/stefangordon/268b979afebf6e6f337f8c3555b4eb36); [react-native-mjpeg on jsDelivr](https://www.jsdelivr.com/package/npm/react-native-mjpeg?tab=files)
- A native (non-WebView) iOS approach parses `multipart/x-mixed-replace` frames directly from the byte stream. Example: the Titanium module. — [titanium-mjpeg-view-ios](https://awesome.ecosyste.ms/projects/github.com%2Fkosso%2Ftitanium-mjpeg-view-ios)
- Theoplayer FAQ on running multiple player instances at once (vendor guidance that it is possible but resource-bound). — [Dolby OptiView/THEOplayer FAQ](https://optiview.dolby.com/docs/theoplayer/v6/faq/possible-to-have-multiple-player-instances-at-same-time/)

### Inferences
- **iOS:** use one shared `AVPlayer` (or a pool of 2) plus `AVPlayerLayer` in the focused cell. SwiftUI `VideoPlayer` brings controls you don't want, so wrap `AVPlayerLayer` in `UIViewRepresentable` instead. Set `automaticallyWaitsToMinimizeStalling` appropriately and `preferredForwardBufferDuration` small for live. Grid tiles show `UIImage`/`AsyncImage` snapshots.
- **iOS MJPEG:** a `URLSession` data delegate that splits on the multipart boundary (or scans for JPEG SOI/EOI markers 0xFFD8/0xFFD9) and decodes each frame to a `UIImage`. This takes about 100 lines and avoids WebView.
- **Android:** use Media3 ExoPlayer (`media3-exoplayer-hls`) with a pool of 1–2 `ExoPlayer` instances reattached to the visible `PlayerView`/`PlayerSurface` in RecyclerView/LazyColumn, and `DefaultPreloadManager` for "next camera". Off-screen tiles use Coil/Glide snapshots. For MJPEG, use OkHttp with a multipart parser into a Bitmap, or `ImageDecoder`.
- **React Native:** react-native-video (v6.x, built on AVPlayer and ExoPlayer) for HLS and MP4. For MJPEG, a custom native module or WebView with `<img>`. Use FlatList `onViewableItemsChanged` to mount only one `<Video>`.
- **Flutter:** `video_player` (AVPlayer/ExoPlayer under the hood) or `media_kit` (libmpv, which can also open RTSP and MJPEG directly). For MJPEG, community packages exist (e.g. `flutter_mjpeg`), unverified this session.
- **RTSP on device:** ExoPlayer has a `media3-exoplayer-rtsp` module, but AVPlayer has no RTSP support (general knowledge). Since DOT cameras rarely expose RTSP publicly anyway, convert server-side.

### Gaps
- I did not verify current versions or dates of react-native-video, Flutter `video_player`, `media_kit`, or Media3 1.9.x/1.10.
- I found no authoritative Android hardware-decoder concurrency figure (it is device and SoC dependent; `MediaCodecInfo.getMaxSupportedInstances()` exists, by general knowledge).

## 4. Problems (CORS, mixed content, tokens, referer checks, ATS) and proxy solutions; legal/ToS and bandwidth cost

### Takeaway
Most 511 cameras that work in a third-party app will need a lightweight server layer. That layer has three jobs: (a) minting or refreshing tokenized HLS URLs, (b) adding CORS headers and HTTPS for web clients, and (c) caching snapshots so the DOT origin sees one request per camera per interval, not one per user. Proxying full video is costly and legally riskier than proxying snapshots or redirecting to signed origin URLs.

### Cited Findings
- PA's 511 HLS uses short-lived `wmsAuthSign` tokens, so the m3u8 "keeps expiring" and needs a refresh mechanism (search snippet). — [VertiGIS thread](https://support.vertigis.com/hc/fr/community/posts/11499060344850-Traffic-Cameras-of-m3u8-file-type-Anyone-embedded)
- PA's delivery uses AWS WAF to allow only authorized referrers ("authorized URL links") and IPs. This is classic hot-link protection that will block direct embedding from third-party apps. — [CloudHesive case study](https://www.cloudhesive.com/case-study/goverment/commonwealth-of-pennsylvania-helps-travelers-get-to-destinations-faster-by-securely-delivering-traffic-video-streams-online/)
- NJ HLS requires Wowza keys. Colorado streams are DRM-protected. — [OpenTrafficCamMap](https://github.com/AidanWelch/OpenTrafficCamMap)
- Caltrans links are published with Conditions of Use, and footage is not archived. — [Caltrans stream list](https://cwwp2.dot.ca.gov/vm/streamlist.htm)
- Iowa DOT changes stream URLs without notice and asks integrators to pull from the open-data feed and join a notification list. — [Iowa DOT advisory](https://iowadot.gov/news/2026-05-28/media-advisory-iowa-dot-updates-traffic-camera-video-system-data-feed-usersdevelopers)
- A private TDOT feed host has blocked third parties in a dispute (search snippet). — [Yahoo News](https://www.yahoo.com/news/private-companies-clash-over-tdot-090551143.html)

### Inferences
- **CORS** (general knowledge): hls.js and MMS fetch the playlist and segments via XHR/fetch, so the origin must send `Access-Control-Allow-Origin` on both the .m3u8 and every .ts/.m4s segment. Native Safari HLS (`video.src`) and `<img>` do not need CORS unless you read pixels (canvas) or use `crossorigin`. Native mobile apps are not subject to CORS at all, which is a strong reason native clients can often hit DOT origins directly while web clients need the proxy.
- **Mixed content:** an https web app cannot load http media via XHR (blocked). `<img>`/`<video>` http subresources are auto-upgraded to https in modern Chrome and Safari and fail if the origin has no TLS. Proxy any http-only camera through your https domain.
- **iOS ATS:** for http-only cameras, use `NSAppTransportSecurity` → `NSExceptionDomains` per DOT host, or `NSAllowsArbitraryLoadsForMedia` (AVFoundation media only; does not cover snapshot `URLSession` fetches). Per-domain exceptions are preferable for App Review. Android needs `network_security_config` cleartext exceptions for the same reason.
- **Referer checks:** native clients can set a `Referer` header (AVURLAsset via `AVURLAssetHTTPHeaderFieldsKey`, an unofficial key; ExoPlayer via `DefaultHttpDataSource.Factory().setDefaultRequestProperties`). Browsers cannot spoof Referer, so web needs the proxy. Spoofing the referer to defeat an agency's hot-link protection is a ToS and legal risk and should be cleared with the agency.
- **Proxy designs, from cheapest to most expensive:**
  1. **Token-minting redirect:** the server scrapes or obtains a fresh signed m3u8 URL and returns `302` or JSON. The client streams directly from the DOT origin. No video bandwidth cost. Works only if the origin sends CORS (web) or the client is native.
  2. **Playlist-rewriting proxy:** the server fetches the m3u8 (add headers/token), rewrites segment URIs to absolute origin URLs (if origin CORS is OK) or to proxy URLs, and adds CORS. Playlists are tiny. Segments either go direct or are proxied.
  3. **Full segment proxy/CDN:** Cloudflare Worker or nginx `proxy_pass` with `proxy_cache` for segments, at roughly 2–6 s TTL for live. All users watching the same camera share cached segments, so origin load is O(cameras), not O(users). The bandwidth bill is O(users × bitrate).
  4. **Snapshot cache:** a server polls each camera's JPEG (or grabs a frame from HLS/RTSP via ffmpeg) every N seconds and stores it on a CDN with `max-age=N`. This is cheapest, has the best UX for lists, and is the DOT-friendliest option.
- **Bandwidth math** (illustrative, assumes 500 kbps per stream): 1 viewer-hour is about 225 MB. 10,000 viewer-hours a month is about 2.25 TB. At typical CDN or cloud egress (cloud egress is often about $0.05–0.09/GB, while Cloudflare does not bill egress on most plans), that ranges from negligible to about $200/month. Snapshots at 50 KB every 60 s cost about 3 MB per viewer-hour, roughly 75× cheaper. (Prices not verified this session.)
- **Legal/ToS:** many DOTs require attribution, forbid implying endorsement, and some forbid rebroadcast or reproxying or require a data-sharing agreement (e.g. Caltrans Conditions of Use; not read in full). Recommend per-agency review, attribution overlays, honoring agency on/off flags (cameras blanked for incidents), and preferring the agency's official data feed (Iowa open data, CWWP2 JSON) over scraping.

### Gaps
- I did not read the full Caltrans Conditions of Use or any specific 511 ToS. The legal claims above are inferences and need per-agency verification.
- I could not verify which DOT HLS origins send permissive CORS headers. This must be tested per agency.
- Current Cloudflare Workers, R2 and CloudFront pricing was not checked.

## 5. Transcoding RTSP/MJPEG to HLS/WebRTC (ffmpeg, MediaMTX, go2rtc, Janus, Wowza): cost at scale vs. snapshot fallback

### Takeaway
go2rtc and MediaMTX can ingest RTSP, RTMP, HLS and MJPEG and re-serve them as WebRTC, HLS, MSE or snapshot JPEG, repackaging without transcoding when codecs allow. For the rare RTSP/RTMP/MJPEG-only camera, this is feasible on a small VM. It does not justify running at fleet scale, where server-generated snapshots plus on-demand (tap-to-play) relays are the better trade-off.

### Cited Findings
- go2rtc inputs include RTSP, RTMP, HLS, MJPEG (`mpjpeg`), ONVIF, WebRTC and FFmpeg-script sources. Outputs: WebRTC, MSE/MP4, HLS, MJPEG, and snapshot JPEG (`jpeg`). FFmpeg transcoding is used "only when needed", with hardware acceleration supported. It negotiates codecs per client for WebRTC/MSE. Older iPhones can only use HLS, and HEVC browser support is limited. — [go2rtc README](https://github.com/AlexxIT/go2rtc)
- go2rtc's built-in web player falls back WebRTC → MSE → HLS → MJPEG. — [go2rtc on pkg.go.dev](https://pkg.go.dev/github.com/AlexxIT/go2rtc)
- go2rtc v1.9.14 was released 2026-01-19. A newer tag may exist (unconfirmed). — [go2rtc releases](https://github.com/AlexxIT/go2rtc/releases); [pkg.go.dev](https://pkg.go.dev/github.com/AlexxIT/go2rtc)
- MediaMTX (MIT; formerly rtsp-simple-server) handles RTSP, RTMP, HLS, WebRTC, SRT and others. A secondary source dates v1.17.0 to 2026-03-17 (not confirmed on the official releases page). — [unsubbed.pages.dev MediaMTX review](https://unsubbed.pages.dev/tools/mediamtx/)
- PA used AWS MediaLive (managed transcoding) from RTMP sources, while Caltrans D7 used Red5 Pro for low-latency RTSP-based delivery. Both show the agency-side pattern of managed or commercial media servers. — [CloudHesive](https://www.cloudhesive.com/case-study/goverment/commonwealth-of-pennsylvania-helps-travelers-get-to-destinations-faster-by-securely-delivering-traffic-video-streams-online/); [Red5](https://www.red5.net/?p=67725)
- An open-source project converts RTSP to m3u8 with ffmpeg served by nginx (search snippet). — [lapd-python/traffic-poll](https://github.com/lapd-python/traffic-poll)

### Inferences
- **Remux vs. transcode:** remux (H.264 RTSP to HLS/WebRTC) costs little CPU, so one small VM can relay dozens of streams. Transcoding MJPEG to H.264 costs about 0.25–1 vCPU per 480p stream with libx264 ultrafast (general estimate, unverified), so 100 always-on MJPEG cameras would need about 25–100 vCPU. That is not worth it.
- **Recommended policy:** (1) Default every camera to a server-cached snapshot. (2) Serve native HLS where the DOT provides it, via the token or rewrite proxy. (3) For RTSP/RTMP/MJPEG-only cameras, start an on-demand go2rtc or MediaMTX relay when a user taps play (both support on-demand sources), output HLS for iOS/web compatibility or WebRTC for low latency, and tear it down after N idle seconds. (4) If the relay fails, fall back to a 2–5 s "fast snapshot" mode (ffmpeg `-frames:v 1` grabs or the go2rtc `jpeg` endpoint).
- **Janus and Wowza:** Janus suits WebRTC SFU fan-out. Wowza is commercial, priced per instance or per hour. Neither is needed at this scale unless low-latency WebRTC fan-out to many concurrent viewers becomes a product requirement.
- **WebRTC vs. HLS:** WebRTC gives sub-second latency, but each viewer is a stateful connection, so CDN caching does not apply and it needs TURN in some networks. HLS is CDN-cacheable. For traffic, 10–30 s latency is fine, so prefer HLS.

### Gaps
- I did not verify MediaMTX's latest version on its official releases page, Janus's current version, or Wowza pricing.
- I found no published benchmark for MJPEG→H.264 transcoding CPU per stream.

## 6. UX patterns: refreshing thumbnail grid, tap-to-play, single active player, preloading the next camera

### Takeaway
The recommended pattern: a list ordered along the route, where each row shows a cached JPEG snapshot that refreshes every 30–120 s only while visible. One shared live player attaches to the focused or tapped camera, and the next camera along the route is preloaded. This respects decoder limits on every platform and keeps bandwidth near snapshot cost.

### Cited Findings
- Paused or off-screen videos still hold hardware decoders in WebKit, and iOS AVPlayer fails beyond a device-dependent number of active players. So "single active player" is a technical requirement, not just a stylistic choice. — [WebKit Bugzilla 193449](https://bugs.webkit.org/show_bug.cgi?id=193449); [Apple Dev Forums 67382](https://developer.apple.com/forums/thread/67382)
- Media3 `DefaultPreloadManager` is designed for feed-style preloading of the next N items with rank-based buffers. — [ProAndroidDev](https://proandroiddev.com/preloading-media-a-future-forward-approach-with-exoplayer-877ca6b0873d); [Media3 1.8.0 blog](https://android-developers.googleblog.com/2025/08/media3-180-whats-new.html?hl=en)
- go2rtc exposes a per-stream `jpeg` snapshot output alongside live outputs, so the same relay can feed thumbnails and tap-to-play. — [go2rtc README](https://github.com/AlexxIT/go2rtc)

### Inferences
- **List row:** snapshot image plus a "x min ago" timestamp (from `Last-Modified` or the proxy's capture time), camera name, direction of travel, and distance or ETA along the route. Add a "LIVE" badge if the camera has video.
- **Refresh policy:** refresh only visible rows (IntersectionObserver, `onViewableItemsChanged`, LazyColumn visible items). Stagger timers to avoid thundering herds. Back off on cellular or Low Data Mode. Pause when the app is backgrounded.
- **Live:** tap expands the row inline (or opens a sheet) and attaches the shared player, with the snapshot as poster until the first frame. Optional "auto-live" plays the most-centered visible camera, muted, after a dwell of about 1 s, and detaches on scroll.
- **Preload next:** for the camera after the active one (in route order), prefetch the m3u8 and, on Android, use PreloadManager to buffer a few seconds. On web, create the hls.js instance with `autoStartLoad` but without attaching to a visible element (decoder not yet allocated until media attaches). Never keep more than one preloaded decoder.
- **Error UX:** if HLS fails (token expiry, 403, CORS), silently fall back to snapshot mode with a "Live unavailable" label. Re-mint the token once and retry.
- **Driving context:** if the app can be used while driving, a snapshot-first, glanceable UI is also the safer choice. Defer to whichever researcher covers safety and platform policy (CarPlay/Android Auto restrict video).

### Gaps
- I found no published UX studies of traffic-camera apps. These patterns are synthesized from platform constraints.
