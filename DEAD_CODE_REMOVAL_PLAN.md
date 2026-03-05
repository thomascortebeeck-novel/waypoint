# Dead Code Removal Plan: Route Builder & Waypoint Pop-ups

This plan lists code that became unnecessary after the Stippl-style **WaypointEditPage** replaced the old waypoint add/edit flows. It does **not** remove the Route Builder screen itself (still used for "Edit Route" / "Create Route" on the map).

---

## 1. What Stays (Not Dead)

| Item | Reason |
|------|--------|
| **RouteBuilderScreen** (`lib/presentation/builder/route_builder_screen.dart`) | Still used for "Edit Route" / "Create Route" from Builder and Adventure Detail. Only the *waypoint add/edit UI* on this screen should change (dialogs → push WaypointEditPage). |
| **Route `/builder/route-builder/:planId/:versionIndex/:dayNum`** (`lib/nav.dart`) | Needed for navigating to the map/route editor. |
| **LocationSearchDialog** (`lib/components/builder/location_search_dialog.dart`) | Still used in **BuilderScreen** for "Add Location" in the adventure form (step 1/2), which is **not** waypoint add. Do not delete. |

---

## 2. Candidate for Removal: WaypointEditDialog

**File:** `lib/components/builder/waypoint_edit_dialog.dart`

**Status:** Replace all usages with **WaypointEditPage** (push), then delete this file.

**Current usages:**

| File | Usage | Action |
|------|--------|--------|
| **builder_screen.dart** | Add waypoint (type chosen) → `showDialog(WaypointEditDialog(fixedType: type, ...))` | Migrate to `context.push<WaypointEditResult>(waypointEditPath, extra: {...})` and handle `WaypointSaved` / apply route. |
| **builder_screen.dart** | Edit waypoint → `showDialog(WaypointEditDialog(existingWaypoint: ...))` | Same: push WaypointEditPage with `mode: 'edit'`, `existingWaypoint`, `initialRoute`. |
| **builder_screen.dart** | Add logistics waypoint → `showDialog(WaypointEditDialog(fixedType: WaypointType.servicePoint))` | Same: push with `mode: 'add'`, optional preselected type. |
| **route_builder_screen.dart** | Add at map location → `WaypointEditDialog(proximityBias: latLng)` | Migrate to push WaypointEditPage; pass `initialRoute` built from current `_poiWaypoints` and day. |
| **route_builder_screen.dart** | Add with type → `WaypointEditDialog(preselectedType: type, proximityBias: position)` | Same. |
| **route_builder_screen.dart** | Edit waypoint → `WaypointEditDialog(existingWaypoint: waypoint, ...)` | Same. |
| **route_builder_screen.dart** | Add from menu (type) → `WaypointEditDialog(proximityBias: center, preselectedType: ...)` | Same. |
| **route_builder_screen.dart** | Add with preselected place → `WaypointEditDialog(preselectedPlace: preselectedPlace, ...)` | Push WaypointEditPage with `preselectedPlace` (PlaceDetails) in extra; page opens at Step 2 with prefilled data (no second API call). |

After all call sites use WaypointEditPage and no code references `WaypointEditDialog`, delete:

- `lib/components/builder/waypoint_edit_dialog.dart`

---

## 3. BuilderScreen: Dead or Redundant Code

**File:** `lib/presentation/builder/builder_screen.dart`

### 3.1 Waypoint type / logistics dialogs (remove after migration)

| Symbol | Approx. lines | Purpose | Action |
|--------|----------------|---------|--------|
| `_showWaypointTypeDialog` | ~5606–5666 | AlertDialog to pick Stay/Eat/Do/See/Logistics | Remove. Replace the "Add Waypoint" button with a single action that pushes WaypointEditPage (no type dialog). |
| `_showLogisticsSubCategoryDialog` | ~5670–5706 | Sub-dialog for Logistics (Gear/Transport/Food) | Remove. WaypointEditPage handles Move (service) and subcategories. |
| `_addWaypointFromItinerary` | ~5387–5455 | Opens WaypointEditDialog with fixed type, then merges result into route | Replace with: ensure route exists, then `context.push<WaypointEditResult>(waypointEditPath, extra: {...})`; on `WaypointSaved` apply `result.route` to `dayState.route` and optional GPX snap. |
| `_addWaypointFromItineraryWithLogistics` | ~5709–5759 | Opens WaypointEditDialog for service, then sets logisticsCategory/timeSlotCategory | Replace with push to WaypointEditPage (type Move); remove TimeSlotCategory/logisticsCategory handling if WaypointEditPage only uses serviceCategory. |
| `_editWaypointFromItinerary` | ~5458–5603 | Opens WaypointEditDialog for edit, then replaces waypoint in route | Replace with push to WaypointEditPage with `mode: 'edit'`, `existingWaypoint`, `initialRoute`; on `WaypointSaved` replace waypoint in `dayState.route`; on `WaypointDeleted` remove waypoint. |

### 3.2 UI that triggers the above (update, do not delete)

| Location | Current behavior | New behavior |
|----------|------------------|--------------|
| Day card "Add Waypoint" IconButton (~3710) | `onPressed: () => _showWaypointTypeDialog(context, dayNum, version)` | `onPressed: () => _pushAddWaypointPage(dayNum, version)` (new helper that pushes WaypointEditPage). |
| Waypoint list edit action (~5957) | Calls `_editWaypointFromItinerary(dayNum, index, version)` | Call new helper that pushes WaypointEditPage in edit mode with `existingWaypoint` and `initialRoute`. |

### 3.3 Helpers to add in BuilderScreen

- **Minimal DayRoute** when no route exists: use the same as in `adventure_detail_screen.dart` (lines 5224–5229):
  ```dart
  dayState.route ??= const DayRoute(
    geometry: {},
    distance: 0,
    duration: 0,
    routePoints: [],
    poiWaypoints: [],
  );
  ```
  (See `lib/models/plan_model.dart` for full `DayRoute`; optional fields can be omitted.)

- `_pushAddWaypointPage(int dayNum, VersionFormState version)`  
  - Ensure `dayState.route` exists (create minimal `DayRoute` above if null).  
  - Build waypoint path: `/builder/:planId/waypoint/:versionIndex/:dayNum`.  
  - `final result = await context.push<WaypointEditResult>(path, extra: { tripName, initialRoute, dayNum, mode: 'add', ... });` then `_applyWaypointEditResult(dayNum, version, result)`.

- `_pushEditWaypointPage(int dayNum, int waypointIndex, VersionFormState version)`  
  - Same path; extra: `mode: 'edit'`, `existingWaypoint`, `initialRoute`.  
  - On return, call `_applyWaypointEditResult(dayNum, version, result)`.

- `_applyWaypointEditResult(int dayNum, VersionFormState version, WaypointEditResult? result)`  
  - **If `result == null`** (user pressed back): return immediately; do not update state or show error.  
  - If `WaypointSaved`: set `dayState.route = result.route`, then `setState`, snackbar. Run GPX snap **only when the day has a GPX route**: `if (dayState.gpxRoute != null) { _snapWaypointsToGpxRoute(dayNum, dayState.gpxRoute!, updatedRoute, version); }` (reuse condition as in builder_screen.dart around lines 5443–5446). Do not run snap when `dayState.gpxRoute` is null.  
  - If `WaypointDeleted`: remove waypoint by id from `dayState.route.poiWaypoints`, then `setState`, snackbar.

### 3.4 Imports to remove (after migration)

- `import 'package:waypoint/components/builder/waypoint_edit_dialog.dart';`  
- **After** removing `_showLogisticsSubCategoryDialog` and `_addWaypointFromItineraryWithLogistics`, **audit** builder_screen.dart for any remaining references to `LogisticsCategory` and `TimeSlotCategory` (search for these symbols). If none remain, remove their imports (e.g. from route_waypoint.dart or route_waypoint_legacy.dart). Do **not** remove the enum definitions elsewhere; only remove imports from builder_screen if they become unused.

---

## 4. RouteBuilderScreen: Dead or Redundant Code

**File:** `lib/presentation/builder/route_builder_screen.dart`

### WaypointEditPage extra contract

Document the `extra` map passed to WaypointEditPage (same for BuilderScreen and RouteBuilderScreen): `mode` ('add' | 'edit'), `initialRoute` (DayRoute), `existingWaypoint` (RouteWaypoint?, edit only), `tripName` (String). Optionally `preselectedPlace` (PlaceDetails, add mode only): RouteBuilderScreen must pass pre-fetched PlaceDetails when the user has already selected a place (e.g. from sidebar search); WaypointEditPage then opens at Step 2 with form prefilled and kicks off photo fetch. No placeId-only path. When using preselectedPlace, the async photo load completion callback must guard with `if (!mounted) return;` before calling `setState` (same as in `_onPlaceSelected`).

### 4.1 Dialog-based waypoint flows (migrate to WaypointEditPage, then remove)

| Symbol | Approx. lines | Purpose | Action |
|--------|----------------|---------|--------|
| `_showWaypointDialogAtLocation` | ~2225–2263 | Add waypoint at map tap (no type) via WaypointEditDialog | Replace with: build `DayRoute` from current `_poiWaypoints` and widget.initial; push WaypointEditPage with `mode: 'add'`, `initialRoute`; on return, apply result to `_poiWaypoints` and call `_initializeRouteOrdering`, `_calculateTravelTimes`, `_fitToWaypoints`. |
| `_addWaypointAtLocation` | ~2265–2300 | Add waypoint with preselected type at position | Same as above; pass optional type or let user choose on page. |
| `_editWaypoint` | ~2305–2360+ | Edit waypoint via WaypointEditDialog | Replace with: push WaypointEditPage with `mode: 'edit'`, `existingWaypoint`, `initialRoute` (from current _poiWaypoints); on `WaypointSaved` replace in `_poiWaypoints` and refresh; on `WaypointDeleted` remove. |
| `_showAddWaypointDialog` | ~3215–3244 | Add waypoint from menu (optional preselectedPlace) | Push WaypointEditPage with `preselectedPlace` (PlaceDetails) in extra when non-null; WaypointEditPage opens at Step 2 with prefilled data. |

All `showDialog(builder: (context) => WaypointEditDialog(...))` in this file (5 call sites) should be replaced by a single helper that builds the waypoint edit route and `extra` map, then `context.push<WaypointEditResult>(...)` and applies the result via a **separate** apply-result helper (same pattern as BuilderScreen but different state — see below).

### 4.2 RouteBuilderScreen-specific details

- **planId / versionIndex / dayNum:** Available from `widget.planId`, `widget.versionIndex`, `widget.dayNum`.
- **initialRoute:** Must reflect **current in-memory state** (including unsaved waypoints). Use: `widget.initial?.copyWith(poiWaypoints: _poiWaypoints.map((w) => w.toJson()).toList()) ?? DayRoute(geometry: {}, distance: 0, duration: 0, routePoints: [], poiWaypoints: _poiWaypoints.map((w) => w.toJson()).toList())`. When `widget.initial` is non-null, pass a copy with `poiWaypoints` replaced by current `_poiWaypoints` (serialized); when null, use minimal DayRoute shape with `poiWaypoints` from `_poiWaypoints`. This avoids WaypointEditPage showing stale waypoints.
- **Apply-result helper** (e.g. `_applyWaypointEditResultFromPage(WaypointEditResult? result)`): **If `result == null`**, return immediately. If `WaypointSaved`, **replace** `_poiWaypoints` **entirely** with the list from `result.route.poiWaypoints` (full replacement, not merge/delta — WaypointEditPage returns the complete updated route). If `WaypointDeleted`, remove waypoint by id from `_poiWaypoints`. After updating `_poiWaypoints`, **call `setState`** so the map and sidebar reflect the new list. Then call in order: (1) `_initializeRouteOrdering()` — sync; (2) `await _calculateTravelTimes()` — async; (3) `_fitToWaypoints()` — sync (verified void in route_builder_screen.dart; if implementation ever returns a Future, await it); (4) if `_poiWaypoints.length >= 2`, `_updatePreview()`. The helper should be `async` and await `_calculateTravelTimes()` to avoid race conditions on map state.

### 4.3 Imports to remove (after migration)

- `import 'package:waypoint/components/builder/waypoint_edit_dialog.dart';`

---

## 5. Navigation and Types

- **WaypointEditResult** and **WaypointEditPage** are already in use from `adventure_detail_screen`. Reuse the same route path and `extra` shape so BuilderScreen and RouteBuilderScreen pass the same structure.
- **nav.dart:** No change needed; `/builder/:planId/waypoint/:versionIndex/:dayNum` and WaypointEditPage are already registered. RouteBuilderScreen and BuilderScreen only need to construct this path and `extra` (including `initialRoute` and optionally `existingWaypoint`).

---

## 6. Optional Cleanups (Low Priority)

- **route_builder_screen.dart:** Reduce log noise (e.g. `Log.i('route_builder', ...)`) if desired; not dead code.
- **Legacy enums:** `WaypointType.activity` / `servicePoint` and `TimeSlotCategory` / `LogisticsCategory` are still used in data and some UI. Do not remove until product confirms migration to the new category/subcategory model everywhere.
- **waypoint_edit_dialog.dart** references `timeSlotCategory` / `logisticsCategory` in a few places; after deleting the dialog, any remaining references in builder_screen (e.g. in `_addWaypointFromItineraryWithLogistics`) disappear with the method removal.

---

## 7. Implementation Order

1. **BuilderScreen**
   - Add `_pushAddWaypointPage`, `_pushEditWaypointPage`, `_applyWaypointEditResult`.
   - Replace "Add Waypoint" button to call `_pushAddWaypointPage`.
   - Replace edit waypoint call sites to call `_pushEditWaypointPage`.
   - Remove `_showWaypointTypeDialog`, `_showLogisticsSubCategoryDialog`, `_addWaypointFromItinerary`, `_addWaypointFromItineraryWithLogistics`, `_editWaypointFromItinerary`.
   - Remove `WaypointEditDialog` import and any dialog-only imports.

2. **RouteBuilderScreen**
   - Add a helper that builds waypoint edit path + extra and calls `context.push<WaypointEditResult>` and applies result to `_poiWaypoints` and ordering/travel time.
   - Replace `_showWaypointDialogAtLocation`, `_addWaypointAtLocation`, `_editWaypoint`, `_showAddWaypointDialog` to use this helper (and same WaypointEditPage contract).
   - Remove `WaypointEditDialog` import.

3. **Delete**
   - `lib/components/builder/waypoint_edit_dialog.dart`.

4. **Smoke test**
   - Add waypoint from Builder day card → WaypointEditPage → save → waypoint appears and route updates.
   - Edit waypoint from Builder day card → WaypointEditPage → save/delete → list and route update.
   - From Route Builder screen: add waypoint at location, add with type, edit waypoint, add from place search → all go through WaypointEditPage and result applies to map/list.

---

## 8. Summary Table

| Item | Action |
|------|--------|
| **WaypointEditDialog** (file) | Delete after all call sites migrated to WaypointEditPage. |
| **LocationSearchDialog** | Keep (used for "Add Location" in builder, not waypoints). |
| **RouteBuilderScreen** | Keep; only replace dialog calls with push to WaypointEditPage. |
| **builder_screen** type/logistics dialogs and dialog-based add/edit | Remove; replace with push to WaypointEditPage + apply result. |
| **route_builder_screen** WaypointEditDialog usages (5) | Replace with push to WaypointEditPage + apply result. |
