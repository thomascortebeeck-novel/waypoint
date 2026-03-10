# Firebase Hosting deployment (GitHub Actions)

The **Deploy Firebase Hosting** workflow builds the Flutter web app and deploys it to Firebase Hosting on every push to `main` that touches the app or hosting config.

## When it runs

- **Push to `main`** when any of these change:
  - `lib/**`, `web/**`, `assets/**`
  - `pubspec.yaml`, `pubspec.lock`, `firebase.json`
  - `.github/workflows/deploy-hosting.yml`
- **Manual run**: Actions → Deploy Firebase Hosting → Run workflow

## Required secrets

Uses the same secrets as the Cloud Functions workflow:

| Secret | Description |
|--------|-------------|
| `FIREBASE_PROJECT_ID` | Your Firebase project ID (e.g. `lo72dwmjbzy4xz7nodczq859vs6xkf`) |
| `FIREBASE_SERVICE_ACCOUNT` | JSON key of a service account with permission to deploy Hosting (same as for Functions) |

No extra secrets are needed. The service account used for Functions deploy can deploy Hosting if it has the **Firebase Hosting Admin** (or **Editor**) role.

## What it does

1. Checkout repo, set up Flutter (stable), install dependencies.
2. Run `flutter build web` → output in `build/web`.
3. Install Firebase CLI, authenticate with the service account.
4. Run `firebase deploy --only hosting`.

## Live URL

After a successful run, the site is at:

- **https://&lt;FIREBASE_PROJECT_ID&gt;.web.app**
- **https://&lt;FIREBASE_PROJECT_ID&gt;.firebaseapp.com**

Add a custom domain (e.g. www.waypoint.tours) in [Firebase Console → Hosting → Add custom domain](https://console.firebase.google.com/).

## Local web development

- **"Failed to exit Chromium" / dangling process**: On Windows, Flutter often cannot cleanly kill the Chrome process it started. The message is harmless. Close the browser tab/window yourself, or end any leftover `chrome.exe` in Task Manager if needed.
- **To avoid Flutter launching/killing Chrome**: Run `flutter run -d web-server`, then open the printed URL (e.g. http://localhost:xxxxx) in your own browser. When you stop the app, only the server stops; no Chromium process is left for Flutter to kill.
