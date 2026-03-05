# DRY components, branding optimization, and Cursor rules

## Scope: the three pages

- **waypoint_edit_page.dart** — form with section labels, cream chips, field sections, Save button, constrained layout.
- **waypoint_detail_page.dart** — hero, tabs, overview (info rows), details (label/value), bottom bar (Edit + Go there), constrained tab content.
- **itinerary_review_screen.dart** — scrollable content with Center > ConstrainedBox(pageMaxWidth).

---

## Execution (recommended split)

- **Issue 1 — Component extraction (DRY):** Create and refactor to shared components (Part 1). Concrete, immediate; do this first.
- **Issue 2 — Cursor rules and documentation:** Update BRANDING_GUIDELINES, add Cursor rules (Parts 2–3) *after* components exist, so docs and rules are written from the real extracted APIs. Governance work does not block extraction; extraction unblocks accurate docs.

---

## Part 1: Reusable components (DRY)

**Existing component to reuse:** **WaypointCreamChip** is already in `lib/components/waypoint/waypoint_cream_chip.dart`. Migrate other screens to use it where chips are needed — e.g. the category picker sheet (`waypoint_category_picker_sheet.dart`) currently has its own chip styling and should be refactored to use WaypointCreamChip.

**First extraction target:** The hero in **waypoint_detail_page.dart** (`_buildHeroCarousel`) is already implemented and clean. Extract it first into `lib/components/` (e.g. **WaypointDetailHero** or **DetailHeroCarousel**) — same behavior (PageView, gradient, category badge, title, address, dots, close), then reuse or adapt elsewhere. No design guesswork; the code is the spec.

**Shared pattern — inline editing:** Tap-to-edit in the hero (e.g. tap name → quick-edit bottom sheet) is a reusable pattern. When extracting the hero, keep an optional `onTitleTap` (or similar) so other detail screens can use the same “tap field → sheet” pattern for other fields.

### 1.1 WaypointDetailHero (extract first)
- **Source:** `_buildHeroCarousel` in waypoint_detail_page.dart (already implemented).
- **New file:** e.g. `lib/components/waypoint/waypoint_detail_hero.dart`
- **API:** Image URLs, title, optional subtitle (address), category label, optional close callback, optional `onTitleTap` for inline-edit pattern. Renders PageView, gradient overlay, category badge, dots, back/close button.
- **Then:** Refactor waypoint_detail_page to use it; reuse on other detail screens if needed.

### 1.2 WaypointSectionLabel
- **New file:** `lib/components/waypoint/waypoint_section_label.dart`
- **API:** `WaypointSectionLabel(String label, {EdgeInsetsGeometry? padding})`
- **Style:** fontSize 14, bold, BrandingLightTokens.formLabel, padding bottom 8.
- **Replace:** `_buildSectionLabel` in waypoint_edit_page; use in waypoint_detail_page for section headings.

### 1.3 WaypointFormFieldSection
- **New file:** `lib/components/waypoint/waypoint_form_field_section.dart`
- **API:** `WaypointFormFieldSection({required String label, required Widget child})`
- **Layout:** label (bold 14 formLabel), SizedBox(8), child.
- **Replace:** all `_formFieldSection('Name', ...)` in waypoint_edit_page.

### 1.4 WaypointCreamCard
- **New file:** `lib/components/waypoint/waypoint_cream_card.dart`
- **API:** `WaypointCreamCard({required List<Widget> children, EdgeInsetsGeometry? padding})`
- **Style:** color BrandingLightTokens.surface (#F2E8CF), borderRadius 16, border formFieldBorder.
- **Use in:** waypoint_detail_page Overview tab.

### 1.5 WaypointInfoRow
- **New file:** `lib/components/waypoint/waypoint_info_row.dart`
- **API:** `WaypointInfoRow({required String label, required String value, bool showDivider = true})`
- **Style:** Row spaceBetween; label secondary 14; value formLabel 14 w600; Divider when showDivider.
- **Replace:** _OverviewRow / _buildInfoRow in waypoint_detail_page.

### 1.6 WaypointDetailSection
- **New file:** `lib/components/waypoint/waypoint_detail_section.dart`
- **API:** `WaypointDetailSection({required String label, required String value})`
- **Style:** label 12 w600 hint; value 16 formLabel height 1.4; padding bottom 20.
- **Replace:** _DetailRow in waypoint_detail_page Details tab.

### 1.7 WaypointActionBar
- **New file:** `lib/components/waypoint/waypoint_action_bar.dart`
- **API:** `WaypointActionBar({Widget? secondaryButton, required Widget primaryButton})` or named params for Edit + primary CTA.
- **Style:** background BrandingLightTokens.background, top border formFieldBorder, safe area; secondary = OutlinedButton appBarGreen; primary = FilledButton.icon appBarGreen min height 54 borderRadius 28.
- **Use in:** waypoint_detail_page bottom bar.

### 1.8 WaypointConstrainedScroll
- **New file:** `lib/components/waypoint/waypoint_constrained_scroll.dart`
- **API:** `WaypointConstrainedScroll({required Widget child, double maxWidth = LayoutTokens.formMaxWidth, EdgeInsets? padding})`
- **Implementation:** SingleChildScrollView > Center > ConstrainedBox(maxWidth) > Padding > child.
- **Replace:** inline Center/ConstrainedBox/Padding in waypoint_edit_page steps, itinerary_review_screen, waypoint_detail_page tab content.

### 1.9 WaypointCategoryBadge
- **New file:** `lib/components/waypoint/waypoint_category_badge.dart`
- **API:** `WaypointCategoryBadge({required WaypointType type})` or `WaypointCategoryBadge.label(String text)`
- **Style:** padding 8×3, appBarGreen, borderRadius 4, white 11 w700 letterSpacing 0.8.
- **Use in:** waypoint_detail_page hero; any list/card showing category.

### 1.10 Exports
- Export all new components (and WaypointCreamChip) from `lib/components/components.dart` or a dedicated waypoint export.

---

## Part 2: Branding guidelines optimization

**Single import path:** Use **waypoint_colors.dart** as the single import for all screens. It re-exports and extends `lib/core/theme/colors.dart` (BrandingLightTokens, etc.) and adds `WaypointColors` aliases. One import path everywhere — no mixing “colors.dart here, waypoint_colors there,” so the “single source” promise holds and developers (and AI) don’t have to guess which file to import.

### 2.1 BRANDING_GUIDELINES.md
Add **"Stippl / waypoint form & view"** subsection (after components exist, so it reflects real APIs):
- **Import:** `package:waypoint/theme/waypoint_colors.dart` for all color tokens (BrandingLightTokens, WaypointColors).
- **Tokens:** BrandingLightTokens for waypoint/edit/detail/itinerary UI; no hardcoded hex for brand colors.
- **Layout:** LayoutTokens.formMaxWidth (600), LayoutTokens.pageMaxWidth (800); import `package:waypoint/core/theme/layout_tokens.dart`.
- **Categories:** WaypointCategoryLabels / fromType only.
- **Cream:** surface (#F2E8CF) for cards; formFieldBackground (#F0E8D2) for inputs/chips.
- **Buttons:** Primary = appBarGreen, white, min height 52–54, radius 28; Secondary = outline appBarGreen.
- **Tab bar:** labelColor appBarGreen, unselectedLabelColor hint, indicatorColor appBarGreen, background.
- **Radius:** Prefer WaypointRadius (lg for cards); 28 for pill buttons.
- **Where it lives:** waypoint_colors.dart (single import); layout_tokens.dart; waypoint_category.dart; radius.dart.

### 2.2 colors.dart / waypoint_colors.dart
Keep BrandingLightTokens in core/theme/colors.dart; waypoint_colors.dart re-exports and adds WaypointColors. Add one-line comments on BrandingLightTokens for surface vs formFieldBackground.

---

## Part 3: Cursor rules

(Written after components are extracted, so rules reference real component names and imports.)

### 3.1 waypoint-branding.mdc
- **Path:** `.cursor/rules/waypoint-branding.mdc`
- **alwaysApply:** true (or globs for Dart)
- **Content (concrete so an AI can act without guessing):**
  - **Colors:** Use design tokens only. Import `package:waypoint/theme/waypoint_colors.dart`; use BrandingLightTokens (e.g. background, surface, appBarGreen, formLabel, secondary, hint, formFieldBorder, formFieldBackground) and/or WaypointColors. No hardcoded hex for brand colors.
  - **Layout:** Import `package:waypoint/core/theme/layout_tokens.dart`; use LayoutTokens.formMaxWidth (600) for forms and narrow detail content, LayoutTokens.pageMaxWidth (800) for wider content when applicable.
  - **Categories:** WaypointCategoryLabels / fromType only. WaypointRadius where applicable. Reference BRANDING_GUIDELINES.md.

### 3.2 waypoint-ui-components.mdc
- **Path:** `.cursor/rules/waypoint-ui-components.mdc`
- **globs:** `**/presentation/**/*.dart` or alwaysApply false with note
- **Content:** Prefer existing waypoint components: **WaypointCreamChip** (for category/chip UIs — migrate category picker sheet and any custom chip styling to it), WaypointDetailHero, WaypointSectionLabel, WaypointFormFieldSection, WaypointCreamCard, WaypointInfoRow, WaypointDetailSection, WaypointActionBar, WaypointConstrainedScroll, WaypointCategoryBadge when building waypoint/edit/detail or form-style pages; do not reimplement as private widgets.

---

## Implementation order

**Principle:** Extract components first; write documentation and Cursor rules from the real extracted code so the docs describe actual APIs and imports.

1. **Extract hero first:** Move `_buildHeroCarousel` from waypoint_detail_page to WaypointDetailHero (1.1); refactor page to use it. Keep optional `onTitleTap` for inline-edit pattern.
2. Create remaining shared components (1.2–1.9), then exports (1.10).
3. Refactor waypoint_edit_page to use new components.
4. Refactor waypoint_detail_page to use new components (hero already done).
5. Migrate category picker sheet (and any other custom chip UI) to WaypointCreamChip.
6. Refactor itinerary_review_screen to use WaypointConstrainedScroll.
7. **Then:** Update BRANDING_GUIDELINES.md (single import path, layout, tokens) and colors.dart/waypoint_colors comments.
8. Add Cursor rules (3.1, 3.2) with concrete import paths and component names.
9. Run analyzer/linter on touched files.
