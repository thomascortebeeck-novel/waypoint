---
name: ""
overview: ""
todos: []
isProject: false
---

# Light theme simplification: 4-color palette (REVISED)

**Revised to incorporate DRY / component-principle feedback: single source of truth for colors and shadows, mandatory audit of local literals, and theme-first implementation order.**

---

## Target palette (light only)


| Role           | Hex       | Usage                                            |
| -------------- | --------- | ------------------------------------------------ |
| Background     | `#fdfbf7` | Scaffold, main content, drawer                   |
| Secondary      | `#faf5eb` | Sidebar, cards, sections, inputs                 |
| Optional brown | `#f2e8d0` | Slightly elevated surfaces, very subtle dividers |
| Brand          | `#2f7d32` | Logo, primary buttons, links, selected state     |


Design rules: minimal borders (same-as-fill or very light); **canonical shadow token** (see below); low contrast; AllTrails-like.

---

## 1. Canonical color tokens

**File: [lib/core/theme/colors.dart](lib/core/theme/colors.dart)**

- **BrandingLightTokens**
  - `background = Color(0xFFFDFBF7)`, `surface = Color(0xFFFAF5EB)`, `surfaceVariant = Color(0xFFF2E8D0)`.
  - `primary = Color(0xFF2F7D32)`, `onPrimary = white`.
  - `divider` / outline: very subtle (e.g. `Color(0xFFF2E8D0)` or low-opacity dark).
  - Align `secondary` / `accent` to brown or primary so light mode doesn’t introduce extra hues.
- **LightModeColors**
  - Map `background`, `surface`, and all `surfaceContainer`* (surfaceContainer, surfaceContainerLow, surfaceContainerHigh, surfaceContainerHighest) to combinations of `fdfbf7`, `faf5eb`, `f2e8d0` only.
  - `primary` → `#2f7d32`, `outline` → minimal.
  - Keep text colors (onSurface, secondaryText, hint) for readability.
- **Shadow / elevation tokens (new)**
  - Add a single source of truth for light-theme shadows so components don’t scatter values:
    - e.g. `kLightCardElevation = 0.0`, `kLightShadowColor = Colors.transparent` (or very low opacity).
  - Define in colors.dart or waypoint_theme.dart and use in `cardTheme`, sidebar `BoxDecoration`, and any shared shadow/elevation usage.

---

## 2. WaypointColors: 100% delegation (no local consts)

**File: [lib/theme/waypoint_colors.dart](lib/theme/waypoint_colors.dart)**

- **Explicit audit:** Every `WaypointColors.xxx` field must delegate to a token from Step 1 (e.g. `BrandingLightTokens` / `LightModeColors`). No local `const Color(0xFF...)` in this file.
- After the audit, “point all aliases to new tokens” is guaranteed; any component reading `WaypointColors.xxx` then gets the update for free.

---

## 3. Theme application: ColorScheme, components, shadows

**Files: [lib/theme.dart](lib/theme.dart), [lib/core/theme/waypoint_theme.dart**](lib/core/theme/waypoint_theme.dart)

- **ColorScheme:** Build `ColorScheme.light(...)` from updated `LightModeColors` including all `surfaceContainer`* so the surface hierarchy uses only the three light colors.
- **Scaffold / AppBar:** scaffoldBackgroundColor `#fdfbf7`; AppBar background from surface; elevation 0.
- **Cards:** elevation = `kLightCardElevation` (0); color from surface tokens; border none or same-as-fill; shadow from `kLightShadowColor`.
- **Buttons:** Elevated = primary; Outlined = minimal border; both use canonical shadow (none).
- **Inputs:** fillColor from surface tokens; borders from outline token.
- **Chips / FAB / Dividers:** Use surface/primary tokens; FAB elevation 0; divider = outline token.
- **Global shadow:** All theme-level `shadowColor` / `elevation` / `boxShadow` reference the canonical shadow token so one change updates everything.

---

## 4. Mandatory audit: replace local color and shadow literals

**Before** touching nav, drawer, or marketplace as “special cases,” remove the DRY leak at the component level.

- **Grep 1:** All `Color(0xFF...)` (and equivalent hex literals) in `lib/` UI code (screens, components, widgets). Replace with `context.colors.`* or `Theme.of(context).colorScheme.*` (or other theme lookups). Exception: the single token file(s) that define the palette.
- **Grep 2:** Local `BoxShadow(...)` and `elevation:` values in widgets. Replace with the canonical shadow token (e.g. elevation 0, shadowColor transparent) or a theme-driven value.
- **Outcome:** After this step, nav, drawer, marketplace, and cards should require **no** (or minimal) component-level color/shadow edits—only validation that they use theme.

---

## 5. Nav / sidebar

**File: [lib/nav.dart](lib/nav.dart)**

- **DesktopSidebar:** Background from theme surface; remove or soften `boxShadow` (use canonical shadow token). Divider from theme outline.
- **_SidebarNavItem:** Selected/hover from `surfaceContainerLow` or token; selected text/icon = primary. No local color consts; rely on theme.

---

## 6. Drawer: remove local constant

**File: [lib/components/adventure/stippl_navigation_drawer.dart](lib/components/adventure/stippl_navigation_drawer.dart)**

- **Remove** `kDrawerAndPlanPageBackground`. Replace every use with `Theme.of(context).colorScheme.background` (or scaffoldBackgroundColor). Token lives only in the theme.

---

## 7. Marketplace and cards: validate, not rewrite

**Files: [lib/presentation/marketplace/marketplace_screen.dart](lib/presentation/marketplace/marketplace_screen.dart), [lib/presentation/marketplace/marketplace_components.dart](lib/presentation/marketplace/marketplace_components.dart), [lib/components/unified/section_card.dart](lib/components/unified/section_card.dart), [lib/presentation/widgets/adventure_card.dart](lib/presentation/widgets/adventure_card.dart), [lib/presentation/mytrips/widgets/horizontal_trip_card.dart**](lib/presentation/mytrips/widgets/horizontal_trip_card.dart)

- After Step 4, these should already be using theme. **Verify:** no remaining hardcoded `Color(0x...)` or local `BoxShadow`/elevation. Fix any remainders by replacing with theme lookups (no new local constants).

---

## 8. Verification

- **Visual:** Light mode only; scaffold, sidebar, cards, sections use only fdfbf7, faf5eb, f2e8d0, and 2f7d32 (plus white on green where needed). No heavy borders or shadows.
- **Text contrast:** Confirm readability of primary and secondary text on all three background tones (fdfbf7, faf5eb, f2e8d0), especially secondary text on `#f2e8d0`.
- **Primary actions and logo:** Consistently #2f7d32.

---

## Revised implementation order (summary)

1. **Colors:** Update BrandingLightTokens + LightModeColors + surface hierarchy + shadow/elevation tokens.
2. **WaypointColors:** Audit and ensure 100% delegation to Step 1 tokens (no local consts).
3. **Theme:** ColorScheme, cardTheme, appBarTheme, buttons, inputs, chips, FAB, dividers, shadows (all using canonical shadow token).
4. **Audit:** Grep UI files for `Color(0xFF...)` and local BoxShadow/elevation; replace with theme lookups.
5. **Nav/Sidebar:** Should need only shadow removal and any missed consts; colors from theme.
6. **Drawer:** Replace `kDrawerAndPlanPageBackground` with theme token.
7. **Marketplace + cards:** Validate; remove any remaining local color/shadow literals.
8. **Verify:** Light-mode visual pass + text contrast on all three background tones.

