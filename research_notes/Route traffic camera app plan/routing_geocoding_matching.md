# Routing, Geocoding, Map Rendering, and Camera-to-Route Matching

Research date: 2026-11-18. Prices change often. Every price below was read on this date unless a different date is given. Third-party price aggregators often disagreed with each other, so official pages were preferred where they could be fetched.

## Which hosted routing + geocoding/autocomplete stack (pricing, free tiers, ToS)?

### Takeaway
Mapbox has the most generous metered free tier that is officially confirmed for this use: 100k Directions requests/month, 100k temporary geocodes/month and 50k web map loads/month. The catch is Search Box autocomplete, whose free tier is small (2,500 sessions/month standard, or 500 under preview pricing). Google is technically the strongest, but it is now capped per SKU (10k Essentials / 5k Pro free per month) and is costlier per call. Google's terms also bar using Directions, Geocoding and related content on a non-Google map, which effectively ties you to the Google map SDK. MapKit JS (Apple) is free at 250k map views and 25k service calls per day, which is very attractive if the app targets Apple. Stadia (Valhalla + Pelias + OSM tiles) is the lowest-cost open-data hosted option, but its free plan is non-commercial.

### Cited Findings
**Google Maps Platform (official pricing page, fetched 2026-11-18)**
- The $200/month credit ended on March 1, 2025. Free monthly caps are now per SKU: 10,000 for Essentials, 5,000 for Pro, 1,000 for Enterprise. Map Tiles get 100,000. Free usage does not pool across SKUs. — [Woosmap blog](https://www.woosmap.com/blog/is-google-maps-api-free); [Google pricing](https://developers.google.com/maps/billing-and-pricing/pricing)
- **Routes: Compute Routes Essentials:** 10,000 free/month, then $5.00/1k up to 100k, falling to $0.38/1k above 5M. — [Google pricing](https://developers.google.com/maps/billing-and-pricing/pricing)
- **Compute Routes Pro:** 5,000 free, then $10/1k. **Enterprise:** 1,000 free, then $15/1k. — [Google pricing](https://developers.google.com/maps/billing-and-pricing/pricing)
- **Legacy Directions:** Essentials 10k free, then $5/1k. Advanced (Pro) 5k free, then $10/1k. — [Google pricing](https://developers.google.com/maps/billing-and-pricing/pricing)
- **Places API (New):**
  - Autocomplete Requests: 10,000 free, then $2.83/1k.
  - Autocomplete Session Usage: unlimited free.
  - Place Details Essentials: 10k free, then $5/1k.
  - Place Details Pro: 5k free, then $17/1k.
  - Geocoding Essentials: 10k free, then $5/1k.
  - Source: [Google pricing](https://developers.google.com/maps/billing-and-pricing/pricing)
- **Maps:** Dynamic Maps Essentials 10k free, then $7/1k. 2D Map Tiles 100k free, then $0.60/1k. — [Google pricing](https://developers.google.com/maps/billing-and-pricing/pricing)
- **ToS, non-Google maps:** The Service Specific Terms contain "No use with a non-Google map" clauses for the Directions API, and in archived versions also for Distance Matrix, Geocoding and Geolocation. I did not find a matching display clause in the Routes API section; the only Routes reference I found was the place_id caching allowance. — [Google Maps Service Specific Terms (current)](https://cloud.google.com/maps-platform/terms/maps-service-terms); [archived 2024-05-22](https://cloud.google.com/maps-platform/terms/maps-service-terms/index-20240522)
- **ToS, caching:** Latitude/longitude from Directions, Geocoding, Places and related services may be cached for at most 30 consecutive calendar days. place_id from Places, Directions, Geolocation and Routes API may be cached indefinitely. — [terms 2023-10-25](https://cloud.google.com/maps-platform/terms/maps-service-terms/index-20231025); [archived 2026-06-04](https://cloud.google.com/archive/maps-platform/terms/maps-service-terms-20260604?hl=es)

**Mapbox (official pricing page, fetched 2026-11-18)**
- **Map Loads for Web (GL JS):** 50,000 free/month, then $5.00/1k, falling to $2.50/1k at 1–5M. A map load includes unlimited Vector Tiles and Raster Tiles API requests. — [Mapbox pricing](https://www.mapbox.com/pricing)
- **Directions API:** 100,000 free/month, then $2.00/1k, falling to $1.20/1k at 1–5M. — [Mapbox pricing](https://www.mapbox.com/pricing)
- **Map Matching API:** 100,000 free, then $2.00/1k. — [Mapbox pricing](https://www.mapbox.com/pricing)
- **Search Box API sessions** (a session is up to 50 /suggest calls plus 1 /retrieve):
  - Standard pricing: 2,500 free, then $11.50/1k.
  - Introductory preview pricing: 500 free, then $3.00/1k.
  - Search Box /category and /reverse requests: 25k free standard ($1.70/1k), or 50k free under preview pricing.
  - Source: [Mapbox pricing](https://www.mapbox.com/pricing)
- **Geocoding API, temporary:** 100k free, then $0.75/1k. **Permanent:** no free tier, $5.00/1k. Only Permanent lets you "permanently store" results, and only for your own use, not for redistribution. — [Mapbox pricing](https://www.mapbox.com/pricing)
- Results from Temporary geocoding cannot be stored in a database or cached. — [Stockist help](https://help.stockist.co/article/104-how-mapboxs-free-tier-works); [Geocodio comparison](https://geocod.io/geocodio-vs-mapbox-geocoding-comparison)
- Aggregator figures for Search Box conflict: some report 50k or 25k, others 2,500. The official page explains this as preview vs. standard, and sessions vs. requests. — [StoreRocket](https://storerocket.io/learn/mapbox-pricing); [Mapbox pricing](https://www.mapbox.com/pricing)

**Apple MapKit JS / Apple Maps Server API**
- **Free quota:** 250,000 map views and 25,000 service calls per day for each Apple Developer Program membership. Service calls cover directions, search and autocomplete. Above that, you contact Apple and fill out an increased-capacity form. — [Apple MapKit JS](https://developer.apple.com/maps/mapkitjs/); [Apple forums](https://developer.apple.com/forums/thread/818109)
- The service-call quota is shared between MapKit JS and the Apple Maps Server API. — [Apple forums](https://developer.apple.com/forums/thread/818109)
- One user reported that the dashboard says "monthly", which conflicts with the documented daily limit. Behaviour past the limit is not officially documented; a third party claims HTTP 429, unverified. — [Apple forums](https://developer.apple.com/forums/thread/818109); [mintlify apple-maps-java](https://www.mintlify.com/WilliamAGH/apple-maps-java/reference/quota)

**HERE**
- The Base plan is pay-as-you-grow and includes 1,000 free HERE Location Services requests per day, excluding Matrix Routing and Tour Planning. — [HERE plans](https://developers.here.com/plans)
- Third-party monthly free figures conflict (30k, 250k, 10k, or 5k routing per month). I could not verify any of them. — [gotime docs](https://gotime.readthedocs.io/en/latest/pricing.html); [gappsy](https://gappsy.com/tools/here/)

**Stadia Maps**
- **Free plan:** 200,000 credits/month across maps, geocoding and routing, no card needed, non-commercial only. Overage is off by default.
- **Paid:** Starter is $20/month for 1M credits, and is required for commercial use. Aggregator listings give Standard at $80 for 7.5M and Professional at $250 for 25M.
- **Storage:** The free plan only permits temporary storage of Autocomplete v2 results.
- Sources: [Stadia pricing](https://stadiamaps.com/pricing/); [freetier.co](https://freetier.co/directory/products/stadia-maps)
- Stadia's routing runs on Valhalla. — [Stadia switch page](https://stadiamaps.com/switch-to-stadia/from-google/)

**Geoapify, LocationIQ, TomTom (third-party figures only, unverified)**
- **Geoapify:** about 3,000 free credits per day across geocoding, routing and places, with attribution required. — [apidog](https://apidog.com/blog/free-maps-api/); [freetier.co](https://freetier.co/compare/geoapify-location-platform-vs-geocodify)
- **LocationIQ:** about 5,000 free requests per day at 2 req/s, including autocomplete and routing. — [freetier.co](https://freetier.co/directory/products/locationiq)
- **TomTom:** about 2,500 free non-tile requests per day plus 50k tile requests per day. Sources conflict. — [Woosmap TomTom alternatives](https://www.woosmap.com/blog/alternative-to-tomtom); [apidog](https://apidog.com/blog/free-maps-api/)

### Inferences
- **Cost per trip.** One user query costs roughly 1 route call, about 1–2 autocomplete sessions and 1 map load.
  - On Mapbox, the free tier covers about 2,500 trips/month before autocomplete costs start, because Search Box sessions run out first.
  - Directions and map loads cover 50k–100k trips/month.
  - A cheaper pattern is Mapbox Directions plus a separate autocomplete provider, or Mapbox temporary Geocoding API v6 in autocomplete mode. That is billed per request at 100k free, but every keystroke counts.
- **Google.** Places Autocomplete (New) has free session usage, but you pay $2.83/1k per autocomplete request, and sessions end in a Place Details call. Compute Routes Essentials costs $5/1k after 10k.
  - Overlaying routes and cameras on MapLibre/OSM tiles is not allowed for Directions, Geocoding or Places content. The Routes API wording was not confirmed in this research.
  - Treat Google as requiring the Google Maps JS or native SDK.
- **iOS-first app.** If the app is iOS-first, MapKit gives you MKDirections and MKLocalSearchCompleter, both native on device. My understanding is that native MapKit is not metered the way MapKit JS is. The web side gets 25k service calls per day free. This is the cheapest polished option, but route geometry comes only as MKPolyline.
- **Storing results.** Camera-to-route matching computed on the server from route geometry does not require storing geocodes. Storing the user's start/end addresses would require Mapbox Permanent geocoding, Stadia paid tiers, or self-hosting.

### Gaps
- I could not read the current Google Service Specific Terms in full; the page was truncated. The live Routes API "non-Google map" clause and the route polyline caching terms need direct verification.
- HERE Routing v8 and TomTom official per-transaction prices could not be confirmed.
- I found no official Geoapify or LocationIQ pricing page.
- OpenRouteService hosted limits were not researched. They are historically about 2,000 directions per day free; verify.
- I did not verify that native (non-JS) MapKit directions and search are unmetered.

## Which open-source self-hosted routing and geocoding engines fit (licensing, hardware, ops)?

### Takeaway
Valhalla is the best fit if you self-host. It has a permissive license, a low serving footprint, polyline6 shape, per-maneuver street names, bearings and shape indices, plus OSRM-compatible output and a built-in map matcher (trace_attributes) that returns OSM way_ids. OSRM is the fastest, but builds of a North America or US extract need about 64–128 GB RAM. GraphHopper (Apache 2.0) is a solid Java alternative. For geocoding, Nominatim is heavy and weak at autocomplete. Photon, built from a Nominatim export, or Pelias are better choices for type-ahead.

### Cited Findings
**OSRM**
- **Official planet figures (v5.26, Nov 2021 planet, car profile):** about 415 GiB after extract, 220 GiB after partition (MLD), 174 GiB after customize, 230 GiB for contract (CH). RAM needed is roughly the size of the preprocessing output. — [OSRM wiki: Disk and Memory Requirements](https://github.com/Project-OSRM/osrm-backend/wiki/Disk-and-Memory-Requirements)
- **North America (older reports):**
  - Building needs at least 64 GB, possibly 128 GB, but serving needs only about 10 GB. — [OSM help 2017](https://help.openstreetmap.org/questions/49651/hardware-requirements-drivetime-server)
  - Another report: the build was tight on 64 GB, with a 9 GB PBF, about 47 GB of output and about 24 GB RAM while serving. — [akiatoji gist](https://gist.github.com/akiatoji/42c04598535e823637ba18a54747fca5)
  - Another: about 50 GB RAM plus swap. — [Datawookie 2017](https://datawookie.dev/blog/2017/11/using-large-maps-with-osrm)

**Valhalla**
- Route responses encode `shape` as a polyline with 6-digit precision. With `format=osrm`, `shape_format` can be `polyline6` (the default), `polyline5`, `geojson` or `no_shape`. — [Valhalla route API reference](https://valhalla.github.io/valhalla/api/route/api-reference/)
- Each maneuver has:
  - `street_names` and `begin_street_names`
  - `begin_shape_index` and `end_shape_index`
  - `bearing_before` and `bearing_after` (clockwise from true north)
  - `time` in seconds and `length`
  - flags `toll`, `highway`, `ferry`
- `way_id` is not returned by /route. — [Valhalla route API reference](https://valhalla.github.io/valhalla/api/route/api-reference/)
- trace_attributes returns edges with filterable attributes, and can turn a trace into the set of matching way IDs. Available attributes include:
  - `edge.way_id`, `edge.names`
  - `edge.begin_heading`, `edge.end_heading`
  - `edge.begin_shape_index`, `edge.end_shape_index`
  - `edge.length`, `edge.speed`
  - `matched_points` with `edge_index` and `distance_from_trace_point`
  - Sources: [Valhalla map-matching API reference](https://valhalla.github.io/valhalla/api/map-matching/api-reference); [MapAtlas docs](https://docs.mapatlas.xyz/overview/directions/mapMatch); [mappymatch source](https://mappymatch.readthedocs.io/en/latest/_modules/mappymatch/matchers/valhalla.html)
- **North America footprint (single blog, unverified):** about 15–20 GB of tiles on disk and 4–8 GB RAM to serve. — [sumguy blog](https://sumguy.com/osrm-vs-valhalla-vs-graphhopper/)

**GraphHopper**
- Licensed Apache 2.0, and the repo includes a map-matching subproject. — [GraphHopper GitHub mirror](https://github.com/GIScience/graphhopper)
- **Full USA (blog, unverified):** a 5–10 GB graph, 6–10 GB RAM to serve, 2–4 hours to build. — [sumguy blog](https://sumguy.com/osrm-vs-valhalla-vs-graphhopper/)
- The GraphHopper Maps UI uses an AGPL dependency. This only matters if you embed the UI. — [sumguy blog](https://sumguy.com/osrm-vs-valhalla-vs-graphhopper/)

**Nominatim, Photon, Pelias**
- **Nominatim full planet:** at least 64 GB RAM and about 900 GB SSD. On a 64 GB, 4-CPU, NVMe machine (2020 planet), import takes about 22 hours for the street style and 54 hours for the full style. US TIGER data adds about 10 GB. — [Nominatim import docs](https://nominatim.org/release-docs/develop/admin/Import/)
- A Nominatim database can be built with `--reverse-only` when it is used only to export a Photon database. — [Nominatim import docs](https://nominatim.org/release-docs/4.4/admin/Import/)

### Inferences
- **Recommended self-hosted stack:**
  - Valhalla in Docker, built from a Geofabrik US extract and rebuilt weekly or monthly.
  - Photon for autocomplete.
  - Optionally Nominatim for exact geocoding.
  - A single 32–64 GB box should serve the US for Valhalla and Photon. The build is the peak.
  - Stadia Maps is effectively the hosted version of this stack (Valhalla plus Pelias-derived geocoding).
- **OSRM.** OSRM's `annotations=duration,distance,nodes` gives per-segment durations and OSM node IDs, which suits ETA and way matching. Its build memory is the main cost. This is prior knowledge, not re-verified here.
- **Update cadence.** For highway camera use, OSM changes slowly, so monthly rebuilds are enough.

### Gaps
- No authoritative current (2026) RAM or disk figures for a US extract with Valhalla, GraphHopper or OSRM.
- Photon and Pelias hardware needs were not found in sources.
- The Valhalla license (MIT) was not confirmed in a fetched source; check the repo.
- OpenRouteService licensing and requirements (GPL, built on GraphHopper) were not researched.

## Which APIs return usable geometry, road names/refs, and bearings?

### Takeaway
Valhalla gives the richest per-maneuver data for direction filtering: polyline6, street_names, bearing_before and bearing_after, shape indices, and time per maneuver. Mapbox and OSRM return polyline, polyline6 or GeoJSON, with step `name` and `ref`. Google Routes returns encoded polylines and step-level instructions. In every case you can compute bearing yourself from the geometry at the point where a camera projects onto the route, which is more reliable than per-step bearings.

### Cited Findings
- Valhalla returns polyline6 by default; with OSRM format it can also return polyline5 or GeoJSON. Maneuver `bearing_before`/`bearing_after` are clockwise from true north. Maneuver `time` and `length` give cumulative ETA. — [Valhalla route API reference](https://valhalla.github.io/valhalla/api/route/api-reference/)
- Valhalla trace_attributes exposes `edge.begin_heading`/`end_heading` and `edge.way_id`. — [MapAtlas docs](https://docs.mapatlas.xyz/overview/directions/mapMatch)

### Inferences
- From prior knowledge, not re-fetched this session:
  - Mapbox and OSRM steps carry `name`, `ref` (e.g. "I 80") and `intersections[].bearings`.
  - `geometries=polyline6|geojson` and `annotations=duration,distance,speed` give per-segment timing.
  - Google Routes API `polyline.encodedPolyline` is precision 5. Its legs carry steps with `navigationInstruction` and `localizedValues`, but no explicit route ref field.
- For direction filtering, compute the route bearing locally from the two polyline vertices around the projected point. Do not depend on any provider's step bearing.

### Gaps
- I did not fetch official Mapbox, OSRM or Google Routes response schemas this session. The fields named above need verification.

## Which map renderer and tile source?

### Takeaway
Use MapLibre GL JS (web) or MapLibre Native (mobile) with OpenFreeMap. OpenFreeMap needs no key and has no limits; self-host Protomaps PMTiles as a fallback. Pair it with a non-Google routing provider. Choose Google or Apple map SDKs only if you use their routing.

### Cited Findings
- OpenFreeMap is free with no limits on map views or requests, no registration and no API keys. Styles such as `tiles.openfreemap.org/styles/liberty` work with MapLibre. It is provided as-is and may change or be discontinued. — [OpenFreeMap](https://openfreemap.org); [GitHub](https://www.github.com/hyperknot/openfreemap)
- OpenFreeMap publishes weekly planet builds; the planet MBTiles file was about 84 GB (Dec 2023). — [OpenFreeMap GitHub](https://www.github.com/hyperknot/openfreemap)
- Protomaps' hosted API has a soft limit of 1M tile requests/month and needs a key. For keyless use it points to OSM or OpenFreeMap. — [Protomaps about](https://protomaps.com/about)
- A Mapbox GL JS map load includes unlimited tiles; there are 50k free loads per month. — [Mapbox pricing](https://www.mapbox.com/pricing)
- Google's Directions, Geocoding and related content may not be used with a non-Google map. — [Google Maps Service Specific Terms](https://cloud.google.com/maps-platform/terms/maps-service-terms)

### Inferences
- Self-hosted PMTiles on a CDN or object storage removes reliance on a free community service. A US-only extract should be much smaller than the planet file.
- Leaflet works for raster tiles but loses vector styling. MapLibre is preferred.

### Gaps
- PMTiles US extract size and hosting costs were not found.
- MapTiler and Stadia tile pricing were not individually verified, beyond Stadia's credit pool.

## How do you match cameras to the route, order them, filter by direction, and compute ETA?

### Takeaway
Use a two-stage pipeline:
1. **Candidates:** query a spatial index for cameras inside a corridor around the route, about 50–150 m. Bounding boxes of route segments against an R-tree, or a buffer in PostGIS, both work.
2. **Linear referencing:** project each candidate onto the polyline to get its distance along the route, which gives both order and ETA. Then reject false positives by perpendicular distance, roadway name/ref match, and camera view direction vs. route bearing at the projected point. For hard cases, map-match cameras to OSM way_ids and compare them with the route's way_ids.

### Cited Findings
- **PostGIS ST_LineLocatePoint** returns a fraction from 0 to 1 giving the position along a linestring of the point closest to the input point. The geography variant uses a spheroid by default (e.g. 0.50007 vs. 0.5 for the geometry variant). — [PostGIS docs](https://postgis.net/docs/ST_LineLocatePoint.html); [Alibaba docs](https://help.aliyun.com/en/rds/apsaradb-rds-for-postgresql/st-linelocatepoint)
- **Turf nearestPointOnLine (v7.4+)** returns on the snapped point:
  - `totalDistance` (distance along the line; formerly `location`)
  - `pointDistance` (snapped point to input point; formerly `dist`)
  - `segmentIndex` (formerly `index`), `lineStringIndex`, `lineDistance`, `segmentDistance`
  - `units` defaults to kilometres.
  - Source: [Turf README](https://github.com/Turfjs/turf/blob/master/packages/turf-nearest-point-on-line/README.md)
- The common "POIs along a route" pattern is `turf.buffer(route)` followed by `turf.within`/`pointsWithinPolygon`. Azure Maps has an official "filter data along route" sample built on Turf. — [Azure Maps sample](https://samples.azuremaps.com/spatial-math/filter-data-along-route); [Turf gist](https://gist.github.com/morganherlocker/597e16852d95acafe5dc)
- TomTom has an SDK example for geometry searches along a route. — [TomTom example](https://docs.tomtom.com/maps-sdk-js/examples/route-geometry-searches)
- The Mapbox MCP server advertises "gas stations along the route" searches. — [Glama MCP listing](https://glama.ai/mcp/servers/bcildyszvp)
- A buffer works "in the simplest cases" only; it ignores network topology. — [2GIS Turf docs](https://docs.2gis.com/en/mapgl/turfjs)
- Valhalla trace_attributes can snap points to edges and return `way_id`, `names`, headings, and `matched_points[].distance_from_trace_point`. — [Valhalla map-matching API](https://valhalla.github.io/valhalla/api/map-matching/api-reference)

### Inferences
These are engineering recommendations from standard GIS practice. They are not individually sourced.

**1. Precompute camera metadata**
- Store each camera's lat/lon, roadway name/ref (normalised, e.g. "I-80"), and view direction (N/S/E/W or degrees).
- Optionally store an offline-matched OSM way_id and road bearing, from Valhalla `locate`/`trace_attributes` or OSRM `nearest`, done once at ingest.

**2. Candidate search**
- Decode the polyline and simplify it for indexing only, not for projection (about 10 m tolerance).
- For each segment, take its bbox expanded by the corridor width and query a static index:
  - flatbush or kdbush in JS (KDBush `around` or geokdbush for radius queries)
  - STRtree in Shapely
  - a GiST index in PostGIS (`ST_DWithin(cam.geog, route.geog, 100)`)
- For about 50k US cameras and a 1,000+ km route (5–20k vertices), this is milliseconds in memory. A buffer polygon followed by point-in-polygon on that many vertices is slower and less precise.
- H3 or geohash cell covers of the corridor are a good fit for a key-value cache, but are coarser.

**3. Projection and ordering**
- Project each candidate with Turf `nearestPointOnLine` (`totalDistance`), Shapely `line.project(pt)`, or `ST_LineLocatePoint` multiplied by the length.
- Use a metric projection (e.g. EPSG:5070 for CONUS) or geography for accuracy.
- Sort by distance along the route.
- **Self-overlapping routes** (out-and-back, cloverleafs): projecting onto the whole line can pick the wrong pass. Project within a window, or use the segment index from the candidate stage.

**4. False-positive filters**
- **Perpendicular distance:** at most about 30–60 m for freeway cameras. Cameras are often offset on poles or overpasses.
- **Bearing:** the route bearing at the snapped segment vs. the camera's view direction or road direction.
  - Accept |Δ| ≤ 45–60°. View directions are coarse (cardinal), so allow wide tolerance.
  - A camera pointing toward oncoming traffic still shows your carriageway on divided highways. Make "both directions" configurable.
  - Reject Δ near 90°, which indicates a cross street or overpass.
- **Name/ref:** normalise "Interstate 80", "I-80" and "I 80 W" to the form "I-80", then match against the route step or maneuver names (Valhalla `street_names`, OSRM/Mapbox `name`/`ref`) for the step containing that shape index.
- **Strongest test:** check whether the camera's precomputed way_id is in the route's way_id set. Get that set by running the route shape through Valhalla trace_attributes with `edge.way_id`, or from OSRM `annotations=nodes`.

**5. De-duplication**
- Cluster cameras within about 50–100 m of each other along the route and keep a site group with multiple views.
- Or group by the source agency's site ID.

**6. ETA**
- Interpolate the cumulative duration at each camera's distance along the route. Use Valhalla maneuver `time`/`length` with `begin_shape_index`, OSRM/Mapbox per-segment `annotations.duration`, or Google step `staticDuration`.
- Add the duration of the partial segment proportionally.

**7. Where to compute**
- Doing this on the client with Turf and flatbush is fine. A US camera set should be a few MB of GeoJSON, or vector tiles.
- Server-side PostGIS is preferred if camera data refreshes often, or if you keep provider route geometry off the client for ToS reasons.

### Gaps
- I found no published benchmark of Turf vs. PostGIS for 1,000+ km routes against tens of thousands of points. The performance claims above are estimates.
- I did not find an official Mapbox "POI along route" tutorial; only third-party, Azure and TomTom equivalents.
- Google Routes API "search along route" (Places Text Search with `searchAlongRouteParameters`) was not verified this session.
- OSRM `nearest`/`match` and GraphHopper map-matching response fields were not fetched.
