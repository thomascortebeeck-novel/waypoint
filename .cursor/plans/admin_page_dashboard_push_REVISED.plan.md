---
name: ""
overview: ""
todos: []
isProject: false
---

# Admin page: dashboard and push notification settings (REVISED)

Revised plan incorporating: (1) close security hole by making Migration a 3rd tab and removing standalone unguarded route, (2) handle missing config doc with safe defaults, (3) loading spinner during admin check, (4) optional config cache in Cloud Functions for scale, (5) dashboard error state, (6) edge-case note for mid-execution config save, (7) explicit Firestore rules note for dashboard reads.

---

## Current state

- **Admin flag:** [lib/models/user_model.dart](lib/models/user_model.dart) has `isAdmin` (Firestore `is_admin`).
- **Existing admin route:** [lib/nav.dart](lib/nav.dart) defines `AppRoutes.adminMigration = '/admin/migration'`; [lib/presentation/admin/admin_migration_screen.dart](lib/presentation/admin/admin_migration_screen.dart) is standalone. Link shown only when `user?.isAdmin == true` in profile. **No route guard** — anyone with the URL can open it.
- **Config pattern:** [lib/services/stripe_config_service.dart](lib/services/stripe_config_service.dart) uses Firestore `config/stripe`. Same for notification settings.
- **Push:** [lib/services/fcm_service.dart](lib/services/fcm_service.dart) + [functions/index.js](functions/index.js); no config read today.
- **Firestore rules:** [firestore.rules](firestore.rules) already has: `config/{configId}` read for any signed-in, write for admin only; `plans`/`trips`/`users` allow **admin read** via `isAdmin()`. **No rule changes needed for dashboard reads.** For `config/notifications`, existing `match /config/{configId}` covers it (admin write, any signed-in read unless we tighten to admin-only read).

---

## Locked-in choices

- **Route option A:** Single `/admin` shell with tabs (Dashboard, Push notifications, Migration). No separate `/admin/migration` route — migration UI is the 3rd tab. **Removes unguarded URL.**
- **Guard in-shell:** Async check in admin shell; show **loading spinner** until resolved, then redirect to `/profile` if not admin (no flash of tabs).
- **StreamBuilder for push tab:** Real-time updates when config changes.
- **Migration as 3rd tab:** Inline the existing migration screen content (or a wrapper that embeds it) so one entry point and one guard.

---

## 1. Route and access control

- **Single admin route:** `/admin` only. Remove or deprecate `/admin/migration` as a standalone route; migration lives inside the admin shell as the third tab.
- **Guard (in-shell):**
  - On load, admin shell shows a **full-screen loading spinner** (e.g. `Center(child: CircularProgressIndicator())`).
  - Resolve `UserService().getUserById(FirebaseAuth.instance.currentUser?.uid)`.
  - **Redirect targets (lock in):** If `FirebaseAuth.instance.currentUser` is **null** (e.g. cold start, signed out) → `context.go(AppRoutes.login)`. If authed but **not admin** (`user?.isAdmin != true`) → `context.go(AppRoutes.profile)`. Only after confirming admin: build the tabbed UI. **No brief render of tabs before redirect.**
- **Profile:** Replace "Database Migration" link with a single "Admin" (or "Admin dashboard") tile that goes to `/admin`. Admin shell tabs: Dashboard | Push notifications | Migration.

---

## 2. Admin shell and tabs

- **New file:** e.g. `lib/presentation/admin/admin_screen.dart`.
  - State: `_isCheckingAdmin = true`, `_isAdmin = false`.
  - Build: if `_isCheckingAdmin` → full-screen loading spinner; else if `!_isAdmin` → empty (redirect will have run); else → `Scaffold` + `DefaultTabController` with 3 tabs: **Dashboard**, **Push notifications**, **Migration**.
  - **Migration tab:** Embed the existing migration UI by extracting **body content only** from [lib/presentation/admin/admin_migration_screen.dart](lib/presentation/admin/admin_migration_screen.dart) into a widget (e.g. `AdminMigrationContent`). The extracted widget must be **scaffold-free** — no nested `Scaffold` inside the tab (the admin shell already provides the Scaffold; nesting causes visual artifacts).
- **Nav:** In [lib/nav.dart](lib/nav.dart): add `AppRoutes.admin = '/admin'`; register `/admin` → `AdminScreen`. Change `/admin/migration` to a **redirect** to `**/admin`** only (no query param to open the Migration tab). Flow: user hits `/admin/migration` → GoRouter redirect runs first → lands on `/admin` → in-shell guard runs → tabs show; no query-param handling needed.

---

## 3. Dashboard tab

- **Data:** [lib/services/admin_service.dart](lib/services/admin_service.dart) (or equivalent) with `Future<AdminDashboardStats> getDashboardStats()` using Firestore aggregation count where available (`collection.count().get()`) for `plans`, `trips`, `users`; fallback to `get().docs.length` if needed.
- **Error handling:** If `getDashboardStats()` throws (e.g. rules block, network error), **dashboard tab must show an error state**: message like "Could not load dashboard" and a retry action. Do not leave a blank or spinning state forever.
- **UI:** Cards/list for counts; optional recent activity. Use existing theme.

---

## 4. Push notifications tab and config

- **Firestore doc:** `config/notifications` with fields: `pushEnabled`, `checkInEnabled`, `voteResolvedEnabled` (all boolean).
- **Missing doc:** The document may not exist until an admin saves for the first time.
  - **Flutter:** In [notification_config_service](lib/services/notification_config_service.dart) (or equivalent), when reading `config/notifications`: if the doc does not exist, return a **default config with all flags `true`** (pushEnabled, checkInEnabled, voteResolvedEnabled). Same for `StreamBuilder` — treat missing snapshot as “doc doesn’t exist” → default all true.
  - **StreamBuilder (push tab):** See section 7 — check `exists` and default when doc missing.
  - **Cloud Functions:** At the start of each trigger, `await db.doc('config/notifications').get()`. If the doc **does not exist**, treat as “all enabled” (e.g. `pushEnabled = true`, `checkInEnabled = true`, `voteResolvedEnabled = true`) and proceed. If it exists, read the flags and return early when disabled.
- **Optional scale optimization:** To avoid a Firestore read on every trigger invocation, cache the config in a **module-level variable** (e.g. `let cachedConfig = null; let cachedAt = 0;`). Before sending, if cache is older than N minutes (e.g. 5), re-read `config/notifications` and update cache; then use cached values. Document this in code so future maintainers know.
- **Edge case (mid-execution save):** If an admin saves new config while a Cloud Function is already running, that run will use the config it read at the start of the run. No special handling required; add a **short comment in the function** (e.g. "Config is read once at start of run; mid-run admin changes apply to the next run").

---

## 5. Firestore rules (explicit)

- **Dashboard:** Existing rules already allow **admin read** for `plans`, `trips`, `users` via `isAdmin()` in [firestore.rules](firestore.rules). **No rule changes needed** for dashboard stats.
- **config/notifications:** Under existing `match /config/{configId}`: any signed-in user can read, only admin can write. If you prefer notification settings to be **admin-read-only**, add a separate block for `config/notifications` with `allow read: if isAdmin(); allow write: if isAdmin();`; otherwise leave as-is.

---

## 6. Summary of files to add or change


| Area                    | Action                                                                                                                                                                                                          |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Nav**                 | Add `/admin` route → `AdminScreen`. Redirect `/admin/migration` → `/admin`. Remove direct builder for `adminMigration` so the only way to see migration is via admin shell.                                     |
| **Admin shell**         | New `lib/presentation/admin/admin_screen.dart`: loading state until admin check, then 3-tab UI (Dashboard, Push notifications, Migration). Migration content inlined or embedded from current migration screen. |
| **Dashboard**           | `AdminService.getDashboardStats()` with error handling; dashboard tab shows error state + retry on failure.                                                                                                     |
| **Notification config** | `config/notifications`; Flutter + Functions treat **missing doc as all flags true**. Optional: module-level cache in Functions with TTL comment. Comment in Functions about config read once per run.           |
| **Push tab**            | Toggles bound to config; StreamBuilder for live updates.                                                                                                                                                        |
| **Profile**             | Single "Admin" tile to `/admin`; remove or repurpose old "Database Migration" link.                                                                                                                             |


---

## 7. Implementation notes (inline details)

- `**/admin/migration` redirect:** Redirect to `/admin` only; do not add query params to open the Migration tab. GoRouter redirect runs first, then the in-shell guard runs on `/admin`. Keeping redirect simple avoids query-param handling.
- **Null `currentUser`:** Already specified in section 1: null → `/login`; authed but not admin → `/profile`.
- **Migration tab widget:** The extracted migration content widget must be scaffold-free (body only). Strip any `Scaffold` from the current `AdminMigrationScreen` when extracting to avoid nested Scaffolds and visual artifacts.
- **StreamBuilder + missing doc:** When the Firestore doc does not exist, the stream still emits a snapshot; it does not error. Check `snapshot.data?.exists == false` (or equivalent) before reading fields and use default config (all flags true). Do not assume `snapshot.hasData` means the document exists with fields.

---

## 8. Optional / future

- Vote reminder trigger + toggle in config.
- Custom message templates or new trigger types.
- Restrict `config/notifications` read to admin only in rules if desired.

