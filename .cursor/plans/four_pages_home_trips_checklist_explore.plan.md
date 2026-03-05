---
name: ""
overview: ""
todos: []
isProject: false
---

# Plan: Home, My Trips, Checklist, and Explore — Same Style, DRY, Branded

## Goal

Recreate the four screens from the provided designs so they share one visual language: **Home (marketplace)**, **My Trips**, **Checklist (packing)**, and **Explore**. Use **DRY** components and tokens, align with **BRANDING_GUIDELINES.md** and **waypoint_edit_page / itinerary** patterns, and keep a **single import path** for colors (`waypoint_colors.dart`) and **LayoutTokens** for width.

---

## Design Targets (from screenshots)


| Page          | Key elements                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Home**      | Hero (image carousel, title “Discover Your Next Adventure”, subtitle, “Explore Now” / “Your trips” buttons, dots); cream background; search bar (cream, green icon); stats row (12.4k Routes, 850+ Adventures, 4.9/5); Featured Adventures horizontal cards; Waypoint Pro dark green promo; Explore by Activity chips; Your Recent Plans (trip-style cards).                                                                                                                  |
| **My Trips**  | Title “My Trips”, subtitle “Your personalized trip plans”; filter chips (Upcoming / Active / Completed — selected = green); trip cards: image left, title, date + calendar icon, avatar group, status chip (Upcoming/Completed), menu; FAB “New Itinerary” (green).                                                                                                                                                                                                           |
| **Checklist** | Back + trip title + location; “Created by” + creator avatar + name; share + menu; Packing Progress cream card (title, “X of Y items packed”, circular green progress); Quick Add Categories (chips: Vaccines, Electronics, …); expandable category panels (cream card, green icon, name, delete, chevron); items: checkbox, name, qty, “Essential” badge, delete; optional description/link/price fields (inline edit); “Add Item” / “Show More”; FAB “New Category” (green). |
| **Explore**   | Title “Explore”, subtitle “Discover your next waypoint adventure”; search bar (cream, green border); filter chips (All selected = green, Hiking, City Trip, …); two-column grid of adventure cards (image, location tag overlay, title, author, rating, price in green); bottom “Map View” button (green).                                                                                                                                                                    |


---

## Branding and tech stack (single source)

- **Colors:** One import only — `package:waypoint/theme/waypoint_colors.dart`. Use **BrandingLightTokens** (background, surface, appBarGreen, formLabel, secondary, hint, formFieldBorder, formFieldBackground) and **WaypointColors** where the existing theme layer already uses it. No hardcoded hex for brand colors.
- **Layout:** `package:waypoint/core/theme/layout_tokens.dart` — **LayoutTokens.formMaxWidth** (600) for narrow content, **LayoutTokens.pageMaxWidth** (800) for wider content when needed.
- **Spacing / radius:** `lib/theme/waypoint_spacing.dart` (sectionGap, cardPadding, cardRadius, pagePaddingMobile). Card radius 12–16; pill buttons 28. Align with [BRANDING_GUIDELINES.md](BRANDING_GUIDELINES.md) and [.cursor/plans/dry_components_branding_cursor_rules.plan.md](.cursor/plans/dry_components_branding_cursor_rules.plan.md).
- **Typography:** Theme `textTheme` and/or **WaypointTypography** (headlineMedium, bodyMedium, label, etc.) from `lib/theme/waypoint_typography.dart` for titles and body. Match waypoint_edit_page / itinerary hierarchy.
- **Inspiration:** Reuse patterns from **waypoint_edit_page** (section labels, cream surfaces, constrained width) and **waypoint_detail_page** / itinerary (hero, tabs, cream card, info rows) so these four pages feel part of the same app.

---

## Shared components (DRY)

Build or reuse so **all four pages** use the same building blocks.

### From existing DRY plan (use or extract first)

- **WaypointCreamChip** — Use for **all** chips: Home “Explore by Activity”, My Trips “Upcoming/Active/Completed”, Checklist “Quick Add Categories”, Explore “All / Hiking / City Trip”. Migrate any custom FilterChip or chip styling to this.
- **WaypointCreamCard** — Cream container (surface #F2E8CF, border formFieldBorder, radius 16). Use for: Packing Progress card, Checklist category panels, any cream block on Home/My Trips if needed.
- **WaypointInfoRow** — Label + value row (optional divider). Use for trip date row, stats, or any key-value line.
- **WaypointConstrainedScroll** — Center + ConstrainedBox(maxWidth) + Padding for narrow content. Use where form/detail content width is capped (e.g. checklist content if desired).
- **WaypointDetailHero** (when extracted) — Reuse or adapt for **Home hero** (image carousel, gradient, title, subtitle, two buttons, dots). Marketplace already has `_buildHeroCarousel`; restyle to BrandingLightTokens and optionally extract to one shared hero component.

### New or clearly specified shared components


| Component                | Purpose                                                                                                                                                                                                                                                                                            | Used on                            |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| **PageHeader**           | Title + subtitle, optional gradient; consistent padding.                                                                                                                                                                                                                                           | Home, My Trips, Explore            |
| **WaypointSearchBar**    | Cream background, green magnifier, placeholder; optional filter/sort icon.                                                                                                                                                                                                                         | Home, Explore                      |
| **StatsRow**             | 2–4 stats with optional dividers (e.g. “12.4k Routes                                                                                                                                                                                                                                               | 850+ Adventures                    |
| **TripCard**             | Image left, right: title, date (calendar icon), avatar group, status chip, menu. Reuse or refactor [HorizontalTripCard](lib/presentation/mytrips/widgets/horizontal_trip_card.dart) to match screenshot (cream card, status chip = WaypointCreamChip).                                             | My Trips, Home “Your Recent Plans” |
| **AdventureGridCard**    | Image top, optional LocationTag overlay, title, author, rating, price (green). Unify with [AdventureCard](lib/presentation/widgets/adventure_card.dart) variant or [Explore _AdventureGridCard](lib/presentation/explore/explore_screen.dart) and style with waypoint_colors + WaypointTypography. | Explore, Home Featured             |
| **LocationTag**          | Pill with map pin icon + text (e.g. “Cascade Mountains,…”).                                                                                                                                                                                                                                        | Explore cards, optional elsewhere  |
| **UserAvatarGroup**      | Overlapping circular avatars (initials or images).                                                                                                                                                                                                                                                 | My Trips cards, Home cards         |
| **WaypointFAB**          | Green (appBarGreen), rounded rectangular, icon + label (“New Itinerary”, “New Category”). Same style on My Trips and Checklist.                                                                                                                                                                    | My Trips, Checklist                |
| **PackingProgressCard**  | Cream card: “Packing Progress”, “X of Y items packed”, circular progress (green fill).                                                                                                                                                                                                             | Checklist                          |
| **PackingCategoryPanel** | Expandable cream card: header = green category icon, name, delete, chevron; body = list of **PackingListItem**.                                                                                                                                                                                    | Checklist                          |
| **PackingListItem**      | Checkbox (green when checked), name, qty, optional “Essential” badge (light orange), delete; optionally expandable description/link/price (inline edit pattern).                                                                                                                                   | Checklist                          |
| **PromoCard** (existing) | Dark green “Waypoint Pro” block; keep styling consistent with WaypointColors.                                                                                                                                                                                                                      | Home                               |


Ensure **WaypointCreamChip** is used for: filter segments (Upcoming/Active/Completed), Quick Add Categories, Explore filters (All, Hiking, City Trip), and any status chip on cards.

---

## Shared component library: waypoint_shared_components.dart

**Single DRY library.** Every shared widget for these four pages lives in one file (e.g. `lib/components/waypoint/waypoint_shared_components.dart` or a dedicated `lib/widgets/waypoint_shared_components.dart`). Adjust import path to match project layout.


| Widget                           | Description                                                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **WaypointPageHeader**           | Gradient title + subtitle; used on Home, My Trips, Explore.                                                        |
| **WaypointSearchBar**            | Cream bg, green icon, optional filter toggle; Home + Explore.                                                      |
| **WaypointCreamChip**            | Single chip for ALL chip contexts: filters, quick-add, activity, status.                                           |
| **WaypointCreamCard**            | Cream surface container (surface token, border, radius 16).                                                        |
| **WaypointFAB**                  | Green extended FAB; same style on My Trips (“New Itinerary”) + Checklist (“New Category”).                         |
| **WaypointUserAvatarGroup**      | Overlapping initials avatars with consistent brand colors.                                                         |
| **WaypointStatsRow**             | Divider-separated stats (e.g. 12.4k Routes                                                                         |
| **WaypointTripCard**             | Image-left card with date, avatars, status chip; My Trips + Home “Your Recent Plans”.                              |
| **WaypointAdventureGridCard**    | Explore grid card; use with **WaypointLocationTag** for overlay pill.                                              |
| **WaypointLocationTag**          | Pill with map pin + text (e.g. “Cascade Mountains,…”).                                                             |
| **WaypointPackingProgressCard**  | Circular progress with CustomPainter; “X of Y items packed”.                                                       |
| **WaypointPackingCategoryPanel** | Expandable cream panel: header (icon, name, delete, chevron), body = list of items.                                |
| **WaypointPackingListItem**      | Checkbox (animated), name, qty, Essential badge, delete; expandable inline edit fields (description, link, price). |


---

## Integration steps (screens → shared library + theme)

The four screens can be implemented first with **color stubs** (`abstract class _C { ... }`) for fast layout and behaviour, then wired to the real theme and shared library.

1. **Create** `waypoint_shared_components.dart` and implement the widgets above. Use `package:waypoint/theme/waypoint_colors.dart` and **BrandingLightTokens** (e.g. `BrandingLightTokens.background`, `BrandingLightTokens.surface`, `BrandingLightTokens.appBarGreen`, `BrandingLightTokens.formFieldBorder`, `BrandingLightTokens.formLabel`, `BrandingLightTokens.secondary`, `BrandingLightTokens.hint`) inside the shared library — no `_C` stubs in the library.
2. **In each screen file**, remove the local `_C` stub and add:
  - `import 'package:waypoint/theme/waypoint_colors.dart';` (and use BrandingLightTokens where a screen still needs a one-off color).
  - `import 'package:waypoint/components/waypoint/waypoint_shared_components.dart';` (or the chosen path).
3. **Replace** inline UI that duplicates shared behaviour with the library widgets (e.g. search bar → WaypointSearchBar, filter row → WaypointCreamChip, trip row → WaypointTripCard, FAB → WaypointFAB, progress card → WaypointPackingProgressCard, category panel → WaypointPackingCategoryPanel + WaypointPackingListItem).
4. **Swap** any remaining `_C.background`, `_C.surface`, `_C.appBarGreen`, etc., to the corresponding **BrandingLightTokens** (or WaypointColors) so there is a single source of truth.

---

## Screen files and current stub pattern


| File                                                                                                         | Role      | Current pattern                                                                                                                                                                                                                      | After integration                                                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------ | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [lib/presentation/marketplace/marketplace_screen.dart](lib/presentation/marketplace/marketplace_screen.dart) | Home      | `_C` stubs (background, surface, appBarGreen, formBorder, formBg, label, secondary, hint, orange); inline hero, search, stats, featured cards, promo, explore-by-activity, recent trip card.                                         | Use WaypointPageHeader (if used), WaypointSearchBar, WaypointStatsRow, WaypointCreamCard/WaypointAdventureGridCard, WaypointTripCard, WaypointCreamChip; remove `_C`, use waypoint_colors.                                                             |
| [lib/presentation/mytrips/my_trips_screen.dart](lib/presentation/mytrips/my_trips_screen.dart)               | My Trips  | `_C` stubs; header, filter row (Upcoming/Active/Completed), trip cards, empty state, FAB.                                                                                                                                            | WaypointPageHeader, WaypointCreamChip for filters, WaypointTripCard, WaypointUserAvatarGroup, WaypointFAB; remove `_C`, use waypoint_colors.                                                                                                           |
| [lib/presentation/trips/checklist_screen.dart](lib/presentation/trips/checklist_screen.dart)                 | Checklist | `_C` stubs (incl. essential/essentialText); app bar (trip title, location, “Created by”), PackingProgressCard (with CustomPainter), Quick Add chips, expandable category panels, packing items with inline edit; FAB “New Category”. | WaypointPackingProgressCard, WaypointCreamChip (Quick Add), WaypointPackingCategoryPanel, WaypointPackingListItem, WaypointFAB; remove `_C`, use waypoint_colors. (Checklist can live as a dedicated screen or replace/restyle member_packing_screen.) |
| [lib/presentation/explore/explore_screen.dart](lib/presentation/explore/explore_screen.dart)                 | Explore   | `_C` stubs; page header, search bar, filter chips (All, Hiking, City Trip, …), grid of adventure cards (location tag, author, rating, price), Map View FAB.                                                                          | WaypointPageHeader, WaypointSearchBar, WaypointCreamChip, WaypointAdventureGridCard + WaypointLocationTag, Map View button (same style as WaypointFAB); remove `_C`, use waypoint_colors.                                                              |


Stub mapping for removal: `_C.background` → `BrandingLightTokens.background`, `_C.surface` → `BrandingLightTokens.surface`, `_C.appBarGreen` → `BrandingLightTokens.appBarGreen`, `_C.formBorder` → `BrandingLightTokens.formFieldBorder`, `_C.formBg` → `BrandingLightTokens.formFieldBackground`, `_C.label` → `BrandingLightTokens.formLabel`, `_C.secondary` → `BrandingLightTokens.secondary`, `_C.hint` → `BrandingLightTokens.hint`; keep accent/orange for “Essential” and rating star via WaypointColors or semantic token if defined.

---

## Page-by-page implementation

### 1. Home (Marketplace)

- **File:** [lib/presentation/marketplace/marketplace_screen.dart](lib/presentation/marketplace/marketplace_screen.dart)
- **Structure:** Scaffold with cream background; single scroll (or CustomScrollView).
- **Sections in order:**
  - **Hero:** Image carousel, gradient overlay, “Discover Your Next Adventure”, “Expert-curated routes…”, buttons “Explore Now” (primary green) and “Your trips” (secondary); carousel dots. Align colors with BrandingLightTokens; consider shared hero component with waypoint_detail hero.
  - **Search:** **WaypointSearchBar** (“Where to next …”), centered or full-width with horizontal padding.
  - **Stats:** **StatsRow** (“12.4k Routes”, “850+ Adventures”, “4.9/5 Rating”) with vertical dividers.
  - **Featured Adventures:** Section title “Featured Adventures”, “See All” link (green); horizontal list of **AdventureGridCard** (or AdventureCard variant).
  - **Waypoint Pro:** Existing **PromoCard** (dark green); keep or adjust to match screenshot.
  - **Explore by Activity:** Section title; horizontal scroll of activity cards/chips — use **WaypointCreamChip** or existing ActivityCircle; same colors and radius.
  - **Your Recent Plans:** Section title; list of **TripCard** (or HorizontalTripCard restyled).
- **Tokens:** waypoint_colors only; WaypointSpacing for section gaps and padding; no new hex.

### 2. My Trips

- **File:** [lib/presentation/mytrips/my_trips_screen.dart](lib/presentation/mytrips/my_trips_screen.dart)
- **Structure:** Scaffold, cream background; **PageHeader** (“My Trips”, “Your personalized trip plans”); filter row; list of trip cards; **WaypointFAB** “New Itinerary”.
- **Changes:**
  - Replace or augment current header with **PageHeader** (title + subtitle, optional soft gradient).
  - **Filter:** Horizontal row of **WaypointCreamChip** for “Upcoming”, “Active”, “Completed” (selected = appBarGreen, white text).
  - **Cards:** Use **TripCard** (or refactor **HorizontalTripCard**) so each card has: left image (rounded), right: title, date row with calendar icon, **UserAvatarGroup**, status **WaypointCreamChip** (“Upcoming” / “Completed”), menu. All styling from waypoint_colors and WaypointSpacing.
  - **FAB:** **WaypointFAB** with icon + “New Itinerary” (green), same as Checklist FAB style.
- **Data:** Keep existing StreamBuilder + TripService; only UI and components change.

### 3. Checklist (Packing)

- **File:** [lib/presentation/trips/member_packing_screen.dart](lib/presentation/trips/member_packing_screen.dart) (or a dedicated checklist screen if routing differs)
- **Structure:** AppBar or custom header (back, trip title, location, “Created by” + creator avatar + name, share, menu); body: **PackingProgressCard**; “Quick Add Categories” + **WaypointCreamChip** row; list of **PackingCategoryPanel**; **WaypointFAB** “New Category”.
- **Header:** Trip name (bold), location below; “Created by” + small avatar + username; share and menu icons. Use WaypointTypography and waypoint_colors.
- **PackingProgressCard:** **WaypointCreamCard** with title “Packing Progress”, “X of Y items packed”, circular progress indicator (green).
- **Quick Add:** Label “Quick Add Categories”; horizontal **WaypointCreamChip** (Vaccines, Electronics, Toiletries, etc.); chips use same style as other pages.
- **Category panels:** **PackingCategoryPanel** (expandable): cream card, header = green category icon + name + delete + chevron; body = **PackingListItem** list; “Add Item” button (cream + green plus); “Show More” if needed.
- **PackingListItem:** Checkbox (green when checked), item name, “Qty: N”, optional “Essential” badge (light orange), delete icon; expandable section for description, link, price (inline edit pattern). Reuse MemberPacking + PackingCategory model; only UI and components change.
- **FAB:** **WaypointFAB** “New Category” (green).
- **Inline editing:** Description/link/price fields in list item follow the same pattern as waypoint_detail name edit (tap → expand or bottom sheet). Prefer one reusable pattern for “inline edit” across the app.

### 4. Explore

- **File:** [lib/presentation/explore/explore_screen.dart](lib/presentation/explore/explore_screen.dart)
- **Structure:** **PageHeader** (“Explore”, “Discover your next waypoint adventure”); **WaypointSearchBar** (placeholder “Search destinations, trails or activi…”, optional filter icon); filter chips row (**WaypointCreamChip**: All, Hiking, City Trip, …); two-column grid of **AdventureGridCard**; bottom “Map View” button (green).
- **Replace:** Current AppBar + search + FilterChip list with **PageHeader** + **WaypointSearchBar** + **WaypointCreamChip** row (selected = green).
- **Grid:** Keep 2 columns (mobile); use **AdventureGridCard** with: image, **LocationTag** overlay (e.g. “Cascade Mountains,…”), title, author avatar + name, rating, price in green. Reuse or unify with existing _AdventureGridCard and AdventureCard; style with waypoint_colors and WaypointTypography.
- **Map View:** One primary button at bottom (green, “Map View”, map pin icon). Use same primary button style as waypoint_detail bottom bar (appBarGreen, white text, radius 28).

---

## Implementation order

1. **Create waypoint_shared_components.dart** — Implement all widgets listed in “Shared component library” (WaypointPageHeader, WaypointSearchBar, WaypointCreamChip, WaypointCreamCard, WaypointFAB, WaypointUserAvatarGroup, WaypointStatsRow, WaypointTripCard, WaypointAdventureGridCard, WaypointLocationTag, WaypointPackingProgressCard, WaypointPackingCategoryPanel, WaypointPackingListItem). Use only `package:waypoint/theme/waypoint_colors.dart` and BrandingLightTokens inside the library; no `_C` stubs there.
2. **Home** — Implement or restyle [marketplace_screen.dart](lib/presentation/marketplace/marketplace_screen.dart) using shared components; replace `_C` stubs with waypoint_colors and BrandingLightTokens; import waypoint_shared_components.
3. **My Trips** — Implement or restyle [my_trips_screen.dart](lib/presentation/mytrips/my_trips_screen.dart) with WaypointPageHeader, WaypointCreamChip filters, WaypointTripCard, WaypointFAB; remove `_C`, use waypoint_colors.
4. **Checklist** — Implement or restyle [lib/presentation/trips/checklist_screen.dart](lib/presentation/trips/checklist_screen.dart) (or [member_packing_screen.dart](lib/presentation/trips/member_packing_screen.dart)) with PackingProgressCard, Quick Add WaypointCreamChip, WaypointPackingCategoryPanel, WaypointPackingListItem (inline edit, Essential badge, CustomPainter progress), WaypointFAB; remove `_C`, use waypoint_colors.
5. **Explore** — Implement or restyle [explore_screen.dart](lib/presentation/explore/explore_screen.dart) with WaypointPageHeader, WaypointSearchBar, WaypointCreamChip, WaypointAdventureGridCard + WaypointLocationTag, Map View button; remove `_C`, use waypoint_colors.
6. **Lint and run** — Run analyzer and app; fix errors and ensure no stray hardcoded brand colors.

---

## Consistency checklist

- All four pages use `package:waypoint/theme/waypoint_colors.dart` (no raw hex for brand).
- Layout width uses `LayoutTokens` where applicable (`package:waypoint/core/theme/layout_tokens.dart`).
- All chips (filters, quick-add, status) use **WaypointCreamChip**.
- Cream surfaces use **WaypointCreamCard** or same token (surface / formFieldBackground).
- Primary buttons and FAB use appBarGreen, white text, consistent radius (28 for pills).
- Typography uses theme or WaypointTypography; hierarchy matches waypoint_edit_page / itinerary.
- Spacing uses WaypointSpacing (sectionGap, cardPadding, pagePaddingMobile).

This plan keeps the four pages visually and technically aligned, reuses components across Home, My Trips, Checklist, and Explore, and stays within the existing branding and architecture (and DRY plan) so implementation stays consistent and maintainable.