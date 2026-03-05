# Overview page branding and layout (revised with screenshot review)

This plan covers the plan/trip overview (builder, viewer, trip), branding/tokens, Plan Settings grouping, and **five high/medium-priority issues identified from screenshots** that were missing or understated in the first version.

---

## Revised priority table

| Category | Priority | Notes |
|----------|----------|--------|
| **Enum display names in dropdowns** | **High** | Missing entirely before review — raw `cityTrips`, `comfort` in builder; add displayName getter/extension. |
| Dead code (screens, exports) | High | Unchanged from code review plan. |
| **WaypointSpacing unification** | **High** | Elevated from Medium — correctness bug. |
| Theme consistency (dark mode) | High | Unchanged; cross-ref dark mode plan. **Decision:** builder follows theme like all other screens (see Builder dark mode scope below). |
| **Mobile vs desktop builder visual parity** | **Medium** | Missing before — [lib/presentation/builder/waypoint_edit_page.dart](lib/presentation/builder/waypoint_edit_page.dart) (cream, tags) vs desktop builder (white/grey, raw labels). |
| **Builder title truncation** | **Medium** | Title clips mid-word with no ellipsis; add maxLines/overflow. |
| DRY waypoint cards | Medium | Single place: confirm [lib/components/waypoint/unified_waypoint_card.dart](lib/components/waypoint/unified_waypoint_card.dart) exists; create if absent. |
| **Shared app bar** | **Medium–High** | More urgent given two nav patterns (Edit Adventure bar vs breadcrumb builder). |
| Hardcoded spacing | Medium | Unchanged. |
| **FAQ / Transport section DRY** | **Medium** | Same data, different chrome ("Common Questions" vs "FAQ's"); unify. |
| Bottom sheet / empty state | Low | Unchanged. |
| **"How to Get There" / Travel Logistics** | **Low** | Card chrome, add button, tip box — candidate for SectionCard/DRY. |
| Linting | **Separate ticket** | Remove from this plan; park in tech-debt. |

---

## New items from screenshot review (add to plan)

### New 1: Raw enum values in builder dropdowns (High)

**Problem:** Desktop builder shows `cityTrips` and `comfort` as selected values — Dart enum names leaking into the UI. Mobile edit view correctly shows "City Trip" and "Comfort", so display mapping exists somewhere but is not used in builder dropdowns.

**Fix:**

- Add a **displayName** getter or extension on `ActivityCategory` and `AccommodationType` (and any other enums used in plan settings) that returns user-facing strings (e.g. "City Trip", "Comfort").
- **Placement (decided):** Put display-name extensions in **[lib/utils/plan_display_utils.dart](lib/utils/plan_display_utils.dart)** — but **check for existing display/label utils in `lib/utils/` before creating** (e.g. `display_utils.dart`, `plan_labels.dart`, or any labels extension). If found, extend that file rather than creating a new one to avoid duplication. Do not put display logic in [lib/models/plan_model.dart](lib/models/plan_model.dart) to avoid UI concerns in the model.
- Apply this display name **consistently** in every dropdown and label: builder overview dropdowns, [lib/presentation/builder/waypoint_edit_page.dart](lib/presentation/builder/waypoint_edit_page.dart), any enum-bound widget.
- **Locations to update:** Builder overview (`_buildBuilderOverviewTab` and the new Plan Settings block), any `InlineEditableDropdown<ActivityCategory>` / `InlineEditableDropdown<AccommodationType>`, and waypoint edit page dropdowns — all use the same helper from plan_display_utils.

### New 2: Title field clips without ellipsis in builder (Medium)

**Problem:** Builder title shows "Jullisa & Tommy's adventu" — clipped mid-word with no ellipsis or wrap.

**Fix:** In the builder overview title field (the inline-editable title used in `_buildBuilderOverviewTab` or equivalent):

- Either allow multiple lines with `maxLines: 2` (or 3) and `overflow: TextOverflow.ellipsis`, or keep single line but set `overflow: TextOverflow.ellipsis` and ensure the parent does not clip (e.g. no fixed width without `Flexible`/`Expanded`). Avoid `maxLines: 1` with no overflow handling.

### New 3: Mobile edit vs desktop builder visual inconsistency (Medium)

**Problem:** Mobile Edit Adventure screen (waypoint_edit_page or equivalent) has cream background, proper tag chips, clear hierarchy. Desktop builder (adventure_detail_screen builder overview) has plain white/grey background, no cream surfaces, raw uppercase labels (TITLE, DESCRIPTION). Same data, two different visual languages.

**Fix:**

- Treat desktop builder overview as in scope for the same branding as mobile edit: apply cream/surface tokens from BRANDING_GUIDELINES, use `context.colors.surface` and design tokens for cards and sections, and align label styling (e.g. use theme titleMedium/bodyMedium instead of ad-hoc uppercase).
- Optionally extract a shared "overview section" or "builder form" chrome used by both mobile edit and desktop builder so one implementation drives both.

### New 4: FAQ / Transport section duplication (Medium)

**Problem:** Mobile shows "Common Questions" with + button and chevrons; desktop builder shows "FAQ's" with same data but different chrome. Same for transport / "How to Get There" — two different widgets for the same data.

**Fix:**

- **FAQ label (decided):** Use **"Common Questions"** everywhere. That is the user-facing label buyers and travelers see; the builder is just editing the same content. Replace "FAQ's" in the builder with "Common Questions" and use one shared section component for both mobile and builder.
- Unify FAQ section: one component (or one section title + list pattern) used for both mobile edit and builder overview — label **"Common Questions"**, same card/section chrome, same add/expand behaviour.
- Unify Transport / "How to Get There" with the same approach: one section component, same card chrome and add button; builder passes editable callbacks, viewer/trip passes read-only.

### New 5: "How to Get There" section not covered by DRY (Low)

**Problem:** Transport options section has its own card chrome, add button, and tip box. The general DRY plan (section 1.3/1.6) mentions bottom sheet shell and section card but doesn’t explicitly call out this section.

**Fix:** Include "How to Get There" / Travel Logistics in the SectionCard and DRY pass: use shared SectionCard, shared add-button style, and a **shared tip/info box**. For the blue info box: if an existing `InfoBox`/`TipCard`-style component exists in `lib/components/`, use it; otherwise **create a shared `WaypointTipCard`** (icon + body text, themed surface via `context.colors`) so the tip is not a one-off hardcoded `Container` with light blue.

---

## Builder dark mode scope (decided)

**Decision:** The builder screen **follows theme like all other screens**. Apply the dark mode / theme consistency work to the builder overview and builder nav so that when the user switches to dark mode, the builder uses the same theme tokens (e.g. `context.colors`, `context.textStyles`) as the rest of the app. Do not treat the builder as intentionally light-only unless product explicitly requests that later.

---

## Cross-reference with code review plan

- **Section 1.1 (duplicate waypoint cards):** See priority table (confirm unified_waypoint_card exists; create if absent).
- **Section 1.2 (shared app bar):** Screenshots confirm two different nav patterns (Edit Adventure: back + title + menu vs desktop: breadcrumb "Back to Explore / CityTrips / Sevilla"). **WaypointAppBar unification is more urgent** — treat as Medium–High.
- **Section 1.5 (duplicate WaypointSpacing):** Elevate to **High**; remains the most urgent unaddressed correctness issue (wrong spacing values).
- **Section 3.1 (theme / dark mode):** Builder is in scope (see Builder dark mode scope above).

---

## Original overview plan summary (still in force)

- **Visual:** Replace hardcoded colors in overview (and related SectionCard, AdventureTagsRow) with `context.colors` and design tokens; use WaypointSpacing and radius tokens.
- **Structure:** Builder: media → title → tags → stats → … → Travel Logistics → FAQ → **Plan Settings** (single block: sharing, activity type, accommodation type, season). Viewer/Trip: no Plan Settings; tags and public data only; trip uses displayName/displayImage/period overrides.
- **Plan Settings block:** One SectionCard at bottom of builder overview containing privacy, best season, activity category, accommodation type; all four already in plan/form state. Tags (AdventureTagsRow) stay visible to all and read from same state. **Reactivity:** Ensure the tag row updates when Plan Settings change. If AdventureTagsRow currently takes `activityCategory`, `accommodationType`, `bestSeasons` as constructor parameters, **wrap the call site** in `ListenableBuilder(listenable: _formState!, builder: (_, __) => AdventureTagsRow(activityCategory: _formState!.activityCategory, ...))` and pass current formState values inside the builder — do not restructure AdventureTagsRow itself.
- **Reusable components:** SectionCard for every section; AdventureTagsRow for tags; InlineEditable* for builder fields; ResponsiveContentLayout for desktop.

---

## Stats row — data sources

Builder and viewer overview both show a compact stats row (e.g. days, activities, stays). Use the same semantics; sources differ by mode:

| Stat | Builder source | Viewer source |
|------|-----------------|---------------|
| Days | `_formState!.activeVersion.daysCount` (or equivalent from active version) | `_adventureData!.selectedVersion?.durationDays` or `plan.versions.first.durationDays` |
| Activities | Waypoint count filtered by type across active version days | Same: count from selected version's days |
| Stays | Waypoint count filtered by accommodation type across active version days | Same: count from selected version's days |

**Activities clarification:** Use the **same type filter** currently used in `_buildQuickStats` (viewer implementation) as the reference — e.g. the same `WaypointType` enum value(s) or waypoint-type predicate. Match builder stats to viewer exactly so the two modes show consistent counts.

Implement the builder stats row using the builder source column; viewer overview already has `_buildQuickStats` — ensure it uses the viewer source column and that both use the same display format (e.g. "3 Days", "12 Activities", "1 Stay").

---

## Implementation order (revised)

1. **Enum displayName** — Check `lib/utils/` for existing display/label utils; extend if found, otherwise add [lib/utils/plan_display_utils.dart](lib/utils/plan_display_utils.dart). Apply displayName to all dropdowns (builder + [lib/presentation/builder/waypoint_edit_page.dart](lib/presentation/builder/waypoint_edit_page.dart)).
2. **Builder title truncation** — maxLines/overflow on builder overview title field.
3. **Theme/tokens in overview** — Replace hardcoded colors/spacing; builder follows theme (dark mode in scope). Do this **before** FAQ unification so the unified FAQ component is built with theme tokens from the start.
4. **FAQ label** — Commit to "Common Questions"; unify section chrome for FAQ across mobile and builder (using tokens from step 3).
5. **Plan Settings block** — Single SectionCard; move privacy, activity, accommodation, season into it; ensure AdventureTagsRow reactivity (wrap call site in ListenableBuilder if it takes constructor params).
6. **Stats row** — Add builder stats row using data sources in the table above; match Activities type filter to `_buildQuickStats` viewer implementation; keep same display format.
7. **Mobile/desktop parity** — Cream, labels, SectionCard alignment between desktop builder and [lib/presentation/builder/waypoint_edit_page.dart](lib/presentation/builder/waypoint_edit_page.dart). **WaypointCreamChip spacing:** In **parent layout only** (not inside the chip): where chip rows are built (overview tags, My Trips filters), use `Wrap(spacing: 8, runSpacing: 8)` so chips do not touch. Do not add internal margin to WaypointCreamChip (that would break intentionally adjacent layouts).
8. **Split passes (do separately).** Before starting 8b/8c: **audit `lib/components/waypoint/`** for existing unified card and app bar implementations.
   - **8a. WaypointSpacing unification** — High; do alone; different files and risk profile.
   - **8b. App bar unification** — Medium–High; shared WaypointAppBar or builder.
   - **8c. DRY card extraction** — Use or extend existing unified card from audit; create [lib/components/waypoint/unified_waypoint_card.dart](lib/components/waypoint/unified_waypoint_card.dart) only if absent.

---

## Files to touch (main)

- [lib/presentation/adventure/adventure_detail_screen.dart](lib/presentation/adventure/adventure_detail_screen.dart) — builder overview, viewer overview, title field, dropdowns (use enum displayName from plan_display_utils), Plan Settings block, FAQ/Transport section, stats row.
- [lib/components/adventure/adventure_tags_row.dart](lib/components/adventure/adventure_tags_row.dart) — theme colors; ensure used with formState so tags update when Plan Settings change.
- [lib/components/unified/section_card.dart](lib/components/unified/section_card.dart) — theme/spacing.
- **lib/utils/** — Add displayName extensions for ActivityCategory, AccommodationType (and any other plan-setting enums) in [lib/utils/plan_display_utils.dart](lib/utils/plan_display_utils.dart) or an existing display/label utils file if one exists. Single source for all dropdowns.
- [lib/presentation/builder/waypoint_edit_page.dart](lib/presentation/builder/waypoint_edit_page.dart) — Dropdowns use same enum displayName; align chrome with builder where appropriate.
- **WaypointCreamChip spacing:** **Parent layout only** — where chip rows are built (overview tags, My Trips filters), use `Wrap(spacing: 8, runSpacing: 8)`. Do not add margin inside [lib/components/waypoint/waypoint_cream_chip.dart](lib/components/waypoint/waypoint_cream_chip.dart). See implementation order step 7.

Linting: **park in a separate tech-debt ticket**; do not include in this plan.
