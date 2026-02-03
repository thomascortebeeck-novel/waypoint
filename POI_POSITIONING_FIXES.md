# POI Positioning and Loading Fixes

## Issues Fixed

### 1. ✅ NoSuchMethodError on Map Click Handler (Line 248)
**Problem**: `originalEvent['target']` was throwing `NoSuchMethodError` because `originalEvent` might not be a JavaScript object.

**Solution**: Added safe type checking to ensure `originalEvent` and `target` are `JsObject` instances before accessing properties. Wrapped in try-catch to prevent blocking all clicks.

**File**: `lib/features/map/web/mapbox_web_widget.dart` (lines 243-277)

### 2. ✅ POI Markers Moving When Zooming
**Problem**: POIs were being cleared and reloaded on every zoom change, causing markers to disappear and reappear, making them appear to "move" across the map.

**Root Causes**:
- POIs were being cleared immediately on zoom changes
- Markers were being recreated instead of updated in place
- No check to see if marker position actually changed before updating

**Solutions**:
1. **Prevent Clearing POIs on Zoom**: Only clear POIs when zooming out below the threshold (12.0), not on every zoom change
2. **Smart Marker Updates**: Check if marker position actually changed (> 1 meter) before updating to prevent unnecessary updates
3. **POI Merging**: When new POIs are loaded, merge them with existing ones instead of replacing all

**Files**:
- `lib/presentation/builder/route_builder_screen.dart` (lines 745-760, 1145-1181)
- `lib/features/map/web/mapbox_web_widget.dart` (lines 662-750)

### 3. ✅ Not All POIs Showing
**Problem**: Only 6 POIs were appearing when more should be available.

**Investigation**:
- Added detailed logging to track POI loading, deduplication, and filtering
- Logs now show:
  - How many POIs were fetched from API
  - How many were new vs. updated
  - How many were filtered due to deduplication
  - If API returned fewer than requested

**Solutions**:
1. **Better Logging**: Added comprehensive logging to understand POI flow
2. **Deduplication Tracking**: Log how many POIs are filtered due to proximity to waypoints/route points
3. **API Response Tracking**: Log if API returns fewer POIs than requested (indicates sparse coverage)

**Files**:
- `lib/presentation/builder/route_builder_screen.dart` (lines 650-683, 1180-1183)

## Key Changes

### Marker Update Logic
- **Before**: Markers were updated on every annotation change, even if position didn't change
- **After**: Markers are only updated if position changed by > 1 meter, preventing flicker

### POI Loading Strategy
- **Before**: POIs were cleared on every zoom change, causing markers to disappear
- **After**: POIs are merged with existing ones, only cleared when zooming out below threshold

### Click Handler Safety
- **Before**: Direct access to `originalEvent['target']` without type checking
- **After**: Safe type checking with try-catch fallback

## Testing Checklist

- [ ] Zoom in/out - POIs should stay in place, not move
- [ ] Check console logs - should see detailed POI loading information
- [ ] Click map (not on controls) - should trigger waypoint picker
- [ ] Click zoom controls - should NOT trigger map tap
- [ ] POI count - check logs to see if API is returning expected number

## Expected Console Output

After fixes, you should see logs like:
```
✅ Loaded 6 OSM POIs from API (6 new, 0 updated) at zoom 14.0 (maxResults: 150, total in memory: 6)
ℹ️ API returned fewer POIs than requested (6 < 150) - may indicate sparse POI coverage in this area
📍 Converting 6 OSM POIs to 6 annotations (0 filtered)
📍 [MapboxWeb] Marker 5699873367 position unchanged (0.2m), skipping update
```

This helps identify:
- How many POIs the API actually returned
- Whether deduplication is filtering too many
- Whether markers are being unnecessarily updated



