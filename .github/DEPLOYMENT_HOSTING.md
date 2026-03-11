# Firebase Hosting deployment (GitHub Actions)

**Push to `main` → latest code is built and deployed to Firebase Hosting automatically.** No extra step needed after `git push origin main`.

The **Deploy Firebase Hosting** workflow (`.github/workflows/deploy-hosting.yml`) builds the Flutter web app and deploys it to Firebase Hosting on **every push to `main`**.

## When it runs

- **Push to `main`**: Runs on every push (no path filter), so all Hosting domains stay in sync with the latest release.
- **Manual run**: Actions → Deploy Firebase Hosting → Run workflow.

**Important:** Firebase Hosting has a single site and a single release. All domains (default `.web.app`, `.firebaseapp.com`, and custom e.g. `waypoint.tours`) serve that same release. There is no separate “update domain” step in code—one deploy updates all URLs. If a URL showed old content, the Hosting workflow likely did not run for that push (e.g. before we removed the path filter, only pushes that changed `lib/`, `web/`, etc. triggered a deploy). After a deploy, if you still see old content, try a hard refresh or incognito to rule out browser/PWA cache.

## Required secrets

Uses the same secrets as the Cloud Functions workflow:


| Secret                     | Description                                                                             |
| -------------------------- | --------------------------------------------------------------------------------------- |
| `FIREBASE_PROJECT_ID`      | Your Firebase project ID (e.g. `lo72dwmjbzy4xz7nodczq859vs6xkf`)                        |
| `FIREBASE_SERVICE_ACCOUNT` | JSON key of a service account with permission to deploy Hosting (same as for Functions) |


No extra secrets are needed. The service account used for Functions deploy can deploy Hosting if it has the **Firebase Hosting Admin** (or **Editor**) role.

If deploy fails with **HTTP 404, Requested entity was not found** on “finalizing version”, the Hosting API is being called without a valid project or site:

1. **Check GitHub secrets**: Repo → Settings → Secrets and variables → Actions. Ensure **FIREBASE_PROJECT_ID** is set to your Firebase project ID (e.g. the value from `.firebaserc` locally). If it’s missing or wrong, the CLI can end up using `projects/-` and the finalize step returns 404.
2. **Check project and site**: In [Firebase Console](https://console.firebase.google.com/), open your project and go to Hosting. Confirm the default site (or the one you use) exists. If you use a **second Hosting site** (e.g. for a separate domain), add `"site": "your-site-id"` under `hosting` in `firebase.json` so the CLI targets the correct site.

## What it does

1. Checkout repo, set up Flutter (stable), install dependencies.
2. Run `flutter build web` → output in `build/web`.
3. Install Firebase CLI, authenticate with the service account.
4. Run `firebase deploy --only hosting`.

## Live URL

After a successful run, the site is at:

- **https://****.web.app**
- **https://****.firebaseapp.com**

Add a custom domain (e.g. waypoint.tours and [www.waypoint.tours](http://www.waypoint.tours)) in [Firebase Console → Hosting → Add custom domain](https://console.firebase.google.com/).

### Making both apex and www work (e.g. waypoint.tours and [www.waypoint.tours](http://www.waypoint.tours))

If the site loads at `https://waypoint.tours` but not at `https://www.waypoint.tours` (or vice versa):

1. **Firebase Console** → Hosting → **Custom domains**: Add **both** the apex (`waypoint.tours`) and the www subdomain (`www.waypoint.tours`) as separate custom domains. Complete the wizard for each.
2. **DNS (at your registrar, e.g. Namecheap)**:
  - **Apex**: Add the **A** records Firebase shows for the apex (usually two IPs).
  - **www**: Add a **CNAME** record: host = `www`, value = the target Firebase gives (e.g. `<project>.web.app`).
3. Wait for DNS propagation (often 15–60 minutes; Firebase may say up to 24h). SSL is provisioned automatically for each domain.

### waypoint.tours not loading (but .web.app works)

All domains share the same release, so if the default URLs work, the custom domain should too. If **[https://waypoint.tours](https://waypoint.tours)** doesn’t load or shows old content:

1. **Confirm which URL you use** — If you use **[https://www.waypoint.tours](https://www.waypoint.tours)**, add **[www.waypoint.tours](http://www.waypoint.tours)** as a separate custom domain in Firebase (apex and www are different).
2. **Firebase Console** → Hosting → Custom domains: ensure **waypoint.tours** (and **[www.waypoint.tours](http://www.waypoint.tours)** if needed) show **Connected**. If not, complete the wizard and add the A/CNAME records Firebase shows.
3. **DNS at your registrar**: Apex needs the **A** records from Firebase; **www** needs a **CNAME** to your `.web.app` host. Wait for propagation (up to 24h).
4. **Cache**: Try a hard refresh (Ctrl+Shift+R) or an incognito window; CDN/browser cache can show old content.

### ERR_SSL_VERSION_OR_CIPHER_MISMATCH on www.waypoint.tours (or waypoint.tours)

This means the browser cannot agree on TLS with the server. Firebase Hosting manages SSL; you cannot fix it from code. Fix it in DNS and Firebase:

1. **Check where the domain points**
   - Open [Firebase Console → Hosting → Custom domains](https://console.firebase.google.com/project/_/hosting/sites). For **www.waypoint.tours** (and **waypoint.tours** if broken), status should be **Connected**.
   - If a domain is not listed, add it via **Add custom domain** and follow the wizard.

2. **Fix DNS at your registrar**
   - **www.waypoint.tours** must have a **CNAME** record: name `www`, value = the host Firebase shows (e.g. `yourproject.web.app`). It must **not** point to an old server, another CDN, or an IP.
   - **waypoint.tours** (apex) must use the **A** records Firebase gives (two IPs). Do not use a CNAME for the apex unless your registrar supports flattening (ALIAS/ANAME).
   - Remove any old A or CNAME records that point elsewhere. Wait for DNS propagation (15–60 min, sometimes up to 24h).

3. **If you use Cloudflare (or another proxy) in front of Firebase**
   - **DNS**: CNAME `www` → `yourproject.web.app`. In Cloudflare, set the proxy to **Proxied (orange)** only if you use Cloudflare’s SSL; otherwise use **DNS only (grey)** so the browser talks directly to Firebase and uses Firebase’s certificate.
   - **SSL/TLS**: Use **Full (strict)** and **Minimum TLS Version 1.2** (or higher). Avoid “Flexible” (client–Cloudflare only) if you want end-to-end HTTPS to Firebase.
   - If the error persists with proxy enabled, try **DNS only** for `www` temporarily to confirm Firebase’s certificate works when not proxied.

4. **Certificate provisioning**
   - After DNS is correct, Firebase provisions SSL (Let’s Encrypt). This can take **up to 24 hours**. If the domain was just added or DNS was just changed, wait and retry.

5. **Quick check**
   - If **https://&lt;your-project&gt;.web.app** works but **https://www.waypoint.tours** does not, the problem is DNS or custom-domain setup for www, not your app code.

## Local web development

- **"Failed to exit Chromium" / dangling process**: On Windows, Flutter often cannot cleanly kill the Chrome process it started. The message is harmless. Close the browser tab/window yourself, or end any leftover `chrome.exe` in Task Manager if needed.
- **To avoid Flutter launching/killing Chrome**: Run `flutter run -d web-server`, then open the printed URL (e.g. [http://localhost:xxxxx](http://localhost:xxxxx)) in your own browser. When you stop the app, only the server stops; no Chromium process is left for Flutter to kill.

