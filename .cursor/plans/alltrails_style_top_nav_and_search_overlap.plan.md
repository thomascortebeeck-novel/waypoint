---
name: ""
overview: ""
todos: []
isProject: false
---

# AllTrails-style Top Nav & Hero Search Overlap — Implementation Plan

> **Key design decision:** Desktop nav is **transparent and overlaid on the hero image** (like AllTrails), not a white bar above it. Text and icons are white for readability over the hero.

---

## Overview of changes


| File                                                   | Change                                                                                                     |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `lib/nav.dart`                                         | Desktop: overlay transparent `DesktopTopNavBar` using a `Stack` over the shell content. Mobile: unchanged. |
| `lib/presentation/marketplace/marketplace_screen.dart` | Combine hero + search into one sliver/Stack; search bar straddles the hero bottom edge 50/50.              |


---

## Change 1 — `lib/nav.dart`

### Layout structure (desktop)

**Before:**

```dart
Scaffold(
  body: Row(
    DesktopSidebar(width: 240),
    Expanded(child: navigationShell),
  ),
)
```

**After:**

```dart
Scaffold(
  body: Stack(
    children: [
      Positioned.fill(child: navigationShell),
      Positioned(
        top: 0, left: 0, right: 0,
        child: DesktopTopNavBar(...),
      ),
    ],
  ),
)
```

> The `navigationShell` fills the entire screen (including behind the nav bar). Individual screens that have a hero image (like Marketplace) will naturally show through. Screens without a hero should add top padding equal to the nav bar height (`~64px`) to avoid content being hidden under it — use a `SafeArea` or a `SizedBox(height: kDesktopNavHeight)` at the top of their scroll content.

### `DesktopTopNavBar` widget spec

```dart
const double kDesktopNavHeight = 64.0;

class DesktopTopNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kDesktopNavHeight,
      // Transparent background — hero image shows through on screens that have one
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // LEFT: Logo
          _Logo(),
          const Spacer(),
          // CENTER-RIGHT: Nav tabs
          _NavTab('Home',       index: 0, current: currentIndex, onTap: onDestinationSelected),
          _NavTab('Explore',    index: 1, current: currentIndex, onTap: onDestinationSelected),
          if (isLoggedIn) ...[
            _NavTab('Your trips', index: 2, current: currentIndex, onTap: onDestinationSelected),
            _NavTab('Build',      index: 3, current: currentIndex, onTap: onDestinationSelected),
          ],
          // RIGHT: Profile icon
          _ProfileIcon(index: 4, onTap: onDestinationSelected),
        ],
      ),
    );
  }
}
```

### Nav tab styling (white text on transparent)

```dart
class _NavTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
              ),
            ),
            // Selected indicator: small white underline dot/bar
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 3),
                height: 2, width: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

### Profile icon

```dart
class _ProfileIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }
}
```

### Optional: dark gradient scrim for readability

On screens where the hero image is light-colored, white text can be hard to read. Add an optional top gradient on the hero image itself (not on the nav):

```dart
// Inside _buildHeroCarousel, wrap the carousel in a Stack and add:
Positioned(
  top: 0, left: 0, right: 0,
  height: 100,
  child: DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black45, Colors.transparent],
      ),
    ),
  ),
),
```

This is the same pattern AllTrails uses.

### Screens without a hero — top padding

Any screen routed through the shell that does NOT have a full-bleed hero image needs to account for the nav bar overlay.

**Where to add it (do not add inside a card or section):** Add **one** top spacer at the **scroll root** of each screen:

- **If the screen uses `CustomScrollView`:** Add `SliverToBoxAdapter(child: SizedBox(height: kDesktopNavHeight))` as the **first sliver** in the `slivers` list. That is the only change needed for that screen.
- **If the screen uses a different root (e.g. single child scroll or column):** Apply `Padding(padding: EdgeInsets.only(top: isDesktop ? kDesktopNavHeight : 0), child: ...)` to the root scrollable content.

**Screens to update (one place each, at scroll root):** Explore, My Trips, Builder home, Profile. Export `kDesktopNavHeight` from `nav.dart` (or a shared constants file) and use it only at that single spot per screen.

---

## Change 2 — `lib/presentation/marketplace/marketplace_screen.dart`

### Before (two separate slivers)

```dart
SliverToBoxAdapter(child: _buildHeroCarousel(heroHeight)),
SliverToBoxAdapter(child: _buildSearchBar()),
```

### After (one sliver with Stack, `clipBehavior: Clip.none`)

```dart
final double heroHeight = isDesktop ? 500 : 400;
const double searchBarHeight = 52;
const double overlap = searchBarHeight / 2; // 26

SliverToBoxAdapter(
  child: SizedBox(
    height: heroHeight + overlap, // Total height: hero + 26px for lower half of search bar
    child: Stack(
      clipBehavior: Clip.none, // REQUIRED — allows Positioned(bottom: -overlap) to render outside bounds
      children: [
        // Hero carousel fills the top heroHeight px
        Positioned(
          top: 0, left: 0, right: 0,
          height: heroHeight,
          child: _buildHeroCarousel(heroHeight),
        ),
        // Search bar: vertically centered on the bottom edge of the hero; centered horizontally with max width
        Positioned(
          bottom: -overlap,
          left: 0, right: 0,
          child: Center(
            child: SizedBox(
              width: min(700, MediaQuery.of(context).size.width - (isDesktop ? 96 : 32)),
              height: searchBarHeight,
              child: _buildSearchBar(),
            ),
          ),
        ),
      ],
    ),
  ),
),
```

Use `min` from `dart:math`. Obtain `screenWidth` from `MediaQuery.of(context).size.width` (or pass it in if already available in scope).

> **Why `Clip.none` is critical:** Flutter's `Stack` clips its children to its own bounds by default. `Positioned(bottom: -26)` places the widget 26px below the Stack's bottom edge — this only renders correctly with `clipBehavior: Clip.none`. Without it, the bottom half of the search bar is silently clipped.

### Remove the old standalone search sliver

Delete:

```dart
SliverToBoxAdapter(child: _buildSearchBar()), // remove this
```

### Adjust `_buildHeroCarousel`

- Method currently takes `(context, isDesktop)` and uses internal `heroHeight`. Call site will pass `heroHeight` so the carousel is exactly that height (e.g. `_buildHeroCarousel(context, isDesktop, heroHeight)` or keep internal height but ensure the `Positioned(height: heroHeight)` wraps the same value).
- Add optional top gradient scrim inside the hero Stack as described above.

### No branching needed for overlap

The 50/50 overlap works identically on mobile and desktop — only the `left`/`right` padding and `heroHeight` differ, which are already conditioned on `isDesktop`.

---

## Summary of key decisions


| Topic                     | Original spec           | Updated plan                                                                                                      |
| ------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Nav layout                | `Column(NavBar, shell)` | `Stack(shell, Positioned NavBar)` — overlay approach                                                              |
| Nav background            | White                   | Transparent (white text over hero)                                                                                |
| Nav text color            | Dark on white           | White (readable over hero image)                                                                                  |
| Gradient scrim            | Not mentioned           | Optional, recommended for legibility                                                                              |
| Non-hero screens          | Not addressed           | Need `kDesktopNavHeight` top padding                                                                              |
| `Clip.none` on Stack      | Not mentioned           | **Required** for `bottom: -26` to work                                                                            |
| Search horizontal padding | Max-width constraint    | `left: 0, right: 0` + `Center` + `SizedBox(width: min(700, screenWidth - padding))` so bar is centered and capped |


---

## Verification checklist

- Desktop >=1024px: transparent nav bar floats over hero image; white text/tabs visible
- Desktop: Home, Explore, Your trips (logged in), Build (logged in), Profile icon all render and navigate
- Desktop: no left sidebar visible
- Mobile: bottom nav unchanged; top nav not rendered
- Marketplace all sizes: search bar is half on the hero image, half below
- Marketplace: content below search bar is not hidden under it
- Non-hero screens: content is not hidden under the transparent nav bar
- Suggestions dropdown (if any): overflows downward correctly with `Clip.none`

