# Plan Overview Page Alignment (REVISED)

**Revisions:** Corrected tags/stats positions (were inverted vs goal), added About the Creator fields audit, Highlights disposition, location chip decision, inline vs sticky price card decision, and canonical section order table.

---

## Canonical section order (goal — Image 3)

**Note on Image 3:** Image 3 is the **builder** view (Edit Adventure app bar, Upload placeholder, Add New FAQ, Add Transport Option, Plan Settings). The goal layout (section order and read-only vs editable) applies as follows: **viewer/trip** show the same section order but with read-only content (real cover image, no add buttons); **builder** shows editable versions with add/delete actions. Sections 8–10 (Travel Logistics, Common Questions; and Itinerary in terms of editability) are **read-only in viewer/trip** — no "Add Transport Option" or "Add New FAQ" buttons; builder shows editable versions with those actions. Cover photo: viewer shows the real plan image; builder shows upload placeholder when empty.

This table is the single source of truth. All reordering and new sections must match it. **Section order applies to the main content column on both mobile and desktop;** the desktop price sidebar is unchanged (sticky right). On desktop, tags also move above the image in the main column.

| Position | Section |
|----------|--------|
| 1 | Title + location text |
| 2 | Creator attribution (avatar + name) + **location as plain text** (not a chip) |
| 3 | **Tags** (activity, accommodation, season only; no location chip) — **before image** |
| 4 | Image gallery / cover photo (viewer: real image; builder: upload placeholder when empty) |
| 5 | **Stats row** (days, activities, stays) — **before description** |
| 6 | About / description |
| — | ~~Highlights~~ **Not shown in viewer** (removed from viewer overview; keep in builder if needed) |
| 7 | About the Creator (full name, role, plan count, rating, bio, More by carousel) |
| 8 | Itinerary carousel + View All |
| 9 | Travel Logistics (viewer: read-only list; builder: editable + Add Transport Option) |
| 10 | Common Questions (viewer: read-only accordion; builder: editable + Add New FAQ) |
| 11 | Plan Settings (builder only) |

**Fixes from original plan:**
- **Tags:** Move **above** image (after title/creator attribution), not below. Goal: Title → Creator → Tags → Cover image.
- **Stats:** Keep **between** image and description. Do **not** move stats below description. Goal: Image → Stats → About (description).

---

## 1. Tags position (corrected)

- **Move AdventureTagsRow** to immediately after the **title + creator attribution** block, **before** the image gallery.
- In `_buildOverviewTab()`, the order at the top must be: **Title + location (if in main column) → Creator attribution → AdventureTagsRow → AdventureImageGallery → …**
- If title/creator are currently in the sliver header (`_buildCenteredHeader`), then the main column should start with **AdventureTagsRow** then **AdventureImageGallery**, so that visually (header + body) the order is title → creator → tags → image.

---

## 2. Stats position (corrected)

- **Do not move** _buildQuickStats below the description.
- **Keep** _buildQuickStats between the image gallery and the description block. Current behavior in the code (stats after image, before description) matches the goal; no change to stats position.

---

## 3. Remove duplicate CreatorCard

- In `_buildOverviewTab()`, **remove** the `FutureBuilder` that renders **CreatorCard** (the "CREATED BY" card) in the main column (lines ~6821–6835).
- Keep "Created by" only at the top: ensure **creator attribution** (avatar + "By {name}") is visible in the header/attribution area for both desktop and mobile (e.g. in `_buildCenteredHeader` or equivalent).

---

## 4. "About the Creator" block — complete specification

Goal (Image 3) shows a rich block, not just username + avatar. The plan must explicitly cover:

- **Full name** (e.g. "Thomas Cortebeeck") — not only username.
- **Role/subtitle** (e.g. "Adventure Architect • 12 Plans").
- **Star rating** (e.g. "4.9 (24 reviews)").
- **Bio/description** (shortBio).
- **"More by [Creator]"** carousel of other plans.

**UserModel audit** ([`lib/models/user_model.dart`](lib/models/user_model.dart)):

- **displayName** — exists; use for full name in "About the Creator" (and in top attribution if desired).
- **shortBio** — exists; use for creator description.
- **createdPlanIds** — exists; **plan count = createdPlanIds.length** (no new field).
- **Role** — no field. **Decision: use a static label** "Adventure Creator" (zero backend work). Do not add UserModel.role unless product later requires custom role text.
- **Rating / review count** — not on UserModel. **Decision: add a dedicated fetch** — `UserService.getCreatorStats(creatorId)` (or equivalent on an existing service) that returns `{ averageRating, reviewCount }`, computed server-side or via Firestore aggregation (e.g. from reviews collection or plan review stats by creator). The overview calls this when building the About the Creator block and displays the returned rating and count. No change to UserModel schema.

**Implementation:** Extend `_buildOwnerCard()` (or equivalent) to show: displayName, static subtitle "Adventure Creator • {createdPlanIds.length} Plans", rating + review count from getCreatorStats(creatorId), shortBio, then "More by [Name]" carousel using `PlanService.getPlansByCreator(creatorId)`.

---

## 5. Highlights section — disposition

- **Goal (Image 3)** does not show a "Highlights" section.
- **Current (Image 2)** shows "Highlights / No highlights yet" between description and "About the creator."
- **Decision:** **Remove the Highlights section from the viewer overview** to match the goal. Do not render _buildHighlightsSection in _buildOverviewTab() when in viewer/trip mode. Keep Highlights in the builder overview if it exists there.

---

## 6. Location chip — decision

- **Goal (Image 3):** Location appears as **plain text** under the creator name ("sevilla, spain"), not as a tag chip.
- **Current (Image 2):** "Sevilla, Sevilla, Spanien" appears as a chip inside AdventureTagsRow with "City Trips" and "Comfort."
- **Decision:** **Promote location to the header** and **remove it from the tag row** in the overview. Show location as plain text under the creator name in the title/attribution block (e.g. in _buildCenteredHeader or the main column header). When building AdventureTagsRow for the viewer overview, pass `location: null` (or equivalent) so the row only shows activity category, accommodation type, and season chips. No location chip in the row.

---

## 7. Inline price card vs bottom bar (mobile)

- **Goal (Image 3):** Price and CTA appear as a **sticky bottom bar** only on mobile.
- **Decisions:** (1) The bottom bar must show for free plans in viewer mode so the CTA is always present. (2) On mobile, when showing the overview and the sticky buy bar is visible, **do not** render the inline price card in the main column — remove or gate the LayoutBuilder that currently shows _buildPriceCard on mobile so the price is not shown twice. Desktop keeps the sidebar unchanged; mobile has only the bottom bar.

---

## 8. Travel Logistics

- Unchanged from original plan: add a "Travel Logistics" / "How to Get There" section in the overview, after Itinerary and before Common Questions, using `selectedVersion?.transportationOptions` and read-only cards. Reuse display logic from builder where possible (DRY).

---

## 9. Itinerary carousel

- Unchanged from original plan: add an "Itinerary" section with horizontal day cards (image + "Day N: title") and "View All" link, using `_adventureData?.selectedVersion?.days` and reusing DayHeroImage or a compact day card.

---

## 10. "More by Thomas" carousel

- Use `PlanService.getPlansByCreator(creatorId)`, exclude the current plan, and show a horizontal list of plan cards in the "About the Creator" block.
- **Card format (committed):** Reuse **AdventureCard** ([`lib/presentation/widgets/adventure_card.dart`](lib/presentation/widgets/adventure_card.dart)) with **AdventureCardVariant.standard**, in a horizontal ListView with fixed width (e.g. 280) per card — the same pattern as the creator profile screen's "Created plans" swimming lane ([`lib/presentation/creator/creator_profile_screen.dart`](lib/presentation/creator/creator_profile_screen.dart) lines ~299–327). This keeps the "More by" carousel DRY with the rest of the app.

---

## Revised implementation order

1. **Fix tags position** — Move AdventureTagsRow **above** image gallery (after title/creator attribution). Do not place tags below image. (Stats remain between image and description; no step for that.)
2. **Remove duplicate CreatorCard** — Delete the CreatorCard block from the main column; ensure creator attribution at top (header) for mobile and desktop.
3. **Location in header, not in tag row** — Promote location to the title/attribution block as plain text under creator name; pass location null (or omit) to AdventureTagsRow in viewer overview so the row shows only activity, accommodation, and season chips.
4. **Remove Highlights from viewer overview** — Do not render _buildHighlightsSection in _buildOverviewTab() for viewer/trip mode; keep in builder if present.
5. **Expand "About the Creator"** — Full name (displayName), static role "Adventure Creator", plan count (createdPlanIds.length), rating + review count via UserService.getCreatorStats(creatorId), bio (shortBio), "More by [Name]" carousel using AdventureCard (standard variant, 280px width) and PlanService.getPlansByCreator(creatorId).
6. **Mobile CTA and inline price** — Show bottom bar for free plans (viewer). On mobile, hide inline price card in overview when sticky bottom bar is shown so price is not duplicated.
7. **Travel Logistics** — Add section; implement read-only transport options.
8. **Itinerary carousel** — Add section with day cards and "View All."

---

## Files to touch (summary)

- [`lib/presentation/adventure/adventure_detail_screen.dart`](lib/presentation/adventure/adventure_detail_screen.dart): Section order (tags above image; stats stay between image and description); remove CreatorCard block; add title/creator/location in header; remove Highlights from viewer overview; add Itinerary section; add Travel section; extend _buildOwnerCard (displayName, static "Adventure Creator", plan count, getCreatorStats for rating, shortBio, More by carousel with AdventureCard); conditional inline price card on mobile; _buildMobileBuyPlanBar show for free (viewer).
- [`lib/components/adventure/adventure_tags_row.dart`](lib/components/adventure/adventure_tags_row.dart): Support omitted location (e.g. pass null so location chip is not shown when location is in header).
- [`lib/services/user_service.dart`](lib/services/user_service.dart) (or equivalent): Add `getCreatorStats(creatorId)` returning `{ averageRating, reviewCount }` (server-side or Firestore aggregation). Used by About the Creator block.
- [`lib/presentation/widgets/adventure_card.dart`](lib/presentation/widgets/adventure_card.dart): Reuse as-is for "More by" carousel (AdventureCard, variant standard).
- No change to [`lib/models/user_model.dart`](lib/models/user_model.dart) for role or rating (static label + service fetch).

---

## Summary of corrections

| Item | Original (wrong) | Corrected |
|------|------------------|-----------|
| Tags | After image | **Before image** (after title/creator) |
| Stats | After description | **Between image and description** (no move) |
| About the Creator | Only bio + More by | **+ Full name, static role "Adventure Creator", plan count, getCreatorStats() for rating, bio, More by carousel (AdventureCard standard)** |
| Highlights | Not mentioned | **Removed from viewer overview** |
| Location | Unspecified | **Promote to header (plain text); remove from tag row** |
| Inline price (mobile) | Not addressed | **Hide inline when sticky bar shown** (no double price) |
| Builder vs viewer | Implicit | **Image 3 = builder; sections 8–10 read-only in viewer; desktop order same as mobile, sidebar unchanged** |
