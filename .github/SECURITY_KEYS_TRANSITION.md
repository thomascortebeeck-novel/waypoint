# Securing API keys — transition checklist

This doc lists everything to do so that **no API keys remain in the repo or in build artifacts** when using CI. You use **one Google API key for multiple APIs** (e.g. Maps + Places); after rotation you will have **one new key** to set in one place (e.g. `GOOGLE_MAPS_API_KEY`).

---

## 1. Rotate keys (Google Cloud / Firebase / Mapbox)

Do this first so any key that ever appeared in history is invalidated.


| Key / product                            | Where to rotate                                                                        | Notes                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ---------------------------------------- | -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Google Maps (and shared Google APIs)** | [Google Cloud Console](https://console.cloud.google.com/google/maps-apis/credentials)  | Create a **new** API key. Restrict it by: Android package `com.thomascortebeeck.waypoint`, iOS bundle ID `com.thomascortebeeck.waypoint`, and HTTP referrers for your web domain. Enable only the APIs you need (Maps SDK Android/iOS/JavaScript, Places, etc.). You will use this **single key** for Android, iOS, and Web in the app and in CI.                                                                           |
| **Firebase (Web / Android / iOS)**       | [Firebase Console](https://console.firebase.google.com) → Project settings → Your apps | Firebase generates platform-specific API keys. To rotate: you can create new Web/Android/iOS apps or use Google Cloud Console to restrict/regenerate keys linked to the same project. Easiest: run `flutterfire configure` again (optionally after creating new keys in Cloud Console) and use the newly generated `lib/firebase_options.dart` only as the source for the `FIREBASE_OPTIONS_DART` secret (never commit it). |
| **Mapbox** (if you rotate)               | [Mapbox Account](https://account.mapbox.com/) → Access tokens                          | Create a new public token; restrict by URL / bundle ID if desired. Update the secret `MAPBOX_PUBLIC_TOKEN` (or keep using the one in code if you accept it as public).                                                                                                                                                                                                                                                      |


---

## 2. GitHub (or GitLab) secrets / variables

Set these in **Settings → Secrets and variables → Actions** (GitHub) or **Settings → CI/CD → Variables** (GitLab). Use the **new** keys from step 1.


| Secret / variable           | Used by                                  | What to put                                                                                                                                                             |
| --------------------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GOOGLE_MAPS_API_KEY`       | Android build, iOS build, **Web deploy** | The **single** new Google API key (Maps + any other Google APIs you use in the app).                                                                                    |
| `GOOGLE_SERVICES_JSON`      | Android build                            | Full contents of `google-services.json` (Firebase Console → Project settings → Your apps → Android).                                                                    |
| `GOOGLE_SERVICE_INFO_PLIST` | iOS build                                | Full contents of `GoogleService-Info.plist` (Firebase Console → iOS app).                                                                                               |
| `FIREBASE_OPTIONS_DART`     | Android build, iOS build, **Web deploy** | Full contents of `lib/firebase_options.dart`. Get them by running `flutterfire configure` locally, then copy the file content (do not commit that file with real keys). |
| `MAPBOX_PUBLIC_TOKEN`       | Optional                                 | Mapbox public token if you want it injected via CI instead of a default in code.                                                                                        |


---

## 3. Code and config (what was changed in the repo)

- **Android:** `android/app/src/main/AndroidManifest.xml` — Google Maps key replaced with placeholder `YOUR_GOOGLE_MAPS_API_KEY`; CI substitutes from `GOOGLE_MAPS_API_KEY`.
- **iOS:** `ios/Runner/AppDelegate.swift` — Same placeholder; CI substitutes from `GOOGLE_MAPS_API_KEY`.
- **Web:** `web/index.html` — Maps script key replaced with placeholder `YOUR_GOOGLE_MAPS_API_KEY`; deploy workflow substitutes into `build/web/index.html` after build from `GOOGLE_MAPS_API_KEY`.
- **Firebase:** `lib/firebase_options.dart` — Replaced with a placeholder version (no real keys). CI overwrites this file from secret `FIREBASE_OPTIONS_DART` before building.
- **Mapbox:** `lib/integrations/mapbox_config.dart` — Default token can be removed or kept; CI can pass `MAPBOX_PUBLIC_TOKEN` via `--dart-define` if you use a secret.

---

## 4. GitHub Actions workflows (what to do in CI)


| Workflow                                                    | What it does now                                                                                                                                                                                                             |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Build Android** (`.github/workflows/build-android.yml`)   | Requires `GOOGLE_SERVICES_JSON`; writes `android/app/google-services.json`. Substitutes `GOOGLE_MAPS_API_KEY` into AndroidManifest. **Added:** Writes `lib/firebase_options.dart` from `FIREBASE_OPTIONS_DART` before build. |
| **Build iOS** (`.github/workflows/build-ios.yml`)           | Optional `GOOGLE_SERVICE_INFO_PLIST` → writes plist. Substitutes `GOOGLE_MAPS_API_KEY` in AppDelegate. **Added:** Writes `lib/firebase_options.dart` from `FIREBASE_OPTIONS_DART`; requires it for build.                    |
| **Deploy Hosting** (`.github/workflows/deploy-hosting.yml`) | **Added:** Writes `lib/firebase_options.dart` from `FIREBASE_OPTIONS_DART`. After `flutter build web`, substitutes `GOOGLE_MAPS_API_KEY` into `build/web/index.html`.                                                        |


For **GitLab**: same idea — in the job that runs `flutter build apk` / `flutter build ios` / `flutter build web`, write the JSON/plist/dart from CI variables and substitute the Maps key where needed.

---

## 5. Local development

- **Google Maps (Android/iOS):** Either keep a local placeholder and run with Maps disabled, or create a `local.properties` / Xcode config with your key (do not commit).
- **Firebase:** Run `flutterfire configure` locally; it generates `lib/firebase_options.dart` and (for Android) can update `google-services.json`. Ensure `lib/firebase_options.dart` is listed in `.gitignore` so you don’t commit the generated file, **or** use the repo’s placeholder version and override with a local script that writes from an env var.
- **Web:** For `flutter run -d chrome`, the built `index.html` uses the placeholder unless you substitute locally (e.g. a script that replaces `YOUR_GOOGLE_MAPS_API_KEY` in `web/index.html` before running).

If you **do** add `lib/firebase_options.dart` to `.gitignore`, then every developer (and CI) must get this file from somewhere (CI from secret, locally from `flutterfire configure`). The repo then keeps a **template** `lib/firebase_options.dart.example` (no real keys) for reference.

---

## 6. Order of operations (recommended)

1. **Rotate** the Google API key (and Firebase/Mapbox if desired) as in section 1.
2. **Add/update** all secrets in GitHub (and GitLab if used) as in section 2.
3. **Merge** the code and workflow changes that use placeholders and inject from secrets (sections 3 and 4).
4. **Run** the Android and iOS workflows and the deploy-hosting workflow; fix any missing secret or path.
5. **Verify** the app on Android, iOS, and web (maps and Firebase work with the new keys).
6. Optionally **revoke** old keys in Google Cloud / Firebase / Mapbox so they no longer work.

---

## 7. One key for multiple APIs

Because you use **one** Google API key for multiple APIs (e.g. Maps + Places):

- Create **one** new key in Google Cloud Console and restrict it by app (Android package, iOS bundle ID, HTTP referrers).
- Enable the needed APIs for that key (Maps SDK for Android, Maps SDK for iOS, Maps JavaScript API, Places API, etc.).
- Set that single value in **one** secret: `GOOGLE_MAPS_API_KEY`. All workflows (Android, iOS, Web) use this same secret for the Maps key. No need for separate “Places” vs “Maps” secrets unless you later split keys on purpose.

