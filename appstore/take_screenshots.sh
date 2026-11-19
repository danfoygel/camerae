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

xcrun simctl launch --terminate-running-process "$DEVICE" com.danfoygel.camerae >/dev/null
sleep 4
xcrun simctl io "$DEVICE" screenshot "$OUT/03-search.png"

xcrun simctl launch --terminate-running-process "$DEVICE" com.danfoygel.camerae \
  -from "San Francisco, CA" -to "Reno, NV" >/dev/null
sleep 12
xcrun simctl io "$DEVICE" screenshot "$OUT/01-route.png"

echo "Now tap the first camera row in the simulator, wait for the video, then press Return."
read
xcrun simctl io "$DEVICE" screenshot "$OUT/02-live-video.png"
