---
name: Custom waypoint markers and list icons
overview: "Implement custom waypoint markers matching the reference design: plectrum/shield pin with a white circle cutout. Map shows category icons (sleep, food & drinks, do & see, move) in the circle; list shows order number (0, 1, 2…). Category colors drive the pin body. One shared geometry spec and anchor for map and list."
todos: []
isProject: false
---

# Custom Waypoint Markers (Plectrum Pin + White Circle)

## Target design (from reference image)

- **Shape:** Plectrum/shield pin — **not** a teardrop.
  - **Top edge:** Nearly flat or slightly convex (low-curvature arc).
  - **Sides:** Two cubic bezier curves that start near the top corners and converge symmetrically to a **sharp** bottom point.
  - **Bottom:** Sharp point at center-bottom.
- **Body:** Solid color by **category** (see color mapping table below).
- **White circle cutout:** One large **circle** (not oval) in the upper-central part of the pin. It sits high, with a visible colored border around it on all sides except where it meets the top curve. This is the only content area:
  - **On the map:** Show the **category icon** (sleep, food & drinks, do & see, move).
  - **In the waypoint list:** Show the **order number** (0, 1, 2, …).

---

## Pin geometry spec (mandatory for consistency)

Use these **exact proportions** so the Flutter `CustomPainter` (list badge + Flutter Map) and the Canvas raster (Google Maps, Mapbox) produce the same shape. Without this, "one shared pin design" will diverge in code.

**Logical dimensions:**

- **Map marker:** 40×52 logical pixels (scale by device pixel ratio for bitmap).
- **List badge:** 32×42 logical pixels.
- **Aspect ratio:** width : height ≈ 1 : 1.3.

**Path (same for both sizes; scale w and h):**

- **Top arc:** Center at `(w/2, h * 0.22)`, radius `w * 0.5`. Arc spans the top; left and right path points at the arc ends.
- **Bottom point:** `(w/2, h)`.
- **Left side:** Cubic bezier from left end of top arc `(0, h * 0.22)` → control point `(w * 0.1, h * 0.75)` → `(w/2, h)`. Control point is slightly inward (not directly below the start) to produce the **mild inward curve** (subtle concavity) seen in the reference.
- **Right side:** Cubic bezier from right end of top arc `(w, h * 0.22)` → control point `(w * 0.9, h * 0.75)` → `(w/2, h)`.
- **White circle:** Center `(w/2, h * 0.32)`. Radius `r = w * 0.36` (circle, not oval). Reference image shows ~12–15% body border on each side; `r = w * 0.36` gives ~14% border; do **not** use `w * 0.38` (only ~10% border, circle can look like it bleeds into the edge). **Implementation:** use `canvas.drawCircle(center, radius, paint)` only — **never** `drawOval` or `Rect.fromCenter`; a developer reaching for the wrong API would get an ellipse and break the spec.

**Anchor point (required for map markers):**

- The geographic point (lat/lng) must align with the **bottom tip** of the pin: `(w/2, h)` in logical pixels.
- **Google Maps:** Set `BitmapDescriptor` anchor to `(width/2, height)` in pixel space (e.g. `Offset(0.5, 1.0)` if the API uses normalized coordinates, or the pixel equivalent).
- **Flutter Map:** `Marker(anchorPos: AnchorPos.exactly(Anchor(0.5, 1.0)))` so the bottom of the widget is the anchor.
- **Mapbox web:** Position the marker element so its bottom tip is at the lng/lat (e.g. transform or anchor setting in Mapbox GL JS).

---

## Category and color mapping

**Four display categories** with body color and icon in the white circle (map only). All waypoint types map to one of these.

| Category       | Body color | Icon in white circle (map) | Waypoint types |
|----------------|------------|----------------------------|----------------|
| Sleep          | catStay    | Sleep (e.g. hotel/bed)    | accommodation |
| Food & drinks  | catEat     | Food/drinks                | restaurant, bar |
| Do & see       | catDo      | Do/see (e.g. activity)      | attraction, activity, **viewingPoint** |
| Move           | catFix     | Move (e.g. navigation)    | **routePoint**, service, servicePoint |

- **viewingPoint** → Do & see (catDo), same icon as attraction/activity.
- **routePoint**, **service**, **servicePoint** → Move (catFix), gray body, navigation icon.
- Colors from existing [`WaypointColors`](lib/theme/waypoint_colors.dart) / [`getCategoryConfig`](lib/components/waypoint/waypoint_timeline_config.dart); no new color system.

---

## Where it's used

1. **Map (Google Maps mobile/web):** Plectrum pin + white circle + **category icon**; body = category color. [`MapMarkerService`](lib/services/map_marker_service.dart) draws this with the geometry spec above; output `BitmapDescriptor.bytes()` with anchor at bottom tip.
2. **Map (Mapbox web):** Same pin design. **Decision: use raster** — generate PNG (or data URL) from the same Canvas/painter used for Google Maps so there is a single source of truth. No separate SVG path to maintain. **Retina:** generate the image at **devicePixelRatio × logical size** (e.g. 2× or 3× for high-DPI); set Mapbox marker **display dimensions** to the logical size (40×52) so the pin stays sharp on retina and isn’t blurry.
3. **Map (Flutter Map, Route Builder):** Same pin as a widget using the same path proportions in [`route_builder_screen.dart`](lib/presentation/builder/route_builder_screen.dart); anchor bottom tip.
4. **Waypoint list:** Same pin with **number** in the white circle. Single reusable widget `WaypointPinBadge` used in:
   - [`waypoint_timeline_list.dart`](lib/components/waypoint/waypoint_timeline_list.dart)
   - [`route_waypoint_card.dart`](lib/components/waypoint/route_waypoint_card.dart)
   - [`unified_waypoint_card.dart`](lib/components/waypoint/unified_waypoint_card.dart)
   - [`waypoint_timeline_card.dart`](lib/components/waypoint/waypoint_timeline_card.dart)
   - [`sidebar_waypoint_tile.dart`](lib/components/builder/sidebar_waypoint_tile.dart)
   - [`sequential_waypoint_list.dart`](lib/components/builder/sequential_waypoint_list.dart)
   - [`timeline_itinerary_widget.dart`](lib/components/itinerary/timeline_itinerary_widget.dart)

---

## Implementation plan

### 1. Single pin geometry and content

- **Shared shape:** One set of constants (or a small "pin geometry" helper) with the proportions above. Used by:
  - `MapMarkerService` (Canvas) for Google Maps and for generating raster for Mapbox.
  - A `WaypointPinPainter` (CustomPainter) for list badge and Flutter Map marker widget.
- **Drawing the cutout:** The content area is a **circle** (not an oval). In code, use **`canvas.drawCircle(center, radius, paint)`** only. Do **not** use `drawOval` or `Rect.fromCenter` — that would produce an ellipse and break the spec; developers often reach for `drawOval` by default, so this must be explicit.
- **Content in circle:** Two modes:
  - **Icon mode (map):** Category icon (sleep, food & drinks, do & see, move) centered in the circle.
  - **Number mode (list):** Order index in the circle. **Text color by luminance:** white text when pin body color luminance **< 0.4**, dark text (e.g. `BrandingLightTokens.formLabel` or equivalent) when **≥ 0.4**. This prevents unreadable gray-on-white numbers when `WaypointPinBadge` is used with catFix (gray) or on dark backgrounds.

### 2. Map markers

- **Google Maps (mobile + web):** In `MapMarkerService`, draw the plectrum path and white circle per geometry spec; paint category icon in the circle. Set **anchor to bottom tip** when creating `BitmapDescriptor`. Category color and icon from waypoint type via existing helpers.
- **Mapbox web:** Use **raster only**: same painter/service as Google produces a bitmap at **devicePixelRatio × logical size**; pass as marker image with Mapbox **display size** set to logical dimensions (40×52). Anchor at bottom tip. No separate SVG implementation.
- **Flutter Map (Route Builder):** Widget that uses `WaypointPinPainter` with same spec; category icon in circle; `Marker(anchorPos: AnchorPos.exactly(Anchor(0.5, 1.0)))`.

### 3. Selected / active state (map)

- **Decision:** When a waypoint pin is selected (e.g. user tapped it), show a **white ring** around the pin and optionally a slight scale (e.g. 1.1×). No pop-up label change in this plan; just the pin state.
- **Implementation:** Do **not** draw the ring as a stroke on the pin path — stroking a bezier at the bottom tip makes the tip look blunt. Instead: draw the ring as a **second path**, identical shape but **scaled up by ~4 px** in each dimension (or equivalent outline offset), **filled white**, rendered **before** the colored pin body. Then draw the main pin body on top. `MapMarkerService.markerForType(…, isSelected: true)` and Mapbox/Flutter Map pass selected id; painter draws this ring when selected. List badge does not need a selected state for this scope.

### 4. Waypoint list: pin with number

- **Widget:** `WaypointPinBadge` in `lib/components/waypoint/`:
  - Params: `orderIndex` (int), `color` (category color), optional `size` (default list size, e.g. 32×42).
  - **Index convention:** Caller is responsible for 0-based vs 1-based. **Dartdoc must state:** "Display value is `orderIndex` as-is; callers should pass `waypoint.order` or `index + 1` depending on whether the screen uses 0-based or 1-based order."
  - **Text color in circle:** Use the same luminance rule as in section 1: **white** when `color.computeLuminance() < 0.4`, **dark** (e.g. `BrandingLightTokens.formLabel`) when **≥ 0.4**, so gray pins (catFix) and dark backgrounds stay readable.
  - **Two-digit and large numbers:** At 32×42 px, use a **minimum readable font size** (e.g. 10–11 px). For **orderIndex ≥ 10**, either: (a) show "9+" for 10 and above, or (b) scale down font and show "10", "11", … with a max two digits. Plan choice: **(b)** — show up to two digits with reduced font so "12" is still visible; only if needed (e.g. 100+) show "99+" or similar. Specify exact min font size (e.g. 8) and max digits (2) in the widget's dartdoc.
  - **Replace usages:** In all seven list locations, swap "circle + Text(number)" for `WaypointPinBadge(orderIndex: order, color: categoryColor)`. Each caller passes the same `order`/index it currently uses so behavior (0- vs 1-based) is unchanged.

### 5. Category icons (sleep, food & drinks, do & see, move)

- Sleep: `Icons.hotel` (accommodation).
- Food & drinks: `Icons.restaurant` / `Icons.local_bar` (restaurant, bar).
- Do & see: `Icons.local_activity` / `Icons.visibility` (attraction, activity, viewingPoint).
- Move: `Icons.navigation` or `Icons.directions` (routePoint, service, servicePoint).
- Use `getCategoryConfig(waypoint.type)` (or equivalent) so one place controls icon and color.

### 6. Colors

- No new color system. Pin body uses existing category colors (`WaypointColors.catStay`, `catEat`, `catDo`, `catFix`) and mapping in `getCategoryConfig`; viewingPoint and routePoint/service are covered in the table above.

---

## Summary

| Location      | Pin body color | Content in white circle | Anchor / notes |
|---------------|----------------|--------------------------|----------------|
| Map (all)     | By category    | Category icon            | Bottom tip `(w/2, h)` |
| Waypoint list | By category    | Order number (0, 1, …)   | N/A (widget)   |

- **Shape:** Plectrum/shield (top arc + two beziers to sharp point); **white circle** cutout with explicit geometry spec.
- **One shared spec** for path and circle; one painter for raster + Flutter UI; Mapbox uses raster from that painter; anchor at bottom tip everywhere on the map.
- **WaypointPinBadge:** Document 0- vs 1-based and handling of orderIndex ≥ 10 (two digits, min font size).
