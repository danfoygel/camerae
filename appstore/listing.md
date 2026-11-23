# App Store listing — Camerae 1.3

Copy these into App Store Connect. Character limits are Apple's.

## App information

| Field | Value |
|---|---|
| Name (30) | Camerae: Route Traffic Cams |
| Subtitle (30) | Live highway cams on your trip |
| Bundle ID | com.danfoygel.camerae |
| SKU | camerae |
| Primary category | Navigation |
| Secondary category | Travel |
| Support URL | https://danfoygel.github.io/camerae/ |
| Marketing URL | (optional) https://danfoygel.github.io/camerae/ |
| Privacy Policy URL | https://danfoygel.github.io/camerae/privacy.html |
| Copyright | 2026 Dan Foygel |
| Price | Free, with in-app subscription (Camerae Live) |
| Availability | United States |

If "Camerae: Route Traffic Cams" is rejected as too similar to another name, plain "Camerae" works too.

## Promotional text (170)

See the road before you drive it. Every highway camera on your route, in order, with live video where the state provides it. California, Nevada and Illinois.

## Description (4,000)

Camerae shows you every highway traffic camera along your drive, in the order you'll pass them.

Enter where you're starting and where you're going. Camerae plans the route and lines up the cameras along it, from the first mile to the last, with the distance and drive time to each one. Tap a camera for live video, or scroll the list to watch the snapshots refresh.

Check for snow on the pass, a backup at the bridge, or fog in the valley before you leave.

• A map of the cameras around you, with live video a tap away
• Every camera on your route, in driving order
• Live video for most California and Nevada cameras with Camerae Live, free for your first 72 hours
• Snapshots for every camera, always free
• Compare alternate routes, each with its own cameras
• Several views from one pole, starting with the one facing your direction of travel
• Offline cameras are marked, so you don't wait on a dead feed
• Start from your current location, or save a Home
• No account, no ads, no tracking

Coverage: about 7,900 cameras across California (Caltrans), Nevada (NDOT) and Illinois (IDOT, the Illinois Tollway, and Lake, DuPage and Kane counties). Illinois cameras are snapshots only.

Camerae Live: live video is an auto-renewing subscription, billed monthly or yearly. Your first 72 hours of live video, starting the first time you press play, are free. Payment is charged to your Apple Account at confirmation of purchase. The subscription renews automatically unless canceled at least 24 hours before the end of the current period; manage or cancel it in your Apple Account settings. Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ · Privacy Policy: https://danfoygel.github.io/camerae/privacy.html

Camerae is for planning a trip and for passengers. Please don't watch cameras while you drive.

Camera imagery courtesy of Caltrans, NDOT / nvroads.com, and IDOT, the Illinois Tollway, and Lake, DuPage and Kane counties via Travel Midwest (CC BY-SA 2.0). Camerae is not affiliated with or endorsed by any of these agencies.

## Keywords (100)

camera,highway,road,conditions,caltrans,nevada,illinois,chicago,511,tahoe,reno,i-80,commute,snow

"traffic" and "cams" are left out because the app name already has them; Apple indexes the name.

## What's New (version 1.3)

Subscribe to Camerae Live anytime: tap the play button beside "Where to?" on the map.

## In-app purchases

Create a subscription group **Camerae Live** with two auto-renewable subscriptions at the same
level, and attach both to the version for review (with a screenshot of the paywall):

| Reference name | Product ID | Duration | Price (US) |
|---|---|---|---|
| Camerae Live Yearly | com.danfoygel.camerae.live.yearly | 1 year | $9.99 |
| Camerae Live Monthly | com.danfoygel.camerae.live.monthly | 1 month | $0.99 |

Each subscription's display name and description match the app's paywall: "Camerae Live Yearly" /
"Live highway camera video, billed yearly" (and the monthly equivalents). The group's display
name is "Camerae Live".

Review Information, for both subscriptions:
- Screenshot: `appstore/subscription-review.png`
- Note: "Unlocks live video from highway cameras. Snapshots stay free. Live video is free for 72
  hours from the first time the user presses play; after that, pressing play on a live camera
  (red pin on the map) opens this subscription screen. During the trial, the 'Free trial' badge
  on the video also opens it. The play button beside 'Where to?' at the top of the map opens it
  at any time."

The 72-hour trial is
handled in the app, so don't add an introductory offer (it would ask for payment up front).
Also fill in the Paid Apps agreement, tax and banking, or the products won't load.

## Age rating questionnaire

Answer **None / No** to every item. There's no user-generated content, chat, web browsing or gambling. (The Camerae Live subscription doesn't affect the rating.) Expected result: the lowest rating (4+).

## App Privacy

- **Data collection:** "No, we do not collect data from this app."
  - The developer runs no server and receives nothing. Location and saved places stay on the device; place searches and routes go to Apple through MapKit; camera images load directly from the DOT servers.
- **Tracking:** No.

## Export compliance

Answered by the build: `ITSAppUsesNonExemptEncryption = NO` (HTTPS through Apple's frameworks only).

## App Review information

- **Sign-in required:** No
- **Contact:** your name, phone and email (only Apple sees these)
- **Notes:**

> No account or sign-in. Coverage is California, Nevada and Illinois. The app opens on a map of nearby cameras; tap a red camera pin, then press play to watch its live video.
>
> Live video is the Camerae Live subscription (monthly or yearly). The first press of play starts a 72-hour free trial with no sign-up or payment; after it, pressing play shows the subscription screen, with Restore Purchases, Terms of Use and Privacy Policy. Snapshots are free for every camera. To test a route, tap "Where to?", then "San Francisco → Reno" under "Try a trip", or "Chicago → Peoria" for Illinois, or enter any two places in a covered state. Tap a camera row to play its live video.
>
> Camera data: California images and video come from the Caltrans Commercial Wholesale Web Portal (cwwp2.dot.ca.gov), which Caltrans provides at no charge for integration into applications; content is public domain per dot.ca.gov/conditions-of-use. Nevada images and video come from the Nevada 511 traveler information service (nvroads.com), which NDOT provides as a public service. Illinois images come from IDOT's public "Illinois Gateway Traffic Cameras" dataset, published under a Creative Commons Attribution-ShareAlike license and served by Travel Midwest (IDOT's traveler information service) and Lake County PASSAGE. Imagery is credited to each agency in the app, and the app does not claim to be affiliated with any of them.
>
> The app shows a notice that it is for trip planning and passengers, not for watching while driving.

## Screenshots

Upload in filename order. App Store Connect asks for the 6.3" size ("iPhone with Dynamic Island (medium display)"):

- `appstore/screenshots/6.3-inch/`: 1206 × 2622, for the required 6.3" slot
- `appstore/screenshots/`: 1320 × 2868 (6.9"), taken on the iPhone 17 Pro Max simulator; the 6.3" set is scaled from these

Camerae is iPhone-only, so the iPad and Apple Watch tabs don't need screenshots.
