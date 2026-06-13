# prottivo_transporter

Transporter Flutter app for Porttivo.

## Google Maps and Places (pickup / drop search)

Pickup and drop use the native **Google Places** stack via [`google_places_autocomplete`](https://pub.dev/packages/google_places_autocomplete). The app:

- Resolves GPS + country **before** initializing Places (single configure — avoids Android crashes from reinitializing Places while GoogleMap is visible).
- When the device is in **India** (geocoded country `IN`), autocomplete is **restricted to India** (`IN`) and biased to the user’s coordinates for local precision.
- Outside India, suggestions are **not** country-locked but still ranked using the user’s location when permission is granted.
- Pass `forceGlobalSearch: true` on [`LocationPickerScreen`](lib/screens/location_picker_screen.dart) if you need worldwide suggestions without the India filter (e.g. international freight).
- If Places search fails to initialize, **Use current location** still works via reverse geocoding (no Places required).

### API keys

- **Android:** `com.google.android.geo.API_KEY` in `AndroidManifest.xml` (Maps + Places SDK).
- **iOS:** `GOOGLE_PLACES_API_KEY` / Maps key in `Info.plist` per the plugin docs.
- Optional Dart override: `flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key` ([`lib/core/config/maps_config.dart`](lib/core/config/maps_config.dart)).

### Production checklist

1. In [Google Cloud Console](https://console.cloud.google.com/), enable **Places SDK for Android** / **Places SDK for iOS** (and Maps SDK as needed).
2. **Restrict API keys** by Android app signing SHA-1 and iOS bundle ID; do not ship unrestricted keys. Include **debug and release** signing SHA-1 for package `com.example.prottivo_transporter`.
3. Release builds require Places ProGuard keep rules in [`android/app/proguard-rules.pro`](android/app/proguard-rules.pro) (already included).
4. Monitor **Places Autocomplete** and **Place Details** usage and quotas; the autocomplete package manages **session tokens** for billing-efficient Autocomplete + Details pairs.
5. Manual QA: search in India with location on/off; search outside India; `forceGlobalSearch` still biases to GPS but skips India-only filter.

### Manual QA matrix (location search)

| Scenario | Location permission | Expected |
|----------|---------------------|----------|
| Mumbai, typing “MG Road” | On | India-restricted suggestions, locally relevant |
| Dubai | On | No `IN` filter; results biased to GPS |
| India, permission denied | Off | No crash; worldwide search; map centered on default until pin/search |
| Create trip picker | On | “Use current location” row; GPS resolved before map opens |
| Release APK | Same flows | No crash; Places search works (verify ProGuard rules applied) |
| Fast back | Open picker → back within 1s | No crash |

---

## Live trip tracking (driver path on map)

Trip detail **Live Tracking** shows two map layers:

| Layer | Style | Data source |
|-------|--------|-------------|
| **Planned route** | Black dashed line | Google Directions API (pickup → drop) |
| **Driver path** | Solid grey line | GPS breadcrumbs from `GET /api/trips/:id/location-trail` + live socket updates |

### Directions API key (planned route only)

The map widget uses the native Maps SDK key from the platform manifest. The **planned route** polyline additionally calls the Directions REST API via [`TripRouteService`](lib/services/trip_route_service.dart).

```bash
flutter run --dart-define=GOOGLE_MAPS_DIRECTIONS_KEY=your_directions_key
```

In [Google Cloud Console](https://console.cloud.google.com/), enable **Directions API** on that key. Without it, the planned route falls back to a straight pickup→drop segment. The **driver path** still works from stored GPS history and live updates.

Release example (sandbox off by default — do not pass `TRACKING_SANDBOX`):

```bash
flutter build apk \
  --dart-define=GOOGLE_MAPS_API_KEY=... \
  --dart-define=GOOGLE_MAPS_DIRECTIONS_KEY=... \
  --dart-define=GOOGLE_MAPS_ROADS_KEY=... \
  --dart-define=GOOGLE_MAPS_DISTANCE_MATRIX_KEY=...
```

---

## Live tracking dev sandbox

For QA without logging in, opt in with:

```bash
flutter run \
  --dart-define=TRACKING_SANDBOX=true \
  --dart-define=GOOGLE_MAPS_DIRECTIONS_KEY=... \
  --dart-define=GOOGLE_MAPS_ROADS_KEY=... \
  --dart-define=GOOGLE_MAPS_DISTANCE_MATRIX_KEY=...
```

The app opens at `/` → [`LiveTrackingSandboxScreen`](lib/screens/dev/live_tracking_sandbox_screen.dart):

| Tab | Purpose |
|-----|---------|
| **Simulate** | Moves a virtual driver along the Directions route; debug HUD shows route/trail counts and API status |
| **Live** | Paste JWT + trip ID → socket `join:trip` + `driver:location:updated` + REST location trail |

**Default:** `TRACKING_SANDBOX` is **off** — app starts at `/splash` with normal login. For local map QA only, pass `--dart-define=TRACKING_SANDBOX=true` ([`AppFlags.trackingSandbox`](lib/core/config/app_flags.dart)).

---

## Getting Started

This project is a Flutter application. See [online documentation](https://docs.flutter.dev/) for tooling and workflows.
