#!/usr/bin/env python3
"""Build the normalized camera catalog the app ships with.

Pulls every camera from each source adapter, normalizes it into one schema and
writes catalog/cameras.json. Run it on a schedule (cron, GitHub Actions) and
publish the output; the app needs no server of its own.

Sources:
  caltrans  Caltrans CWWP2 CCTV status feeds, one JSON per district (keyless).
  nevada    NVroads (IBI/Arcadis 511). Uses the official keyed API when
            NV511_API_KEY is set, otherwise the public list endpoint that
            backs nvroads.com/list/cameras (undocumented; dev use only).

Usage: python3 tools/build_catalog.py [--out catalog/cameras.json] [--only caltrans,nevada]
"""

import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone

USER_AGENT = "camerae-catalog/0.1 (+https://github.com/; route traffic camera viewer)"
CALTRANS_DISTRICTS = range(1, 13)
NV_BASE = "https://www.nvroads.com"
NV_PAGE_SIZE = 100  # the list endpoint caps pages at 100 rows
POLITE_DELAY_S = 1.0

SOURCES = {
    "caltrans": {
        "name": "Caltrans",
        "attribution": "Camera imagery courtesy of Caltrans",
        "infoURL": "https://cwwp2.dot.ca.gov/",
    },
    "nevada": {
        "name": "Nevada DOT",
        "attribution": "Camera imagery courtesy of NDOT / nvroads.com",
        "infoURL": "https://www.nvroads.com/",
    },
}


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.load(resp)


def clean_url(url):
    """Return an https URL or None. Repairs the odd truncated scheme in the feeds."""
    if not url:
        return None
    url = url.strip()
    if url.startswith("ttps://"):
        url = "h" + url
    if url.startswith("http://"):
        url = "https://" + url[len("http://"):]
    return url if url.startswith("https://") else None


def to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


COMPASS = {"north": "N", "south": "S", "east": "E", "west": "W"}


# --- Caltrans --------------------------------------------------------------

def caltrans_cameras():
    cameras = []
    for d in CALTRANS_DISTRICTS:
        url = f"https://cwwp2.dot.ca.gov/data/d{d}/cctv/cctvStatusD{d:02d}.json"
        try:
            items = fetch_json(url)["data"]
        except Exception as exc:  # one bad district must not sink the build
            print(f"caltrans D{d}: {exc}", file=sys.stderr)
            continue
        kept = 0
        for item in items:
            cam = caltrans_camera(d, item["cctv"])
            if cam:
                cameras.append(cam)
                kept += 1
        print(f"caltrans D{d:02d}: {kept}/{len(items)} in service", file=sys.stderr)
        time.sleep(POLITE_DELAY_S)
    return cameras


def caltrans_camera(district, c):
    if c.get("inService") != "true":
        return None
    loc = c["location"]
    lat, lon = to_float(loc.get("latitude")), to_float(loc.get("longitude"))
    if lat is None or lon is None or lat == 0 or lon == 0:
        return None
    image = c.get("imageData", {})
    static = image.get("static", {})
    snapshot = clean_url(static.get("currentImageURL"))
    hls = clean_url(image.get("streamingVideoURL"))
    if not snapshot and not hls:
        return None
    # Caltrans states the refresh in minutes.
    refresh_min = to_float(static.get("currentImageUpdateFrequency")) or 2
    return {
        "id": f"ca-d{district}-{c['index']}",
        "source": "caltrans",
        "name": loc.get("locationName", "").strip(),
        "place": loc.get("nearbyPlace") or None,
        "lat": lat,
        "lon": lon,
        "road": loc.get("route") or None,
        "direction": COMPASS.get((loc.get("direction") or "").lower()),
        "snapshotURL": snapshot,
        "snapshotRefreshSeconds": int(refresh_min * 60),
        "hlsURL": hls,
    }


# --- Nevada ----------------------------------------------------------------

def nevada_cameras():
    key = os.environ.get("NV511_API_KEY")
    rows = nevada_official(key) if key else nevada_list_endpoint()
    print(f"nevada: {len(rows)} cameras", file=sys.stderr)
    return rows


def nevada_official(key):
    """Official IBI 511 API: GET /api/v2/get/cameras?key=&format=json.

    Field names follow the published docs (nvroads.com/help/endpoint/cameras);
    not yet exercised against a real key.
    """
    data = fetch_json(f"{NV_BASE}/api/v2/get/cameras?key={urllib.parse.quote(key)}&format=json")
    cameras = []
    for site in data:
        lat, lon = to_float(site.get("Latitude")), to_float(site.get("Longitude"))
        for view in site.get("Views") or []:
            if (view.get("Status") or "").lower() == "disabled":
                continue
            cameras.append(nevada_record(
                view_id=view.get("Id"),
                name=view.get("Description") or site.get("Location") or site.get("Roadway"),
                road=site.get("Roadway"),
                direction=site.get("Direction"),
                lat=lat, lon=lon,
                snapshot=clean_url(view.get("Url")) or f"{NV_BASE}/map/Cctv/{view.get('Id')}",
                hls=clean_url(view.get("VideoUrl")),
            ))
    return [c for c in cameras if c]


def nevada_list_endpoint():
    cameras, start, total = [], 0, None
    while total is None or start < total:
        query = {
            "columns": [{"data": None, "name": ""}, {"name": "sortOrder", "s": True}],
            "order": [{"column": 1, "dir": "asc"}],
            "start": start,
            "length": NV_PAGE_SIZE,
            "search": {"value": ""},
        }
        params = urllib.parse.urlencode({"query": json.dumps(query), "lang": "en-US"})
        page = fetch_json(f"{NV_BASE}/List/GetData/Cameras?{params}")
        total = page["recordsTotal"]
        if not page["data"]:
            break
        for site in page["data"]:
            lat, lon = parse_wkt_point(site.get("latLng", {}).get("geography", {}).get("wellKnownText"))
            for img in site.get("images") or []:
                if img.get("disabled") or img.get("blocked"):
                    continue
                hls = None
                if not img.get("videoDisabled") and not img.get("isVideoAuthRequired"):
                    hls = clean_url(img.get("videoUrl"))
                cameras.append(nevada_record(
                    view_id=img.get("id"),
                    name=img.get("description") or site.get("roadway"),
                    road=site.get("roadway"),
                    direction=site.get("direction"),
                    lat=lat, lon=lon,
                    snapshot=f"{NV_BASE}{img['imageUrl']}" if img.get("imageUrl") else None,
                    hls=hls,
                ))
        start += NV_PAGE_SIZE
        time.sleep(POLITE_DELAY_S)
    return [c for c in cameras if c]


def nevada_record(view_id, name, road, direction, lat, lon, snapshot, hls):
    if lat is None or lon is None or view_id is None or not (snapshot or hls):
        return None
    return {
        "id": f"nv-{view_id}",
        "source": "nevada",
        "name": (name or "").strip(),
        "place": None,
        "lat": lat,
        "lon": lon,
        # Roadway is free text ("I80 @ East Verdi"); the app parses road refs from it.
        "road": (road or "").strip() or None,
        "direction": COMPASS.get((direction or "").lower().removesuffix("bound")),
        "snapshotURL": snapshot,
        "snapshotRefreshSeconds": 60,  # nvroads serves images with max-age=60
        "hlsURL": hls,
    }


def parse_wkt_point(wkt):
    """'POINT (-119.85 39.48)' -> (lat, lon)."""
    try:
        lon, lat = wkt[wkt.index("(") + 1:wkt.index(")")].split()
        return float(lat), float(lon)
    except (AttributeError, ValueError):
        return None, None


# --- main ------------------------------------------------------------------

ADAPTERS = {"caltrans": caltrans_cameras, "nevada": nevada_cameras}

STREAM_CHECK_WORKERS = 4


# 403 is deliberately absent: Caltrans's Wowza hosts answer 403 when busy.
DEAD_STATUSES = {404, 410}


def stream_is_live(url, attempts=2):
    """False only when the playlist definitively answers 404/410 (twice).

    Timeouts and other errors keep the stream: under load the Wowza hosts stall or refuse
    requests for streams that are fine, and a false "dead" hides a working camera.
    """
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(req, timeout=8):
                return True
        except urllib.error.HTTPError as exc:
            if exc.code not in DEAD_STATUSES:
                return True
        except Exception:
            return True
        if attempt + 1 < attempts:
            time.sleep(2)
    return False


def answers_ok(url):
    """First-pass probe: True only for a clean 200. Anything else is a suspect to re-check."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=8):
            return True
    except Exception:
        return False


def drop_dead_streams(cameras):
    """Clear hlsURL on cameras whose playlist is gone, so the app shows their snapshot
    instead of waiting on a stream that will never start. Feeds keep listing dead streams
    (e.g. Caltrans D7 returns 404 for some 'in service' cameras)."""
    from concurrent.futures import ThreadPoolExecutor

    with_video = [c for c in cameras if c["hlsURL"]]
    with ThreadPoolExecutor(max_workers=STREAM_CHECK_WORKERS) as pool:
        live = list(pool.map(lambda c: answers_ok(c["hlsURL"]), with_video))
    suspects = [cam for cam, ok in zip(with_video, live) if not ok]
    print(f"stream check: {len(suspects)} of {len(with_video)} streams suspect; confirming one at a time",
          file=sys.stderr)

    # Confirm sequentially, without the concurrent load that can itself cause errors.
    dead = 0
    for cam in suspects:
        if not stream_is_live(cam["hlsURL"]):
            cam["hlsURL"] = None
            dead += 1
        time.sleep(0.5)
    print(f"stream check: {dead} dead streams cleared", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "catalog", "cameras.json"))
    parser.add_argument("--only", help="comma-separated source ids")
    parser.add_argument("--skip-stream-check", action="store_true",
                        help="don't probe each HLS playlist (faster, but keeps dead streams)")
    args = parser.parse_args()

    wanted = args.only.split(",") if args.only else list(ADAPTERS)
    cameras = []
    for source_id in wanted:
        cameras.extend(ADAPTERS[source_id]())

    # Drop exact duplicate streams (the same feed listed twice).
    seen, unique = set(), []
    for cam in cameras:
        key = cam["hlsURL"] or cam["snapshotURL"]
        if key in seen:
            continue
        seen.add(key)
        unique.append(cam)

    if not args.skip_stream_check:
        drop_dead_streams(unique)

    catalog = {
        "version": 1,
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "sources": [{"id": s, **SOURCES[s]} for s in wanted],
        "cameras": unique,
    }
    out = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        json.dump(catalog, f, separators=(",", ":"))
    with_video = sum(1 for c in unique if c["hlsURL"])
    print(f"wrote {len(unique)} cameras ({with_video} with live video) to {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
