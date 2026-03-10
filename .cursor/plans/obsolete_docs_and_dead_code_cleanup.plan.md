---
name: ""
overview: ""
todos: []
isProject: false
---

# Obsolete docs and dead code cleanup

## Essential documents — never delete

These must be **kept** under all circumstances. The rest of this plan only identifies candidates for deletion; it never applies to the following.

### Branding and design

- **[BRANDING_GUIDELINES.md](BRANDING_GUIDELINES.md)** — Canonical branding, theme, and design tokens. Referenced from [architecture.md](architecture.md). Required for consistent UI and any new feature work.

### Architecture and system knowledge

- **[architecture.md](architecture.md)** — App architecture, tech stack, project structure, Firebase integration, navigation. Core reference for how the app is built and where things live.

### Recurring processes and operational documentation

Documents that describe **how to do things** (setup, deployment, testing) so the team can repeat them:

- **[STRIPE_SETUP.md](STRIPE_SETUP.md)** — Stripe keys and configuration.
- **[OPENROUTER_SETUP.md](OPENROUTER_SETUP.md)** — OpenRouter API key setup.
- **[FIREBASE_STORAGE_SETUP.md](FIREBASE_STORAGE_SETUP.md)** — Firebase Storage setup.
- **[FONT_SETUP_INSTRUCTIONS.md](FONT_SETUP_INSTRUCTIONS.md)** — Font download and setup.
- **[.github/DEPLOYMENT_HOSTING.md](.github/DEPLOYMENT_HOSTING.md)** — Firebase Hosting deployment (GitHub Actions).
- **[.github/DEPLOYMENT_PERMISSIONS.md](.github/DEPLOYMENT_PERMISSIONS.md)** — Deployment permissions (if present).
- **[functions/DEPLOYMENT.md](functions/DEPLOYMENT.md)** — Cloud Functions deployment.
- **[functions/README.md](functions/README.md)** — Functions overview and usage.
- **[TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)** — Testing checklist for releases/features.

### Map and integration reference (ongoing use)

- **MAP_IMPLEMENTATION_GUIDE.md** — Map system setup and implementation reference. The app uses **Google Maps** for all map rendering; Mapbox-only docs have been removed.

Other root-level docs (e.g. **DEPLOYMENT_REQUIRED.md**, **COLLAPSIBLE_MAP_IMPLEMENTATION_PLAN.md**, **EDIT_WAYPOINT_REDESIGN_PLAN.md**, **BREADCRUMB_RESEARCH.md**, **ARCHITECTURE_REVIEW_AND_RECOMMENDATIONS.md**) and docs under **lib/** (e.g. **lib/features/map/README.md**), **ios/**, etc. remain **keep** unless you explicitly decide to trim them.

---

## Part 1: Markdown files to delete or archive

### 1.1 `.cursor/plans/` — obsolete (safe to delete)

These are completed, one-off, or superseded plans. The folder has duplicate entries (same name with `/` vs `\`); treat the list below as unique filenames and delete once per name.


| File                                                     | Reason                                                                                               |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| **phase0-snapshot-capture-notes.md**                     | One-off Phase 0 snapshot capture instructions; obsolete after migration.                             |
| **phase0e-migration-guide.md**                           | Step-by-step migration of `builder_screen.dart` to state classes; historical once migration is done. |
| **code_review_plan_REVISION.md**                         | Patch/revision for another plan; obsolete once edits are applied or the target plan is updated.      |
| **straight-line_fallback_&_gpx_import_e4141433.plan.md** | Straight-line fallback + GPX import; todos are largely "completed"; implementation done.             |


### 1.2 `.cursor/plans/` — keep (still relevant)

- **stripe_integration_plan_REVISED.md**, **web-only_checkout_and_stripe_mode_REVISED.plan.md** — Stripe/checkout not fully implemented.
- **code_review_improvements_dry_dead_code.md** — Active list of dead code, spacing, theme, DRY (references the same dead files we list below).
- **dry_components_branding_cursor_rules.plan.md**, **four_pages_home_trips_checklist_explore.plan.md**, **faq_transport_cta_tags_REVISED.plan.md**, **overview_page_branding_and_layout.md**, **plan_overview_page_alignment_REVISED.md**, **custom_waypoint_markers_and_list_icons_562bb66e.plan.md**, **unified_plan_trip_detail_screen_with_tab_navigation_ad8895a3.plan.md**, **unified_checklist_and_suggestions_a9f203ad.plan.md** — Future or partially done work; keep as reference.

### 1.3 Root-level `.md` — likely obsolete (candidates to delete)

One-off implementation/fix summaries; safe to remove once you no longer need the history. **None of these are essential (branding, architecture, or recurring process) documents.**

- **IMPLEMENTATION_SUMMARY.md** — Trail corridor + architecture summary.
- **POI_POSITIONING_FIXES.md** — Fixes applied (NoSuchMethodError, POI zoom).
- **CODE_REVIEW_SUMMARY.md** — Improvements implemented (PriceDisplayWidget, etc.).
- **OPENROUTER_API_KEY_SETUP.md** — Marked "COMPLETED"; overlaps with **OPENROUTER_SETUP.md** (keep the latter). **Before deleting:** confirm OPENROUTER_SETUP.md contains everything from this file so no setup steps are lost.
- **TRAIL_CORRIDOR_FILTER_INTEGRATION.md** — "Complete" integration notes.
- **PHASE8_RESPONSIVE_POLISH_SUMMARY.md** — Phase 8 completed items.
- **MAP_FIX_SUMMARY.md** — Which map showed up and event handler fix.
- **FIXES_APPLIED.md** — Mapbox GL JS fixes applied.
- **CODE_REVIEW_IMPROVEMENTS.md** — Issue list; likely superseded by **CODE_REVIEW_SUMMARY.md** and **code_review_improvements_dry_dead_code.md**.
- **CUSTOM_STYLE_FIX_GUIDE.md** — One-off Mapbox style fix; optional keep if you still maintain that style manually.

### 1.4 Root-level `.md` — keep (including essential)

All **essential** docs are listed in the "Essential documents — never delete" section at the top. In addition, keep:

- **DEAD_CODE_REMOVAL_PLAN.md** — Until the dead code work below is done (or archive after); documents WaypointEditDialog migration.
- Any other root .md not listed in 1.3 as delete candidates.

Docs under **lib/**, **functions/**, **.github/**, **ios/** — keep unless you explicitly want to trim them (and never remove the recurring-process ones listed above).

---

## Part 2: Dead / unused code

**Test coverage:** The table below reflects "no references in lib/". Before deleting any of these files, **also** verify there are no references in **test/** (widget tests, unit tests, integration tests). `dart analyze` may not flag test-only imports; run the test suite after removals to surface any breakage. For each candidate, run e.g. `grep -r "SymbolName\|filename" test/` before deleting.

### 2.1 Files never imported (safe to delete after verification)


| File                                                             | Notes                                                                                                                                                                                                                                                                               |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **lib/presentation/builder/legacy/waypoint_url_extraction.dart** | No references in lib/ or test/; confirmed in code_review_improvements_dry_dead_code.md as safe to delete.                                                                                                                                                                           |
| **lib/presentation/details/plan_details_screen.dart**            | Deprecated; `/details/:planId` uses `AdventureDetailScreen`. Only reference is commented import in nav.dart.                                                                                                                                                                        |
| **lib/presentation/trips/trip_details_screen.dart**              | Deprecated; `/trip/:tripId` uses `AdventureDetailScreen`. Only reference is commented import in nav.dart.                                                                                                                                                                           |
| **lib/features/map/enhanced_map_screen.dart**                    | `EnhancedMapScreen` not imported anywhere in lib/. Verify test/ and delete.                                                                                                                                                                                                         |
| **lib/presentation/map/map_location_picker.dart**                | `MapLocationPicker` not imported anywhere in lib/. Verify test/ and delete.                                                                                                                                                                                                         |
| **lib/models/day_content_item.dart**                             | `DayContentItem` / `WaypointContentItem` / `MediaContentItem` not imported in lib/. Verify test/ and delete.                                                                                                                                                                        |
| **lib/features/map/offline_download_sheet.dart**                 | `OfflineDownloadSheet` only referenced inside its own file. **Sanity check:** confirm it is not self-registering (e.g. static initializer or plugin registration); then verify test/ and delete.                                                                                    |
| **lib/presentation/adventure/tabs/local_tips_tab.dart**          | Placeholder stub; logic lives in adventure_detail_screen.dart. **Before delete:** grep for `local_tips_tab` / `LocalTipsTab` (and string or reflection refs) in lib/, test/, and any tab controller or factory — if registered by name, deletion can cause silent runtime failures. |
| **lib/presentation/adventure/tabs/prepare_tab.dart**             | Placeholder stub; logic lives in adventure_detail_screen.dart. **Before delete:** same as local_tips_tab — grep for `prepare_tab` / `PrepareTab` and tab registration so deletion isn’t a silent runtime break.                                                                     |


### 2.2 Screens imported in nav but never built (route redirects)


| File                                                       | Reason                                                                             |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **lib/presentation/builder/edit_plan_screen.dart**         | Route `/builder/edit/:planId` redirects to `/builder/:planId`; screen never built. |
| **lib/presentation/itinerary/itinerary_setup_screen.dart** | Route `AppRoutes.itinerarySetup` redirects to `/trip/:tripId`; screen never built. |


**BuilderScreen:** **lib/presentation/builder/builder_screen.dart** is only used by `EditPlanScreen`. Nav does not use it; `/builder/:planId` builds `AdventureDetailScreen`. After removing `EditPlanScreen` and its route/import, **before** deleting builder_screen.dart run a thorough **grep** for `BuilderScreen` and `builder_screen` across the whole repo (lib/, test/, and any config or scripts). Check for: direct imports, tests, deep links, analytics events, or string-based route references. Anything that references it by name can cause **silent runtime failures** (no compile error) after deletion. Only delete once grep shows no remaining references.

### 2.3 Legacy folder

- **lib/presentation/builder/legacy/** — Contains only `waypoint_url_extraction.dart` (unused). Safe to delete the file; then delete the folder if empty.
- **lib/features/map/legacy/** — Only README.md (no Dart). Keep per README: "DO NOT DELETE" until Mapbox is proven stable.

### 2.4 Unused export

- **lib/components/components.dart** exports `map/fullscreen_route_map.dart` (`FullscreenRouteMap`). No other file imports and uses it. Either remove the export and delete **lib/components/map/fullscreen_route_map.dart**, or keep the file and document it as optional/future use.

### 2.5 Do not remove (still used or compatibility)

- **lib/models/route_waypoint_legacy.dart** — Marked `@Deprecated` but still used for backward compatibility; keep unless you explicitly drop legacy support.
- **WaypointEditDialog** — Already removed (no file, no imports). DEAD_CODE_REMOVAL_PLAN.md can be archived after the rest of the dead code work is done.

---

## Part 3: Doc updates when deprecated screens are removed

**Do this right after deleting the deprecated screens** (not at the end). Stale references in architecture docs cause real confusion later.

If you delete **plan_details_screen** and **trip_details_screen**, **immediately** update:

- **architecture.md** — Remove or update references to the old screen paths; point to AdventureDetailScreen where relevant.
- **MAP_IMPLEMENTATION_GUIDE.md** — Same; no stale screen file references.
- **MAPBOX_WEBGL_MIGRATION_PLAN.md** — Same.

---

## Recommended order of work

1. Delete obsolete .cursor/plans (4 files in 1.1).
2. Delete or archive root-level one-off .md (list in 1.3) if you no longer need them. For OPENROUTER_API_KEY_SETUP.md, confirm OPENROUTER_SETUP.md has full content first.
3. **Verify test/:** For each file in 2.1 and 2.2, grep in test/ (and run tests) so no widget/unit test imports are missed; dart analyze won’t always catch test-only refs.
4. Remove dead Dart: remove nav imports for EditPlanScreen, ItinerarySetupScreen, and builder (BuilderScreen). Delete the files listed in 2.1 and 2.2 (after the pre-deletion checks in 2.1: BuilderScreen grep, tab file grep, OfflineDownloadSheet sanity check). **Then run dart analyze + flutter test** so any compile or test failure is caught here rather than after later steps.
5. **Doc touch-ups (right after step 4):** Update architecture.md, MAP_IMPLEMENTATION_GUIDE.md, MAPBOX_WEBGL_MIGRATION_PLAN.md for deprecated screen renames (Part 3).
6. Delete **builder_screen.dart** only after a full grep for `BuilderScreen` / `builder_screen` (lib/, test/, deep links, analytics, string routes) shows no references. **Then run dart analyze + flutter test** again so BuilderScreen removal is verified before touching legacy/fullscreen.
7. Legacy folder: delete waypoint_url_extraction.dart and folder if empty.
8. components.dart: remove fullscreen_route_map export; delete fullscreen_route_map.dart if not needed.
9. Final verification: **dart analyze**, **flutter test**, and **flutter run** (or hot restart); fix any remaining references.

---

## Summary

- **Essential (never delete):** BRANDING_GUIDELINES.md, architecture.md, and all recurring-process docs (Stripe/OpenRouter/Firebase/Font setup, deployment, testing checklist).
- **Obsolete plans:** 4 files in .cursor/plans.
- **Obsolete root .md:** One-off fix/summary docs in 1.3 (none are essential); confirm OPENROUTER_SETUP.md before deleting OPENROUTER_API_KEY_SETUP.md.
- **Dead code:** 9 never-imported files + 2 never-built screens + BuilderScreen + legacy waypoint_url_extraction + FullscreenRouteMap export.
- **Pre-deletion:** Grep BuilderScreen/builder_screen repo-wide; grep tab files for registration; sanity-check OfflineDownloadSheet; verify test/ for all dead files. Doc updates (Part 3) right after removing deprecated screens; then run tests and app.

This plan is research-only until you approve; then implementation can proceed with verification after each step.