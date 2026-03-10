# iOS and Android testing + CI/CD — Revised plan

This document is the **revised** deployment plan for iOS/Android local testing and GitHub Actions CI. It incorporates fixes for critical blockers and quality improvements identified in review, and is aligned with the **actual architecture** of the Waypoint codebase (see below).

---

## Architecture summary (from codebase review)

### Map rendering

- **Primary engine: Google Maps** for all map screens. `MapConfiguration` uses `MapEngineType.googleMaps` for route builder, main map, tracking, and trip day maps. `AdaptiveMapWidget` builds `GoogleMapWidget` (mobile and web) by default.
- **Mapbox Native and Mapbox WebGL are deprecated:** In `adaptive_map_widget.dart`, `mapboxNative` and `mapboxWebGL` explicitly fall back to Google Maps with a deprecation log. Mapbox is **not** used for map rendering in the default configuration.
- **flutter_map** is used for: (1) preview cards (`MapConfiguration.preview()`), (2) fallback when Google Maps fails, (3) Route Builder when `useLegacyEditor` is true or `useMapboxEverywhere` is false (default). Raster tiles can come from Mapbox Static Tiles API or other URLs.

### Where Mapbox is still used (non-rendering)

- **MapboxService** ([lib/integrations/mapbox_service.dart](lib/integrations/mapbox_service.dart)): Geocoding (search) and directions API (HTTP calls to `api.mapbox.com`). Used by map search and route builder.
- **Route Builder** optional path: When `useMapboxEverywhere` is true (feature flag, default **false**), the editor can use Mapbox; otherwise it uses Google Maps or flutter_map.
- **flutter_map raster URL:** `defaultRasterTileUrl` in [lib/integrations/mapbox_config.dart](lib/integrations/mapbox_config.dart) uses the Mapbox Static Tiles API for tile URLs. Token comes from `mapboxPublicToken` (see below).

The **Mapbox public token** is set via `String.fromEnvironment('MAPBOX_PUBLIC_TOKEN', defaultValue: '...')` in `mapbox_config.dart` with a **committed default**. So **CI does not require a Mapbox secret** for build or for default runtime (geocoding/directions use the default token). If the default is ever removed or restricted, then a secret would be needed.

### Google Maps API key (required for map display on mobile)

- **Web:** Key is set in [web/index.html](web/index.html) (committed).
- **Android:** The app uses `google_maps_flutter`. The **Google Maps API key is not currently in** [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml). Maps SDK for Android expects `com.google.android.geo.API_KEY` meta-data. Without it, the map may not display on device or in CI-built APKs. **This must be added** (in manifest or via Secrets Gradle Plugin / CI-injected manifest) for Android maps to work.
- **iOS:** The app uses `google_maps_flutter`. There is no `GMSServices.provideAPIKey(...)` in [ios/Runner/AppDelegate.swift](ios/Runner/AppDelegate.swift) and no key in Info.plist. Maps SDK for iOS requires the key at runtime. **This must be added** (AppDelegate or plist, or CI-injected) for iOS maps to work.

So for “map works on device,” the **real** requirements are **Google Maps API keys for Android and iOS**, not Mapbox.

### Firebase

- **Initialization:** [lib/main.dart](lib/main.dart) calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` using [lib/firebase_options.dart](lib/firebase_options.dart), which is **committed** and contains web, Android, and iOS options. No CI secret needed for Firebase options.
- **Android:** [android/app/google-services.json](android/app/google-services.json) exists in the repo (not gitignored in the current setup). If it were ever removed or gitignored, CI would need to inject it from a secret.
- **iOS:** No `GoogleService-Info.plist` in the repo. FlutterFire can work with only `firebase_options.dart` for iOS; the plist is optional unless a plugin or build step requires it. If the iOS build fails due to missing plist, add a secret and inject it in CI.

### Stripe

- [lib/services/stripe_config_service.dart](lib/services/stripe_config_service.dart) reads publishable key from `String.fromEnvironment('STRIPE_PK_TEST'|'STRIPE_PK'|'STRIPE_PK_LIVE', defaultValue: '')`. Defaults are empty; `init()` returns without setting a key if empty. **No Stripe secret is required for CI**; the app runs without Stripe until keys are provided (e.g. for production builds).

### Other

- **Cloud Functions** (e.g. getDirections, matchRoute) use server-side Mapbox/Google; the client only needs Firebase and, for map display, Google Maps API key. No additional client build-time secrets for those.

---

## Critical blockers (must fix before workflows)

These will cause **immediate CI failures** if not addressed.

### 1. `google-services.json` in Android CI

- **Problem:** Android build in CI will fail if `google-services.json` is gitignored or missing from the repo.
- **Solution:** Treat `android/app/google-services.json` as **injectable in CI**:
  - Add a GitHub secret **`GOOGLE_SERVICES_JSON`** containing the full JSON content of `google-services.json`.
  - In the Android workflow, **before** `flutter build apk` / `flutter build appbundle`, add a step that writes the secret to the file, e.g.:
    ```yaml
    - name: Create google-services.json
      run: echo '${{ secrets.GOOGLE_SERVICES_JSON }}' > android/app/google-services.json
    ```
  - If the JSON is multiline, use a single-line encoding (e.g. base64) and decode in the step, or use GitHub’s multiline secret handling (write to file from secret).
- **Alternative:** Commit `google-services.json` (it’s not highly sensitive; many Flutter repos do). Then no CI secret is needed. Document the **conscious decision** either way in DEPLOYMENT_IOS_ANDROID.md.

### 2. Mapbox token in CI — not a blocker

- **Reality:** Mapbox is **not** used for map rendering (Google Maps is). Mapbox is only used for **MapboxService** (geocoding, directions HTTP API) and optional/legacy paths. The token has a **committed default** in [lib/integrations/mapbox_config.dart](lib/integrations/mapbox_config.dart), so CI builds and default runtime do **not** require a Mapbox secret. **No action needed for CI** unless the default is removed; then document and optionally add `MAPBOX_PUBLIC_TOKEN` secret and `--dart-define` in workflows.

### 3. Google Maps API key for Android and iOS

- **Problem:** The map engine is **Google Maps**. Android has no `com.google.android.geo.API_KEY` in AndroidManifest; iOS has no API key in AppDelegate or Info.plist. Without the key, the map will not display on device (and may fail at runtime). For CI-built APKs/IPAs that you install and test, the key is required for the map to work.
- **Solution:**
  - **Android:** Add `<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_KEY" />` inside `<application>` in AndroidManifest, or use Secrets Gradle Plugin / `local.properties` and inject in CI from secret `GOOGLE_MAPS_API_KEY` (or similar).
  - **iOS:** Call `GMSServices.provideAPIKey("...")` in AppDelegate before `GeneratedPluginRegistrant.register`, or add key to Info.plist; for CI, inject from secret if the key is not committed.
  - **Document** in DEPLOYMENT_IOS_ANDROID.md where the key is set and that it must be restricted (e.g. by package name / bundle ID) in Google Cloud Console.

### 4. Conditional logic for Android release builds

- **Problem:** The plan said “if secrets are present” for release but did not specify *how* to conditionally run in GitHub Actions.
- **Solution:** Use one of:
  - **Option A — Conditional step:** Use `if: env.ANDROID_KEYSTORE_BASE64 != ''` (set env from secret in a prior step). If the secret is missing, the env may be empty; the step that creates `key.properties` and runs `flutter build appbundle` only runs when the env is non-empty.
  - **Option B — Separate job:** A job “build-android-release” that has `if: secrets.ANDROID_KEYSTORE_BASE64 != ''` (note: GitHub does not allow direct `secrets.*` in `if` for security; use a previous step that sets an output or env from the secret and then `if: steps.one.outputs.has_keystore == 'true'`).
  - **Recommended:** A step that checks for the keystore secret and sets an output, e.g. `has_keystore`. Then a subsequent step or job runs release build only when `has_keystore` is true. Document the exact pattern in the workflow and in DEPLOYMENT_IOS_ANDROID.md.
  - **Example pattern:** Use a step that writes the secret to a file (e.g. decode base64 to keystore); set a job output like `has_keystore` to `success()` only if the step ran and the file exists. Run the release build step/job only when that output is set. (Note: GitHub redacts missing secrets, so you cannot safely test “secret non-empty” in an expression; prefer “run a step that uses the secret; if the secret is missing the step fails” and use `if: success()` for the next step, or use a separate workflow_dispatch-only “release” workflow that requires the secret to be set.)

---

## Other important fixes and clarifications

### Android

- **`firebase_options.dart`:** It is **committed** and contains API keys. Document this as a conscious choice (no CI secret needed for Firebase options). If the project later moves to gitignored or env-only config, add a CI step to generate or inject it.
- **`applicationId` casing:** `com.mycompany.CounterApp` uses a capital letter. Valid but unusual for Android; some Play Store tooling can be sensitive. **Flag in docs** as something to consider changing to e.g. `com.mycompany.waypoint` or `com.mycompany.counterapp` in a future cleanup; not a prerequisite for first CI.

### iOS

- **macOS runner cost:** `macos-latest` is ~10× more expensive than Ubuntu. For solo/small teams, **recommend** running the iOS workflow only on **`workflow_dispatch`** (manual trigger) instead of on every push to `main`. Document this in DEPLOYMENT_IOS_ANDROID.md and set the workflow `on:` accordingly (e.g. only `workflow_dispatch` and optionally `pull_request` for PRs targeting `main` if desired).
- **CocoaPods / Flutter version:** Pin **Flutter version** in `subosito/flutter-action` (e.g. `flutter-version: '3.24.x'` or a specific stable) instead of relying on floating `stable` to avoid sudden breakages when the runner image or Flutter changes. Mention that **`pod install`** in `ios/` is often **required** before `flutter build ios` (Flutter may run it, but making it explicit reduces flakiness). Optionally pin CocoaPods version in the workflow if needed.
- **GoogleService-Info.plist in iOS CI:** If any Firebase plugin or the build expects `GoogleService-Info.plist` in `ios/Runner/`, CI will fail without it. **Add:** A secret (e.g. `GOOGLE_SERVICE_INFO_PLIST`) and a step that writes its content to `ios/Runner/GoogleService-Info.plist` before building. If the project is FlutterFire-only and does not require the plist for build, document that so future changes don’t assume it’s optional without verification.

### Documentation

- **Stripe:** Stripe keys are optional at build time (defaults are empty; app runs without payment until keys are provided). No CI secret required. Document in DEPLOYMENT_IOS_ANDROID.md how to pass `STRIPE_PK_TEST` / `STRIPE_PK_LIVE` for production builds if desired.

---

## Additions that were missing from the original plan

### Tests in CI

- Add a **`flutter test`** step in at least one workflow (e.g. Android workflow on Ubuntu, or a dedicated “test” job). Run it **before** the build step so failing tests fail the workflow. Optionally run on both `push` and `pull_request` to `main` (and feature branches if desired).

### Build caching

- **Pub cache:** Use `actions/cache` (or the cache option in `subosito/flutter-action`) to cache `~/.pub-cache` with key including `pubspec.lock` (or Flutter version + lockfile hash).
- **Gradle:** Cache Gradle caches (e.g. `~/.gradle/caches`, `~/.gradle/wrapper`) in the Android workflow to speed up subsequent runs. Key can include `**/gradle-wrapper.properties` and/or `pubspec.lock`.

### Artifact retention

- For debug APKs (and any other build artifacts) uploaded with `actions/upload-artifact`, set **`retention-days`** (e.g. 7 or 14) to avoid unbounded storage growth.

### Branch / PR strategy

- **Clarify in plan and docs:** CI is most valuable on **pull requests** (e.g. run tests and Android build on every PR to `main`; run iOS build on `workflow_dispatch` or on PR to `main` if budget allows). Document in DEPLOYMENT_IOS_ANDROID.md:
  - Which workflows run on **push to main** vs **pull_request** vs **workflow_dispatch**.
  - Recommendation: tests + Android (Ubuntu) on push and PR; iOS (macOS) on manual or selected branches to control cost.

---

## Implementation order (revised)

1. **Fix Android MainActivity path:** Move `MainActivity.kt` to `com/mycompany/CounterApp/` and remove the old `com/example/counter/` directory.
2. **Google Maps API key for mobile:** Add key to Android (AndroidManifest or Secrets Gradle / CI secret) and iOS (AppDelegate or Info.plist / CI secret). Document in DEPLOYMENT_IOS_ANDROID.md and restrict keys in Google Cloud Console.
3. **Decide and implement Firebase config in CI:**
   - If `google-services.json` is not committed: add `GOOGLE_SERVICES_JSON` secret and write file in Android workflow.
   - If iOS build fails without `GoogleService-Info.plist`: add `GOOGLE_SERVICE_INFO_PLIST` secret and write to `ios/Runner/` in iOS workflow.
4. **iOS Podfile:** Set `platform :ios, '12.0'` (or appropriate minimum).
5. **Config template:** Add `android/key.properties.example` and document in DEPLOYMENT_IOS_ANDROID.md.
6. **Documentation:** Add or update `.github/DEPLOYMENT_IOS_ANDROID.md` with:
   - Architecture summary (Google Maps primary; Mapbox only for APIs; Firebase/Stripe as above).
   - Prerequisites, local iOS/Android steps, and **secrets table** (GOOGLE_SERVICES_JSON, GOOGLE_MAPS_API_KEY or platform-specific, ANDROID_KEYSTORE_*, optional Apple cert/profile; **not** MAPBOX_PUBLIC_TOKEN unless default is removed).
   - Branch/trigger strategy (push vs PR vs workflow_dispatch), macOS cost note, and conditional release build pattern.
7. **Workflows with conditional release and caching:**
   - **build-android.yml:** Run `flutter test`; cache pub + Gradle; create `google-services.json` from secret (if not committed); build debug APK and upload with `retention-days`; **conditionally** build release (using the agreed pattern for “if keystore secret present”) and upload AAB.
   - **build-ios.yml:** Trigger on `workflow_dispatch` (and optionally PR); pin Flutter version; run `pod install` in `ios/`; optionally write `GoogleService-Info.plist` from secret if needed; run `flutter build ios --no-codesign`; document optional signed IPA job for later.
8. **Optional:** `ios/ExportOptions.plist`, align iOS display name to “Waypoint,” and add a dedicated “test” workflow that only runs `flutter test` on PR/push.

---

## Summary table: CI secrets and when they’re needed

| Secret / config | Used in | When required |
|----------------|--------|----------------|
| `GOOGLE_SERVICES_JSON` | Android workflow | If `google-services.json` is not committed |
| `GOOGLE_SERVICE_INFO_PLIST` | iOS workflow | If iOS build expects `GoogleService-Info.plist` |
| Google Maps API key | Android manifest / iOS AppDelegate or plist | **Required for map to display on device.** Add in repo or inject from secret (e.g. `GOOGLE_MAPS_API_KEY`) in CI. |
| `ANDROID_KEYSTORE_BASE64`, `*_PASSWORD`, `*_ALIAS` | Android release job/step | Only for release AAB/APK; use conditional run |
| Apple cert + profile + keychain password | iOS signed IPA job | Only if adding signed IPA/TestFlight later |
| `MAPBOX_PUBLIC_TOKEN` | Optional | Only if the committed default in `mapbox_config.dart` is removed |
| Stripe keys | Optional | Only for production builds that need payment; not required for CI |

This revised plan is aligned with the architecture (Google Maps for map rendering; Mapbox only for APIs with committed default). Implement the blockers (google-services.json decision, Google Maps API key on mobile, conditional release logic) before wiring up the workflows.
