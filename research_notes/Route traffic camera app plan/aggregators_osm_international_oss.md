# Traffic camera aggregators, OSM camera data, international sources, and open-source aggregation projects

Research date: 2026-11-18. About 25 tool calls. Several vendor pages could not be fetched (trafficland.com reset the connection; NSW open data returned 403; road511 dev.to posts returned 404; Ora SOURCES.md returned 404). Those topics rely on secondary sources and are flagged below.

## Commercial aggregators: TrafficLand, INRIX, Iteris, HERE, TomTom, Windy, Road511, others (video vs. stills, pricing, licensing)

### Takeaway
Only two vendors were confirmed to deliver multi-DOT US camera feeds with video through an API: TrafficLand (RTSP/H.264, licensed from more than 50 DOTs, pricing by quote) and INRIX (powered by Vizzion; per-camera license flags, with a 302 redirect to the stream). Road511 is a cheap, newer unified 511 API ($29 to $279 a month) that returns camera features with image URLs, and no video was confirmed. Windy Webcams is mostly scenic webcams, serves stills and timelapses rather than live video, and costs €9,990 a year for the professional tier. No evidence was found that HERE or TomTom expose camera imagery.

### Cited Findings
**TrafficLand**
- Calls itself the largest authorized aggregator and distributor of live US traffic video, with contractual redistribution agreements with more than 50 DOTs. A TxDOT deal added more than 1,600 TxDOT cameras through TxDOT's C2C data portal. Named partners include Garmin and TomTom. — [World Highways](https://www.worldhighways.com/wh12/news/trafficland-agreement-texas-dot-access-traffic-cameras)
- Under the TxDOT deal, TrafficLand may use the imagery in services sold to public safety, media and commercial clients, and may also show it free on its public website. — [World Highways](https://www.worldhighways.com/wh12/news/trafficland-agreement-texas-dot-access-traffic-cameras)
- The FirstNet developer listing says the API gives real-time video from DOT cameras nationwide. Delivery formats:
  - JPEG with manual or auto refresh
  - RTSP streams, "192k streams at 12-15 fps, H.264", from many cameras
  - No mention of HLS or MJPEG
- Metadata fields: camera ID, name, status, direction, lat/lon, refresh rate, DOT source credit, city code, zip code, video URL. The listing shows "Access: Open". Users listed include public safety agencies, private security command centers, connected device makers, and broadcasters/media. No pricing is given. — [FirstNet Developer Portal](https://developer.att.com/firstnet/apis-sdks/trafficland)
- Camera counts conflict even on the same page: "40,000+" and "over 25,000 ... 200+ cities". Older press gives 8,000 and 18,000. RTSP streaming was added around 2019. — [FirstNet Developer Portal](https://developer.att.com/firstnet/apis-sdks/trafficland); [EMS1 press release](https://www.ems1.com/ems-products/computer-aided-dispatch-cad/press-releases/trafficland-provides-live-traffic-video-for-enroute-public-safety-software-u9MfPm6f5r4nR95f/); [Police1](https://www.police1.com/police-products/traffic-enforcement/press-releases/trafficland-offers-public-safety-agencies-upgraded-access-to-roadside-dot-cameras-qPwbGPd07XmeVSUb/)
- TrafficLand has its own iOS app, "TrafficLand Live Cameras" (3.0 stars from 20 ratings). It licensed its feed to WeatherBug's iOS app in 2014. — [App Store](https://apps.apple.com/us/app/id1469322424); [BroadwayWorld 2014](https://www.broadwayworld.com/bwwtravel/article/TrafficLands-Live-Camera-Network-Available-on-Latest-WeatherBug-iOS-App-to-Boost-Convenience-User-Experience-20140506)

**INRIX (imagery from Vizzion)**
- The INRIX Traffic Cameras API has these GET actions, each needing a token from GetSecurityToken:
  - `GetTrafficCamerasInBox` (Corner1/Corner2)
  - `GetTrafficCamerasInRadius` (Center, Radius, Units)
  - `GetTrafficCamerasInGeography` (GeoId)
  - `GetTrafficCamera` (metadata)
  - `GetTrafficCameraImage` (JPEG; DesiredWidth/Height; ImageOptions bitmask for full field of view and dynamic-range enhancement)
  - `GetTrafficCameraVideoURL` (HTTP 302 to the stream; the doc example is RTMP)
  — [INRIX docs](https://docs.inrix.com/traffic/trafficcameras/)
- A `StreamingOnly` filter is available. Fields: Point, Status (outOfService, updateFreq in ms), Name, View, License, CopyrightNotice, StreamUrl, HasStream, Image, Direction, ClosestLane. — [INRIX docs](https://docs.inrix.com/traffic/trafficcameras/)
- Each camera carries a License element with the flags **useWhileDrivingProhibited**, **feeToEndUserProhibited** and **sublicenseProhibited**, plus a required copyright notice. This matters directly for an in-car route app. — [INRIX docs](https://docs.inrix.com/traffic/trafficcameras/)
- Coverage examples in the docs: WSDOT (Seattle/Bellevue), City of Seattle, NYSDOT, Highways England (M25). No full list or pricing is given. — [INRIX docs](https://docs.inrix.com/traffic/trafficcameras/)
- Vizzion says its traffic camera API, which supplies INRIX imagery, is XML-based. — [Vizzion API](https://www.vizzion.com/API.html)
- INRIX Traffic Cameras is also sold as an Esri partner layer. — [Esri partner listing](https://www.esri.com/partners/inrix-a2T70000000TNW1EAO/traffic-cameras-a2dUU000008GT4fYAG)

**Road511 (new unified 511 API, covering the US and Canada)**
- Pricing from road511.com, fetched 2026-11:

  | Tier | Price | Requests | Other limits |
  |---|---|---|---|
  | Free Trial | $0 for 14 days | 20 RPM, 1k requests/day | 2 jurisdictions, 15-minute data delay |
  | Starter | $29/mo | 300 RPM, 50k/day | All US and Canadian jurisdictions, GeoJSON bulk export |
  | Pro | $99/mo | 1k RPM, 500k/day | Historical data, webhooks |
  | Enterprise | $279/mo | Custom | SLA, private deployment |

  Annual billing is 10% off. — [Road511](https://road511.com/)
- Claims 64 jurisdictions: 51 US and 13 Canadian provinces and territories. A sibling service covers Europe: NAPSPAN (napspan.com). — [Road511](https://road511.com/)
- Cameras are a feature type: `GET /api/v1/features?type=cameras` or `/features/geojson`, filtered by `bbox` or `lat/lng/radius_km`. Auth uses an `X-API-Key` header. The site does not mention video streams or image redistribution rights. — [Road511](https://road511.com/); [Road511 blog](https://road511.com/blog/traffic-camera-feeds-api.html)
- A Road511 tutorial claims "10,000+ traffic cameras across 40+ US states and Canadian provinces". The `image_url` is a direct link to the agency image. — [Road511 blog](https://road511.com/blog/traffic-camera-feeds-api.html); [DEV Community](https://dev.to/road511/how-i-normalized-30-different-511-traffic-apis-into-one-rest-endpoint-3cl9) (a 404 at fetch time; search snippet only)
- Road511's own comparison table marks HERE, TomTom and INRIX as having no live cameras. This is vendor marketing, and INRIX's own docs contradict it. It also claims "navigation apps like Waze and Google Maps use Road511", which I could not verify and doubt. — [DEV Community comparison](https://dev.to/road511/comparing-traffic-data-apis-road511-vs-here-vs-tomtom-vs-inrix-55cg)

**Windy Webcams API v3**
- Two tiers:
  - **Free**: images must link to windy.com, or you embed the timelapse player (with ads). Image size is limited. Image URL tokens last 15 minutes. Listing offset is capped at 1,000.
  - **Professional, €9,990 per year**: no ads in the player, full-size images, 24-hour image URLs, offset up to 10,000, and the full webcam list in one call.
  — [Windy pricing](https://api.windy.com/webcams/pricing)
- The docs overview gives a token life of "10 minutes for the free" tier, which conflicts with the 15 minutes on the pricing page. An expired token returns HTTP 401. Windy recommends calling `/webcams/api/v3/webcams` on each page load. The auth header is `x-windy-api-key`. — [Windy docs](https://api.windy.com/webcams/docs); [Windy v2 to v3 migration](https://api.windy.com/webcams/version-transfer)
- Terms of use:
  - Credit Windy in the corner of the webcam context.
  - Show images only at original size or smaller.
  - Use only the image URLs the API returns.
  - Link every image to Windy (`webcam.urls`) or to the timelapse player (`webcam.player`).
  - Use the data "as is".
  - Windy can end the API at any time.
  — [Windy terms](https://api.windy.com/webcams/terms)
- `include=categories,images,location,player,urls`. The player object gives iframe embed links for day, month, year and lifetime timelapses. There is a categories endpoint. — [Windy migration guide](https://api.windy.com/webcams/version-transfer)
- A third-party site lists "traffic" among the Windy categories and says "the Windy player does not show live video streams". — [World Monitor webcam layer doc](https://www.worldmonitor.app/docs/webcam-layer)

### Inferences
- **Fastest path to licensed nationwide video is TrafficLand or INRIX/Vizzion.** Both are sales-led with quote pricing. Plan on per-camera license flags; INRIX explicitly has a useWhileDrivingProhibited flag. A "plays video while driving" UX may be contractually barred for some cameras, so the app should probably show video only to a passenger or when parked.
- **Cheapest broad metadata is Road511.** It is a reasonable bootstrap for camera locations and image URLs across the US and Canada. It is not a video source, and it gives no redistribution license; image rights stay with each DOT.
- **Windy is a poor fit.** It is mostly scenic webcams with stills or timelapses only, requires link-back, and the professional tier is expensive. It could serve as a supplementary layer at most.

### Gaps
- Not researched or found within the call budget:
  - Iteris ClearGuide camera services
  - HERE (no camera API found)
  - TomTom (only a 2021 article mentioning camera "alerts", which probably means speed cameras)
  - Skyline / SkyVDN
  - Waycare / Rekor
  - The FHWA or ITS JPO "national 511": no unified national camera API surfaced. Road511 lists FHWA, NBI and WZDx feeds but no cameras.
- TrafficLand's public pricing, current DOT list, and whether consumer apps can license it: trafficland.com could not be fetched.
- The INRIX camera count and per-camera pricing.
- The count of Windy cameras in the "traffic" category and its category ID: you would need to call `/webcams/api/v3/categories`.

## Mapping and consumer apps that show traffic cameras: how they source data

### Takeaway
I found no documented camera feature in Waze, Apple Maps or Sygic. The many per-state "State Roads" or "Road Cameras" iOS apps say they pull directly from each state DOT's public feed, and some ship stills rather than video. TrafficLand runs its own app and licenses feeds to others.

### Cited Findings
- Per-state apps credit the DOT directly:
  - Wisconsin State Roads: "courtesy of" WisDOT
  - Pennsylvania State Roads: PennDOT
  - Louisiana State Roads: DOTD
  - Illinois State Roads: 2,100+ camera feeds
  - Traffic Advisor: data "directly from your state's Department of Transportation"
  — [Wisconsin](https://apps.apple.com/us/app/id1208919165); [Pennsylvania](https://apps.apple.com/us/app/id1378235029); [Louisiana](https://apps.apple.com/app/id1523044093); [Illinois](https://spark.mwm.ai/en/apps/illinois-state-roads/1212012250); [Traffic Advisor](https://clickontyler.com/traffic-advisor)
- Other camera apps: New York Road Cameras, California Road Cameras, Oregon Roads, and Live Lane - Traffic Cameras. — [NY](https://apps.apple.com/us/app/-/id6751172778); [CA](https://apps.apple.com/us/app/-/id6738664422); [Oregon](https://apps.apple.com/app/id1202562910); [Live Lane](https://apps.apple.com/app/id6759710688)
- One Georgia State Roads reviewer says the cameras are "recent snapshots rather than realtime video". This is anecdotal. — [Georgia State Roads](https://apps.apple.com/us/app/id1209150810)

### Inferences
- The independent-app ecosystem is built mostly on public DOT 511 feeds, often one app per state, without visible commercial licensing. No major navigation app shows DOT cameras inline along a route, which suggests a product gap.

### Gaps
- No sources on Waze, Apple Maps, Sygic, "TrafficCam+", "US Traffic Cameras" or "Roadtrip" camera sourcing.

## OpenStreetMap camera data: tagging, coverage, Overpass, ODbL

### Takeaway
OSM can model traffic cameras (`man_made=surveillance` + `surveillance:type=camera` + `surveillance:zone=traffic`), but it holds only location and direction, no feed URLs. For a feed-playing app it is at most a weak supplementary location source. DOT/511 feeds are the authoritative inventory.

### Cited Findings
- `surveillance:type` goes on `man_made=surveillance` nodes and has de facto status. Values: `camera` (the most common), `guard`, `ALPR`, `gunshot_detector`. `camera` works with `camera:*=*` and `contact:webcam=*`. — [OSM wiki Key:surveillance:type](https://wiki.openstreetmap.org/wiki/Key:surveillance:type)
- `surveillance:zone=traffic` is documented as "for example on a motorway". The wiki notes it is not for speed cameras, which use `highway=speed_camera`. The value has no dedicated wiki page. — [OSM wiki Key:surveillance:zone](https://wiki.openstreetmap.org/wiki/Key:surveillance:zone); [Talk page](https://wiki.openstreetmap.org/wiki/Talk:Key:surveillance:zone)
- Related keys: `surveillance=*` (public/outdoor/indoor), `camera:type=*` (fixed/dome/panning), `camera:direction`, `camera:mount`. The MapComplete surveillance_camera layer documents an editing UI for these tags. — [OSM wiki man_made=surveillance](https://wiki.openstreetmap.org/wiki/Tag%3Aman_made%3Dsurveillance); [MapComplete layer doc](https://source.mapcomplete.org/loviuz/MapComplete/raw/commit/50ae3bf5bad5a94ec00c6fe41d5a82c6ec6dd19d/Docs/Layers/surveillance_camera.md)
- The wiki value table showed no usage counts. Live numbers have to come from taginfo or Overpass. — [OSM wiki Key:surveillance:type](https://wiki.openstreetmap.org/wiki/Key:surveillance:type)

### Inferences
- **Overpass query along a route** (from general knowledge, not verified this session):
  ```
  [out:json];
  nwr["man_made"="surveillance"]["surveillance:zone"="traffic"](around.route:200,lat1,lon1,lat2,lon2,...);
  out center;
  ```
  To count: `nwr["surveillance:zone"="traffic"];out count;`
- **Coverage is likely sparse and uneven**, driven by privacy and ALPR mapping communities rather than DOT camera inventories. Nothing in OSM links a node to a live feed, so you would need to match OSM nodes to DOT camera records anyway.
- **ODbL** (general knowledge; https://www.openstreetmap.org/copyright was not fetched this session):
  - Requires "© OpenStreetMap contributors" attribution.
  - Share-alike applies to a "derivative database". Merging OSM camera nodes into your own camera database could trigger an obligation to offer that combined database under ODbL.
  - Keeping OSM data in a separate layer (a "collective database") avoids this.
  - Have counsel confirm.

### Gaps
- No current taginfo or Overpass count of `surveillance:zone=traffic` or of traffic cameras with `contact:webcam`.
- No coverage-quality study comparing OSM traffic cameras with DOT inventories.

## International official sources: Canada, UK, Netherlands, Germany, Australia, New Zealand

### Takeaway
Canada is the strongest: BC's DriveBC is under OGL-BC with commercial use allowed, Québec offers GeoJSON/WFS open data with stream URLs, and Ontario plus several provinces run the same Arcadis/IBI "511 developer" API. London's TfL JamCams gives JSON with `.jpg` and 9-second `.mp4` clip URLs. NSW has a GeoJSON camera API. National Highways (England) has no official camera API; a 2024 petition for one was rejected. NZTA's camera API is legacy XML and closed to new accounts. Germany, the Netherlands, VicRoads and Alberta specifics were not confirmed.

### Cited Findings
**Canada**
- **Ontario 511 (511on.ca)**: has a Cameras resource. It needs a developer key ("query string 'key' parameter"). Rate limit: "Throttling is enabled. Ten calls every 60 seconds." — [511ON developer docs](https://511on.ca/developers/doc)
- Ontario also publishes a "Traffic cameras" dataset on its data catalogue. — [Ontario Data Catalogue](https://data.ontario.ca/dataset/traffic-cameras)
- The same IBI-style `/developers/doc` API is used by:
  - New Brunswick
  - New York
  - Nevada
  - Utah, hosted at `prod-ut.ibi511.com`, which shows the platform is Arcadis/IBI
  — [NB](https://511.gnb.ca/developers/doc); [511NY](https://511ny.org/developers/help); [NV](https://www.nvroads.com/developers/doc); [UDOT](https://prod-ut.ibi511.com/developers/doc)
- **DriveBC (BC)**: webcam images and data are released on DataBC for commercial use under the Open Government Licence – British Columbia. The Open511 events API (api.open511.gov.bc.ca) is also under OGL-BC and has its own API terms. — [BC gov news 2016](https://news.gov.bc.ca/releases/2016TRAN0045-000360); [Open511 BC help](https://api.open511.gov.bc.ca/help); [bcgov/drivebc-webcam-api](https://github.com/bcgov/drivebc-webcam-api)
- **Québec**: the Ministry of Transport and Sustainable Mobility publishes camera locations as CSV or GeoJSON through WFS. Each camera has a URL to view the "video stream of images". — [Open Government Portal](https://open.canada.ca/data/en/dataset/f086e1f7-66f9-45dd-9dc7-bc1ee8436bc9)
- **Alberta**: ha-the511 lists Alberta and Ontario as needing no key. — [ha-the511](https://github.com/ihavespoken327/ha-the511)

**UK**
- **TfL JamCams**: `https://api.tfl.gov.uk/Place/Type/JamCam`. Each record is a Place with `additionalProperties` keys `imageUrl` (.jpg) and `videoUrl` (.mp4, about a 9-second clip), hosted on the S3 bucket `jamcams.tfl.gov.uk`. The S3 objects need no key; the API takes `app_id`/`app_key`. — [TfL Techforum: live JamCam images and clips](https://techforum.tfl.gov.uk/t/live-jamcam-images-and-clips/596); [TfL blog 2016](https://blog.tfl.gov.uk/2016/01/22/improved-roads-open-data-car-parks-jamcams/)
- Images refresh roughly every 5 to 10 minutes per a third-party site, and there is no archive. — [jamcams.pages.dev](https://jamcams.pages.dev/blog/tfl-cameras-explained); [TfL Techforum historic images](https://techforum.tfl.gov.uk/t/jamcam-multiple-historic-images/1016)
- Reliability: forum threads report empty `/Place/Type/JamCam` responses and outages. They were undated in results. — [Techforum empty list](https://techforum.tfl.gov.uk/t/unable-to-get-list-of-jamcam/3622); [Jamcams not working](https://techforum.tfl.gov.uk/t/jamcams-not-working/1479)
- **National Highways (England)**: a February 2024 e-petition asked for API access to camera images. It was rejected; the response called the format an operational matter for National Highways. The petition says recent changes had made services inaccessible. — [Petition mirror](https://repetition.me/657108-enable-api-access-to-national-highways-traffic-camera-cctv-images)
- trafficcameras.uk claims to aggregate National Highways images with 20-second refresh. Its terms are unverified. — [trafficcameras.uk help](https://trafficcameras.uk/help)
- WebTRIS is sensor data only, not cameras. — [Jentic Highways England](https://jentic.com/apis/highwaysengland.co.uk/highwaysengland)
- INRIX lists Highways England M25 cameras, so a licensed commercial route exists. — [INRIX docs](https://docs.inrix.com/traffic/trafficcameras/)

**Australia and New Zealand**
- **NSW**: the Live Traffic Cameras API returns GeoJSON with image URLs, GPS and view descriptions. The page returned 403 when fetched, so the licence and key requirements are unconfirmed. — [NSW Open Data](https://opendata.transport.nsw.gov.au/dataset/live-traffic-cameras); [transportnsw.info developers](https://transportnsw.info/livetraffic/developers)
- **NZTA**:
  - The camera API "does not return JSON, but rather, it returns XML".
  - The legacy Traffic Camera API is "no longer available for new account requests". It served static JPGs refreshed every 30 seconds at 100+ locations.
  - The current REST base is `https://trafficnz.info/service/traffic/rest/4`.
  - There is also an ArcGIS FeatureServer "NZTA_Highway_Information".
  - A third-party claim that JSON is available via an Accept header is unverified.
  — [NZTA traffic cameras](https://nzta.govt.nz/traffic-and-travel-information/use-our-data/about-the-apis/traffic-cameras/); [NZTA camera API PDF](https://nzta2.cwp.govt.nz/assets/traffic/docs/NZTA-Traffic-Camera-APIs.pdf); [ArcGIS](https://services.arcgis.com/CXBb7LAjgIIdcsPt/ArcGIS/rest/services/NZTA_Highway_Information/FeatureServer); [ClawHub skill](https://clawhub.ai/skills/nzta-traffic)

### Inferences
- For Canada, one adapter for the IBI/Arcadis 511 API plus small adapters for DriveBC and Québec WFS covers most of the population. Ontario's 10 calls per minute means you must bulk-cache the camera list server-side, not call it per user.
- TfL is the only international source confirmed to offer video-like content: short MP4 clips, not live streams.

### Gaps
- Not found:
  - Germany: the Autobahn API (autobahn.api.bund.dev) webcam endpoint. The fetch returned only a title. From memory, there is a `/{roadId}/services/webcam` endpoint; this is unverified.
  - Netherlands (NDW or Rijkswaterstaat cameras)
  - VicRoads
  - Alberta 511 terms
  - Traffic Scotland and Traffic Wales
- Road511's European sibling NAPSPAN was not investigated.

## Open-source projects and datasets aggregating traffic cameras

### Takeaway
The best reusable starting point is **Ora**. It is very fresh (sweep on 2026-10-22), maps about 46-47k cameras in all 50 states as per-state GeoJSON, plays HLS video in about 22 states, and has a relay for origin-locked hosts. However, it has 4 stars and a **PolyForm Noncommercial** license, so its code and data compilation cannot be reused commercially without permission. **ha-the511** (MIT) is a clean, permissive reference for the two dominant 511 vendor platforms. Its key finding is that 21 of 24 providers run on Arcadis/IBI "TravelIQ" and 3 on the Iteris/ATG GeoJSON CDN.

### Cited Findings
**Ora** (warner-wvez/Ora)
- "Live Apple-Maps-style map" of public traffic cameras. Stats:
  - 4 stars, 632 commits
  - License: PolyForm Noncommercial 1.0.0
  - Coverage table: 50/50 states, 46,853 cameras (the About text says about 46,100 and "every state but New Jersey"; New Jersey appears to have been added since)
  - 22 states with live video; 7,637 cameras down at the last sweep (2026-10-22 17:47 UTC)
  — [GitHub Ora](https://github.com/warner-wvez/Ora)
- Data layout: per-state GeoJSON in `states/<CODE>.json`, plus `cameras.json`, the original Illinois layer. Each feed has its own Python script.
- Video handling: HLS plays through hls.js directly from agency servers. Florida and New Jersey go through a VPS relay for "hosts that lock out other origins". A stream counts as video only if it plays from a static page; expiring tokens, DRM, and Referer-locked hosts are refused.
— [GitHub Ora](https://github.com/warner-wvez/Ora)

**ha-the511** (ihavespoken327/ha-the511)
- Home Assistant integration. Stats: 1 star, 86 commits, MIT license. — [GitHub ha-the511](https://github.com/ihavespoken327/ha-the511)
- 24 providers in total:

  | Platform | Providers |
  |---|---|
  | TravelIQ (Arcadis/IBI) | 21 |
  | Iteris/ATG GeoJSON CDN | SC, MT, SD |

- US states covered: WI, LA, AK, NY, GA, AZ, CT, FL, ID, NV, UT, NC, PA, SC, MT, SD.
- Canadian provinces covered: AB, ON, NL, MB, NB, SK, NS, YT.
- Stills only.
- Keys: AB, ON, SC, MT and SD need none. The rest need a free developer key from each provider. SK and NS have no self-serve portal.
— [GitHub ha-the511](https://github.com/ihavespoken327/ha-the511)

**Smaller projects**
- StrongHorse44/maps PR #53: about 12,400 cameras across 15 states. Notes "No traffic feed" for NJ and MO. — [PR #53](https://github.com/StrongHorse44/maps/pull/53)
- bobbyearl/roadie PR #63 adds per-state camera data:

  | State | Cameras | Source |
  |---|---|---|
  | IL | 1,372 | travelmidwest Gateway |
  | MI | 804 | MDOT MiDrive |
  | AZ | 644 | az511.gov |
  | MA | 306 | — |
  | KY | 254 | — |

  — [roadie PR #63](https://github.com/bobbyearl/roadie/pull/63)
- Eleutheria PR #99: registry rows for 14 targets in 13 states, deliberately excluding image and video URLs. — [Eleutheria PR #99](https://github.com/SteveVitali/Eleutheria/pull/99)
- cailinpitt/ClassicTraffic: a bot that posts videos of state traffic cameras. — [GitHub](https://github.com/cailinpitt/ClassicTraffic)
- qwazwsx/traffic-cameras: batch image downloader for Minnesota and Iowa (IRIS). — [GitHub](https://github.com/qwazwsx/traffic-cameras)
- Apify "CARS-511 Traveler Info Extractor": a commercial scraper for the Castle Rock CARS-511 platform. — [Apify](https://apify.com/datamule/cars-511-traveler-extractor)
- Road511 publishes a road511-examples repo. — [mirror](https://gh.r-mj.com/Road511/road511-examples)

### Inferences
- US 511 systems cluster on a few vendor platforms: Arcadis/IBI TravelIQ, Iteris/ATG, and Castle Rock CARS. Writing about 3 to 5 platform adapters plus around 10 bespoke state adapters probably reaches about 45k+ cameras, matching Ora's count.
- Ora's HLS-verified list of about 22 states is the best existing map of where free inline video is feasible. Because of the noncommercial license, use it only as a reference or for a permission request, and re-derive the data independently.
- ha-the511 (MIT) can be ported directly for endpoint shapes.

### Gaps
- Not searched (budget):
  - Kaggle and academic camera datasets
  - "WeatherCams" and "CamerasNearMe"
  - Larger-star repos such as Windy-based or 511 scrapers
- Ora's SOURCES doc returned 404, so the per-state vendor breakdown and the list of HLS states could not be read. It is worth a direct look at the repo.

## Legal and ToS: scraping DOT web viewers vs. official feeds; hot-link blocking

### Takeaway
Some DOT camera terms explicitly prohibit embedding or linking camera images in third-party apps; Arkansas is confirmed. The technical lock-out is real too: Ora relays Florida and New Jersey because those hosts reject other origins. The safe paths are official developer APIs with stated licences (OGL-BC, the TfL open data licence, Road511's unstated terms), data-use agreements with each DOT, or a licensed aggregator such as TrafficLand or INRIX.

### Cited Findings
- **Arkansas (IDrive Arkansas)**:
  - Embedding live camera images or the site in another website or app is prohibited.
  - Linking to any camera from another site or app is prohibited.
  - Images are owned and copyrighted by each camera owner.
  - Broadcast or streaming use of commercial TV station cameras needs an agreement.
  — [IDrive Arkansas camera terms](https://site.idrivearkansas.com/index.php/policies/camera-terms-of-use)
- Similar "Michigan-style" terms, requiring the camera owner's logo on screen captures, appear on an unofficial blog copy. Unverified. — [booyscripts](https://booyscripts.weebly.com/blog/mdot-traffic-cam)
- **Texas**: a developer removed TxDOT and Houston TranStar camera imagery from a public site, citing terms that restrict copying, redistribution or framing, until a data-use agreement was in place. — [cruzewebsite PR #111](https://github.com/cruzemaps/cruzewebsite/pull/111)
- **Technical blocking**: Ora documents hosts that "lock out other origins" (Florida) plus Referer-locked and expiring-token streams. — [GitHub Ora](https://github.com/warner-wvez/Ora)
- **Commercial license flags**: INRIX per-camera flags (useWhileDrivingProhibited, feeToEndUserProhibited, sublicenseProhibited) show that DOT licences passed through aggregators carry restrictions. — [INRIX docs](https://docs.inrix.com/traffic/trafficcameras/)
- **Ontario**: Jentic (secondhand) says the developer agreement requires caching of at least 60 seconds. — [Jentic 511ON](https://jentic.com/apis/511on.ca/511on.md)

### Inferences
- A per-state legal matrix is needed. Some states (for example BC, and probably many 511 developer programs) explicitly allow reuse. Others (AR, possibly TX and MI) forbid embedding without agreement.
- Proxying video to get around CORS or Referer locks, as Ora does for Florida, is a legal gray area. It also transfers bandwidth cost to you.
- Showing the DOT source credit and logo, as TrafficLand and INRIX metadata include, should be standard.

### Gaps
- No court cases or public enforcement actions were found against apps hot-linking DOT cameras.
- No survey of which states' developer agreements permit commercial redistribution.
