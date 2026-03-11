---
name: ""
overview: ""
todos: []
isProject: false
---

# Waypoint map quality and customizable click info (revised)

## 1. Improve waypoint marker quality (reduce pixelation)

**Cause:** On Google Maps (web and mobile), markers are rasterized at `displayScale * 46×58` logical pixels × `devicePixelRatio`. With `_markerScale()` capped at **0.125–0.39** ([google_map_widget_web.dart](lib/features/map/google_map_widget_web.dart) lines 64–69), the bitmap can be as small as ~18×23 logical × DPR (e.g. 36×45 px at DPR 2). That low pixel count can look soft or pixelated on high-DPI displays.

**Approach:** Rasterize the pin at a **minimum resolution** inside the single place that paints markers, so the bitmap always has enough pixels. The on-screen size is unchanged.

- In [MapMarkerService](lib/services/map_marker_service.dart) only:
  - In `markerForType` and `getMarkerImageBytes`, do **not** pass through the caller’s `devicePixelRatio` directly into `_paintMarker`. Instead, compute an **effective DPR** inside the service: `effectiveDpr = max(devicePixelRatio, 3.0)` and use that for all canvas/raster work. This keeps clamping in one place and avoids cache collisions (cache key will use the same effective value for a given logical request).
  - In `_paintMarker`, use this effective DPR for the canvas dimensions and scaling. Keep the same logical size (`displayScale`); only the raster resolution increases.
- No DPR clamping at call sites (Google map web/mobile, or any other consumer). They continue to pass `MediaQuery.of(context).devicePixelRatio` (or equivalent); MapMarkerService is the single place that enforces the minimum.

**Files:** [lib/services/map_marker_service.dart](lib/services/map_marker_service.dart).

---

## 2. Customize what is shown when a waypoint is clicked

**Current behaviour:**  
Google Maps shows the default **InfoWindow** with only **title** (waypoint name). [MapAnnotation](lib/features/map/adaptive_map_widget.dart) already has `showInfoWindow` (default `true`), and it is already threaded: [google_map_widget_web.dart](lib/features/map/google_map_widget_web.dart) and [google_map_widget_mobile.dart](lib/features/map/google_map_widget_mobile.dart) read `annotation.showInfoWindow` and set `infoWindow` accordingly. Callers only need to set `showInfoWindow: false` when they provide a custom onTap. The **flutter_map** fallback (used when Google Maps is not available) has no InfoWindow; taps are already `annotation.onTap` only ([adaptive_map_widget.dart](lib/features/map/adaptive_map_widget.dart) ~480). No change needed there.

**Desired behaviour (match second screenshot):**  
A bottom sheet with: hero image, name/title, description, and actions (Save, Open link).

**Approach**

1. **Reusable waypoint map detail bottom sheet**
  New shared widget (e.g. `lib/components/map/waypoint_map_detail_sheet.dart` or `lib/components/dialogs/waypoint_map_detail_sheet.dart`) that shows:
  - **Hero image:** Use `linkImageUrl` or first waypoint photo if available. **If both are null,** use a graceful fallback: either a placeholder image (e.g. category icon or generic “no image” placeholder) or hide the hero section so the sheet still shows name, description, and actions.
  - **Name, type/category, description** (all optional in the widget; hide sections when null).
  - **Actions:**  
    - **Open:** Open `linkUrl` in browser; hide or disable if `linkUrl` is null.  
    - **Save:** Show only when **authenticated**. Filled heart if the **plan** is already favorited, outline otherwise; on tap, toggle via [FavoriteService](lib/services/favorite_service.dart) (plan-scoped). **Saved-state data source:** When the sheet opens, perform a **one-time async read** (`FavoriteService.isFavorited(userId, planId)`) and show a loading or outline heart until the result returns so there is no wrong initial state or flash. **Trip/plan context:** Save is plan-scoped, so the sheet must receive **planId** (or an `onSave` callback that the caller implements with plan context). Pass `planId` into the shared helper; adventure detail and WaypointMapCard both have plan context. If `planId` is null (e.g. waypoint without plan), hide the Save action or show it disabled. If not authenticated, hide Save or show disabled with tooltip.
2. **Shared entry point (no per-screen duplication)**  
   Do **not** implement a private `_showWaypointMapDetailSheet` in each screen. Provide a **shared helper** that both callers use, e.g. `WaypointMapDetailSheet.show(context, waypoint, { planId, ... })`, which performs `showModalBottomSheet` with the new widget so barrier, shape, and content setup live in one place. Adventure detail and waypoint_map_card both call this helper.
3. **Wire tap to the sheet and hide default InfoWindow**
  - **Adventure detail – day map** ([adventure_detail_screen.dart](lib/presentation/adventure/adventure_detail_screen.dart) ~4923–4925): Build annotations with `showInfoWindow: false` and `onTap: () => WaypointMapDetailSheet.show(context, wp, planId: ...)` (with planId in scope).
  - **Adventure detail – overview map** (~9711–9726): Same: `showInfoWindow: false` and `onTap: () => WaypointMapDetailSheet.show(context, wp, planId: ...)`.
  - **WaypointMapCard** ([waypoint_map_card.dart](lib/components/map/waypoint_map_card.dart)): Replace or extend `_showWaypointDetails` to call the same shared helper with the waypoint and planId from the day/plan context. Sheet handles nulls for partial data.
4. **Sheet dismissal and “tap another marker”**
  - **Decision: Replace.** When the user taps another marker, **update the sheet content in place** (one sheet instance, content switches to the new waypoint). No close-and-reopen (avoids flash). Implementation: the shared helper or the caller holds a way to update the visible sheet—e.g. the sheet widget accepts a `ValueNotifier<RouteWaypoint?>` and the caller updates it when another marker is tapped, so the sheet rebuilds with the new waypoint; or the helper tracks “sheet already open” and, when invoked again with a new waypoint, updates the existing sheet’s content. Dismissal remains by user only (drag, back, tap outside if configured). **Pan** does not auto-dismiss.

**Files to touch**

- New: `lib/components/map/waypoint_map_detail_sheet.dart` (or `lib/components/dialogs/waypoint_map_detail_sheet.dart`) – bottom sheet widget plus **shared static helper** `WaypointMapDetailSheet.show(context, waypoint, { planId, ... })` that runs `showModalBottomSheet` and supports in-place content update when another marker is tapped (e.g. via ValueNotifier or “if sheet open, update content”).
- [lib/presentation/adventure/adventure_detail_screen.dart](lib/presentation/adventure/adventure_detail_screen.dart): In day map and overview map set `showInfoWindow: false` and `onTap: () => WaypointMapDetailSheet.show(context, wp, planId: ...)` (planId from current plan).
- [lib/components/map/waypoint_map_card.dart](lib/components/map/waypoint_map_card.dart): Call the same shared helper instead of `_showWaypointDetails`; pass waypoint and planId from day/plan context.

---

## Summary


| Goal                  | Change                                                                                                                                                                                                                                                                          |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Sharper markers**   | In `MapMarkerService` only: use `effectiveDpr = max(devicePixelRatio, 3.0)` for all rasterization; no call-site clamping; cache key remains consistent.                                                                                                                         |
| **Custom click info** | Shared `WaypointMapDetailSheet.show(context, waypoint, { planId })`; sheet has image null fallback, name, description, Save (auth + one-time `FavoriteService.isFavorited` on open, planId required), Open. Tap another marker → **replace** content in place. Both adventure detail and WaypointMapCard call the helper; flutter_map unchanged. |


**Removed:** All Mapbox web references (app no longer uses Mapbox; map stack is Google Maps + optional flutter_map fallback).