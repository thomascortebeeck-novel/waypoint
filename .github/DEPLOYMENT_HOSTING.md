# Firebase Hosting deployment (GitHub Actions)

The **Deploy Firebase Hosting** workflow builds the Flutter web app and deploys it to Firebase Hosting on **every push to `main`**.

## When it runs

- **Push to `main`**: Runs on every push (no path filter), so all Hosting domains stay in sync with the latest release.
- **Manual run**: Actions → Deploy Firebase Hosting → Run workflow.

**Important:** Firebase Hosting has a single site and a single release. All domains (default `.web.app`, `.firebaseapp.com`, and custom e.g. `waypoint.tours`) serve that same release. There is no separate “update domain” step in code—one deploy updates all URLs. If a URL showed old content, the Hosting workflow likely did not run for that push (e.g. before we removed the path filter, only pushes that changed `lib/`, `web/`, etc. triggered a deploy). After a deploy, if you still see old content, try a hard refresh or incognito to rule out browser/PWA cache.

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

Add a custom domain (e.g. waypoint.tours and www.waypoint.tours) in [Firebase Console → Hosting → Add custom domain](https://console.firebase.google.com/).

### Making both apex and www work (e.g. waypoint.tours and www.waypoint.tours)

If the site loads at `https://waypoint.tours` but not at `https://www.waypoint.tours` (or vice versa):

1. **Firebase Console** → Hosting → **Custom domains**: Add **both** the apex (`waypoint.tours`) and the www subdomain (`www.waypoint.tours`) as separate custom domains. Complete the wizard for each.
2. **DNS (at your registrar, e.g. Namecheap)**:
   - **Apex**: Add the **A** records Firebase shows for the apex (usually two IPs).
   - **www**: Add a **CNAME** record: host = `www`, value = the target Firebase gives (e.g. `&lt;project&gt;.web.app`).
3. Wait for DNS propagation (often 15–60 minutes; Firebase may say up to 24h). SSL is provisioned automatically for each domain.

## Local web development

- **"Failed to exit Chromium" / dangling process**: On Windows, Flutter often cannot cleanly kill the Chrome process it started. The message is harmless. Close the browser tab/window yourself, or end any leftover `chrome.exe` in Task Manager if needed.
- **To avoid Flutter launching/killing Chrome**: Run `flutter run -d web-server`, then open the printed URL (e.g. http://localhost:xxxxx) in your own browser. When you stop the app, only the server stops; no Chromium process is left for Flutter to kill.
