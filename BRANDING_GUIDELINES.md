# Waypoint app — branding and theme guidelines

This document is the canonical reference for visual branding and theme tokens. It is linked from [architecture.md](architecture.md). Implementation lives in `lib/theme.dart`, `lib/core/theme/waypoint_theme.dart`, `lib/core/theme/colors.dart`, and related files under `lib/core/theme/`.

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
| background      | `#FDFBF7` | Page background |
| surface         | `#F2E8CF` | Cards, elevated surfaces |
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
