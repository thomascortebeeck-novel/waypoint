# Legacy Flutter Map Implementations

## Purpose

This folder contains **working reference implementations** using `flutter_map` with raster tiles. These files represent the **proven, stable baseline** that works reliably across all platforms.

## ⚠️ CRITICAL: DO NOT DELETE

These files serve three important purposes:

1. **Fallback Reference** - If Mapbox has issues, we can quickly revert to these implementations
2. **Behavior Reference** - Document how map interactions should work (tap handling, marker placement, route drawing)
3. **Testing Baseline** - Provide a comparison point when testing new Mapbox features

## Files

Currently empty - legacy files will be copied here when migrating screens to Mapbox.

## Migration Process

When migrating a screen to use Mapbox (via `MapConfiguration.routeBuilder()` with `useMapboxEverywhere` flag):

1. **Before changing**: Copy the current flutter_map implementation here
2. **Add documentation**: Note the date, reason for migration, and any specific behavior to preserve
3. **Update screen**: Modify to use `AdaptiveMapWidget` with `MapConfiguration`
4. **Test thoroughly**: Ensure Mapbox version matches flutter_map behavior
5. **Keep this file**: Do NOT delete until Mapbox is proven stable in production for 2+ weeks

## Rollback Instructions

If Mapbox causes issues:

1. Copy the legacy file back to its original location
2. Ensure it uses `flutter_map` directly (not `AdaptiveMapWidget`)
3. Test that original functionality is restored
4. Document the issue that caused the rollback

## Future

Once Mapbox is **proven stable at 100% rollout for 2+ weeks**, these files can be archived but should be kept in version control history.

---

**Last Updated:** 2026-01-28  
**Status:** Legacy folder created, awaiting first migration
