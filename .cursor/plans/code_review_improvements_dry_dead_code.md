# Code review: improvements, dead code, and issues

Implementation order: follow section order (dead code → spacing unification → theme → DRY → remaining issues).

---

## 2. Dead code

### 2.1 Unused screens (safe to remove after confirmation)

| File | Reason |
|------|--------|
| `lib/presentation/builder/edit_plan_screen.dart` | No route uses it; only imported in nav. Wraps BuilderScreen. |
| `lib/presentation/builder/builder_screen.dart` | Deprecated; `/builder/:planId` uses AdventureDetailScreen. |
| `lib/presentation/details/plan_details_screen.dart` | Deprecated; `/details/:planId` uses AdventureDetailScreen. |
| `lib/presentation/trips/trip_details_screen.dart` | Deprecated; `/trip/:tripId` uses AdventureDetailScreen. |
| `lib/presentation/itinerary/itinerary_setup_screen.dart` | Route redirects to `/trip/:tripId`; screen never built. Remove import from nav. |

**Action:** Remove nav imports for these; delete the four unused screen files. Verify no other imports reference them.

### 2.2 Unused widget and export

- `lib/components/map/fullscreen_route_map.dart` — FullscreenRouteMap never imported; only in components.dart.
- Remove export from `components.dart`; delete or document the file.

### 2.3 Legacy

- `lib/presentation/builder/legacy/waypoint_url_extraction.dart` — "not used"; safe to delete if no references.
- `lib/services/adventure_context_service.dart` — deprecated; remove when BuilderScreen is removed.
- **Decision (choose one):** (A) We are keeping legacy support — document that `lib/models/route_waypoint_legacy.dart` is kept for compatibility; no removal. (B) We are dropping legacy support by [date/milestone] — add removal of `route_waypoint_legacy.dart` and related imports to the dead-code work. (C) Remove this item from the plan until product decides; track elsewhere.

---

## 1.5 Duplicate spacing sources (design system) — High priority

Duplicate `WaypointSpacing` is a **correctness bug** (wrong spacing values in different parts of the app), not just a style issue.

- **Winner:** `lib/core/theme/spacing.dart` (more complete: full scale, edge insets, component tokens, layout constants). It is already exported via `lib/core/theme/waypoint_theme.dart` and `lib/theme.dart`.
- **Missing in core:** `cardPaddingInsets` — theme/waypoint_spacing uses 14px; core has `cardPadding` = 16px. Either add `cardPaddingInsets = EdgeInsets.all(14)` to core or standardize on 16px and migrate call sites.
- **Value conflict:** `sectionGap` is 24 in core vs 32 in theme/waypoint_spacing — decide one value and use it everywhere.
- **Audit:** Grep for `waypoint_spacing.dart` and `spacing.dart`; migrate every file that imports `theme/waypoint_spacing.dart` to use `theme.dart` (or core/waypoint_theme) only; then delete or re-export `lib/theme/waypoint_spacing.dart`.
- **Decision:** Pick core, add any agreed missing tokens, audit and fix imports, then remove the duplicate class (delete or deprecate `theme/waypoint_spacing.dart`).

---

## 3.1 Theme / dark mode consistency — High priority

**Coordination:** The dark mode sync plan (see that plan document) already scopes waypoint_detail_page, adventure_detail_screen, and adventure components. Implement theme fixes there to avoid duplicate or inconsistent approaches. This section summarizes scope only.

Replace `BrandingLightTokens` / `WaypointColors` with `context.colors` in:

- **High:** waypoint_detail_page (~20), adventure_detail_screen (~52), waypoint_edit_page (~18), components/adventure/* (section_header, buy_plan_card, version_carousel, adventure_tags_row, gpx_import_area, breadcrumb_nav, creator_card, review_score_row, etc.).

---

## 1. Code improvements (DRY, components, responsive)

### 1.1 Duplicate waypoint cards (high impact)

Three nearly identical cards differ only by type badge and a few fields:

- `lib/presentation/widgets/hotel_waypoint_card.dart`
- `lib/presentation/widgets/poi_waypoint_card.dart`
- `lib/presentation/widgets/airbnb_waypoint_card.dart`

**Recommendation:** Use the existing `lib/components/waypoint/unified_waypoint_card.dart` (confirm it supports a type parameter or extend it for hotel | poi | airbnb). Use design tokens for margin (e.g. 12), padding (16), and radius (12) from `lib/core/theme/spacing.dart`.

### 1.2 Repeated app bar pattern (medium impact)

Many screens use the same "back + title + actions" pattern: checklist_screen (`_buildAppBar`), member_packing_screen, waypoint_edit_page, waypoint_detail_page, onboarding screens, creator_profile_screen, itinerary_review_screen, etc.

**Recommendation:** Introduce a shared `WaypointAppBar` or "back + title" builder in `lib/components/waypoint/waypoint_shared_components.dart` that uses theme colors and optional trailing actions. Before implementing, check the existing DRY/branding plan and whether `WaypointSharedComponents` (or another shared module) already defines a shared app bar — avoid a second parallel implementation.

### 1.3 Bottom sheet shell (low impact)

`share_bottom_sheet.dart` and `sign_in_bottom_sheet.dart` share the same chrome: top radius 20, padding 20, handle bar. Extract a `BottomSheetShell` and use design tokens.

### 1.4 Hardcoded spacing (medium impact)

Replace raw numbers with `WaypointSpacing` from `lib/core/theme/spacing.dart` in:

- Plan details screen (EdgeInsets.all(24/16/12/20))
- Builder home screen (all(24), all(40), all(48))
- Adventure card and waypoint cards (all(10), all(24), circular(12))
- Route info section, section_card (SizedBox height 12/16/8 → gapSm, gapMd, subsectionGap)

**WaypointCreamChip:** Chips in a Wrap were touching; ensure Wrap uses consistent spacing (e.g. `spacing: 8`, `runSpacing: 8`) where chips are used (e.g. My Trips). Fix in the shared chip or in the Wrap usage so all chip rows are consistent.

### 1.6 Plan / trip / section cards (medium impact)

- Plan card: Standardize on one primary API (AdventureCard with variants or WaypointFeaturedPlanCard).
- Trip card: One `TripCard` with layout variant (horizontal vs overview) to avoid duplicating date/status/image logic.
- Section card: Use `lib/components/unified/section_card.dart` in plan_details_screen for consistent section styling.
- **SectionHeader:** Audit usage of `SectionHeader` from `lib/components/adventure/section_header.dart` vs inline implementations (e.g. `SectionHeader` in `adventure_card.dart`, `_SectionHeader` in `itinerary_select_screen.dart`, `_buildSectionHeader` in `day_content_builder.dart`). Prefer the shared component and migrate or remove duplicates so section headers are consistent.

### 1.7 Empty state and form patterns (low impact)

- Unify or align `empty_state_widget.dart` and `waypoint_empty_state.dart`.
- Shared `FormFieldSection` or `LabeledField` for waypoint_edit_page, adventure_detail_screen, route_info_section, profile_screen.

---

## 3. Remaining code issues

### 3.2 Nav imports cleanup

In `lib/nav.dart`: Remove imports for builder_screen, edit_plan_screen, itinerary_setup_screen; clean commented plan_details_screen and trip_details_screen.

### 3.3 User-visible error handling

Add or improve feedback for these critical flows only: (1) payment/checkout failure, (2) trip delete/fail, (3) auth/sign-in errors, (4) trip load failure (e.g. checklist, my trips), (5) save failure (e.g. waypoint edit, plan save). For each, define one approach (e.g. snackbar + retry or dialog). All other catch blocks can remain log-only; track in a separate tech-debt list if desired.

### 3.4 Linting (parked)

Enabling new lint rules in `analysis_options.yaml` will generate many warnings across unrelated files and create noise during feature work. Do not enable as part of this plan; track in a separate tech-debt or tooling ticket.

---

## Summary

| Category | Priority | Action |
|----------|----------|--------|
| Dead screens | High | Remove nav refs and delete edit_plan_screen, builder_screen, plan_details_screen, trip_details_screen; drop itinerary_setup_screen import. |
| Dead widget/export | High | Remove fullscreen_route_map export from components.dart; delete or document file. |
| Single WaypointSpacing | High | Unify on core/theme/spacing.dart; add missing tokens, audit imports, deprecate theme/waypoint_spacing.dart. |
| Theme consistency | High | Replace BrandingLightTokens with context.colors (implement in dark mode plan). |
| DRY waypoint cards | Medium | Unify hotel/poi/airbnb using existing unified_waypoint_card; confirm or extend. |
| Shared app bar | Medium | Add WaypointAppBar (check prior DRY plan first); migrate screens. |
| Hardcoded spacing | Medium | Use WaypointSpacing in plan details, builder home, cards, sections; fix WaypointCreamChip Wrap spacing. |
| Bottom sheet / empty state / form section | Low | Extract shared shell; unify empty state and form section. |
| Linting | Parked | Separate tech-debt ticket. |

Implementation order: follow section order (dead code → spacing unification → theme → DRY → remaining issues).
