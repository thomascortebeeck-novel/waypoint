# Edit Waypoint Screen Redesign — Plan

This plan aligns the Edit Waypoint screen with the provided visual spec and reuses the same design tokens and DRY principles as the itinerary page and navigation drawer.

---

## 1. Design tokens (DRY — single source of truth)

**Recommendation:** Add a small set of **waypoint edit / form** tokens to the design system so the edit page, drawer, and itinerary card stay consistent. Reuse existing tokens where they already match.

| Spec / usage | Hex | Where to define | Notes |
|--------------|-----|-----------------|--------|
| Page background | `#FDFBF7` | Already `BrandingLightTokens.background` | Use `BrandingLightTokens.background` or `WaypointColors.background` |
| Input / pill background | `#F0E8D2` | Add to `BrandingLightTokens` or `SemanticColors` (e.g. `formFieldBackground`) | Same as drawer active pill; used for fields, category pills, chips, photo add button |
| Input / pill border | `#D4C5A0` | Add (e.g. `formFieldBorder`) | Used for outlined fields, pills, add-photo box |
| Dark brown (text, icons, selected border) | `#5D3A1A` | Already `BrandingLightTokens.secondary` | Use for labels, icons in fields, pill text, selected pill border |
| Label / heading dark | `#1A1D21` | Add or use `NeutralColors` (e.g. `textPrimary` 0xFF212529; 0xFF1A1D21 is slightly darker) | Spec calls out 1A1D21; consider adding `formLabel` or using existing primary text |
| Placeholder | `#A8A29E` | Already `BrandingLightTokens.hint` | Use for placeholder text |
| Forest green (app bar, save, selected chip) | `#2E7D32` | In use in builder_screen; add to `BrandingLightTokens` or `BrandColors` as e.g. `primaryGreen` if not already | App bar, Save button, selected Accommodation chip |

**Concrete DRY steps:**

- **Option A (minimal):** Use existing `lib/core/theme/colors.dart`: `BrandingLightTokens.background`, `secondary` (5D3A1A), `hint` (A8A29E). Add only what’s missing, e.g.:
  - `formFieldBackground = Color(0xFFF0E8D2)`
  - `formFieldBorder = Color(0xFFD4C5A0)`
  - Use `Color(0xFF2E7D32)` for app bar/save/selected chip (or add a named token if used in multiple places).
- **Option B:** If the drawer and itinerary card keep hardcoding `0xFFF0E8D2` / `0xFFD4C5A0`, refactor them to use the same tokens from `colors.dart` so the edit page and those components share one definition.

**Typography:** Use existing `WaypointTypography` (via `waypoint_typography.dart` → core typography): labels = `bodyMedium` weight 600 (or core `label`), input = `bodyMedium` weight 400 (or core `bodySmall`). Section titles (e.g. "Photos", "Accommodation Type") = 16px bold → e.g. `WaypointTypography.bodyMedium.copyWith(fontSize: 16, fontWeight: FontWeight.w600)` or a shared “section label” style.

---

## 2. App bar

- **Background:** `#2E7D32` (forest green).
- **Title:** "Edit Waypoint" (or "Add waypoint" in add mode) — centered, white, bold.
- **Leading:** White close (×) icon; `onPressed` → `context.pop()`.
- **Actions:** White trash/delete icon; only when `_isEditMode`; `onPressed` → `_delete`.

**Implementation:** Set `AppBar` `backgroundColor: Color(0xFF2E7D32)`, `foregroundColor: Colors.white`, `title: Text(..., style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))`, `centerTitle: true`. Use `Icons.close` and `Icons.delete_outline` (or `Icons.delete`) in white.

---

## 3. Page background and layout

- **Scaffold body background:** `#FDFBF7` → `BrandingLightTokens.background` or `WaypointColors.background`.
- **Padding:** 20px horizontal, 16px between sections, 8px between label and field.

**Implementation:** `Scaffold(backgroundColor: BrandingLightTokens.background, ...)`. Step 2 content: `SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: 20), child: Column(..., spacing 16 between sections; 8 between label and field)).`

---

## 4. Category selector (replace current chip row)

- **Replace:** Current horizontal chips ("Sleep" / "Eat & Drink" / "Do & See" / "See" / "Move") and the "Change category" link.
- **With:** Single row of **4 large rounded pill buttons**: **Eat**, **Stay**, **Fix**, **Do**.
  - **Stay** = current "Sleep" (accommodation).
  - **Eat** = restaurant.
  - **Fix** = service.
  - **Do** = attraction (treat `viewingPoint` as Do when loading/saving if needed).
- **Placement:** Near top of Step 2, below app bar, with 16px horizontal padding (already in page padding).
- **Pill style (all):** Background `#F0E8D2`, border `#D4C5A0`, text `#5D3A1A`, font weight medium.
- **Selected pill:** Same background `#F0E8D2`, **visible dark brown border** `#5D3A1A` (no green).
- Remove "Change category" entirely (or move subcategories into a separate sheet/modal if needed later).

**Type mapping:**

- Eat → `WaypointType.restaurant`
- Stay → `WaypointType.accommodation`
- Fix → `WaypointType.service`
- Do → `WaypointType.attraction` (when user selects Do, set `_selectedType = WaypointType.attraction`; if existing waypoint is `viewingPoint`, show "Do" as selected and optionally map to attraction on save).

**Implementation:** Replace `_buildCategoryRow()` with a `Row` of 4 `Material`/`InkWell` pills: same height (e.g. 44), `BorderRadius.circular(22)`, `BoxDecoration` with `color: formFieldBackground`, `border: Border.all(color: isSelected ? 5D3A1A : D4C5A0, width: isSelected ? 2 : 1)`. No icons required in spec; text only "Eat", "Stay", "Fix", "Do". Use `Expanded` or `Flexible` so they share width.

---

## 5. Photos section

- **Label:** "Photos", bold, `#1A1D21`, 16px (section label style).
- **Thumbnails:** 90×90 px rounded squares (e.g. `BorderRadius.circular(12)`). Small × dismiss badge: dark circle, white ×, top-right.
- **Add button:** 90×90 px rounded square, background `#F0E8D2`, border `#D4C5A0` (dashed or solid), camera-plus icon and "Add" label below in `#5D3A1A`.

**Implementation:**

- Keep existing logic for `_currentPhotoUrls`, `_photoBytes`, `_loadingPhoto`, `_addPhoto`, and remove-by-index.
- Change thumbnail size from 80 to 90; use same Stack + ClipRRect + Positioned dismiss (badge: dark circle + Icons.close white).
- Add-photo box: 90×90, `BoxDecoration(color: 0xFFF0E8D2, border: Border.all(0xFFD4C5A0), borderRadius: 12)`, `Column(mainAxisSize: min)` with `Icon(Icons.add_a_photo, color: 0xFF5D3A1A)` and `Text('Add', style: TextStyle(..., color: 0xFF5D3A1A))`.
- When no photos, show the section label and the add button only (no empty list).
- Use `WaypointTypography` for "Photos" label (section style).

---

## 6. Form fields (Name, Address, Description, Phone, Rating, Price)

- **Labels:** Bold, `#1A1D21`, 14px, 8px above field → use `WaypointTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1D21))` or core `label` with fontSize 14.
- **Input containers:** Full box style (no underline). Background `#F0E8D2`, border 1px `#D4C5A0`, `borderRadius: 12`.
- **Placeholder:** `#A8A29E` (BrandingLightTokens.hint).
- **Icons inside fields (e.g. map pin, phone, star, dollar):** `#5D3A1A`.
- **Description:** Multiline, min-height ~100px.
- **Phone and Rating:** Side by side in a `Row`, 50/50 (e.g. `Expanded` each), with same container styling.

**Implementation:**

- Create a **reusable styled wrapper** (e.g. `_CreamTextField` or a shared `WaypointFormField` in `lib/components/` or `lib/presentation/widgets/`) that applies:
  - Outer `Container`/`InputDecoration`-like box: `decoration: BoxDecoration(color: 0xFFF0E8D2, border: Border.all(0xFFD4C5A0), borderRadius: 12)`, no underline.
  - `hintStyle: TextStyle(color: BrandingLightTokens.hint)`.
  - `prefixIcon` color `0xFF5D3A1A` when used.
- Use this for: Name, Address, Description (minLines/maxLines + min height), Phone, Rating, Price (and Website if kept). Label above each: 8px gap, then the wrapper.
- **Phone + Rating row:** One `Row` with two `Expanded` children; each has label + 8px + styled field. Rating field: prefix icon star, `#5D3A1A`.
- **Price field:** Label "Price Estimation (USD)", dollar icon in `#5D3A1A`. Keep `_estimatedPriceController` and optional min/max if needed; spec shows single "145.00" style field.
- Remove or restyle any `OutlineInputBorder` / default Material underline; use only the full-box cream style.

**Optional DRY:** If itinerary or other screens need the same “cream box” input, move the wrapper to a shared widget (e.g. `lib/widgets/waypoint_form_field.dart`) and use it here and there.

---

## 7. Accommodation Type chips (below price)

- **Section label:** "Accommodation Type", bold `#1A1D21`, 16px.
- **Chips:** Background `#F0E8D2`, border `#D4C5A0`, text `#5D3A1A`, `borderRadius: 20` (pill).
- **Selected chip:** Background `#2E7D32`, white text, no border.

**Implementation:** Keep `_buildAccommodationTypeRow()` and `POIAccommodationType` + `getPOIAccommodationTypeLabel`. Replace raw `ChoiceChip` with custom-styled chips: unselected → cream bg + D4C5A0 border; selected → 2E7D32 bg, white text. Use `Wrap` with spacing 8, runSpacing 8. Only show when `_selectedType == WaypointType.accommodation`.

---

## 8. Save button

- Full width, height 52px, background `#2E7D32`, white text "✓ Save Changes" (or "Add place to the list" in add mode), `borderRadius: 28` (pill), 16px horizontal margins (match page padding).

**Implementation:** Replace current `FilledButton` with same semantics; `style: FilledButton.styleFrom(backgroundColor: Color(0xFF2E7D32), foregroundColor: Colors.white, minimumSize: Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)))`, padding horizontal 16. Child: Row with checkmark icon + text.

---

## 9. Other sections (unchanged or minor)

- **Back to search (add mode):** Keep below app bar or below category row; style to match (e.g. text button in 5D3A1A or neutral).
- **Eat / Attraction / Sight / Service subcategory rows:** Keep `_buildEatCategoryRow`, `_buildAttractionCategoryRow`, etc.; restyle chips to match Accommodation (cream unselected, green selected) for consistency.
- **Meal time / Activity time dropdowns:** If kept, wrap in same cream box style or use a dropdown style that matches (background F0E8D2, border D4C5A0).
- **Reviews section:** Optional; no spec change. If kept, use same label/body typography and neutral colors.
- **Website field:** Spec doesn’t mention it; keep or remove per product. If kept, use same cream field style.

---

## 10. Implementation order

1. **Tokens (optional but recommended):** Add `formFieldBackground`, `formFieldBorder` (and optionally app bar green) to `lib/core/theme/colors.dart`. Refactor `stippl_navigation_drawer.dart` (and optionally `waypoint_itinerary_card.dart`) to use them so edit page and drawer/card stay in sync.
2. **App bar:** Colors and title/leading/actions as above.
3. **Scaffold background** and **Step 2 padding** (20 h, 16 between sections, 8 label–field).
4. **Category selector:** Replace with 4 pills (Eat, Stay, Fix, Do), type mapping, remove "Change category".
5. **Photos:** Label, 90×90 thumbnails + dismiss badge, add button styling.
6. **Form fields:** Shared cream-box wrapper; apply to Name, Address, Description (min height), Phone, Rating (side-by-side with Phone), Price; icons and placeholders.
7. **Accommodation Type chips:** Restyle to cream/green.
8. **Save button:** Pill shape, height, color, label.
9. **Subcategory rows (Eat, Attraction, etc.):** Restyle chips to match Accommodation for visual consistency.
10. **Add-mode title:** Use "Add waypoint" or "Add place" when not edit mode so app bar title matches spec in both modes.

---

## 11. DRY summary vs itinerary / drawer

- **Colors:** Use `BrandingLightTokens.background` (FDFBF7), `secondary` (5D3A1A), `hint` (A8A29E). Add form tokens (F0E8D2, D4C5A0) once and reuse in edit page, drawer active state, and any itinerary form-like UI.
- **Typography:** Use `WaypointTypography` (bodyMedium 600 for labels, 400 for input) and core typography; one section-label style (16px bold 1A1D21) for "Photos", "Accommodation Type", "Waypoint Category".
- **Components:** Consider a shared `WaypointFormField` (cream box + label) and a shared `WaypointPillChip` (cream/green chip) used by edit page and any future forms or filters. Drawer and itinerary card already use similar creams; referencing the same tokens keeps them aligned without duplicating hex values.

This plan gives a clear, step-by-step redesign that matches the spec and aligns the Edit Waypoint screen with the rest of the app’s visual system.
