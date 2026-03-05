---
name: ""
overview: ""
todos: []
isProject: false
---

# FAQ, Transport, CTA, Tags — Revised Plan (reality-checked)

**Status:** This plan trims completed work and fixes plan-specific issues. Only outstanding items are in the implementation order.

---

## Already done (remove from scope)


| Item                                | Evidence                                                                            |
| ----------------------------------- | ----------------------------------------------------------------------------------- |
| Tags position                       | Tags (City Trips, Comfort) are above the image in the live viewer.                  |
| Stats position                      | Stats row (3 days, 3 restaurants, 2 stays) sits between image and description.      |
| Sticky bottom bar for free plans    | "FREE + Start Trip" bar visible throughout scroll.                                  |
| Travel Logistics in overview        | Section exists with transport card (icons, title, full description).                |
| About the Creator role + plan count | "Adventure Creator • 2 Plans" is live; static label done.                           |
| Itinerary carousel                  | Day 1/2/3 carousel with images and day titles is live.                              |
| Location in header, not in tag row  | "Sevilla, Sevilla, Spanien" in header; tag row shows only activity + accommodation. |


---

## Outstanding work (implementation order)

### 1. Reduce "More by" card size (high impact)

**Problem:** Image 3 shows the "More by Thomas" card as a full-width, full-featured card (~320×500+), not a compact horizontal peek. It currently behaves like a standard AdventureCard, not compact.

**Target:** Make the section feel like a horizontal peek with 2–3 cards partially visible.

**Content decision (pick one explicitly):**

- **Option A (recommended):** Target **160×220**. To fit six content layers (image, badge, location, tags, description, rating) without overflow, **drop description excerpt and rating row** from the compact variant when used in "More by". Keep only: image, title, location, and tag chips. This makes the card a true peek; implement by extending `AdventureCardVariant.compact` so the bottom section omits description and `_buildRatingRow` in that context.
- **Option B:** Keep all content; use **~260px height** and accept 1–2 cards visible (wider cards). Do not use 160×220 with full content — it will overflow or be cut.

**Files:** `[lib/presentation/adventure/adventure_detail_screen.dart](lib/presentation/adventure/adventure_detail_screen.dart)` (carousel `SizedBox` width/height); `[lib/presentation/widgets/adventure_card.dart](lib/presentation/widgets/adventure_card.dart)` (compact variant: either trim content per Option A or tighten padding/fonts for Option B).

---

### 2. Apply shared icon map to "More by" card tags

**Problem:** "More by" cards still show emoji in tags (e.g. Skiing, Comfort). Shared IconData must apply to tags **inside AdventureCard** when used in the "More by" carousel.

**Action:** When the shared activity/accommodation IconData map is introduced (see item 3), ensure **AdventureCard**’s `_buildBadgeRow` / `_buildInfoBadge` use that map instead of emoji for activity and accommodation. So: same icon source for detail page tags, explore, and cards (including compact "More by" cards).

---

### 3. Shared activity and accommodation IconData

**Goal:** One source of truth for activity and accommodation icons; use simple abstract icons (e.g. Material) everywhere.

- Add `ActivityCategory` → `IconData` and `AccommodationType` → `IconData` (e.g. in `[lib/utils/activity_config.dart](lib/utils/activity_config.dart)` or new `activity_icons.dart`). Examples: cityTrips → `Icons.location_city`, comfort → `Icons.hotel`, adventure → `Icons.terrain` or `Icons.camping`.
- **AdventureTagsRow:** Use IconData instead of emoji for activity and accommodation.
- **Season chips:** Use `**Icons.calendar_month`**; the text label carries the range (e.g. "Feb – Mar"). Do not keep emoji for season — the icon is generic calendar, the label provides the month-range meaning.
- **Location:** If still shown as a chip anywhere, keep existing treatment or use `Icons.location_on`; no emoji.
- **Explore screen:** Refactor `_getCategoryIcon` to use the shared map.
- **AdventureCard:** Use the same map in badge row so "More by" and all other cards show the same icons (addresses item 2).

---

### 4. FAQ styling (green chevron)

**Problem:** Common Questions section uses plain dark chevrons; plan specifies green chevrons.

**Action:** In `_buildFAQItem` (`[adventure_detail_screen.dart](lib/presentation/adventure/adventure_detail_screen.dart)`), set `**iconColor`** and `**collapsedIconColor`** on `ExpansionTile` to `Theme.of(context).colorScheme.primary` (green). Do **not** use `themeColor` — it is not a valid `ExpansionTile` property and will have no effect. Add dividers between FAQ items if not already present.

---

### 5. Prepare tab transport placeholder fix

**Current:** Overview Travel Logistics is done. Prepare tab still has a "Transportation" SectionCard with placeholder text ("Transportation options will be displayed here").

**Action:** Replace placeholder with the same read-only transport UI as overview: list `selectedVersion?.transportationOptions` and use the same read-only card (e.g. `_buildTransportationOptionReadOnly` or an extracted shared widget). No data structure changes; transport already supports multiple options and types.

**Gating:** If the Prepare tab is accessible to non-purchasers, apply the same limited preview as FAQ (e.g. show first N transport options or a placeholder) for consistency. If Prepare is post-purchase only, show the full list.

**Note:** Keep "analysis" as a one-liner: data structure is fine; only this UI fix is needed.

---

### 6. Creator rating (4.9 (24 reviews))

**Problem:** Goal (Image 2) shows star rating and review count in About the Creator; current UI (Image 3) does not show rating.

**Action:** First verify whether `PlanService.getCreatorStats(creatorId)` (or equivalent) exists and returns `{ averageRating, totalReviews }`. If it exists, ensure `_buildOwnerCard` uses it and displays the rating row when `totalReviews > 0`; do not block the rest of the card on this fetch — show name, role, plan count, bio, and "More by" immediately; add the rating row when the future resolves. If `getCreatorStats` does **not** exist, implement it (e.g. aggregate from plan-level review stats or a `getReviewsByCreator(creatorId)`-style API, same pattern as plan reviews). Then in `_buildOwnerCard`, use a `FutureBuilder` (or existing overview future) for creator stats; render the rating row only when the future resolves with `totalReviews > 0`; keep the rest of the card visible without waiting.

---

### 7. CTA "Start Trip" text color

**Goal:** Button text in yellowish-white (cream) instead of pure white.

**Correct token:** Do **not** use `kDrawerAndPlanPageBackground` from the drawer for button text — that creates a wrong dependency. Use `**context.colors.surface`** or **BrandingLightTokens** (e.g. background/surface) so the cream color comes from the design system.

**Contrast:** Before implementing, verify that the cream color has sufficient contrast (≥4.5:1) on the green button background. If it does not, keep white and document the decision.

**Files:** `[adventure_detail_screen.dart](lib/presentation/adventure/adventure_detail_screen.dart)` `_buildMobileBuyPlanBar`: set `foregroundColor` for the Start Trip (and Buy) button to the chosen token.

---

### 8. Tag spacing above the image

**Observation:** Image 1 shows a large gap (roughly 3× normal spacing) between "By thomas.cortebeeck93" and the "City Trips / Comfort" chips. This is likely excessive.

**Action:** Check `_buildCenteredHeader` and the sliver/content that contains `AdventureTagsRow` (e.g. the main column in the overview). If there is a `SizedBox(height: X)` or equivalent padding between the header block and the tags row with **X > 16**, reduce it to **12 or 8**. Do not add more vertical padding.

---

## Summary of plan-specific fixes


| Issue               | Correction                                                                                                                        |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Creator card size   | Pick Option A (160×220, drop description + rating in compact) or Option B (~260 height, 1–2 cards visible); see item 1.           |
| FAQ chevron         | Use **iconColor** and **collapsedIconColor** on ExpansionTile (not themeColor).                                                   |
| Season chips        | Use **Icons.calendar_month**; text label carries range (e.g. "Feb – Mar"); no emoji.                                              |
| Tag spacing         | In header/sliver before AdventureTagsRow, if gap > 16 reduce to 12 or 8.                                                          |
| CTA color reference | Use **context.colors.surface** (or BrandingLightTokens), not kDrawerAndPlanPageBackground.                                        |
| Transport section   | Separate "analysis" (one line: no schema change) from "Prepare tab fix"; note gating for non-purchasers.                          |
| "More by" icons     | Explicitly apply shared icon map to tags inside AdventureCard (compact carousel).                                                 |
| Creator rating      | If getCreatorStats missing, aggregate from reviews; FutureBuilder; show rating row only when totalReviews > 0; do not block card. |


---

## Revised implementation order (outstanding only)


| #   | Item                                                                                                                                              | Status |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 1   | **Shared activity/accommodation IconData** — add map; use in AdventureTagsRow, explore, and AdventureCard badge row (covers "More by" card tags). | Done   |
| 2   | **Reduce "More by" card** — 160×220 (Option A: drop description + rating in compact).                                                             | Done   |
| 3   | **FAQ** — green chevron (`iconColor` / `collapsedIconColor`) and dividers.                                                                        | Done   |
| 4   | **Prepare tab** — replace transport placeholder with read-only list.                                                                              | Done   |
| 5   | **Creator rating** — getCreatorStats + UI already wired; no change.                                                                               | Done   |
| 6   | **CTA text color** — `foregroundColor: context.colors.surface` for Start Trip and Buy.                                                            | Done   |
| 7   | **Tag spacing** — header/tags gap reduced to 12 in `_buildCenteredHeader` and overview column.                                                    | Done   |


