# Camerae

An iPhone app: enter a start and a destination, get a driving route, and see every highway
camera along it in the order you'll pass them, with live video playing inline.

Coverage today: **California (Caltrans)** and **Nevada (NDOT / nvroads.com)**: about 4,100
cameras, of which about 2,800 have live HLS video.

## How it fits together

```
tools/build_catalog.py ──► catalog/cameras.json ──► bundled into the app
   (run on a schedule)        (normalized schema)

App (SwiftUI, iOS 18+)
  SearchView    MKLocalSearchCompleter autocomplete, "Current Location"
  RoutePlanner  MKDirections (with alternates) → RouteGeometry → RouteMatcher (CamCore), per route
  RouteView     route picker, Map with routes + camera dots, ordered camera list
  CameraRow     snapshot that refreshes only while on screen; tap to expand
  LivePlayback  one shared AVPlayer that moves to the selected camera

CamCore (Swift package, no UIKit/MapKit)
  RouteMatcher  grid-indexed corridor search → projection for distance along the route →
                road-name filters → ordered list with distance and ETA
  RoadRef       parses "I-80", "I80", "US50", "CA-99 N", "Hwy 50", "215 WB …"
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
  direction (Caltrans N/S/E/W), it must line up with the direction of travel.

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

## Not done yet

- Hosting the catalog and refreshing it in the app. The app currently uses only the copy
  bundled at build time.
- More states (the IBI/Arcadis 511 adapter reuses Nevada's code shape for about 10 more
  states).
- App icon, and checking the CarPlay and in-motion rules before any driving-mode features.
