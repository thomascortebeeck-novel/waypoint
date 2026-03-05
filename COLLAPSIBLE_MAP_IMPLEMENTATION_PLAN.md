# Collapsible Map + Pinned Day Tabs — Implementation Plan

## Target behaviour

- **Map visible by default** at ~40% of screen height.
- **Scroll down** → map collapses/hides automatically.
- **Scroll back up** → map reappears.
- **Day tabs** stay pinned below the map (always visible when scrolling).
- **Waypoint list** for the selected day scrolls under the pinned tabs.

## Architecture

```
CustomScrollView
  ├── SliverAppBar (expandedHeight: 40% screen, floating: true, pinned: false)
  │     └── FlexibleSpaceBar.background → map for selected day
  ├── SliverPersistentHeader (pinned: true)
  │     └── _DayTabBarDelegate → TabBar (Day 1, Day 2, …)
  └── SliverList / SliverFillRemaining
        └── waypoint list for selected day
```

## Codebase adaptations (vs generic patch)

| Patch assumption | This codebase |
|------------------|---------------|
| `_getDaysForCurrentVersion()` | Use `_dayCount` (int) and `_selectedDay` (int). Tabs built as `List.generate(dayCount, (i) => Tab(text: 'Day ${i+1}'))`. |
| `_getWaypointsForDay(day)` | Waypoints come from `_buildBuilderItineraryContentForDay` / `_buildViewerItineraryContentForDay` logic. Add `_getWaypointsForSelectedDay()` → `(List<RouteWaypoint>, bool isBuilder)`. |
| Single `_buildItineraryMap(center, waypoints)` | Keep existing `_buildItineraryMap(route, dayNum, version)` (builder) and `_buildViewerDayMap(day)` (viewer). Add `_buildMapForSelectedDay()` that picks one and passes optional height for sliver. |
| `_buildWaypointListTile(wp)` | Use existing `_buildWaypointCard(waypoint, index, isBuilder)`. |
| TabController in initState | TabController is currently created in `_buildStipplItineraryLayout` when `dayCount` is known. Keep creating it at start of `_buildItineraryTab()` (same as now) so length stays in sync. |

## Implementation steps

### 1. State and mixin

- **No change.** Class already uses `TickerProviderStateMixin`.
- Add optional `WaypointMapController? _itineraryMapController` for future fit-to-waypoints (optional).

### 2. TabController and dispose

- Keep `_dayTabController` creation inside the itinerary build path when `dayCount` is known (same as current `_buildStipplItineraryLayout`). Move that init into the new `_buildItineraryTab()` before building the `CustomScrollView`.
- Keep existing `_dayTabController?.dispose()` and nulling in `dispose()`.

### 3. Replace itinerary tab body

- **Remove:** `_buildStipplItineraryLayout`, `_buildMapToggleBar`, `_buildDayTabs` (replaced by delegate).
- **New `_buildItineraryTab()`:**  
  - If `_dayCount == 0` → return empty-state (unchanged).  
  - Clamp `_selectedDay` to valid range.  
  - Create/update `_dayTabController` when length != `_dayCount` (reuse current logic).  
  - Return `CustomScrollView` with:
    - `SliverAppBar` (expandedHeight: 40% of height, floating: true, pinned: false, toolbarHeight: 0, no leading), `flexibleSpace: FlexibleSpaceBar(background: _buildMapForSelectedDay())`.
    - `SliverPersistentHeader(pinned: true, delegate: _DayTabBarDelegate(controller: _dayTabController!, dayCount: _dayCount))`.
    - Waypoints for selected day via `_getWaypointsForSelectedDay()`. If empty → `SliverFillRemaining` with empty state; else `SliverList` with `_buildWaypointCard(wp, index, isBuilder)`.
    - `SliverToBoxAdapter(SizedBox(height: 80))` for bottom padding.

### 4. Map for selected day

- **`_buildMapForSelectedDay()`:**  
  - Builder mode: get `version`, `dayState = version.getDayState(_selectedDay)`, `route = dayState.route`; return `_buildItineraryMap(route, _selectedDay, version)`. (Already constraint-adaptive via internal `LayoutBuilder`.)  
  - Viewer mode: if `_adventureData!.days.length < _selectedDay` return empty placeholder; else `day = _adventureData!.days[_selectedDay - 1]` and return `_buildViewerDayMap(day, mapHeight: null)`. When used in sliver, call with `mapHeight` from a `LayoutBuilder` around the FlexibleSpaceBar content so the viewer map fills the expanded height.

- **`_buildViewerDayMap(DayItinerary day, {double? mapHeight})`:**  
  - Add optional `mapHeight`. If provided, use it for the outer `SizedBox(height: mapHeight)`; else keep current `SizedBox(height: 300)`.

### 5. Waypoints for selected day

- **`_getWaypointsForSelectedDay()`:**  
  - Returns `(List<RouteWaypoint> waypoints, bool isBuilder)`.  
  - Builder: `version = _formState!.activeVersion`, `dayState = version.getDayState(_selectedDay)`, `route = dayState.route`; parse waypoints from `route.poiWaypoints` (same as `_buildBuilderItineraryContentForDay`), sort by order; return `(waypoints, true)`.  
  - Viewer: if `_selectedDay > _adventureData!.days.length` return `([], false)`; else `day = _adventureData!.days[_selectedDay - 1]`, get waypoints from `day.route` (same as `_buildViewerItineraryContentForDay`); return `(waypoints, false)`.

### 6. _DayTabBarDelegate

- New class at file level (bottom of file, outside State):  
  - Implements `SliverPersistentHeaderDelegate`.  
  - Constructor: `TabController controller`, `int dayCount`.  
  - `minExtent` / `maxExtent`: 48.0.  
  - `build(context, shrinkOffset, overlapsContent)`: white `Container` with `TabBar(controller, isScrollable: true, tabs: List.generate(dayCount, (i) => Tab(text: 'Day ${i+1}')))`.  
  - `shouldRebuild`: compare controller and dayCount.

### 7. FlexibleSpaceBar map height

- In `SliverAppBar.flexibleSpace`, use `LayoutBuilder` so the map gets the expanded height:  
  `FlexibleSpaceBar(background: LayoutBuilder(builder: (context, constraints) => _buildMapForSelectedDay(height: constraints.maxHeight)))`.  
- `_buildMapForSelectedDay({double? height})` passes `height` into `_buildViewerDayMap(day, mapHeight: height)` so the viewer map fills the sliver area; builder map already adapts via its internal `LayoutBuilder`.

### 8. Cleanup

- Remove `_buildMapToggleBar()`.
- Remove `_buildDayTabs(int dayCount)`.
- Remove `_buildStipplItineraryLayout(int dayCount)`.
- Keep `_mapVisible` only if still used elsewhere (e.g. other tabs); otherwise remove. After change, `_buildItineraryLayout` is only used by… nothing if we fully replace the tab content. So we can keep `_buildItineraryLayout`, `_buildBuilderItineraryContentForDay`, `_buildViewerItineraryContentForDay` for potential reuse (e.g. desktop 50/50 layout elsewhere) or remove later. For this task, only the itinerary tab body is replaced; no need to delete those three methods unless we want to avoid dead code.

### 9. Sync selected day with tab

- When user taps a day tab, `TabController` listener already calls `_onDayTabChanged(index + 1)`, which sets `_selectedDay`. So the `CustomScrollView` will rebuild with the new selected day’s map and waypoints. Ensure the TabBar in the delegate uses the same `_dayTabController` and the listener remains attached when we create the controller in `_buildItineraryTab()`.

## Things to watch (review notes)

- **TabController in build:** Creating/disposing the controller inside `_buildItineraryTab()` can cause a one-frame flash when `dayCount` changes (e.g. user edits duration). Documented in code; acceptable trade-off since length isn’t known until we have form/adventure data.
- **Dead code / vestigial state:** `_buildItineraryLayout`, `_buildItineraryContent`, `_buildBuilderItineraryContentForDay`, `_buildViewerItineraryContentForDay` are kept for potential desktop 50/50 reuse. `_mapVisible` is vestigial for the itinerary tab but still used by those layouts. Comments and TODOs added so future readers aren’t confused.
- **CollapseMode.none / jank:** Correct for the map (no parallax/fade). On slower devices, the `LayoutBuilder` height change during sliver collapse can occasionally cause a jank frame; if observed, consider caching the map widget or simplifying the layout.

## Files to change

- `lib/presentation/adventure/adventure_detail_screen.dart` only.

## Risk and testing

- **Constraint safety:** SliverAppBar and SliverPersistentHeader provide bounded constraints; no unbounded width.
- **Test:** Itinerary tab with 1 day and multiple days; scroll to collapse map; scroll up to reveal; switch days and confirm map and list update.
