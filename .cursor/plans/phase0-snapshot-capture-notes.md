# Phase 0: Snapshot Capture Notes

## Status
✅ Temporary logging added to `_composeDays()` method in `builder_screen.dart`

## How to Capture Snapshots

1. **Open the first plan** in the builder screen (edit mode)
2. **Trigger a save** (click "Save Changes" or "Publish")
3. **Check console logs** for output starting with `=== SNAPSHOT OUTPUT FOR PLAN ... ===`
4. **Copy the JSON** between the markers
5. **Save to file**: `test/fixtures/plan_1_snapshot.json`
6. **Repeat for the second plan**: Save to `test/fixtures/plan_2_snapshot.json`

## Important Notes

- The snapshot includes:
  - `plan_id`: The plan ID
  - `version_id`: The version ID (tempId)
  - `days`: Array of DayItinerary JSON objects
  - `captured_at`: Timestamp

- **Known Blind Spot**: Fields that don't exist in the 2 current plans won't be covered by golden files. Manually verify any new fields added during migration.

## After Capture

- Verify both files exist and contain valid JSON
- Check that days array has expected structure
- **DO NOT proceed to Phase 1 until golden files are captured**

## Cleanup

After Phase 4 (when snapshot test is created and passing), remove the temporary logging code from `_composeDays()`.







