# Camerae

An iPhone app: it opens on a map of the highway cameras around you (tap one for live video).
Enter a start and a destination to get a driving route and see every camera along it in the
order you'll pass them, with live video playing inline.

Coverage today: **California (Caltrans)** and **Nevada (NDOT / nvroads.com)**: about 4,100
cameras, of which about 2,800 have live HLS video.

## How it fits together

```
tools/build_catalog.py ──► catalog/cameras.json ──► bundled into the app
   (run on a schedule)        (normalized schema)

App (SwiftUI, iOS 18+)
  NearbyMapView home screen: cameras around the current location, thinned to one pin per grid
                cell when zoomed out; tap for a live card; "Where to?" opens SearchView
  SearchView    from/to with MKLocalSearchCompleter autocomplete, "Current Location", saved Home
  RoutePlanner  MKDirections (with alternates) → RouteGeometry → RouteMatcher (CamCore), per route
  RouteView     route picker, Map with routes + camera dots, ordered camera list
  CameraRow     snapshot that refreshes only while on screen; tap to expand; OFFLINE badge
  FeedHealth    cameras whose latest snapshot was a DOT "unavailable" image
  LivePlayback  one shared AVPlayer that moves to the selected camera

CamCore (Swift package, no UIKit/MapKit)
  RouteMatcher  grid-indexed corridor search → projection for distance along the route →
                road-name filters → ordered list with distance and ETA
  RoadRef       parses "I-80", "I80", "US50", "CA-99 N", "Hwy 50", "215 WB …"
  PlaceholderDetector  16×12 thumbnail compared against the stock error images in
                Resources/Placeholders (Caltrans and NDOT send these as normal 200 OK images)
```

No server is needed. MapKit does geocoding and routing on the device, matching runs on the
device (about 1 ms for a 350 km route against the full catalog), and AVPlayer plays the DOT
streams directly. Native apps aren't subject to browser CORS rules.

### Matching rules

- A camera must be within 150 m of the route, and is placed in order by its projected
  distance along the route.
- MapKit step instructions describe the maneuver at the **end** of a step's polyline, so the
  road driven along step *i* is the one named in step *i − 1*.
- If both the camera and the route step name a highway, the numbers must match. This drops
  overpasses and crossing freeways.
- A highway camera beside a plain street step ("Turn left onto De Anza Blvd") is rejected as
  an overpass or ramp view.
- Freeway names inherit numbers seen elsewhere on the route ("San Bernardino Fwy, I-10 East").
- Cameras with no road information are kept only within 50 m. When the source gives a camera
  direction (Caltrans N/S/E/W), it must line up with the direction of travel. That field is
  shared by every view on a pole, so it gives the road's axis, not which way a camera looks.
- Matched cameras within 70 m of a site's first camera become one site with several views
  (Caltrans often has a view each way from one pole or intersection). The view direction comes
  from the name ("Looking North", "East View", `T256E --`, "- North", "(N)"). The view looking
  the way the route travels is shown first; unlabeled views rank above ones known to look back.
  The other views are a tap away in the expanded row.

## Running

```bash
# Rebuild the camera catalog (about 1 min to fetch; the stream health check adds more)
python3 tools/build_catalog.py
python3 tools/build_catalog.py --skip-stream-check   # faster, keeps dead streams

# Core logic tests
cd CamCore && swift test

# Re-render the app icon after editing design/AppIcon.svg (needs Chrome and Pillow)
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
  --window-size=1024,1024 --screenshot=/tmp/icon.png "file://$PWD/design/AppIcon.svg"
python3 -c "from PIL import Image; Image.open('/tmp/icon.png').convert('RGB').save('App/Assets.xcassets/AppIcon.appiconset/AppIcon.png')"

# Generate the Xcode project and build
xcodegen generate
open Camerae.xcodeproj
```

Development shortcut: launch with `-from "San Francisco, CA" -to "Reno, NV"` to plan a trip at
startup (Xcode scheme → Arguments, or `xcrun simctl launch <device> com.camerae.app -from … -to …`).

## Data sources and caveats

- **Caltrans CWWP2** (`cwwp2.dot.ca.gov/data/d{N}/cctv/cctvStatusD{NN}.json`): keyless, with
  HLS streams on `wzmedia.dot.ca.gov`. Caltrans's Conditions of Use treat the content as
  generally public, but confirm before shipping. Some cameras marked "in service" serve a
  "Temporarily Unavailable" image or a dead stream, so the builder probes every playlist and
  drops dead ones.
- **Nevada (nvroads.com)**: the official API needs a free developer key
  (`NV511_API_KEY=… python3 tools/build_catalog.py`). That code path follows the published
  docs but hasn't been run against a real key yet. Without a key, the builder falls back to the
  public list endpoint behind nvroads.com/list/cameras. That endpoint is undocumented, so it's
  for development only; get the key and permission before shipping.
- Attribution for each source is shown at the bottom of every route.

## App Store

- `appstore/listing.md`: name, description, keywords, privacy answers and review notes to paste
  into App Store Connect.
- `appstore/screenshots/`: 6.9" screenshots. `appstore/take_screenshots.sh` retakes them.
- `docs/`: support page and privacy policy, served by GitHub Pages at
  https://danfoygel.github.io/camerae/.
- `App/PrivacyInfo.xcprivacy`: privacy manifest (declares the `UserDefaults` use for Home and
  recent places). Update it if the app adds tracking, data collection or another required-reason API.

## Not done yet

- Hosting the catalog and refreshing it in the app. The app currently uses only the copy
  bundled at build time.
- More states (the IBI/Arcadis 511 adapter reuses Nevada's code shape for about 10 more
  states).
- Checking the CarPlay and in-motion rules before any driving-mode features.
