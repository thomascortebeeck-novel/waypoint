---
name: ""
overview: ""
todos: []
isProject: false
---

# Web-only checkout and admin Stripe mode toggle (REVISED)

Revisions incorporate: Stripe key init timing and restart requirement; backend defensive checks for missing secrets; async launchUrl in GoRouter; config cold-read mitigation; join-flow UX gap; url_launcher dependency; adventure_detail_screen framing.

---

## 1. Platform-specific purchase flow (web vs app)

**Goal:** Only the web app shows checkout and handles purchases. On iOS/Android, "Buy" opens the plan on the web app in the external browser; no checkout routes or screens in the app.

**Detection:** Use `kIsWeb` from `package:flutter/foundation.dart`. Web = full checkout in-app. Non-web (iOS/Android) = open web URL for purchase.

**Web app base URL:** Reuse the same pattern as [lib/presentation/widgets/share_bottom_sheet.dart](lib/presentation/widgets/share_bottom_sheet.dart): on web use `Uri.base`; on mobile use `'https://waypoint.app'`. Extract a single shared helper (e.g. [lib/utils/app_urls.dart](lib/utils/app_urls.dart)) so all "open web" links use one place: `getWebAppBaseUrl()` and `getPlanDetailsWebUrl(planId)` / `getCheckoutWebUrl(planId)`.

**Dependency:** [pubspec.yaml](pubspec.yaml) already includes `url_launcher: ^6.2.0`. Use `launchUrl(uri, mode: LaunchMode.externalApplication)` for opening the web app from iOS/Android. No new dependency.

**Where "Buy" is triggered:**


| Location                                                                                                           | Current behavior                                                                                                                                                                                                                   | Change                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [lib/presentation/details/plan_details_screen.dart](lib/presentation/details/plan_details_screen.dart)             | `context.push('/checkout/$planId', ...)`                                                                                                                                                                                           | If `!kIsWeb`: open `getPlanDetailsWebUrl(planId)` (or checkout URL) with `launchUrl(..., mode: LaunchMode.externalApplication)` and return. Else keep current push.                                         |
| [lib/presentation/trips/join_trip_screen.dart](lib/presentation/trips/join_trip_screen.dart)                       | `context.push('/checkout/${trip.planId}', ...)`                                                                                                                                                                                    | If `!kIsWeb`: open web URL. **Important:** Pass invite context (see Section 4 / join-flow gap below) so user does not lose join context after purchasing on web. Else keep current push.                    |
| [lib/presentation/adventure/adventure_detail_screen.dart](lib/presentation/adventure/adventure_detail_screen.dart) | Two places: (1) mobile bar "Buy" button (line ~1418) and (2) sidebar `BuyPlanCard` `onBuyTap` (line ~4473). **Both currently show "Buy plan functionality coming soon"** — so this is **new logic**, not only a behavioral switch. | Implement full buy path: if `kIsWeb`, `onBuyTap` = `context.push('/checkout/$planId', extra: {...})`. If `!kIsWeb`, `onBuyTap` = open web URL for this plan. Wire both the mobile bar and the sidebar card. |


**Checkout route on app (deep link):** When the app is running on non-web and the user hits `/checkout/:planId` (e.g. via deep link), the route’s `builder` runs synchronously but `launchUrl` is async. **Spell this out:** do not await `launchUrl` inside the builder. Trigger the launch as a side effect (e.g. `WidgetsBinding.instance.addPostFrameCallback((_) { launchUrl(...); })`) and immediately navigate away so the user is not left on a checkout screen in the app — e.g. `context.go('/')` or `context.go('/details/$planId')`. So in [lib/nav.dart](lib/nav.dart), for the `/checkout/:planId` route: when `!kIsWeb`, in the builder schedule `launchUrl(getCheckoutWebUrl(planId), ...)` in a post-frame callback and return a redirect to `/` (or a "Opening browser…" stub that pops immediately). This avoids blocking the navigator on async work and keeps a single "link to web" pattern.

**Plans after purchase:** No change. Purchased plans and access are already synced via Firestore.

---

## 2. Admin Stripe test/live toggle (profile/settings)

**Goal:** Admins can choose whether the app (and backend) use Stripe test or production from the profile/settings page.

**Firestore:** Add a document that only admins can write, e.g. `config/stripe` with field `useLiveKeys: boolean` (default `false`). Rules: only users with `is_admin == true` can write; authenticated users can read (or public read if acceptable).

**Backend (Cloud Functions):**

- **Secrets:** Both test and live secrets must exist in Secret Manager when admin toggle is used: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` (test), `STRIPE_SECRET_KEY_LIVE`, `STRIPE_WEBHOOK_SECRET_LIVE`. **Defensive check:** In every callable that uses the live secret (createPaymentIntent, createConnectAccountLink, etc.), when `useLiveKeys === true` and the live secret is missing or empty, throw a clear HttpsError (e.g. "Stripe live keys not configured. Set STRIPE_SECRET_KEY_LIVE in Secret Manager.") instead of allowing a cryptic undefined/null crash. Same idea in stripeWebhook when handling a livemode event and the live webhook secret is missing.
- **createPaymentIntent (and other callables):** Read `config/stripe.useLiveKeys` from Firestore. Use the corresponding Stripe secret; if useLive and live secret not available, throw the clear error above.
- **stripeWebhook:** Use `event.livemode` to select which webhook secret to use for verification and which Stripe client to use. If livemode and live secret is missing, log and return 200 (or 500 with clear body) so Stripe does not retry indefinitely; document the fix.

**Flutter app — Stripe publishable key and init timing:**

- **Mutability:** flutter_stripe requires `Stripe.publishableKey` to be set before `Stripe.instance.initPaymentSheet`. Changing the key mid-session can cause in-flight checkouts to mismatch (test key vs live backend or vice versa). **Explicit requirement:** (1) Do **not** change the publishable key after it has been used for payment sheet init in that session. (2) When an admin toggles Stripe mode in profile, either **require an app restart** (e.g. show a dialog "Restart the app for the change to take effect") or **re-init** the app’s Stripe usage in a way that is equivalent to a fresh start (if the SDK allows). Document this in the admin UI: "Takes effect after app restart" or "You may need to restart the app."
- **Block checkout while config is loading:** Until `config/stripe` has been read (and optionally Stripe.publishableKey set), **block or hide the checkout UI** (e.g. disable "Buy" button or show a short "Loading…" so no one can open the Payment Sheet with a stale or wrong key).
- **Config read strategy — avoid cold read on every launch:** Reading Firestore `config/stripe` before showing UI on every app start adds latency for all users, including non-paying. **Prefer:** (1) **Cache last known value** in SharedPreferences (e.g. `stripe_use_live` and optionally `stripe_config_fetched_at`). On startup, use the cached value immediately so UI and Stripe key can be set without waiting. Then fetch `config/stripe` in the background and, if different, update cache and Stripe key (and if key changed, apply the "restart or re-init" rule above). Or (2) **Lazy load:** only fetch `config/stripe` when the user enters a flow that needs Stripe (e.g. plan details with paid price or checkout screen). Then block that screen until config is loaded. Option (1) gives faster startup and consistent behavior; option (2) avoids Firestore read for users who never buy. Choose one and document it in the plan/code.

**Profile UI:** In [lib/presentation/profile/profile_screen.dart](lib/presentation/profile/profile_screen.dart), under the ADMIN section, add a Stripe mode control (e.g. "Payments: Test / Production" switch). Only visible when `user?.isAdmin == true`. On change: write `config/stripe.useLiveKeys` in Firestore (rules: admin-only). Show a short note: "Takes effect after app restart. Use Test for development." so admins know not to expect immediate key switch in the same session.

---

## 3. Join flow from app — UX gap (prominent)

**Issue:** If a user taps "Buy" from [lib/presentation/trips/join_trip_screen.dart](lib/presentation/trips/join_trip_screen.dart) on mobile, they are sent to the web app. **Without passing invite context to web**, after they complete purchase on web they **lose their join context** (invite code, returnToJoin) and may not be guided back into the trip-join flow. That is a real UX gap, not just an optional follow-up.

**Recommendation:** Treat this as part of the initial scope, not deferred. When opening the web URL from join_trip_screen on app, use a URL that includes invite and return intent, e.g. `https://waypoint.app/details/$planId?inviteCode=xxx&returnToJoin=1`. The web app should: (1) read query params; (2) after checkout success, if `returnToJoin` and `inviteCode` are present, redirect the user to the join flow (e.g. `/join/$inviteCode` or a dedicated "You’re invited to join this trip" step). That way the user who started from the app invite does not lose context. Implement the query param passing in the app and the web redirect/join handoff in the initial implementation.

---

## 4. Summary of files to touch

**Platform / URLs:**

- Add [lib/utils/app_urls.dart](lib/utils/app_urls.dart): `getWebAppBaseUrl()`, `getPlanDetailsWebUrl(planId)`, `getCheckoutWebUrl(planId)` using `kIsWeb` and `'https://waypoint.app'`.
- [lib/presentation/details/plan_details_screen.dart](lib/presentation/details/plan_details_screen.dart): If `!kIsWeb` open web URL with `launchUrl` and return; else push to checkout.
- [lib/presentation/trips/join_trip_screen.dart](lib/presentation/trips/join_trip_screen.dart): If `!kIsWeb` open web URL **with invite params** (`?inviteCode=...&returnToJoin=1`); else push to checkout.
- [lib/presentation/adventure/adventure_detail_screen.dart](lib/presentation/adventure/adventure_detail_screen.dart): **Implement buy path** (new logic) for both mobile bar and sidebar: web → push checkout; app → open web URL.
- [lib/nav.dart](lib/nav.dart): For `/checkout/:planId` when `!kIsWeb`, in builder schedule `launchUrl(getCheckoutWebUrl(planId), ...)` in a post-frame callback and redirect (e.g. `context.go('/')`) so the route does not block on async launch.

**Stripe config and backend:**

- Firestore: create `config/stripe` with `useLiveKeys`; rules for admin-only write.
- [functions/src/stripe.ts](functions/src/stripe.ts): Read `useLiveKeys` in callables; use both secret pairs; **defensively check** that when useLive is true the live secret exists, else throw clear error. In webhook use `event.livemode` to pick secret/client; if livemode and live secret missing, handle without cryptic crash.
- Deploy/docs: Ensure both test and live Stripe secrets are set in Secret Manager when using admin toggle.

**Flutter Stripe key and profile:**

- **Config load:** Use cached value (e.g. SharedPreferences) and background refresh, or lazy load when entering checkout; **block checkout UI** until config is loaded and Stripe key is set.
- [lib/main.dart](lib/main.dart): Set `Stripe.publishableKey` from config (or cache) after read; document that admin toggle **requires app restart or re-init** and that key must not change mid-session after payment sheet has been used.
- [lib/presentation/profile/profile_screen.dart](lib/presentation/profile/profile_screen.dart): ADMIN section — add Stripe mode tile; write `config/stripe.useLiveKeys`; note "Takes effect after app restart."
- Build: Pass both `STRIPE_PK_TEST` and `STRIPE_PK_LIVE` via `--dart-define` for the toggle to work.

**Join flow on web:**

- Web app: Read `inviteCode` and `returnToJoin` from URL query on plan/details or checkout; after checkout success, if set, redirect to join flow (e.g. `/join/$inviteCode`).

---

## 5. Dependency

- **url_launcher:** Already in [pubspec.yaml](pubspec.yaml) (`url_launcher: ^6.2.0`). No change needed.

