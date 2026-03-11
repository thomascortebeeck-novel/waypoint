# iOS and Android — Local testing and CI/CD

This doc covers running the Waypoint Flutter app on iOS (Xcode) and Android, and the GitHub Actions workflows that build and test mobile.

## Architecture (relevant to config)

- **Map rendering:** Google Maps is used for all map screens. Mapbox is not used for rendering (only for geocoding/directions API); a default Mapbox token is committed in `lib/integrations/mapbox_config.dart`.
- **Firebase:** Initialization uses `lib/firebase_options.dart` (committed). Android uses `android/app/google-services.json` (committed or inject from CI). iOS can use FlutterFire-only (no plist required) unless a plugin needs `GoogleService-Info.plist`.
- **Stripe:** Publishable keys are optional at build time (empty defaults); no CI secret required.

## Prerequisites

- **Flutter SDK** (stable), **Xcode** (iOS), **Android Studio** or Android SDK (Android), **CocoaPods** (iOS)
- For release builds: **Apple Developer account** (iOS), **Android keystore** (see `android/key.properties.example`)

## Google Maps API key (required for map on device)

The app uses **Google Maps** for the map. You must set an API key per platform:

- **Android:** In `android/app/src/main/AndroidManifest.xml`, replace `YOUR_GOOGLE_MAPS_API_KEY` in the `com.google.android.geo.API_KEY` meta-data with your key. Or use Secrets Gradle Plugin / `local.properties` and inject in CI from secret `GOOGLE_MAPS_API_KEY`.
- **iOS:** In `ios/Runner/AppDelegate.swift`, replace `YOUR_GOOGLE_MAPS_API_KEY` in `GMSServices.provideAPIKey("...")` with your key. For CI, you can inject via a secret and substitute in the workflow.

Restrict the key in [Google Cloud Console](https://console.cloud.google.com/google/maps-apis/credentials) by package name (`com.thomascortebeeck.waypoint` on Android) and iOS bundle ID `com.thomascortebeeck.waypoint`, and enable Maps SDK for Android / Maps SDK for iOS.

## Local: iOS (Xcode)

1. On a Mac, clone the repo and open **`ios/Runner.xcworkspace`** in Xcode (not the `.xcodeproj`).
2. Select the **Runner** target → **Signing & Capabilities** → choose your **Team** (automatic signing).
3. Connect your iPhone, select it as the run destination, and run (or from project root: `flutter run` with device connected).
4. If you need **GoogleService-Info.plist** (e.g. for Crashlytics), add it from Firebase Console (iOS app with bundle ID `com.thomascortebeeck.waypoint`) into `ios/Runner/` and add it to the Runner target in Xcode. See `ios/Runner/README-GoogleService-Info.md`.

## Local: Android

1. Connect a device (USB debugging) or start an emulator.
2. From project root: `flutter run` (or `flutter run -d <device-id>`).
3. For **release** build: copy `android/key.properties.example` to `android/key.properties`, fill in your keystore path and passwords, then run `flutter build apk` or `flutter build appbundle`.

## CI/CD workflows

| Workflow | Trigger | Runner | What it does |
|----------|--------|--------|--------------|
| **Build Android** | Push to `main`, pull requests, `workflow_dispatch` | `ubuntu-latest` | `flutter test`, build debug APK (and optionally release AAB when keystore secret is set), upload artifacts with retention |
| **Build iOS** | `workflow_dispatch` (manual) | `macos-latest` | `flutter build ios --no-codesign` to verify the iOS build. macOS runners are more expensive; running on manual keeps cost down. |

Recommendation: run tests and Android build on every push and PR; run iOS build manually when you need to verify the iOS target.

## CI secrets (when required)

| Secret / config | Used in | When required |
|----------------|--------|----------------|
| **Google Maps API key** | Android manifest / iOS AppDelegate | Required for map to display. Set in repo (replace placeholder) or inject in CI (e.g. `GOOGLE_MAPS_API_KEY`). |
| `GOOGLE_SERVICES_JSON` | Android workflow | Only if you do **not** commit `android/app/google-services.json`. If set, the workflow writes it to `android/app/google-services.json` before the build. |
| `GOOGLE_SERVICE_INFO_PLIST` | iOS workflow | Only if the iOS build fails without `GoogleService-Info.plist`. If set, the workflow writes it to `ios/Runner/GoogleService-Info.plist`. |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Android release step | Only for building a **release** AAB/APK in CI. The release step runs in a separate job that requires these; if they are not set, only the debug build runs. |
| Apple cert + profile + keychain | iOS | Only if you add a signed IPA / TestFlight job later. |
| `MAPBOX_PUBLIC_TOKEN` | Optional | Not needed for CI; a default is committed in `mapbox_config.dart`. |
| Stripe keys | Optional | Only for production builds that need payment; not required for CI. |

## Android release build in CI

Release AAB is built only when keystore secrets are configured. The workflow uses a **separate job** that runs after the debug build; that job decodes `ANDROID_KEYSTORE_BASE64` to a keystore file, creates `key.properties`, and runs `flutter build appbundle`. If you do not set these secrets, the workflow still succeeds and uploads only the debug APK.

## Application ID note

The app uses Android `applicationId` and iOS bundle ID `com.thomascortebeeck.waypoint`. For Firebase, use the same bundle ID when registering the iOS app.

## See also

- [DEPLOYMENT_HOSTING.md](DEPLOYMENT_HOSTING.md) — Web deploy (Firebase Hosting)
- [DEPLOYMENT_IOS_ANDROID_PLAN.md](DEPLOYMENT_IOS_ANDROID_PLAN.md) — Full plan and architecture details
