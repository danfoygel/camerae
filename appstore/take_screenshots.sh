#!/bin/zsh
# Captures App Store screenshots (6.9", 1320×2868) on the iPhone 17 Pro Max simulator.
# Run in daylight Pacific time so the camera images are bright. Needs a simulator build:
#   xcodebuild -project Camerae.xcodeproj -scheme Camerae -destination 'name=iPhone 17 Pro Max' -derivedDataPath build
set -e
cd "$(dirname "$0")/.."
DEVICE="iPhone 17 Pro Max"
APP=$(find build/Build/Products/Debug-iphonesimulator -name Camerae.app -maxdepth 1 | head -1)
OUT=appstore/screenshots

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl status_bar "$DEVICE" override --time 9:41 --dataNetwork wifi --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
xcrun simctl ui "$DEVICE" appearance light
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl privacy "$DEVICE" grant location com.danfoygel.camerae
xcrun simctl location "$DEVICE" set 37.7749,-122.4194

rm -f "$OUT"/0*.png "$OUT"/6.3-inch/0*.png

# A fresh trial, so pressing play starts live video.
xcrun simctl launch --terminate-running-process "$DEVICE" com.danfoygel.camerae -resetVideoTrial YES >/dev/null
sleep 8
# Launch opens on the map of nearby cameras.
xcrun simctl io "$DEVICE" screenshot "$OUT/01-map.png"

echo "Now tap a camera pin near downtown, press play, wait for the video, then press Return."
read
xcrun simctl io "$DEVICE" screenshot "$OUT/02-map-live.png"

xcrun simctl launch --terminate-running-process "$DEVICE" com.danfoygel.camerae \
  -from "San Francisco, CA" -to "Reno, NV" >/dev/null
sleep 14
xcrun simctl io "$DEVICE" screenshot "$OUT/03-route.png"

# App Store Connect rejects transparency, and its required slot is 6.3" (1206 × 2622). Needs Pillow.
python3 - "$OUT" <<'PY'
import glob, os, sys
from PIL import Image
out = sys.argv[1]
os.makedirs(f"{out}/6.3-inch", exist_ok=True)
for f in sorted(glob.glob(f"{out}/0*.png")):
    im = Image.open(f).convert("RGB")
    im.save(f)
    im.resize((1207, 2622), Image.LANCZOS).crop((0, 0, 1206, 2622)).save(f"{out}/6.3-inch/{os.path.basename(f)}")
PY
