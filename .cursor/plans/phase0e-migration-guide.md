# Phase 0e: Migration Guide - Integrating State Classes into builder_screen.dart

## Overview

This guide provides a step-by-step process for migrating `builder_screen.dart` from the old state management pattern (individual controllers and `_VersionFormData`) to the new state classes (`AdventureFormState`, `VersionFormState`, `DayFormState`).

**File Size**: 7685 lines  
**Estimated Changes**: ~500-800 lines modified  
**Risk Level**: High - requires careful systematic replacement

---

## Table of Contents

1. [Known Schema Changes](#known-schema-changes)
2. [State Variable Mapping](#state-variable-mapping)
3. [Method Signature Changes](#method-signature-changes)
4. [UI Pattern Updates](#ui-pattern-updates)
5. [Step-by-Step Migration Process](#step-by-step-migration-process)
6. [Common Patterns & Replacements](#common-patterns--replacements)
7. [Testing Checklist](#testing-checklist)
8. [Rollback Plan](#rollback-plan)

---

## State Variable Mapping

### Plan-Level State → AdventureFormState

| Old Variable | New Location | Notes |
|-------------|--------------|-------|
| `_nameCtrl` | `formState.nameCtrl` | Direct replacement |
| `_locationCtrl` | `formState.locationCtrl` | Direct replacement |
| `_locationFocusNode` | `formState.locationSearch.focusNode` | Moved to LocationSearchState |
| `_locationSuggestions` | `formState.locationSearch.suggestions` | Moved to LocationSearchState |
| `_searchingLocation` | `formState.locationSearch.isSearching` | Moved to LocationSearchState |
| `_locationLat`, `_locationLng` | `formState.locationSearch.selectedLocation` | Now ll.LatLng? instead of separate |
| `_locationDebounceTimer` | `formState.locationSearch._debounceTimer` | Internal to LocationSearchState |
| `_locationLastQuery` | `formState.locationSearch.lastQuery` | Moved to LocationSearchState |
| `_locationSearchFuture` | `formState.locationSearch.searchFuture` | Moved to LocationSearchState |
| `_locationLastSearchTime` | `formState.locationSearch.lastSearchTime` | Moved to LocationSearchState |
| `_descCtrl` | `formState.descriptionCtrl` | Direct replacement |
| `_heroCtrl` | `formState.heroImageUrlCtrl` | Renamed for clarity |
| `_priceCtrl` | `formState.priceCtrl` | Direct replacement |
| `_coverImageBytes` | `formState.coverImageBytes` | Direct replacement |
| `_coverImageExtension` | `formState.coverImageExtension` | Direct replacement |
| `_uploadingCoverImage` | `formState.uploadingCoverImage` | Direct replacement |
| `_isPublished` | `formState.isPublished` | Direct replacement |
| `_activityCategory` | `formState.activityCategory` | Direct replacement |
| `_accommodationType` | `formState.accommodationType` | Direct replacement |
| `_bestSeasons` | `formState.bestSeasons` | Direct replacement |
| `_isEntireYear` | `formState.isEntireYear` | Direct replacement |
| `_showPrices` | `formState.showPrices` | Direct replacement |
| `_isGeneratingInfo` | `formState.isGeneratingInfo` | Direct replacement |
| `_generatedPrepare` | `formState.activeVersion.generatedPrepare` | **MOVED TO VERSION LEVEL** |
| `_generatedLocalTips` | `formState.activeVersion.generatedLocalTips` | **MOVED TO VERSION LEVEL** |
| `_isSaving` | `formState.isSaving` | Direct replacement |
| `_lastSavedAt` | `formState.lastSavedAt` | Direct replacement |
| `_saveStatus` | `formState.saveStatus` | Direct replacement |
| `_editingPlan` | `formState.editingPlan` | Direct replacement |
| `_versions` | `formState.versions` | Now List<VersionFormState> |
| `_activeVersionIndex` | `formState.activeVersionIndex` | Direct replacement |
| `_currentDayIndex` | **TODO: Migrate to VersionFormState** | Can go out of bounds when switching versions. Add bounds checking now, migrate later. |
| `_dayOrderManagers` | **TODO: Migrate to use RouteWaypoint.order** | Should use RouteWaypoint.order as single source of truth. Keep as local state for now, migrate in follow-up PR. |

### Version-Level State → VersionFormState

| Old Pattern | New Pattern | Notes |
|------------|-------------|-------|
| `_versions[i]` | `formState.versions[i]` | Direct replacement |
| `_versions[_activeVersionIndex]` | `formState.activeVersion` | Use shortcut getter |
| `vf.name` | `version.nameCtrl` | Controller access |
| `vf.duration` | `version.durationCtrl` | Controller access |
| `vf.daysCount` | `version.daysCount` | Direct replacement |
| `vf.packingCategories` | `version.packingCategories` | Direct replacement |
| `vf.transportationOptions` | `version.transportationOptions` | Direct replacement |
| `vf.faqItems` | `formState.faqItems` | **MOVED TO PLAN LEVEL** |
| `vf.titleCtrl(dayNum)` | `version.getDayState(dayNum).titleCtrl` | Lazy day state creation |
| `vf.descCtrl(dayNum)` | `version.getDayState(dayNum).descCtrl` | Lazy day state creation |
| `vf.distanceCtrl(dayNum)` | `version.getDayState(dayNum).distanceCtrl` | Lazy day state creation |
| `vf.timeCtrl(dayNum)` | `version.getDayState(dayNum).timeCtrl` | Lazy day state creation |
| `vf.stayUrlCtrl(dayNum)` | `version.getDayState(dayNum).stayUrlCtrl` | Lazy day state creation |
| `vf.stayCostCtrl(dayNum)` | `version.getDayState(dayNum).stayCostCtrl` | Lazy day state creation |
| `vf.komootLinkCtrl(dayNum)` | `version.getDayState(dayNum).komootLinkCtrl` | Lazy day state creation |
| `vf.allTrailsLinkCtrl(dayNum)` | `version.getDayState(dayNum).allTrailsLinkCtrl` | Lazy day state creation |
| `vf.startForDay[dayNum]` | `version.getDayState(dayNum).start` | Direct property |
| `vf.endForDay[dayNum]` | `version.getDayState(dayNum).end` | Direct property |
| `vf.routeByDay[dayNum]` | `version.getDayState(dayNum).route` | Direct property |
| `vf.routeInfoByDay[dayNum]` | `version.getDayState(dayNum).routeInfo` | Direct property |
| `vf.gpxRouteByDay[dayNum]` | `version.getDayState(dayNum).gpxRoute` | Direct property |
| `vf.dayImagesByDay[dayNum]` | `version.getDayState(dayNum).dayImageBytes` | Direct property |
| `vf.dayImageExtByDay[dayNum]` | `version.getDayState(dayNum).dayImageExtension` | Direct property |
| `vf.existingDayImageUrls[dayNum]` | `version.getDayState(dayNum).existingDayImageUrl` | Direct property |
| `vf.stayMetaByDay[dayNum]` | `version.getDayState(dayNum).stayMeta` | Direct property |

---

## Method Signature Changes

### Initialization Methods

**Before:**
```dart
@override
void initState() {
  super.initState();
  _pageController.addListener(_onPageChanged);
  if (widget.editPlanId != null) {
    _loadExistingPlan(widget.editPlanId!);
  } else {
    final initialVersion = _VersionFormData.initial();
    _addVersionListeners(initialVersion);
    _versions.add(initialVersion);
  }
  _nameCtrl.addListener(() => setState(() {}));
  // ... more listeners
}
```

**After:**
```dart
AdventureFormState? formState; // Nullable to handle async load
late final AdventureSaveService saveService;

@override
void initState() {
  super.initState();
  _pageController.addListener(_onPageChanged);
  
  // Initialize services
  saveService = AdventureSaveService(
    planService: _planService,
    storageService: _storageService,
    userService: _userService,
  );
  
  if (widget.editPlanId != null) {
    _loadExistingPlan(widget.editPlanId!);
    // formState will be set in _loadExistingPlan (async)
  } else {
    formState = AdventureFormState.initial();
    // Listeners are handled by ListenableBuilder in UI
  }
}

@override
Widget build(BuildContext context) {
  // Guard against null formState during async load
  if (formState == null) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
  // ... rest of build method
}
```

### Load Existing Plan

**Before:**
```dart
Future<void> _loadExistingPlan(String planId) async {
  setState(() => _isLoadingExisting = true);
  try {
    final plan = await _planService.loadFullPlan(planId);
    if (plan != null) {
      _editingPlan = plan;
      _generatedPrepare = plan.prepare ?? Prepare();
      _generatedLocalTips = plan.localTips ?? LocalTips();
      _nameCtrl.text = plan.name;
      // ... 150+ lines of hydration
    }
  } finally {
    setState(() => _isLoadingExisting = false);
  }
}
```

**After:**
```dart
Future<void> _loadExistingPlan(String planId) async {
  setState(() => _isLoadingExisting = true);
  try {
    final plan = await _planService.loadFullPlan(planId);
    if (plan != null) {
      // Create new state from plan
      formState = AdventureFormState.fromPlan(plan);
      
      // TEMPORARY: Dual-write - also populate old state for validation
      _editingPlan = plan;
      _nameCtrl.text = plan.name;
      _locationCtrl.text = plan.location;
      // ... populate other old state fields
      
      // TEMPORARY: Assert new state matches old state
      assert(formState!.nameCtrl.text == _nameCtrl.text);
      assert(formState!.locationCtrl.text == _locationCtrl.text);
      
      // Geocode location for map preview (if needed)
      if (plan.location.isNotEmpty) {
        try {
          final placesService = GooglePlacesService();
          final location = await placesService.geocodeAddress(plan.location);
          if (location != null && mounted) {
            formState!.locationSearch.selectedLocation = location;
            formState!.locationSearch.selectedLocationName = plan.location;
            formState!.locationSearch.notifyListeners();
          }
        } catch (e) {
          Log.w('builder', 'Failed to geocode location: $e');
        }
      }
      
      // Trigger rebuild now that formState is set
      if (mounted) setState(() {});
    }
  } finally {
    if (mounted) {
      setState(() => _isLoadingExisting = false);
    }
  }
}
```

### Save Methods

**Before:**
```dart
Future<bool> _saveCurrentStep() async {
  // ... 100+ lines of save logic
  await _planService.updatePlanWithVersions(updated);
  setState(() {
    _saveStatus = 'Saved';
    _lastSavedAt = DateTime.now();
  });
  return true;
}
```

**After:**
```dart
Future<bool> _saveCurrentStep() async {
  final result = await saveService.saveDraft(formState);
  return result.success;
}
```

**Before:**
```dart
Future<void> _saveAIGeneratedData(Prepare prepare, LocalTips localTips) async {
  // ... Firestore update logic
}
```

**After:**
```dart
Future<void> _saveAIGeneratedData(Prepare prepare, LocalTips localTips) async {
  if (formState.editingPlan == null) return;
  final version = formState.activeVersion;
  await saveService.saveAIData(
    formState.editingPlan!.id,
    version.tempId,
    prepare,
    localTips,
  );
}
```

---

## UI Pattern Updates

### Replace setState() with ListenableBuilder

**Before:**
```dart
TextField(
  controller: _nameCtrl,
  onChanged: (value) => setState(() {}),
)
```

**After:**
```dart
ListenableBuilder(
  listenable: formState,
  builder: (context, _) => TextField(
    controller: formState.nameCtrl,
  ),
)
```

**Before:**
```dart
Text(_saveStatus)
```

**After:**
```dart
ListenableBuilder(
  listenable: formState,
  builder: (context, _) => Text(formState.saveStatus),
)
```

### Version Access Pattern

**Before:**
```dart
final vf = _versions[_activeVersionIndex];
final dayCount = vf.daysCount;
```

**After:**
```dart
final version = formState.activeVersion;
final dayCount = version.daysCount;
```

### Day Access Pattern

**Before:**
```dart
final titleCtrl = vf.titleCtrl(dayNum);
final descCtrl = vf.descCtrl(dayNum);
```

**After:**
```dart
final day = version.getDayState(dayNum);
final titleCtrl = day.titleCtrl;
final descCtrl = day.descCtrl;
```

### Activity Category Helpers

**Before:**
```dart
String _getActivityTimeLabel() {
  switch (_activityCategory) {
    // ...
  }
}
```

**After:**
```dart
String _getActivityTimeLabel() {
  switch (formState.activityCategory) {
    // ...
  }
}
```

Or use the helper:
```dart
formState.isOutdoorActivity
formState.isCityActivity
```

---

## Known Schema Changes

### Firestore Structure Changes

**CRITICAL**: The following structural changes affect how data is saved and loaded:

1. **Prepare and LocalTips moved to version subcollection**
   - **Before**: `plans/{planId}/prepare` and `plans/{planId}/local_tips`
   - **After**: `plans/{planId}/versions/{versionId}/prepare` and `plans/{planId}/versions/{versionId}/local_tips`
   - **Impact**: `saveAIData()` now saves to version subcollection, not plan level
   - **Migration**: Existing plans will need to be re-saved (only 2 plans exist, can be done manually)

2. **Version data structure**
   - Versions are stored in subcollections: `plans/{planId}/versions/{versionId}`
   - Days are stored in: `plans/{planId}/versions/{versionId}/days/{dayId}`
   - This structure already exists, but Prepare/LocalTips are now included

3. **Plan metadata**
   - Plan document now contains only metadata (no embedded versions)
   - FAQ items remain at plan level: `plans/{planId}/faq_items`

### Data Migration Notes

- **No automatic migration needed** - only 2 plans exist
- Plans can be manually re-saved through new builder
- Old plans with Prepare/LocalTips at plan level will be ignored
- New saves will use per-version structure

---

## Step-by-Step Migration Process

### Phase 0: Regression Safety Net (CRITICAL - DO NOT SKIP)

**Purpose**: Capture golden-file snapshots of current save output to verify migration doesn't change data structure.

**Why This Matters**: Without this, you have no way to verify that `_composeDays()` and save logic produce identical Firestore documents after migration. A single field order change or missing field could break existing plans.

#### Step 0.1: Capture Current Save Output

1. **Load both existing plans** in current builder_screen.dart
2. **Trigger save** for each plan (use `_saveCurrentStep()` or `_publishPlan()`)
3. **Capture Firestore document structure**:
   ```dart
   // Add temporary logging in _composeDays()
   final daysJson = days.map((d) => d.toJson()).toList();
   final versionsJson = versions.map((v) => v.toJson()).toList();
   Log.i('snapshot', 'Plan ${plan.id} versions: ${jsonEncode(versionsJson)}');
   Log.i('snapshot', 'Plan ${plan.id} days: ${jsonEncode(daysJson)}');
   ```

4. **Save output to files**:
   - `test/fixtures/plan_1_snapshot.json`
   - `test/fixtures/plan_2_snapshot.json`

#### Step 0.2: Capture Output from CURRENT Code

**CRITICAL**: This step captures output from the **existing** `_composeDays()` method, not the new classes.

1. **Add temporary export in builder_screen.dart**:
   ```dart
   // TEMPORARY: Export for snapshot test
   Future<List<DayItinerary>> _composeDaysForSnapshot(
     _VersionFormData vf, 
     String planId, 
     {List<DayItinerary> existing = const []}
   ) async {
     return await _composeDays(vf, planId, existing: existing);
   }
   ```

2. **Create capture script** (run once, then delete):
   ```dart
   // scripts/capture_snapshots.dart
   import 'package:waypoint/services/plan_service.dart';
   import 'package:waypoint/presentation/builder/builder_screen.dart';
   import 'dart:convert';
   import 'dart:io';
   
   Future<void> main() async {
     final planService = PlanService();
     
     // Capture plan 1
     final plan1 = await planService.loadFullPlan('plan_1_id');
     if (plan1 != null) {
       final vf = _VersionFormData.fromVersion(plan1.versions.first);
       final days = await _composeDaysForSnapshot(vf, plan1.id, existing: plan1.versions.first.days);
       final output = {
         'plan_id': plan1.id,
         'version_id': plan1.versions.first.id,
         'days': days.map((d) => d.toJson()).toList(),
         'version': plan1.versions.first.toJson(),
       };
       await File('test/fixtures/plan_1_snapshot.json')
           .writeAsString(jsonEncode(output));
     }
     
     // Repeat for plan 2
   }
   ```

3. **Run capture script**:
   ```bash
   dart run scripts/capture_snapshots.dart
   ```

4. **Verify golden files created**:
   - `test/fixtures/plan_1_snapshot.json`
   - `test/fixtures/plan_2_snapshot.json`

#### Step 0.3: Create Comparison Test (For Phase 4)

**Note**: This test will be created in Phase 4, not Phase 0. Phase 0 only captures the golden files.

The test will compare new `AdventureSaveService.composeDays()` output against the golden files captured in Phase 0.

```dart
// test/presentation/builder/builder_save_snapshot_test.dart
// Created in Phase 4, not Phase 0
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/services/adventure_save_service.dart';
import 'package:waypoint/state/adventure_form_state.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  test('save output matches golden file for plan 1', () async {
    // Load plan 1
    final plan = await planService.loadFullPlan('plan_1_id');
    final formState = AdventureFormState.fromPlan(plan);
    
    // Compose days using NEW service
    final saveService = AdventureSaveService(...);
    final version = formState.activeVersion;
    final days = await saveService.composeDays(
      version,
      plan.id,
      formState.activityCategory,
    );
    
    // Compare to golden file captured in Phase 0
    final goldenFile = File('test/fixtures/plan_1_snapshot.json');
    final expected = jsonDecode(await goldenFile.readAsString());
    final actual = days.map((d) => d.toJson()).toList();
    
    expect(actual, equals(expected['days']));
  });
  
  // Repeat for plan 2
}
```

#### Step 0.4: Verify Golden Files

- Check that both golden files exist and contain valid JSON
- Verify they contain expected structure (days array, version data)
- **DO NOT proceed to Phase 1 until golden files are captured**

#### Known Blind Spot: New Fields Not in Existing Plans

**CRITICAL**: The snapshot test only validates fields that exist in the 2 current plans. If you add new fields during migration that don't exist in those plans, they won't be covered by the golden files.

**Risk**: If `fromPlan()` loads a field into `day.distanceCtrl` but `composeDays()` saves from a different property, data silently disappears. The snapshot test won't catch this for new fields.

**Mitigation**:
- Manually verify any field that doesn't exist in the 2 current plans
- Add explicit tests for new fields if they're added during migration
- Document any new fields added in migration notes

---

### Phase 1: Add New State and Services (Low Risk)

1. **Add imports** at top of file:
```dart
import 'package:waypoint/state/adventure_form_state.dart';
import 'package:waypoint/state/version_form_state.dart';
import 'package:waypoint/state/day_form_state.dart';
import 'package:waypoint/services/adventure_save_service.dart';
```

2. **Add new state fields** (keep old ones for now):
```dart
// Use nullable to handle async load - will be initialized in initState or _loadExistingPlan
AdventureFormState? formState; // Nullable because _loadExistingPlan() is async
late final AdventureSaveService saveService;
```

**IMPORTANT**: `formState` is nullable because `_loadExistingPlan()` is async. Add a loading guard in build method:
```dart
@override
Widget build(BuildContext context) {
  // Guard against null formState during async load
  if (formState == null) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
  // ... rest of build method
}
```

3. **Initialize in initState()** (parallel to old code):
```dart
saveService = AdventureSaveService(
  planService: _planService,
  storageService: _storageService,
  userService: _userService,
);
```

### Phase 2: Update Load Logic (Medium Risk)

**Dual-Write Pattern**: During this phase, populate BOTH old and new state, then assert they match.

1. **Update `_loadExistingPlan()`**:
   - Replace hydration logic with `AdventureFormState.fromPlan()`
   - Set `formState = AdventureFormState.fromPlan(plan)` (async, so formState is nullable)
   - Keep geocoding logic separate
   - **Dual-write**: Also populate old state temporarily for validation
   - Test loading existing plans

2. **Update `initState()` for new plans**:
   - Replace `_VersionFormData.initial()` with `AdventureFormState.initial()`
   - Set `formState = AdventureFormState.initial()` (synchronous, so formState is set immediately)
   - **Dual-write**: Also populate old state temporarily for validation

3. **Add dual-write assertions** (temporary, remove in Phase 5):
   ```dart
   // TEMPORARY: Verify new state matches old state
   assert(formState.nameCtrl.text == _nameCtrl.text);
   assert(formState.locationCtrl.text == _locationCtrl.text);
   assert(formState.versions.length == _versions.length);
   for (var i = 0; i < formState.versions.length; i++) {
     assert(formState.versions[i].nameCtrl.text == _versions[i].name.text);
     assert(formState.versions[i].daysCount == _versions[i].daysCount);
   }
   ```
   - Add these assertions after loading/initializing
   - Remove in Phase 5 (cleanup)

### Phase 3: Update UI Builders (High Risk, Large Scope)

**IMPORTANT**: UI migration comes BEFORE save migration because:
- Save logic reads from form state
- UI populates form state
- If save reads new state while UI writes old state, they'll be out of sync

**Rebuild Boundary Strategy**: Wrap at SECTION level, not per-field.

#### Rebuild Boundary Guidelines

1. **Section-level wrapping**:
   - Wrap `_buildGeneralInfoSection()` in `ListenableBuilder(listenable: formState)`
   - Wrap `_buildDayCard()` in `ListenableBuilder(listenable: dayState)`
   - Wrap `_buildPrepareSection()` in `ListenableBuilder(listenable: versionState)`

2. **TextEditingController updates**:
   - **NO ListenableBuilder needed** for TextField typing
   - TextEditingController already updates its own TextField
   - Only wrap if you need to show/hide fields based on state

3. **Derived UI needs ListenableBuilder**:
   - Save status: `ListenableBuilder(listenable: formState, builder: (_, __) => Text(formState.saveStatus))`
   - Computed labels: Activity time label, version count
   - Conditional visibility: Outdoor fields based on activity category
   - Validation indicators: "Complete" badges, error messages

4. **State notification boundaries**:
   - `AdventureFormState.notifyListeners()` → rebuilds plan-level sections
   - `VersionFormState.notifyListeners()` → rebuilds version-dependent tabs
   - `DayFormState.notifyListeners()` → rebuilds individual day cards
   - TextEditingController changes → only that field updates (no rebuild needed)

#### UI Migration Order (Least to Most Complex)

1. **Simple text fields** (name, description, price):
   - Replace controller: `_nameCtrl` → `formState.nameCtrl`
   - **NO ListenableBuilder needed** - TextField handles its own updates
   - Only add ListenableBuilder if field visibility depends on state

2. **Version selector**:
   - Update to use `formState.versions` and `formState.activeVersionIndex`
   - Add `ListenableBuilder(listenable: formState)` around version selector widget
   - Update setter: `formState.activeVersionIndex = newIndex` (triggers rebuild)

3. **Day builders**:
   - Replace `vf.titleCtrl(dayNum)` with `version.getDayState(dayNum).titleCtrl`
   - Wrap `_buildDayCard()` in `ListenableBuilder(listenable: dayState)`
   - Update all day field access patterns

4. **Prepare/LocalTips sections**:
   - Update to use `formState.activeVersion.prepareInsuranceRecommendationCtrl`
   - Wrap sections in `ListenableBuilder(listenable: formState.activeVersion)`
   - Update all Prepare/LocalTips field access

5. **Location search**:
   - Replace `_locationCtrl` with `formState.locationCtrl`
   - Replace location search logic to use `formState.locationSearch`
   - Wrap location search widget in `ListenableBuilder(listenable: formState.locationSearch)`

6. **Complex builders** (overview, day cards):
   - Update last, as they depend on all other changes
   - Wrap entire overview section in `ListenableBuilder(listenable: formState)`

#### Verification After Each UI Sub-Step

**CRITICAL**: After migrating each UI category (1-6), verify before moving to the next:

1. **Hot reload** the app
2. **Open builder screen** (new or existing plan)
3. **Verify the migrated section renders correctly**:
   - Fields appear in correct positions
   - No layout breaks
   - No missing widgets
4. **Verify typing works**:
   - Type in migrated text fields
   - Values update correctly
   - No console errors
5. **Verify state updates**:
   - Change values in migrated fields
   - Navigate away and back
   - Values persist correctly
6. **Git commit** after each sub-step passes verification

**Why this matters**: If you migrate all 6 categories and hit a crash, you won't know which change broke it. Incremental verification catches issues immediately.

---

### Phase 4: Update Save Logic (High Risk)

**Why After UI**: Save logic reads from form state. UI must be writing to form state first.

1. **Create snapshot comparison test** (from Step 0.3):
   - Create `test/presentation/builder/builder_save_snapshot_test.dart`
   - Test compares new `AdventureSaveService.composeDays()` output to golden files
   - Run test - should pass if migration is correct

2. **Replace `_saveCurrentStep()`**:
   - Replace entire method body with `saveService.saveDraft(formState!)`
   - Remove all manual Plan construction
   - Test save functionality
   - **Verify snapshot test still passes**

3. **Replace `_saveAIGeneratedData()`**:
   - Update to use `saveService.saveAIData()`
   - **CRITICAL**: Update to pass version ID: `formState!.activeVersion.tempId`
   - Update all call sites (currently saves to plan level, now saves to version subcollection)
   - Verify Firestore structure matches expected (version subcollection)

4. **Update `_publishPlan()` and `_saveChanges()`**:
   - Replace with `saveService.saveAndValidate(formState!)`
   - Remove manual version/day composition
   - Test publish and save flows
   - **Verify snapshot test still passes**

5. **Final snapshot test verification**:
   - Re-run snapshot comparison test
   - Output should match golden files exactly
   - If not, investigate differences before proceeding
   - Check Firestore structure matches (Prepare/LocalTips in version subcollection)

### Phase 5: Remove Old State & Cleanup (Low Risk, After Testing)

1. **Remove old state variables**:
   - Delete `_nameCtrl`, `_locationCtrl`, etc.
   - Delete `List<_VersionFormData> _versions`
   - Delete `_VersionFormData` class definition

2. **Remove old listeners**:
   - Delete `_addVersionListeners()` method
   - Delete `_addFaqListeners()` method
   - Remove all `addListener(() => setState(() {}))` calls

3. **Update dispose()**:
   - Replace with `formState?.dispose()` (nullable check) and `saveService.dispose()`
   - Remove all old controller dispose calls

4. **Remove dual-write assertions**:
   - Remove all temporary assertions added in Phases 2-3
   - Remove commented-out old UI code
   - Remove dual-write state population code

5. **Migrate `_dayOrderManagers`** (Follow-up):
   - **Current**: Kept as local state (not ideal)
   - **Future**: Should use `RouteWaypoint.order` as single source of truth
   - **Action**: Flag as technical debt, migrate in separate PR
   - **Note**: DayPlanOrderManager may still be needed for UI reordering, but should sync with RouteWaypoint.order

6. **Migrate `_currentDayIndex`** (Follow-up):
   - **Current**: Kept as local state (can go out of bounds)
   - **Better**: Store on `VersionFormState` (each version remembers current day)
   - **Minimum**: Add bounds checking when switching versions
   - **Action**: Add to VersionFormState: `int? currentDayIndex`
   - **Update**: Check bounds in `set activeVersionIndex`:
     ```dart
     set activeVersionIndex(int value) {
       if (value >= 0 && value < versions.length) {
         _activeVersionIndex = value;
         // Reset currentDayIndex if out of bounds for new version
         final newVersion = versions[value];
         if (currentDayIndex != null && currentDayIndex! >= newVersion.daysCount) {
           currentDayIndex = null;
         }
         notifyListeners();
       }
     }
     ```

---

## Common Patterns & Replacements

### Pattern 1: Accessing Current Version

**Before:**
```dart
final vf = _versions[_activeVersionIndex];
```

**After:**
```dart
final version = formState.activeVersion;
```

### Pattern 2: Accessing Day Fields

**Before:**
```dart
final title = vf.titleCtrl(dayNum).text;
vf.distanceCtrl(dayNum).text = '10.5';
```

**After:**
```dart
final day = version.getDayState(dayNum);
final title = day.titleCtrl.text;
day.distanceCtrl.text = '10.5';
```

### Pattern 3: Updating State

**Before:**
```dart
setState(() {
  _isSaving = true;
  _saveStatus = 'Saving...';
});
```

**After:**
```dart
formState.isSaving = true;
formState.saveStatus = 'Saving...';
// No setState needed - ListenableBuilder will rebuild
```

### Pattern 4: Conditional UI Based on Activity

**Before:**
```dart
if (_activityCategory == ActivityCategory.hiking) {
  // Show outdoor fields
}
```

**After:**
```dart
if (formState.isOutdoorActivity) {
  // Show outdoor fields
}
```

### Pattern 5: Version List Operations

**Before:**
```dart
_versions.add(_VersionFormData.initial());
_versions.removeAt(index);
_versions.length;
```

**After:**
```dart
// CRITICAL: List mutations don't auto-notify - must call notifyListeners()
formState!.versions.add(VersionFormState.initial());
formState!.notifyListeners(); // Required for UI to update

// Or better: Add helper method to AdventureFormState
formState!.addVersion(VersionFormState.initial());
// where addVersion() calls notifyListeners() internally

// Removing versions
formState!.versions.removeAt(index);
// Adjust activeVersionIndex if needed
if (formState!.activeVersionIndex >= formState!.versions.length) {
  formState!.activeVersionIndex = formState!.versions.length - 1;
}
formState!.notifyListeners(); // Required for UI to update
```

**Better Pattern**: Add helper methods to `AdventureFormState`:
```dart
// In AdventureFormState class
void addVersion(VersionFormState version) {
  versions.add(version);
  notifyListeners();
}

void removeVersion(int index) {
  if (index < 0 || index >= versions.length) return;
  versions[index].dispose(); // Clean up
  versions.removeAt(index);
  if (_activeVersionIndex >= versions.length) {
    _activeVersionIndex = versions.length > 0 ? versions.length - 1 : 0;
  }
  notifyListeners();
}
```

### Pattern 6: Location Search

**Before:**
```dart
_locationDebounceTimer?.cancel();
_locationSearchFuture = null;
_locationLastQuery = query;
```

**After:**
```dart
formState.locationSearch.cancelSearch();
formState.locationSearch.lastQuery = query;
```

### Pattern 7: Prepare/LocalTips Access

**Before:**
```dart
_generatedPrepare?.travelInsurance?.recommendation
_generatedLocalTips?.emergency?.police
```

**After:**
```dart
formState.activeVersion.generatedPrepare?.travelInsurance?.recommendation
formState.activeVersion.generatedLocalTips?.emergency?.police
```

### Pattern 8: Day Route Access

**Before:**
```dart
final route = vf.routeByDay[dayNum];
vf.routeByDay[dayNum] = newRoute;
```

**After:**
```dart
final day = version.getDayState(dayNum);
final route = day.route;
day.route = newRoute;
// DayFormState.route setter should call notifyListeners() internally
// If it doesn't, that's a bug in DayFormState - fix the setter, don't call notifyListeners() here
```

**IMPORTANT**: Property setters in state classes should call `notifyListeners()` internally. External code should **never** need to call `notifyListeners()` directly. If you find yourself calling `notifyListeners()` from `builder_screen.dart`, the state class is missing a proper setter.

**Correct Pattern** (in DayFormState):
```dart
DayRoute? _route;
DayRoute? get route => _route;
set route(DayRoute? value) {
  if (_route != value) {
    _route = value;
    notifyListeners(); // Called internally
  }
}
```

**Incorrect Pattern** (in builder_screen.dart):
```dart
day.route = newRoute;
day.notifyListeners(); // DON'T DO THIS - fix the setter instead
```

---

## Testing Checklist

### Pre-Migration Testing
- [ ] Current builder_screen.dart works (create, edit, save, publish)
- [ ] All existing tests pass
- [ ] No linter errors

### Post-Phase 1 (Add New State)
- [ ] File compiles
- [ ] No runtime errors on startup
- [ ] Old functionality still works

### Post-Phase 2 (Update Load Logic)
- [ ] Can load existing plan
- [ ] All fields populate correctly
- [ ] Versions load correctly
- [ ] Days load correctly
- [ ] Prepare/LocalTips load correctly (from version)

### Post-Phase 3 (Update UI)
- [ ] All text fields work
- [ ] Version selector works
- [ ] Day tabs work
- [ ] Prepare tab works
- [ ] Local Tips tab works
- [ ] Location search works
- [ ] Activity category changes work
- [ ] UI updates reactively (no setState needed)
- [ ] Rebuild boundaries are at section level (not per-field)

### Post-Phase 4 (Update Save Logic)
- [ ] Can save draft
- [ ] Can publish new plan
- [ ] Can update existing plan
- [ ] AI data saves correctly (to version subcollection)
- [ ] Images upload correctly
- [ ] Save status updates correctly
- [ ] **Snapshot test still passes** (output matches golden files)

### Post-Phase 5 (Cleanup)
- [ ] Old state variables removed
- [ ] Old methods removed
- [ ] Dual-write assertions removed
- [ ] File compiles
- [ ] All functionality works
- [ ] Dispose verification passes (see below)

### Dispose Verification

**Purpose**: Verify all controllers are properly disposed to prevent memory leaks.

**Steps**:
1. **Add logging to dispose methods**:
   ```dart
   @override
   void dispose() {
     print('[AdventureFormState] dispose() called');
     nameCtrl.dispose();
     // ... rest of dispose
     super.dispose();
   }
   ```

2. **Navigate away from builder screen**:
   - Open builder screen
   - Make some changes
   - Navigate back (pop route)
   - Check console for dispose logs

3. **Verify dispose fires**:
   - All dispose methods should log
   - No "dispose called multiple times" errors
   - Check Flutter DevTools Memory tab

4. **Check for leaked controllers**:
   - Open Flutter DevTools
   - Navigate to Memory tab
   - Take heap snapshot before opening builder
   - Open builder, make changes, navigate away
   - Take heap snapshot after
   - Compare: TextEditingController count should not increase
   - If controllers leak, check dispose() cascade

5. **Remove dispose logging** after verification

### Integration Testing
- [ ] Create new plan → fill all fields → publish
- [ ] Edit existing plan → modify fields → save
- [ ] Add/remove versions
- [ ] Add/remove days
- [ ] Add/remove waypoints
- [ ] AI generation → fields update visually
- [ ] GPX upload → map updates
- [ ] Switch between versions → correct data displayed
- [ ] Switch activity category → fields hide/show correctly
- [ ] Save indicator shows correct status
- [ ] No console errors

---

## Rollback Plan

If issues arise during migration:

1. **Git commit after each phase** - allows easy rollback to last working state
2. **Keep old code commented** - don't delete until fully tested
3. **Feature flag** - could add a flag to switch between old/new state (not recommended due to complexity)

### Quick Rollback Steps

1. Revert to last commit before problematic phase
2. Re-run tests
3. Identify specific issue
4. Fix in isolation
5. Re-apply phase

---

## Critical Gotchas

### 1. Day State Lazy Creation
- `getDayState(dayNum)` creates day state on first access
- Don't assume day state exists - always use `getDayState()`
- Day state is created per version, not globally

### 2. Prepare/LocalTips Per-Version
- **CRITICAL**: Prepare and LocalTips are now per-version, not per-plan
- When accessing: `formState.activeVersion.generatedPrepare`
- When saving: Must save to version subcollection

### 3. FAQ Items at Plan Level
- FAQ items moved from version to plan level
- Access via: `formState.faqItems`
- Only first version's FAQ items are shown in UI (legacy pattern)

### 4. ListenableBuilder Scope & notifyListeners() Rules
- Wrap only the widgets that need to rebuild (section level, not per-field)
- Don't wrap entire build method - causes unnecessary rebuilds
- Use `ValueListenableBuilder` for single controller if needed
- **CRITICAL**: Property setters in state classes should call `notifyListeners()` internally
- External code should **never** call `notifyListeners()` directly
- If you're calling `notifyListeners()` from `builder_screen.dart`, the state class is missing a proper setter
- List mutations (add/remove) require manual `notifyListeners()` call OR helper methods that call it internally

### 5. Version Index Management
- When adding/removing versions, check `activeVersionIndex` bounds
- Use `formState.activeVersion` shortcut instead of `formState.versions[formState.activeVersionIndex]`

### 6. Location Search State
- Location search is now in `LocationSearchState`
- Cooldown and debouncing handled internally
- Use `formState.locationSearch.selectedLocation` for coordinates

### 7. Day Image Uploads
- Day images stored in `DayFormState.dayImageBytes`
- Use `day.existingDayImageUrl` for previously uploaded images
- Parallel uploads handled by `AdventureSaveService.composeDays()`

### 8. Route Data
- Route data stored in `DayFormState.route`
- RouteInfo in `DayFormState.routeInfo`
- GPX route in `DayFormState.gpxRoute`
- All accessible via `version.getDayState(dayNum)`

### 9. Day Order Managers (Technical Debt)
- `_dayOrderManagers` kept as local state for now
- **Future**: Should use `RouteWaypoint.order` as single source of truth
- DayPlanOrderManager may still be needed for UI, but should sync with waypoint order
- Flag as follow-up task, migrate in separate PR

### 10. Current Day Index (Technical Debt)
- `_currentDayIndex` kept as local state for now
- **Problem**: Can go out of bounds when switching versions
- **Better**: Store on `VersionFormState` (each version remembers current day)
- **Minimum**: Add bounds checking in `set activeVersionIndex`
- Flag as follow-up task, migrate in separate PR

---

## Estimated Time

- **Phase 0**: 2-3 hours (snapshot test setup, capture golden files, write tests)
- **Phase 1**: 1 hour (low risk, add new state alongside old)
- **Phase 2**: 2-3 hours (medium risk, test thoroughly, add dual-write assertions)
- **Phase 3**: 6-8 hours (high risk, large scope, UI migration, test incrementally)
- **Phase 4**: 3-4 hours (high risk, save logic, Firestore schema changes, verify snapshots)
- **Phase 5**: 1-2 hours (low risk, cleanup, remove old code, dispose verification)

**Total**: 15-20 hours of focused work + testing time

**Note**: These estimates account for:
- Debugging time for state synchronization issues
- Firestore schema change testing (Prepare/LocalTips per-version)
- UI rebuild boundary tuning
- Snapshot test debugging if mismatches occur

---

## Success Criteria

Migration is complete when:
1. ✅ All old state variables removed
2. ✅ All old methods removed or replaced
3. ✅ File compiles without errors
4. ✅ All functionality works (see testing checklist)
5. ✅ No `setState()` calls for form state updates
6. ✅ All UI uses `ListenableBuilder` where needed
7. ✅ Memory leaks fixed (proper dispose)
8. ✅ Code is cleaner and more maintainable

---

## Next Steps After Migration

1. Update `route_builder_screen.dart` if it shares similar patterns
2. Consider extracting common UI patterns into reusable components
3. Add unit tests for state classes
4. Document the new state management pattern for team

---

## Questions to Resolve During Migration

1. **Day state lifecycle**: Should day states be disposed when version is removed?
   - **Answer**: Yes, handled by `VersionFormState.dispose()` cascading to all day states

2. **Location geocoding**: Should it happen in `fromPlan()` or separately?
   - **Answer**: Separately, as it's async and may fail. Do in `_loadExistingPlan()` after creating formState

3. **FAQ items**: Should we migrate to plan-level in UI too?
   - **Answer**: Keep legacy pattern for now (first version's FAQ shown). Full migration in future PR.

4. **Auto-save**: Should we implement auto-save using `AdventureSaveService.scheduleAutoSave()`?
   - **Answer**: Yes, but after core migration is complete (Phase 6 follow-up)

5. **Day order managers**: Keep as local state or migrate now?
   - **Answer**: Keep as local state for now, migrate in follow-up PR. Document as technical debt.

6. **Current day index**: Keep as local state or move to VersionFormState?
   - **Answer**: Add bounds checking now, move to VersionFormState in follow-up PR. Document as technical debt.

7. **When to call notifyListeners()**?
   - **Answer**: Property setters in state classes should call it internally. External code should never call it. List mutations require manual call or helper methods.

8. **formState nullable vs late final**?
   - **Answer**: Must be nullable because `_loadExistingPlan()` is async. Add loading guard in build method.

---

## Notes

- This migration is **reversible** if done phase-by-phase with commits
- Test thoroughly after each phase
- Don't rush - systematic replacement is safer than bulk find/replace
- Keep old code commented during migration for reference
- Use IDE refactoring tools carefully - some patterns need manual replacement

