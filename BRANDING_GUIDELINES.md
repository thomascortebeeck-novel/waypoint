# Waypoint app — branding and theme guidelines

This document is the canonical reference for visual branding and theme tokens. It is linked from [architecture.md](architecture.md). Implementation lives in `lib/theme.dart`, `lib/core/theme/waypoint_theme.dart`, `lib/core/theme/colors.dart`, and related files under `lib/core/theme/`.

**Color import:** Use `package:waypoint/theme/waypoint_colors.dart` as the single import for UI color tokens (BrandingLightTokens, WaypointColors). Do not mix `colors.dart` and `waypoint_colors.dart` in the same feature; prefer one so the single-source promise holds.

**New screens:** Any new screen or tab (including Footprint/Climate) must use these tokens and the centered, max-width layout described in [.cursor/rules/page-layout.mdc](.cursor/rules/page-layout.mdc) (e.g. `WaypointSpacing.contentMaxWidth`, padding from WaypointBreakpoints/WaypointSpacing).

---

## Fonts

| Role       | Font family   | Usage                                      |
|-----------|----------------|--------------------------------------------|
| Primary   | **Fira Sans** | Headings, primary UI, buttons, labels      |
| Secondary | **Source Sans Pro** | Body copy, secondary text, descriptions |

Ensure both fonts are available in the project (e.g. via `google_fonts` or bundled assets) and applied through the app theme and text styles.

---

## Colors (light theme)

| Token           | Hex       | Usage |
|-----------------|-----------|--------|
| primary         | `#228B22` | CTAs, selected day tab, Add Waypoint button |
| on_primary      | `#FFFFFF` | Text on primary surfaces |
| secondary       | `#5D3A1A` | Secondary actions, secondary text |
| on_secondary    | `#FFFFFF` | Text on secondary surfaces |
| background      | `#F8F6F1` | Page background (warm off-white; match home) |
| surface         | `#F5F0E1` | Cards, elevated surfaces (light beige; match home) |
| on_surface      | `#212529` | Primary text on surface |
| error           | `#D62828` | Errors |
| on_error        | `#FFFFFF` | Text on error |
| accent          | `#E67E22` | Accent/orange highlights |
| divider         | `#D2B48C` | Dividers, borders |
| hint            | `#A8A29E` | Placeholder, hint text |
| primary_text    | `#212529` | Main text |
| secondary_text  | `#5D3A1A` | Secondary text |
| success         | `#386641` | Success states |

---

## Dark mode

The app supports light and dark theme. User preference is persisted via `ThemeProvider` (SharedPreferences) and applied in `main.dart` (`theme`, `darkTheme`, `themeMode`).

- **Light:** Use **LightModeColors** and **BrandingLightTokens** (see `lib/core/theme/colors.dart`). Theme is built in `lib/core/theme/waypoint_theme.dart` (`waypointLightTheme`) and `lib/theme.dart` (`lightTheme`).
- **Dark:** Use **DarkModeColors** (same file). Dark theme is `waypointDarkTheme` / `darkTheme`. Surfaces use dark backgrounds (e.g. `#1C1C1C`, `#121212`); primary uses a lighter green (`BrandColors.successGreen`).
- **Theme-aware widgets:** Prefer `Theme.of(context).colorScheme` and `Theme.of(context).brightness` so the same widget works in both modes. When you need explicit tokens, use `final isDark = Theme.of(context).brightness == Brightness.dark` then `isDark ? DarkModeColors.x : LightModeColors.x` (see `lib/components/inputs/waypoint_text_field.dart`, `lib/components/badges/waypoint_chip.dart`).
- **New UI:** Use theme colorScheme where possible; for one-off colors use LightModeColors/DarkModeColors so dark mode stays consistent.

---

## Reference screens (for consistency)

- **Home / Marketplace** (`lib/presentation/marketplace/marketplace_screen.dart`): Uses `_CenteredSection` — `Center` → `Container(maxWidth: WaypointBreakpoints.contentMaxWidth)` (1200 from `lib/layout/waypoint_breakpoints.dart`) with horizontal padding 24 (mobile) or 48 (desktop). Uses `context.textStyles`, `context.colors`, and `WaypointColors` / theme. Good reference for section layout and typography.
- **Plan / Trip detail** (`lib/presentation/adventure/adventure_detail_screen.dart`): Centered content with `WaypointSpacing.contentMaxWidth` (900), `WaypointSpacing.layoutMaxWidth` (1240), horizontal padding from `WaypointSpacing.pagePaddingMobile` / desktop. Overview tab and other tabs follow the same responsive shell. Use as reference for detail pages and tab content.
- **Trip / Itinerary page** (see below): Use as the main reference for hero sections, content sections with icons, and card-heavy layouts.

When adding new screens or tabs, align with these patterns (centered, max-width, padding by breakpoint) and the tokens above.

---

## Trip / Itinerary page (design reference)

The **trip and itinerary flows** are well-designed references for hero treatment, sectioned content, and primary actions. Align new detail or day-based screens with these patterns.

**Implementation:** `lib/presentation/itinerary/itinerary_day_screen.dart`, `lib/presentation/itinerary/itinerary_travel_screen.dart`, `lib/presentation/itinerary/itinerary_review_screen.dart`, `lib/presentation/mytrips/my_trips_screen.dart`.

| Pattern | Usage |
|--------|--------|
| **Hero / SliverAppBar** | Use a `SliverAppBar` with `expandedHeight` (e.g. 280) and `FlexibleSpaceBar` for day or trip headers. Background: day photo via `CachedNetworkImage` or a gradient fallback (`primary` → `secondary`). Overlay: `LinearGradient` top-to-bottom (transparent → black 0.6) so title stays readable. Title: white, `FontWeight.bold`, `Shadow(color: black54, blurRadius: 4)`. Leading: back with `IconButton.styleFrom(backgroundColor: black26)` for contrast. |
| **Section headings** | Section = icon (20px, `context.colors.primary`) + 8px gap + title (`context.textStyles.titleMedium`, `fontWeight: FontWeight.w600`). Then 12px spacing, then section content. Reuse this row for “Where to stay”, “Where to eat”, “Activities”, etc. |
| **Content cards** | Description / info blocks: `Container` with `color: context.colors.surfaceContainer`, `borderRadius: 12`, `border: Border.all(color: context.colors.outlineVariant)`, padding 16. Waypoint-style items: use `UnifiedWaypointCard` for accommodations, restaurants, activities. |
| **Spacing** | Main content: `SliverPadding(padding: AppSpacing.paddingLg)`. Between sections: `SizedBox(height: 24)`. Between section title and content: 12. |
| **Primary actions** | Use `ElevatedButton` / `ElevatedButton.icon` with `backgroundColor: context.colors.primary`, `foregroundColor: Colors.white`, `padding: symmetric(horizontal: 28, vertical: 14)`, `shape: RoundedRectangleBorder(borderRadius: 12)`, `elevation: 2`. For secondary nav: `TextButton.icon` with `foregroundColor: context.colors.onSurfaceVariant`. |
| **Bottom bar** | Sticky bottom bar: `Container` with light shadow (`black08`, blur 20, offset (0, -4)), padding 16, `SafeArea`. Use for day nav (back / next) or “Finish” so primary action is always visible. |
| **Filter chips** | On list/dashboard screens (e.g. My Trips): horizontal `ListView` of filter chips. Use `WaypointCreamChip` with `prominent: true` and a clear selected state for “All”, “Upcoming”, “Active”, “Completed”. |
| **Responsive padding** | Trip/list screens: horizontal padding `isDesktop ? 32 : 16` for a consistent gutter. |

Use these patterns when adding or restyling trip-like, day-based, or sectioned detail screens so the app feels consistent with the trip page.

---

## Design tokens

- **Spacing:** Tight preset. Map to `lib/core/theme/spacing.dart` (e.g. use existing scale with tighter defaults or document target values for "Tight").
- **Corner radius:** Default preset. Map to `lib/core/theme/radius.dart` (e.g. Default = 8–12px for cards).
- **Text size:** 1.0x base. Reference `lib/core/theme/typography.dart` for the type scale.
- **Constants:**
  - Spacing Constants (5)
  - Radii Constants (4)
  - Typography Constants (10)
  - Shadows Constants (4)  

These are defined or referenced in `lib/core/theme/` (spacing.dart, radius.dart, typography.dart, shadows.dart). When adding new constants, keep this doc in sync.

---

## Itinerary page reference

For restyling the itinerary page (map on top, day tabs, waypoint list, Add Waypoint button), use the implementation prompt in the plan **"Branding guidelines and itinerary restyle prompt"** (see `.cursor/plans/`). It specifies layout, waypoint card appearance, travel segments, and how to apply the fonts and colors above.
