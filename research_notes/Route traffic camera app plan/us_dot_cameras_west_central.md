# Public traffic-camera (CCTV) feeds from Western and Central US state DOTs

Method note: almost everything marked "verified (probe 2026-11-18)" was checked by fetching the endpoint with curl on 2026-11-18, without an API key or account. Counts are what the endpoint returned that day. "CORS" means the `Access-Control-Allow-Origin` header sent back when the request carried a third-party `Origin`. Where only documentation or search results were available, that is stated.

---

## 1. Per-state summary table (inventory endpoint, auth, media, CORS, counts)

### Takeaway
Most of the 21 states fall onto three vendor platforms, each with one API shape: IBI/Arcadis 511 (AZ, NV, UT, ID, WI), Castle Rock CARS (CO, MN, IA, KS, IN), and Iteris (MT). A few states run their own systems (CA, WA, OR, MO, NM, OK, TX, OH, MI, IL). Without any key, a lat/lon camera inventory is available for at least CA, OR, WA (KML/ArcGIS), CO, MN, IA, KS, IN, MO, NM, OK and TX. Browser-playable HLS with `ACAO: *` was confirmed for CA, CO, MN, IA, KS, IN, MO, WI and NV.

### Cited Findings

**Master table**

| State / system | Inventory endpoint (format) | Key? | Location fields | Media | CORS / HTTPS | Count (2026-11-18) |
|---|---|---|---|---|---|---|
| **California / Caltrans CWWP2** | `https://cwwp2.dot.ca.gov/data/d{N}/cctv/cctvStatusD{NN}.{json,xml,csv,txt}`, 12 district files | No | lat, lon, elevation, `direction` (view), route, county, postmile, milepost, nearbyPlace, district, inService | JPEG `currentImageURL` plus 12 "previous" reference JPEGs; HLS `streamingVideoURL` on `wzmedia.dot.ca.gov` (Wowza) | `ACAO: *` on JSON, JPEG and m3u8; HTTPS | 3,615 cameras; 3,441 inService; 2,313 with HLS |
| **Washington / WSDOT** | REST/SOAP `wsdot.wa.gov/Traffic/api/HighwayCameras/HighwayCamerasREST.svc/GetCamerasAsJson?AccessCode=` (key). Keyless alternatives: `.../HighwayCameras/kml.aspx` (KML), `rss.aspx`, ArcGIS `data.wsdot.wa.gov/.../TravelInfoCamerasWeather/MapServer/0` | AccessCode (free, by email) for REST; KML, RSS and ArcGIS need none | REST: route, milepost, region (SearchCameras filters by StateRoute, milepost range); ArcGIS: title, ImageURL, CompassDirection | JPEG only (`images.wsdot.wa.gov`) | No ACAO on images.wsdot.wa.gov JPEGs; ArcGIS echoes origin | KML 1,635 placemarks; ArcGIS layer 1,710 (includes partner and Oregon cameras) |
| **Oregon / ODOT TripCheck** | Official: TripCheck Data API (`apiportal.odot.state.or.us`), CCTV Inventory feed (XSD, 24 h refresh). Unofficial keyless: `tripcheck.com/Scripts/map/data/cctvinventory.js` (Esri JSON) | Subscription key (Azure APIM header `Ocp-Apim-Subscription-Key`) for the API | cameraId, lat, lon, route, title, filename, videoId | JPEG `tripcheck.com/RoadCams/cams/{filename}`; a small number of video IDs | No ACAO observed on the JS or JPEG; HTTPS | 1,181 features in cctvinventory.js (88 with videoId); ODOT says about 1,066 (2025) |
| **Nevada / NVroads (IBI)** | `https://www.nvroads.com/api/v2/get/cameras?key=&format=json` | Yes (account plus key) | Id, Roadway, Direction, Lat, Lon, Location, Views[] | JPEG `/map/Cctv/{viewId}`; HLS `VideoUrl` (`d1wse1/d2wse*.its.nv.gov` Wowza) | HLS `ACAO: *` | 649 camera sites |
| **Arizona / AZ511 (IBI)** | `https://az511.com/api/v2/get/cameras?key=` | Yes | same as NV | JPEG `/map/Cctv/{id}` (`max-age=30`); no video URL in the sampled records | Duplicate ACAO headers (`*` and the echoed origin); see notes | 644 sites |
| **Utah / UDOT Traffic (IBI)** | `https://udottraffic.utah.gov/api/v2/get/cameras?key=` | Yes | same | Image `/map/Cctv/{id}` (served as PNG, `max-age=60`); no video in the sample | Malformed ACAO `*,https://origin` | 2,090 sites |
| **Idaho / 511.idaho.gov (IBI)** | `https://511.idaho.gov/api/v2/get/cameras?key=` | Yes | same | JPEG `/map/Cctv/{id}`; no video in the sample | n/c | 456 sites |
| **Wisconsin / 511WI (IBI)** | `https://511wi.gov/api/v2/get/cameras?key=` (the old `/api/getcameras` returns 404) | Yes, plus a "Developers Access Agreement" | same, plus county and DOT district in the web list | JPEG `/map/Cctv/{id}`; HLS `cctv1.dot.wi.gov/rtplive/CCTV-xx-xxxx/playlist.m3u8` | HLS `ACAO: *` | 495 sites |
| **Colorado / COtrip (Castle Rock CARS-X)** | `https://cotg.carsprogram.org/cameras_v1/api/cameras` (JSON) | No | lat, lon, routeId, linearReference (milepost), cityReference, owner | Views: `STILL_IMAGE` JPEG (`cocam.carsprogram.org`), `WMP` = HLS (`publicstreamer{1-3}.cotrip.org/rtplive/.../playlist.m3u8`), `videoPreviewUrl` PNG | API and HLS `ACAO: *` | 1,005 cameras / 1,301 views (815 HLS) |
| **Montana / 511mt.net (Iteris)** | Iteris "aggregator" services (`aggregator.iteris-atis.com/aggregator/services/layers/group/mdt/current/`) | Unknown | n/c | n/c | n/c | not determined |
| **New Mexico / NMRoads (in-house)** | `https://servicev5.nmroads.com/RealMapWAR/GetCameraInfo` (JSON, served as text/javascript) | No | lat, lon, title, district, grouping | Snapshot `http://ss.nmroads.com/snapshots/*.jpg` (HTTP only; the HTTPS fetch failed); video is RTMP (`rtmp://video.nmroads.com/nmroads` + `*.stream`) | No HTTPS for snapshots; RTMP cannot play in browsers | 185 |
| **Texas / TxDOT** | Undocumented `https://its.txdot.gov/its/DistrictIts/GetCctvStatusListByDistrict?districtCode={AUS,HOU,DAL,SAT,FTW,ELP,...}` (JSON) | No | lat, lon, roadway, direction, status, `icd_Id`, hasSnapshot | Snapshot via `GetCctvSnapshotByIcdId?icdId=&districtCode=` (returns JSON) | n/c | AUS 283, HOU 1,157, DAL 844, SAT 310, FTW 489, ELP 257 (6 of 25 districts) |
| **Oklahoma / OKTraffic (LoopBack API)** | `https://oktraffic.org/api/MapCameras`, `/api/CameraPoles` (JSON) | No | lat, lon, location, direction, city, make/model, `blockAtis` flag | Stream URL scheme not identified | No ACAO for third-party origins | 900 MapCameras (824 with blockAtis = "0"), 229 poles |
| **Kansas / KanDrive (CARS)** | `https://kstg.carsprogram.org/cameras_v1/api/cameras` | No | same CARS schema | STILL_IMAGE (often `www.kcscout.net`, `kscam.carsprogram.org`); HLS on `kdot-sfs*.us-east-1.skyvdn.com` **with a JWT `?token=` that expires 300 s after issue** | `ACAO: *` | 603 cameras (200 HLS) |
| **Missouri / MoDOT Traveler (in-house, Esri)** | `https://traveler.modot.org/timconfig/feed/desktop/StreamingCams2.json` | No | location (text incl. MM), x/y (lon/lat) | HLS `sfs0x-traveler.modot.mo.gov/rtplive/MODOT_CAM_nnn/playlist.m3u8` | HLS `ACAO: *` | 875, all HLS |
| **Minnesota / 511mn (CARS-X)** | `https://mntg.carsprogram.org/cameras_v1/api/cameras` | No | CARS schema | STILL_IMAGE (`public.carsprogram.org`); HLS `video.dot.state.mn.us/public/Cnnnn.stream/playlist.m3u8` | `ACAO: *` | 1,533 cameras / 1,947 views (1,252 HLS) |
| **Iowa / 511ia (CARS)** | `https://iatg.carsprogram.org/cameras_v1/api/cameras`; the site also uses GraphQL `/api/graphql` | No | CARS schema | STILL_IMAGE (`atmsqf.iowadot.gov`); HLS `video{2-4}.iowadot.gov:8888/.../playlist.m3u8` | `ACAO: *` | 860 cameras / 1,259 views (697 HLS) |
| **Illinois / IDOT** | IDOT Open Data "Gateway Traffic Camera Locations [Illinois]" (ArcGIS FeatureLayer, modified 2026-01-07) | Probably none | includes image-age fields | Snapshots via Travel Midwest Gateway | n/c | not determined |
| **Michigan / MDOT Mi Drive** | No public developer feed found; contact MDOT-ITS-Data@Michigan.gov | n/a | n/a | n/a | n/a | not determined |
| **Ohio / OHGO** | `https://publicapi.ohgo.com/api/v1/cameras?api-key=` | Yes (free registration) | Lat, Lon, Location, Description, CameraViews[] (Direction, SmallUrl, LargeUrl, MainRoute) | JPEG snapshots "updated every 5 seconds" | n/c | not determined (key needed) |
| **Indiana / 511in (CARS)** | `https://intg.carsprogram.org/cameras_v1/api/cameras` | No | CARS schema | All HLS (`skysfs3/4.trafficwise.org/rtplive/INDOT_..._{random}/playlist.m3u8`) | `ACAO: *` | 782 (all HLS) |

n/c = not checked.

**Supporting citations**
- Caltrans publishes CCTV location and status files in CSV, JSON, TXT and XML, split by district, over HTTPS, and says "There is no charge for the use of this data". Video and still images "are neither retained nor archived". The site links field descriptions, a GIS data dictionary and a district reporting matrix. — [Caltrans CWWP2 CCTV documentation](https://cwwp2.dot.ca.gov/documentation/cctv/cctv.htm)
- The Caltrans district JSON record has `location` {district, locationName, nearbyPlace, latitude, longitude, elevation, direction, county, route, postmile, milepost}, `inService`, and `imageData` {streamingVideoURL, static.currentImageURL, currentImageUpdateFrequency, referenceImage1..12UpdatesAgoURL}. Example HLS: `https://wzmedia.dot.ca.gov/D7/CCTV-196.stream/playlist.m3u8` (master playlist, 1280x720 H.264). JSON, JPEG and m3u8 all return `Access-Control-Allow-Origin: *`. Verified (probe 2026-11-18). — [cctvStatusD07.json](https://cwwp2.dot.ca.gov/data/d7/cctv/cctvStatusD07.json)
- Caltrans counts by district (verified probe): D1 149, D2 91, D3 274, D4 775, D5 181, D6 128, D7 591, D8 505, D9 23, D10 154, D11 324, D12 420. Total 3,615, of which 2,313 have an HLS URL. D2 and D9 have no HLS. — [CWWP2 data files](https://cwwp2.dot.ca.gov/documentation/cctv/cctv.htm)
- WSDOT Highway Cameras methods are GetCameras(AccessCode), GetCamera(AccessCode, CameraID), and SearchCameras(AccessCode, StateRoute, Region, StartingMilepost, EndingMilepost). — [WSDOT API docs: Highway Cameras](https://wsdot.wa.gov/traffic/api/Documentation/group___highway_cameras.html)
- "To use WSDL services you must be assigned an Access Code. Please enter your email address to receive your code." WSDOT also links REST, RSS and KML variants for Highway Cameras. — [WSDOT Traveler Information API](https://wsdot.wa.gov/traffic/api/)
- WSDOT REST without a code returns 401 "The supplied access code was missing or invalid". The KML (`HighwayCameras/kml.aspx`) returned 1,635 placemarks with `images.wsdot.wa.gov` JPEG URLs, no key needed. Verified (probe 2026-11-18). — [WSDOT cameras KML](https://wsdot.wa.gov/Traffic/api/HighwayCameras/kml.aspx)
- The WSDOT ArcGIS MapServer layer 0 has fields CameraID, CameraTitle, ImageURL, CompassDirection. It returned count 1,710 and includes TripCheck (Oregon) image URLs. Verified (probe). — [WSDOT TravelInfoCamerasWeather MapServer](https://data.wsdot.wa.gov/arcgis/rest/services/TravelInformation/TravelInfoCamerasWeather/MapServer/info/iteminfo)
- A third-party wrapper says WSDOT camera images refresh every 1-5 minutes. This is secondary, not WSDOT documentation. — [ws-dottie docs (unpkg)](https://app.unpkg.com/ws-dottie@0.7.0/files/docs/apis/wsdot-highway-cameras.md)
- TripCheck API: the CCTV Inventory feed (CctvInventory.xsd, 24-hour refresh) gives "an inventory of all available cameras currently displayed on TripCheck, along with an Internet URL" for the still image. Cameras may be ODOT-owned or partner-owned. — [TripCheck API page](https://tripcheck.com/Pages/API)
- The ODOT developer portal requires sign-up to get an API subscription key through the 'Products' tab. — [TripCheck API Getting Started Guide v5](https://WWW.TRIPCHECK.COM/pdfs/TripCheckAPI_Getting_Started_GuideV5.pdf); [ODOT API portal](https://apiportal.odot.state.or.us/product/tripcheck-data-api)
- A third-party example sends the key in an `Ocp-Apim-Subscription-Key` header (secondary source). — [gist (mjmenger)](https://gist.github.com/mjmenger/07cd7b285ee3ab1ed76eb1ac5a6d7aef)
- The keyless `cctvinventory.js` is Esri JSON with fields cameraId, publishedImageId, filename, latitude, longitude, route, title, videoId: 1,181 features, 88 with a nonzero videoId. Verified (probe). — [tripcheck.com cctvinventory.js](https://tripcheck.com/Scripts/map/data/cctvinventory.js)
- IBI 511 developer docs for Nevada, Arizona, Utah, Idaho and Wisconsin all say: "Requires a developer key... query string 'key' parameter is required. Throttling is enabled. Ten calls every 60 seconds. A registered account is needed before you can sign up for a Developer API key." — [NV 511 API doc](https://www.nvroads.com/developers/doc); [AZ511 API doc](https://az511.gov/developers/doc); [UDOT API doc](https://udottraffic.utah.gov/developers/doc); [Idaho 511 API doc](https://511.idaho.gov/developers/doc); [511WI API doc](https://511wi.gov/developers/doc)
- IBI GET Cameras: `https://az511.com/api/v2/get/cameras`, params `key` (required) and `format` (xml|json). Response fields: Id, Source, SourceId, Roadway, Direction (None, All Directions, Northbound...), Latitude, Longitude, Location, SortOrder, Views[] {Id, Url, Status, Description}. — [AZ511 GET Cameras](https://az511.com/help/endpoint/cameras)
- NV and WI camera docs show a `VideoUrl` view field with HLS playlists (`https://d1wse1.its.nv.gov:443/vegasxcd01/...m3u8`, `https://cctv1.dot.wi.gov:443/rtplive/CCTV-18-0012/playlist.m3u8`). — [NV GET Cameras](https://www.nvroads.com/help/endpoint/cameras); [511WI GET Cameras](https://511wi.gov:443/help/endpoint/cameras)
- WI requires a "Developers Access Agreement for 511 API" (PDF linked from the doc page; contents not reviewed). — [511WI API doc](https://511wi.gov/developers/doc)
- Without a key, IBI `/api/v2/get/cameras` returns `<Error><Message>Invalid Key</Message></Error>` (HTTP 400) on NV, AZ, UT and ID. Verified (probe).
- The IBI websites' own keyless DataTables endpoint `/List/GetData/Cameras?query={...}` returns JSON with `recordsTotal` and per-image `imageUrl`, `videoUrl`, `videoType` ("application/x-mpegURL"), `isVideoAuthRequired`, plus WKT location, county and DOT district. recordsTotal on 2026-11-18: AZ 644, NV 649, UT 2,090, ID 456, WI 495. This endpoint is undocumented, backs the web UI, and could change or be blocked. Verified (probe). — [511WI list endpoint](https://511wi.gov/List/GetData/Cameras)
- Castle Rock CARS camera API: `https://{st}tg.carsprogram.org/cameras_v1/api/cameras` returned public JSON with `Access-Control-Allow-Origin: *` for CO, MN, IA, KS, IN (and NE). Records contain id, public, name, lastUpdated, location {fips, latitude, longitude, routeId, linearReference, localRoad, cityReference}, cameraOwner, and views[] {name, type STILL_IMAGE|WMP, url, videoPreviewUrl, imageTimestamp}. Verified (probe 2026-11-18). — [MN CARS cameras API](https://mntg.carsprogram.org/cameras_v1/api/cameras); [CO](https://cotg.carsprogram.org/cameras_v1/api/cameras); [IA](https://iatg.carsprogram.org/cameras_v1/api/cameras); [KS](https://kstg.carsprogram.org/cameras_v1/api/cameras); [IN](https://intg.carsprogram.org/cameras_v1/api/cameras)
- The Iowa 511 front-end bundle sets base `https://iatg.carsprogram.org`, endpoint `cameras: ${m}/cameras_v1/api`, and `graphqlUrl: "/api/graphql"` (MapFeatures query, layer slug `normalCameras`). The MN and CO "CARS-X" configs point at `https://api-511x-{mn,co}.carsprogram.org/cameras`; that root returns `{"healthy":true}`. Verified (probe). — [511ia.org](https://511ia.org/); [new.511mn.org config](https://new.511mn.org/configs/main.json?v=1.10.1); [511.cotrip.org config](https://511.cotrip.org/configs/main.json?v=1.10.1)
- The MN 511 config help text says "Cameras are updated about every 15 minutes throughout the day" (likely still images). — [new.511mn.org config](https://new.511mn.org/configs/main.json?v=1.10.1)
- Castle Rock's official XML data feeds (incidents and the like; "CCTV information" also via the 511 sites) need a login and password obtained through a request form. Listed: San Diego, Nebraska, Minnesota, Kansas, Iowa, Indiana. — [Castle Rock ITS XML Data Feeds](https://www.castlerockits.com/xml-data-feeds)
- A Home Assistant forum post (Jan 2024) points to the COtrip developer page `maps.cotrip.org/help/section/for-developers.html`. That page is JS-rendered and its contents were not retrieved. — [Home Assistant community](https://community.home-assistant.io/t/cotrip-colorado-road-information/666496)
- COTAK says CDOT live roadside video feeds are available to TAK apps (Feb 2025). — [COTAK: Introducing CDOT cameras](https://cotak.gov/pages/news/introducing-cdot-cameras)
- MoDOT `StreamingCams2.json` returns 875 records with `location`, `x` (lon), `y` (lat), `rtmp` (null) and `html` (HLS URL). Verified (probe). — [MoDOT StreamingCams2.json](https://traveler.modot.org/timconfig/feed/desktop/StreamingCams2.json)
- NMRoads `GetCameraInfo` returns `cameraInfo[]` (185) with lat, lon, title, district, videoServer `rtmp://video.nmroads.com/nmroads`, `sdpFileHighRes` (`*.stream`), and `snapshotFile` `http://ss.nmroads.com/snapshots/*.jpg`. The snapshot loads over HTTP; the HTTPS request failed. Verified (probe). — [NMRoads GetCameraInfo](https://servicev5.nmroads.com/RealMapWAR/GetCameraInfo)
- The OKTraffic (LoopBack) API `/api/MapCameras` returned 900 records with latitude, longitude, location, direction, city, make/model (Axis), type (Web/CCTV/Security) and a `blockAtis` flag. The JS bundle names models `Streams`, `LiveStreams`, `MapCameraTranscoders`, but those requests returned 404 or `[]`. Verified (probe). — [OKTraffic MapCameras](https://oktraffic.org/api/MapCameras)
- TxDOT `its.txdot.gov/its/DistrictIts/GetCctvStatusListByDistrict` returns `roadwayCctvStatuses` keyed by roadway, each with lat, lon, roadway, direction, `icd_Id`, `hasSnapshot` and `statusDescription`. Counts by district: AUS 283, HOU 1,157, DAL 844, SAT 310, FTW 489, ELP 257. Verified (probe). The DriveTexas.org front-end bundle had no camera references. — [TxDOT ITS](https://its.txdot.gov/its/District/AUS/cameras)
- TxDOT's own newsroom says clicking a DriveTexas camera icon shows a live video feed. — [TxDOT: Be your own traffic reporter](https://www.txdot.gov/about/newsroom/stories/be-your-own-traffic-reporter.html)
- TxDOT's Connected Services Platform APIs are limited to TxDOT employees, contractors and consultants. — [TxDOT digital roadway data](https://www.txdot.gov/about/programs/innovative-transportation/cooperative-automated-transportation-cat-program/digital-roadway-data.html)
- TrafficLand has an agreement with TxDOT for camera video (undated). — [Global Highways](https://d10dev.globalhighways.com/wh12/news/trafficland-agreement-texas-dot-access-traffic-cameras?page=31)
- OHGO camera model: Latitude, Longitude, Location, Description, CameraViews[] {Direction ("PTZ" means no fixed position), SmallUrl, LargeUrl, MainRoute}, with "Image snapshots are updated every 5 seconds". The endpoint without a key returns "API key required." — [OHGO Cameras docs](https://publicapi.ohgo.com/docs/v1/cameras)
- MDOT lists MDOT-ITS-Data@Michigan.gov for ITS data questions. The "MDOT ITS Video Sharing Portal" is for staff and approved partner agencies. — [MDOT ITS data](https://www.michigan.gov/mdot/travel/safety/efforts/its/its-data); [MDOT ITS Video Sharing Portal docs](https://docs.mdot.ravnur.com/)
- IDOT has a "Gateway Traffic Camera Locations [Illinois]" ArcGIS FeatureLayer with image-age fields (search-result summary; not fetched). — [IDOT interactive data tools](https://idot.illinois.gov/transportation-system/network-overview/highway-system/interactive-data-tools.html); [BTAA geoportal record](https://geo.btaa.org/catalog/8a885da23dfb46caaa1827ad920fb5b1_0.oai_dc_xml)
- Montana's 511mt.net HTML references Iteris services (`aggregator.iteris-atis.com/.../group/mdt/current/`, `iteris-mdt511.net`) and an Iteris "SafeTravel4" camera viewer. A guessed `layers/...?layer_type=cameras` query returned an empty FeatureCollection. — [511mt.net](https://www.511mt.net/)

### Inferences
- For a route app, the easiest keyless, CORS-friendly sources are Caltrans CWWP2, the five CARS states (CO, MN, IA, KS, IN), and MoDOT. Each publishes lat/lon plus HLS from a single JSON fetch, and the browser can play the HLS directly with hls.js.
- IBI states (AZ, NV, UT, ID, WI) each need a key and allow only 10 calls per minute. For a route app that limit means caching the full camera list server-side (one call every few minutes), not querying per user.
- Kansas's 5-minute JWT tokens on skyvdn HLS URLs mean the app has to refresh the CARS camera list (or proxy it) shortly before playback. Caching m3u8 URLs long-term will fail. Other skyvdn/"sfs" Wowza deployments may adopt tokens later.

### Gaps
- OHGO, Michigan, Illinois and Montana camera counts were not determined: OHGO needs a key, and no public feed was found for the other three.
- I did not check whether AZ, UT and ID expose any video. Only the first three list records were sampled, and none had `videoUrl`.
- The TxDOT snapshot response format was not confirmed. `GetCctvSnapshotByIcdId` returned JSON `null` for a guessed ID. TxDOT has 25 districts; only 6 were counted.
- The Oklahoma stream URL scheme was not identified.

---

## 2. Authentication, registration and rate limits

### Takeaway
Keyless: Caltrans, CARS states, MoDOT, NMRoads, OKTraffic, TxDOT ITS, and WSDOT KML/ArcGIS. Free key with registration: WSDOT REST (email AccessCode), ODOT TripCheck (Azure APIM subscription key), IBI states (account plus key; 10 calls/60 s), and OHGO (key; about 25 req/s, "subject to change").

### Cited Findings
- IBI: "Throttling is enabled. Ten calls every 60 seconds." A registered account is required first. — [UDOT API doc](https://udottraffic.utah.gov/developers/doc)
- OHGO: an API key is required on every request. Example limit: "we may allow 25 requests per second for a single API Key. (Subject to change)". ODOT may revoke access without notice; higher limits can be requested. — [OHGO Terms of Use](https://publicapi.ohgo.com/docs/terms-of-use)
- WSDOT: an Access Code is issued by email, and the email "will be used only to notify you of changes". — [WSDOT Traveler Information API](https://wsdot.wa.gov/traffic/api/)
- ODOT TripCheck: a subscription key comes from the developer portal "Products" tab. — [Getting Started Guide](https://WWW.TRIPCHECK.COM/pdfs/TripCheckAPI_Getting_Started_GuideV5.pdf)
- CARS official XML feeds need a login and password via a request form. The public `cameras_v1` JSON used by the 511 sites did not need one (verified probe). — [Castle Rock XML feeds](https://www.castlerockits.com/xml-data-feeds)
- Caltrans: "There is no charge for the use of this data"; no key. — [CWWP2 CCTV](https://cwwp2.dot.ca.gov/documentation/cctv/cctv.htm)
- The Iowa 511 front-end config has `routeSearchRPM:20` and `clientPollTime:6e4`. These are client-side settings, not published limits. — [511ia.org bundle](https://511ia.org/)

### Inferences
- The keyless endpoints (CARS `cameras_v1`, MoDOT `StreamingCams2.json`, TxDOT ITS, NMRoads, OKTraffic, tripcheck.com `cctvinventory.js`, IBI `/List/GetData`) are front-end backends, not published developer APIs. They carry no stated rate limits or SLA and could add bot protection; reCAPTCHA is already loaded on the IA, IN and KS sites. Server-side caching plus polite polling is advisable.

### Gaps
- No rate limits are published for Caltrans, WSDOT, ODOT TripCheck API, or the CARS JSON.

---

## 3. Media delivery: snapshots, HLS, RTMP, tokens, CORS, HTTPS

### Takeaway
HLS from Wowza "rtplive"-style servers is now the dominant video format, and the confirmed HLS hosts all send `ACAO: *` over HTTPS. Only New Mexico still advertises RTMP. Kansas is the one tokenized/expiring case found. No RTSP, MJPEG or DASH was seen in any public feed. IBI image endpoints return duplicate or malformed CORS headers.

### Cited Findings
- HLS master playlists returned 200 with `Access-Control-Allow-Origin: *` for Caltrans (`wzmedia.dot.ca.gov`), MN (`video.dot.state.mn.us`), IA (`video{2,3,4}.iowadot.gov:8888`), KS (`kdot-sfs{2,3}.us-east-1.skyvdn.com`), IN (`skysfs{3,4}.trafficwise.org`), MO (`sfs02-traveler.modot.mo.gov`), WI (`cctv1.dot.wi.gov`), CO (`publicstreamer1.cotrip.org`) and NV (`d2wse2.its.nv.gov`). Resolutions range from 320x240 (MO) to 1280x720 (Caltrans). Chunklist names like `chunklist_w922835813.m3u8` are Wowza session IDs, not auth tokens. Verified (probe 2026-11-18). — [Caltrans sample m3u8](https://wzmedia.dot.ca.gov/D7/CCTV-196.stream/playlist.m3u8); [MoDOT feed](https://traveler.modot.org/timconfig/feed/desktop/StreamingCams2.json); [MN CARS](https://mntg.carsprogram.org/cameras_v1/api/cameras)
- Kansas HLS URLs carry `?token=<JWT>` with `iat` 1795039176 and `exp` 1795039476, a 300-second lifetime. The token propagates to the chunklist URLs. The tokens are issued inside the keyless CARS camera JSON. Verified (probe). — [KS CARS cameras](https://kstg.carsprogram.org/cameras_v1/api/cameras)
- Indiana HLS paths include a random-looking suffix (`INDOT_10_rwMMVpHx71BIeF-Q`). It looks like an obfuscated static ID rather than an expiring token (inference; it worked without a token). — [IN CARS cameras](https://intg.carsprogram.org/cameras_v1/api/cameras)
- IBI images at `/map/Cctv/{id}`: AZ returned image/jpeg, `cache-control: max-age=30`, and **two** `access-control-allow-origin` headers (`*` and the echoed origin). UDOT returned image/png, `max-age=60`, and `access-control-allow-origin: *,https://example.com`. Verified (probe). — [AZ511 sample image](https://az511.com/map/Cctv/682)
- IBI web-list records include `isVideoAuthRequired` (false in every record sampled) and `videoDisabled` flags. — [511WI list endpoint](https://511wi.gov/List/GetData/Cameras)
- Caltrans `currentImageUpdateFrequency` is "2" and `referenceImageUpdateFrequency` is "15" in the D7 sample (the field doc defines the units). The JPEG `Last-Modified` was about 1.5 minutes old when fetched. — [cctvStatusD07.json](https://cwwp2.dot.ca.gov/data/d7/cctv/cctvStatusD07.json)
- OHGO snapshots: "updated every 5 seconds". — [OHGO Cameras docs](https://publicapi.ohgo.com/docs/v1/cameras)
- WSDOT `images.wsdot.wa.gov` JPEGs came back without an ACAO header. — verified probe ([KML](https://wsdot.wa.gov/Traffic/api/HighwayCameras/kml.aspx))
- New Mexico video is RTMP-only, with HTTP-only snapshots. — [NMRoads GetCameraInfo](https://servicev5.nmroads.com/RealMapWAR/GetCameraInfo)
- The Caltrans CWWP2 site moved to HTTPS-only in November 2020. — [CWWP2 CCTV](https://cwwp2.dot.ca.gov/documentation/cctv/cctv.htm)

### Inferences
- With `<img>` tags, CORS doesn't matter. With `fetch()`, canvas processing or service-worker caching, the IBI double or comma-joined ACAO headers will likely be rejected by browsers, so a proxy would be needed.
- An HTTPS app will hit mixed-content blocking on New Mexico's HTTP snapshots, so those need a proxy. Its RTMP needs server-side transcoding, or the app can skip NM video.

### Gaps
- MJPEG, RTSP or DASH were not observed in any public feed. Some DOTs may offer them to partners privately (not found).
- Utah, Arizona and Idaho video availability is unconfirmed.

---

## 4. Licensing and terms of use (redistribution, embedding, attribution)

### Takeaway
Very few of these states publish explicit camera-imagery licenses. Caltrans treats its site content as generally public domain and charges nothing for CWWP2 data. OHGO's terms cover access and abuse but say nothing on redistribution. WI requires signing a developer access agreement. No explicit hot-linking or rebroadcast prohibition was found in the pages reviewed, but most terms were not located at all. That is a gap, not permission.

### Cited Findings
- Caltrans Conditions of Use: "information presented on this website, unless otherwise indicated, is considered in the public domain. It may be distributed or copied as permitted by law. However, the California Department of Transportation does make use of copyrighted data (e.g., photographs) which may require additional permissions." — [Caltrans Conditions of Use](https://dot.ca.gov/conditions-of-use)
- CWWP2 tells users to read the Conditions of Use and says the data carries no charge. — [CWWP2 CCTV](https://cwwp2.dot.ca.gov/documentation/cctv/cctv.htm)
- OHGO terms: free service, API key required, rate limiting, revocation for abuse, "AS IS" with no liability. There is no clause on commercial use, redistribution or attribution. — [OHGO Terms of Use](https://publicapi.ohgo.com/docs/terms-of-use)
- 511WI: a "Developers Access Agreement for 511 API" is linked (PDF not reviewed). — [511WI API doc](https://511wi.gov/developers/doc)
- WSDOT has a general "as-is / as available" travel information disclaimer; no reuse clause was found for imagery. — [WSDOT travel information disclaimer](https://wsdot.wa.gov/about/policies/travel-information-disclaimer)
- The MDOT Mi Drive disclaimer says cameras expected to be out for over a day may be removed. — [Mi Drive Disclaimer](https://www.michigan.gov/mdot/About/Mi-Drive-Disclaimer)
- A neighboring-state example of explicit camera terms (Arkansas, not in scope) shows that some DOTs do publish camera-specific terms. — [iDriveArkansas camera terms](https://site.idrivearkansas.com/index.php/policies/camera-terms-of-use/)
- Texas licenses camera video to TrafficLand, which suggests commercial redistribution there goes through a licensee. The source is undated. — [Global Highways](https://d10dev.globalhighways.com/wh12/news/trafficland-agreement-texas-dot-access-traffic-cameras?page=31)

### Inferences
- California is the lowest-risk state for third-party embedding. Others should be treated as "ask or confirm", especially states whose only access is an undocumented front-end endpoint (TX, OK, NM, MO, CARS states). Going through the official keyed API (IBI, OHGO, WSDOT, ODOT) gives clearer standing.

### Gaps
- Terms or licenses were not found or reviewed for: AZ/NV/UT/ID disclaimers (the AZ disclaimer page text was not camera-specific), WI agreement PDF contents, ODOT TripCheck API terms, CDOT/COtrip, CARS states (MN, IA, KS, IN), MoDOT, NMDOT, ODOT (OK), TxDOT, IDOT, MDOT and MDT. No attribution requirements were found anywhere.

---

## 5. Vendor platforms and shared API shapes

### Takeaway
Three vendor families cover most states in scope. Within each family the API shape is identical, so one adapter per family works. IBI/Arcadis (AZ, NV, UT, ID, WI) uses `/api/v2/get/cameras?key=` plus `/map/Cctv/{id}` images. Castle Rock CARS (CO, MN, IA, KS, IN, plus NE) uses `{st}tg.carsprogram.org/cameras_v1/api/cameras`. Iteris (MT) uses an aggregator service. The rest are in-house or Esri-based.

### Cited Findings
- The IBI doc pages for NV, AZ, UT, ID and WI share identical text, the same `/help/endpoint/cameras` layout, and the same throttle. The same IBI platform runs NY, GA, LA, AK, CT, Ontario and New Brunswick 511. — [511NY](https://511ny.org/developers/doc); [511GA](https://511ga.org/help/endpoint/cameras); [511LA](https://511la.org/help/endpoint/cameras); [Alaska 511](https://511.alaska.gov/help/endpoint/cameras); [CT](https://ctroads.org/developers/help)
- The older IBI path `/api/getcameras?key=&format=` still appears in 511NY docs. 511WI now returns 404 for `/api/getcameras`, so v2 `/api/v2/get/cameras` is current. — [511NY getcameras](https://511ny.org/developers/help/api/get-api-getcameras_key_format); verified probe on 511wi.gov
- CARS: CO, MN, IA, KS, IN and NE all return the same JSON schema from `{st}tg.carsprogram.org/cameras_v1/api/cameras`. MN and CO run the newer "CARS-X" front-end (`api-511x-{st}.carsprogram.org`, Vite/Ionic/videojs bundle). IA, IN and KS run the older webpack front-end with GraphQL `/api/graphql`. Verified (probe). — [MN config](https://new.511mn.org/configs/main.json?v=1.10.1); [CO config](https://511.cotrip.org/configs/main.json?v=1.10.1)
- Castle Rock (Portland, OR) lists CARS XML feeds for San Diego, Nebraska, Minnesota, Kansas, Iowa and Indiana. — [Castle Rock ITS](https://www.castlerockits.com/xml-data-feeds)
- Montana 511 runs on Iteris ATIS (`iteris-atis.com`, `iteriscdn.com`, "SafeTravel4"). — [511mt.net](https://www.511mt.net/)
- OKTraffic is an Angular/LoopBack app with references to `hbesystems.com` and `its.ou.edu`. — [oktraffic.org bundle](https://oktraffic.org/)
- MoDOT Traveler uses the Esri ArcGIS JS API. — [traveler.modot.org/map](https://traveler.modot.org/map/)
- IDOT's Getting Around Illinois is ArcGIS-based (`idot.maps.arcgis.com`, `experience.arcgis.com`). — [gettingaroundillinois.com](https://www.gettingaroundillinois.com/)
- Video servers: many states use Wowza-style `/rtplive/.../playlist.m3u8` paths (WI, MO, CO, KS, IN). KS and IN use "skyvdn"/"Skyline"-style SFS hosts. — verified probe (see section 3)

### Inferences
- Adapter count for this region: (1) IBI v2 with a key, or the `/List/GetData/Cameras` fallback; (2) CARS `cameras_v1`; (3) Caltrans CWWP2; (4) one-off adapters for WA, OR, MO, NM, OK, TX, OH, and possibly IL, MI and MT.
- I could not attribute the Iteris, TransCore, Cubic/Trafficware or Skyline/ibi platforms to any of these states beyond what is listed above.

### Gaps
- Platform attribution for Michigan (Mi Drive), DriveTexas and NMRoads was not confirmed.

---

## 6. Caltrans specifics (CWWP2 CCTV and HLS)

### Takeaway
Caltrans CWWP2 is the best-documented feed in this set: 12 per-district files in four formats, rich location fields (route, postmile, milepost, direction), JPEG snapshots with 12-frame history, and HLS for about 64% of cameras. Everything is served with `ACAO: *` over HTTPS, with no key.

### Cited Findings
- URL pattern `https://cwwp2.dot.ca.gov/data/d{1..12}/cctv/cctvStatusD{01..12}.{csv,json,txt,xml}`, update frequency "as necessary". Supporting docs: field descriptions, GIS data dictionary (XLSX), district reporting matrix, route and postmile charts. — [CWWP2 CCTV](https://cwwp2.dot.ca.gov/documentation/cctv/cctv.htm)
- Image URL pattern `https://cwwp2.dot.ca.gov/data/d7/cctv/image/{slug}/{slug}.jpg`, history at `/previous/{slug}-{1..12}.jpg`. HLS pattern `https://wzmedia.dot.ca.gov/D{n}/{CCTV-id}.stream/playlist.m3u8`. Verified (probe). — [cctvStatusD07.json](https://cwwp2.dot.ca.gov/data/d7/cctv/cctvStatusD07.json)
- Data-quality caveats seen in D7 record 1: `recordDate` 2024-05-07, although the file's Last-Modified was 2026-11-18, and `county` "Alameda" for a Los Angeles location (I-110 Cypress Park). `streamingVideoURL` can be "Not Reported". Verified (probe).

### Inferences
- Use the file's HTTP `Last-Modified`/`ETag` for change detection rather than `recordTimestamp`. Don't rely on `county`, which may be wrong.

### Gaps
- The exact units and semantics of `currentImageUpdateFrequency` were not confirmed from the field-description document.
- Caltrans gives no rate-limit guidance.
