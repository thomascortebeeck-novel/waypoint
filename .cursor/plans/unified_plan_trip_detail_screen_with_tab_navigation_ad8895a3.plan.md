---
name: ""
overview: ""
todos: []
---

---name: Unified Plan/Trip Detail Screen with Tab Navigationoverview: Consolidate builder, plan detail (pre/post purchase), and trip detail screens into a single unified screen with a Wanderlog-style tab navigation system. The screen will support inline editing for builders, mandatory validation, and different permission levels based on user role and purchase status. CRITICAL: Extract state management first (Phase 0) before any migration work, including fixing known bugs. DATA MIGRATION: Not required. Only 2 plans exist — they can be manually re-saved through the new builder if any schema changes occur.todos:

- id: phase0-fix-known-bugs

content: "Fix critical bugs before extraction: LogisticsCategory/ServiceCategory mismatch, food specialty identity-by-name (use index-based updates), initialValue not updating (use TextEditingController pattern), permits save path (direct _saveAIGeneratedData → _savePrepareAndLocalTips), indexOf performance (replace with indexed loop), remove ~300 lines of dead code"status: completed

- id: phase0-extract-state

content: "Extract _VersionFormData and form state into ChangeNotifier-based classes (AdventureFormState, VersionFormState, DayFormState, LocationSearchState, PackingCategoryFormState, TransportationFormState, AccommodationFormState, RestaurantFormState, ActivityFormState, FAQFormState). Includes dispose() cascade, lazy DayFormState creation, activity-specific field grouping, per-version Prepare/LocalTips, and ALL fields from _BuilderScreenState audit."status: completeddependencies:

    - phase0-fix-known-bugs
- id: phase0-location-search-state

content: "Extract location search state into LocationSearchState class with 1500ms cooldown, debouncing, cancellation."status: completeddependencies:

    - phase0-extract-state
- id: phase0-hydration-logic

content: "Create AdventureFormState.fromPlan() factory to hydrate form state from existing Plan - replaces _loadExistingPlan."status: completeddependencies:

    - phase0-extract-state
- id: phase0-update-data-models

content: "Update Plan and PlanVersion model classes: move Prepare and LocalTips fields from Plan to PlanVersion (per-version). Update Firestore schema references. No data migration needed (only 2 plans exist)."status: completeddependencies:

    - phase0-extract-state
- id: phase0-extract-save-logic

content: "Extract save logic into AdventureSaveService. Fix indexOf O(n²). Unify save paths. Parallel image uploads."status: completeddependencies:

    - phase0-extract-state
- id: phase0-cleanup-dead-code

content: "Remove dead code: _composePackingCategories, _composeTransportationOptions, _composeFAQItems (removed), _addFaqListeners (removed). Legacy form data classes (_VersionFormData, _PackingCategory, etc.) still used by _PackingCategoryCardWidget and _buildTransportationCardImpl - marked for future refactoring."status: completeddependencies:

    - phase0-extract-state
- id: phase0-verify

content: "Verify Phase 0: Update builder_screen.dart to use new state classes. Manual test all builder flows (create, edit, save, publish). Document any regressions."status: in_progressdependencies:

    - phase0-extract-save-logic
    - phase0-location-search-state
    - phase0-hydration-logic
    - phase0-cleanup-dead-code
- id: create-unified-screen

content: "Create adventure_detail_screen.dart with AdventureMode enum, AdventureData wrapper, persistent version selector, and mode-specific tab navigation using DefaultTabController with ValueKey(tabCount)."status: completeddependencies:

    - phase0-verify
- id: implement-reusable-components

content: "Build reusable component library: SectionCard, InlineEditableField, InlineEditableDropdown, InlineEditableChips, InlineEditableImagePicker, InlineEditableLinkPreview, VersionSelectorBar, ActivityAwareBuilder. All components accept isEditable flag and use TextEditingController pattern."status: completeddependencies:

    - create-unified-screen
- id: implement-viewer-tabs

content: "Viewer mode: [Overview] [Prepare] [Local Tips] [Day 1...N]. Port from plan_details_screen.dart. Uses reusable components in read-only mode. Overview includes read-only FAQ. Prepare includes packing + transport (read-only)."status: completeddependencies:

    - implement-reusable-components
- id: phase1-verify

content: "Verify Phase 1: Manual test viewer mode for both existing plans. Test plan preview and purchased views. Test version switching."status: pendingdependencies:

    - implement-viewer-tabs
- id: implement-builder-general-tab

content: "Builder [General] tab: name, location, description, image, activity category, accommodation type, best seasons, FAQ editor. Uses reusable components in edit mode."status: completeddependencies:

    - phase1-verify
- id: implement-builder-versions-tab

content: "Builder [Versions] tab: version CRUD, duration, naming. Duration change triggers tab rebuild via DefaultTabController key change. New versions copy Prepare/LocalTips from active version as starting point (VersionFormState.copyFrom)."status: completeddependencies:

    - implement-builder-general-tab
- id: implement-builder-prepare-tab

content: "Builder [Prepare] tab: AI generation + editing for travel insurance, visa, passport, permits, vaccines, climate, PLUS packing categories editor and transportation options editor. All per-version via version selector. TextEditingController pattern. Version selector at top."status: completeddependencies:

    - implement-builder-versions-tab
- id: implement-builder-local-tips-tab

content: "Builder [Local Tips] tab: AI generation + editing. TextEditingController pattern. Index-based food specialty updates. Per-version via version selector."status: completeddependencies:

    - implement-builder-prepare-tab
- id: implement-builder-day-tabs

content: "Builder [Day 1...N] tabs: inline editing, waypoints, routes. Activity-aware: shows GPX/distance/elevation for outdoor activities, hides them for city trips. Ordering via RouteWaypoint.order. Uses reusable components."status: completeddependencies:

    - implement-builder-local-tips-tab
- id: implement-waypoint-editing

content: "Waypoint management in day tabs: add, edit, delete, reorder, snap to GPX, choice groups. Reuse RouteBuilderScreen."status: pendingdependencies:

    - implement-builder-day-tabs
- id: implement-complex-editors

content: "Complex editing components: maps, GPX upload, link previews, season pickers. Activity-aware visibility. All use TextEditingController pattern and reusable component patterns."status: pendingdependencies:

    - implement-builder-day-tabs
- id: implement-builder-review-tab

content: "Builder [Review] tab: summary cards, publish overlay, publish status toggle."status: pendingdependencies:

    - implement-complex-editors
    - phase0-extract-save-logic
- id: integrate-save-service

content: "Integrate AdventureSaveService: auto-save, manual save, validation, status indicator."status: pendingdependencies:

    - phase0-extract-save-logic
    - implement-builder-review-tab
- id: phase2-verify

content: "Verify Phase 2: Manual test full builder flow. Test both outdoor (hiking) and city trip activity types. Test with 1-day and 30-day plans. Test version switching in Prepare/LocalTips/Days."status: pendingdependencies:

    - integrate-save-service
- id: add-trip-support

content: "Trip mode: owner/participant permissions, trip-specific sections. Uses reusable components in trip-specific configuration."status: pendingdependencies:

    - phase1-verify
- id: update-routing

content: "Update nav.dart routes. Deprecate old screens."status: pendingdependencies:

    - phase2-verify
    - add-trip-support
- id: future-unit-tests

content: "FUTURE: Add unit tests for all state classes and save service."status: pendingdependencies:

    - update-routing

---

# Unified Plan/Trip Detail Screen with Tab Navigation (v4)

## Overview

Consolidate builder, plan detail (pre/post purchase), and trip detail screens into a single unified screen with a Wanderlog-style tab navigation system. The screen will support inline editing for builders, mandatory validation, and different permission levels based on user role and purchase status.**CRITICAL:** Extract state management first (Phase 0) before any migration work, including fixing known bugs.**DATA MIGRATION:** Not required. Only 2 plans exist — they can be manually re-saved through the new builder if any schema changes occur.---

## Key Structural Decisions

### Prepare, Local Tips, and Days are PER-VERSION

All content below the General tab is version-specific:

- **Prepare** (travel insurance, visa, passport, permits, vaccines, climate, **packing categories**, **transportation options**) → per-version
- **Local Tips** (food specialties, etiquette, language, emergency info) → per-version
- **Days** (day content, waypoints, routes) → per-version (already was)

This means:

- A **persistent version selector** appears above the tab content on all version-dependent tabs
- `generatedPrepare` and `generatedLocalTips` move from `AdventureFormState` to `VersionFormState`
- The old "Logistics" tab is **removed** — packing and transportation live inside the Prepare tab
- AI generation runs per-version (different versions of a plan may have different prepare/tips content)

### Activity-Specific Day Logic

The plan's `ActivityCategory` determines which fields and components appear on day tabs:| Feature | Outdoor (hike/bike/climb/ski) | City (city trip/tour) ||---------|-------------------------------|----------------------|| GPX upload | ✅ | ❌ || Komoot/AllTrails links | ✅ | ❌ || Distance (km) | ✅ | ❌ || Elevation gain | ✅ | ❌ || Route builder (polyline) | ✅ | ❌ (markers only) || Route info (surface, difficulty) | ✅ | ❌ || Accommodation section | ✅ | ✅ || Restaurant section | ✅ | ✅ || Activity/POI section | ✅ | ✅ || Stay URL/Cost | ✅ | ✅ || Day image | ✅ | ✅ |This is handled via **conditional visibility** (not separate state classes). `DayFormState` keeps all controllers, but the UI checks `activityCategory` to show/hide sections. This is simpler than inheritance and avoids the need for different state subclasses.

### Reusable Component System

All UI components must be designed for reuse across builder mode, viewer mode, and trip mode. The principle: **build once, configure via mode**.---

## Architecture Decisions

### Decision 1: State Management — ChangeNotifier + ListenableBuilder

**Why not Riverpod:** Adding a dependency and migrating mid-refactor is high risk. The app uses vanilla Flutter.**Why not plain classes with setState:** That's the current problem — every field change calls `setState(() {})` on the 4000-line widget.**Solution:** `ChangeNotifier` subclasses with `ListenableBuilder` for selective rebuilds.

```dart
// State class notifies only when it changes
class AdventureFormState extends ChangeNotifier {
  String _saveStatus = '';
  String get saveStatus => _saveStatus;
  set saveStatus(String value) {
    if (_saveStatus != value) {
      _saveStatus = value;
      notifyListeners();
    }
  }
}

// Widget rebuilds only when this specific state changes
ListenableBuilder(
  listenable: formState,
  builder: (context, _) => Text(formState.saveStatus),
)
```

For text fields: `TextEditingController` is already a `Listenable` — use `ValueListenableBuilder` instead of `setState`:

```dart
// Only rebuilds the button, not the entire screen
ValueListenableBuilder<TextEditingValue>(
  valueListenable: formState.nameCtrl,
  builder: (context, value, _) => ElevatedButton(
    onPressed: value.text.trim().isNotEmpty ? _onNext : null,
    child: Text('Next'),
  ),
)
```



### Decision 2: Dispose Lifecycle — Cascading dispose()

Up to 30 days × 8+ controllers per day = 240+ controllers. Proper disposal is critical.

```dart
class AdventureFormState extends ChangeNotifier {
  @override
  void dispose() {
    nameCtrl.dispose();
    locationCtrl.dispose();
    descriptionCtrl.dispose();
    heroImageUrlCtrl.dispose();
    priceCtrl.dispose();
    locationSearch.dispose();
    for (final faq in faqItems) { faq.dispose(); }
    for (final version in versions) { version.dispose(); }
    super.dispose();
  }
}

class VersionFormState extends ChangeNotifier {
  @override
  void dispose() {
    nameCtrl.dispose();
    durationCtrl.dispose();
    for (final p in packingCategories) { p.dispose(); }
    for (final t in transportationOptions) { t.dispose(); }
    for (final day in days.values) { day.dispose(); }
    super.dispose();
  }
}

class DayFormState extends ChangeNotifier {
  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    distanceCtrl.dispose();
    elevationCtrl.dispose();
    timeCtrl.dispose();
    stayUrlCtrl.dispose();
    stayCostCtrl.dispose();
    komootLinkCtrl.dispose();
    allTrailsLinkCtrl.dispose();
    for (final a in accommodations) { a.dispose(); }
    for (final r in restaurants) { r.dispose(); }
    for (final a in activities) { a.dispose(); }
    super.dispose();
  }
}
```

Lazy creation ensures DayFormState for day 27 only exists when visited:

```dart
DayFormState getDayState(int dayNum) {
  return days.putIfAbsent(dayNum, () => DayFormState(dayNum: dayNum));
}
```



### Decision 3: Tab Controller — DefaultTabController with ValueKey

Instead of manually disposing/recreating TabController when day count changes, use `DefaultTabController` with a key:

```dart
DefaultTabController(
  key: ValueKey('tabs-$dayCount-${formState?.activeVersionIndex}'),
  length: tabs.length,
  child: Scaffold(
    appBar: AppBar(
      bottom: TabBar(
        isScrollable: true,
        tabs: tabs.map((t) => Tab(icon: Icon(t.icon, size: 18), text: t.label)).toList(),
      ),
    ),
    body: TabBarView(
      children: tabs.map((tab) => _buildTabContent(tab)).toList(),
    ),
  ),
)
```

The `ValueKey` forces Flutter to rebuild the controller smoothly when tab count changes, avoiding animation glitches from manual dispose/recreate.

### Decision 4: AdventureData Wrapper

Thin read-only wrapper for viewer mode. Builder uses `AdventureFormState` directly.

```dart
class AdventureData {
  final Plan? plan;
  final Trip? trip;
  final PlanVersion? selectedVersion;
  final Map<int, TripDaySelection>? daySelections;
  final Map<String, MemberPacking>? memberPacking;
  
  AdventureData.fromPlan(Plan plan, {PlanVersion? version})
    : this.plan = plan, trip = null, selectedVersion = version,
      daySelections = null, memberPacking = null;
  
  AdventureData.fromTrip(Trip trip, Plan sourcePlan, {PlanVersion? version})
    : this.plan = sourcePlan, this.trip = trip, selectedVersion = version,
      daySelections = trip.daySelections, memberPacking = trip.memberPacking;
  
  String get displayName => trip?.title ?? plan?.name ?? '';
  String get displayImage => trip?.heroImageUrl ?? plan?.heroImageUrl ?? '';
  String get location => plan?.location ?? '';
  List<DayItinerary> get days => selectedVersion?.days ?? const [];
  int get dayCount => selectedVersion?.durationDays ?? 0;
  Prepare? get prepare => selectedVersion?.prepare;  // Now per-version only
  LocalTips? get localTips => selectedVersion?.localTips;  // Now per-version only
  List<FAQItem> get faqItems => plan?.faqItems ?? const [];
  bool get isTrip => trip != null;
  ActivityCategory? get activityCategory => plan?.activityCategory;
}
```



### Decision 5: Single Source of Truth for Waypoint Ordering — RouteWaypoint.order

No separate `waypointOrder` list. Use `RouteWaypoint.order` field directly.

```dart
// In DayFormState — ordering helpers, no separate state
List<RouteWaypoint> getOrderedWaypoints(DayRoute? route) {
  if (route == null) return const [];
  final waypoints = route.poiWaypoints
      .map((json) => RouteWaypoint.fromJson(json))
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return waypoints;
}

DayRoute? moveWaypointUp(String waypointId, DayRoute route) {
  final waypoints = getOrderedWaypoints(route);
  final index = waypoints.indexWhere((w) => w.id == waypointId);
  if (index <= 0) return null;
  // Swap order values
  final current = waypoints[index];
  final previous = waypoints[index - 1];
  final tempOrder = current.order;
  waypoints[index] = current.copyWith(order: previous.order);
  waypoints[index - 1] = previous.copyWith(order: tempOrder);
  return route.copyWith(poiWaypoints: waypoints.map((w) => w.toJson()).toList());
}
```



### Decision 6: LocationSearchState Cooldown — 1500ms

Match current code. Google Places API rate limits require it.

```dart
class LocationSearchState extends ChangeNotifier {
  static const Duration searchCooldown = Duration(milliseconds: 1500);
  static const Duration debounceDelay = Duration(milliseconds: 1000);
  static const int minQueryLength = 4;
}
```



### Decision 7: Activity-Specific Logic — Conditional Visibility

`DayFormState` keeps ALL controllers regardless of activity type. The UI uses an `ActivityAwareBuilder` widget to show/hide sections:

```dart
/// Reusable widget that shows/hides children based on activity category
class ActivityAwareBuilder extends StatelessWidget {
  final ActivityCategory? activityCategory;
  final Set<ActivityCategory> showFor;
  final Widget child;
  
  const ActivityAwareBuilder({
    required this.activityCategory,
    required this.showFor,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    if (activityCategory == null) return child; // Show all if not set yet
    if (showFor.contains(activityCategory)) return child;
    return const SizedBox.shrink();
  }
}

// Usage in day tab:
ActivityAwareBuilder(
  activityCategory: formState.activityCategory,
  showFor: {ActivityCategory.hiking, ActivityCategory.biking, 
            ActivityCategory.climbing, ActivityCategory.skiing},
  child: _buildGpxUploadSection(dayState),
)

ActivityAwareBuilder(
  activityCategory: formState.activityCategory,
  showFor: {ActivityCategory.hiking, ActivityCategory.biking,
            ActivityCategory.climbing, ActivityCategory.skiing},
  child: _buildDistanceElevationFields(dayState),
)

// Accommodation, restaurants, activities show for ALL categories
_buildAccommodationSection(dayState), // Always visible
```

The same `ActivityAwareBuilder` works in both builder mode (editing) and viewer mode (display). Activity category is set once in the General tab and propagated everywhere.**Data Preservation:** When activity category changes mid-editing (e.g., hiking → city trip), all controller data is preserved silently. The UI hides outdoor-specific fields, but the data remains in `DayFormState` controllers. If the user switches back to an outdoor activity, the data reappears. The save service writes all controller data to Firestore regardless of activity type — filtering is UI-only. This ensures no data loss when switching activity types.---

## Mode-Specific Tab Navigation

### Builder Mode:

```javascript
[General] [Versions] [Prepare] [Local Tips] [Day 1] ... [Day N] [Review]
```



- **General** is plan-level (name, location, description, image, activity type, FAQ)
- **Versions** is plan-level (add/remove versions, set duration/name)
- **Prepare, Local Tips, Day 1...N** are per-version (version selector shown above content)
- **Review** aggregates all versions

### Viewer Mode (Plan/Trip):

```javascript
[Overview] [Prepare] [Local Tips] [Day 1] ... [Day N]
```



- Version selector in Overview tab or above tabs

### Persistent Version Selector

On any version-dependent tab (Prepare, Local Tips, Day tabs), a version selector bar appears between the tab bar and the tab content:

```dart
/// Type-agnostic version selector — accepts display names and indices
class VersionSelectorBar extends StatelessWidget {
  final List<({String name, int index})> versions;  // Generic tuple list
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final bool isEditable;
  
  VersionSelectorBar.fromFormStates({
    required List<VersionFormState> versions,
    required this.activeIndex,
    required this.onChanged,
    this.isEditable = false,
  }) : versions = versions.asMap().entries.map((e) => (
          name: e.value.nameCtrl.text.isEmpty 
              ? 'Version ${e.key + 1}' 
              : e.value.nameCtrl.text,
          index: e.key,
        )).toList();
  
  VersionSelectorBar.fromPlanVersions({
    required List<PlanVersion> versions,
    required this.activeIndex,
    required this.onChanged,
    this.isEditable = false,
  }) : versions = versions.asMap().entries.map((e) => (
          name: e.value.name.isEmpty 
              ? 'Version ${e.key + 1}' 
              : e.value.name,
          index: e.key,
        )).toList();
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Text('Version:', style: Theme.of(context).textTheme.labelMedium),
          SizedBox(width: 8),
          SegmentedButton<int>(
            segments: [
              for (final v in versions)
                ButtonSegment(value: v.index, label: Text(v.name)),
            ],
            selected: {activeIndex},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}
```

When version changes, the day tabs update (different version may have different day count).

### Tab Generation:

```dart
class TabDefinition {
  final String label;
  final IconData icon;
  
  TabDefinition(this.label, this.icon);
}

List<TabDefinition> _getTabsForMode(AdventureMode mode, int dayCount) {
  switch (mode) {
    case AdventureMode.builder:
      return [
        TabDefinition('General', Icons.info_outline),
        TabDefinition('Versions', Icons.layers_outlined),
        TabDefinition('Prepare', Icons.shield_outlined),
        TabDefinition('Local Tips', Icons.lightbulb_outline),
        for (int i = 1; i <= dayCount; i++)
          TabDefinition('Day $i', Icons.calendar_today),
        TabDefinition('Review', Icons.check_circle_outline),
      ];
    default:
      return [
        TabDefinition('Overview', Icons.info_outline),
        TabDefinition('Prepare', Icons.shield_outlined),
        TabDefinition('Local Tips', Icons.lightbulb_outline),
        for (int i = 1; i <= dayCount; i++)
          TabDefinition('Day $i', Icons.calendar_today),
      ];
  }
}
```

**For 30-day adventures:** The tab bar is already `scrollable: true` (default `TabBar` with `isScrollable: true`), so it scrolls horizontally. No special handling needed — this is the standard Flutter pattern for many tabs.---

## Reusable Component System

### Design Principle: Build Once, Configure Via Mode

Every content component is built as a reusable widget that accepts an `isEditable` flag. This means the same component renders in builder mode (with editing controls) and viewer mode (read-only display) without duplication.

### Component Library

```javascript
lib/components/unified/
  ├── section_card.dart              # Card wrapper with title, icon, optional edit actions
  ├── inline_editable_field.dart     # Text field: editable or read-only
  ├── inline_editable_dropdown.dart  # Dropdown: editable or read-only chip
  ├── inline_editable_chips.dart     # Multi-select: editable or read-only chips
  ├── inline_editable_image.dart     # Image: with picker or display-only
  ├── inline_editable_link.dart      # Link: with preview fetch or display-only
  ├── version_selector_bar.dart      # Version selector (used in multiple tabs)
  ├── activity_aware_builder.dart    # Conditional visibility by activity type
  ├── day_waypoint_section.dart      # Waypoint list (edit or view mode)
  ├── prepare_section.dart           # Prepare content (used in Prepare tab for both modes)
  ├── local_tips_section.dart        # Local tips content (used in LocalTips tab for both modes)
  ├── packing_section.dart           # Packing categories (inside Prepare tab, or Overview)
  ├── transportation_section.dart    # Transportation options (inside Prepare tab, or Overview)
  ├── day_content_section.dart       # Day content (used in Day tab for both modes)
  ├── faq_section.dart               # FAQ items (edit in General, view in Overview)
  └── publish_overlay.dart           # Publish dialog (builder only)
```



### Component Pattern:

```dart
/// Example: InlineEditableField
/// Used everywhere text needs to be displayed (viewer) or edited (builder)
class InlineEditableField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;  // Builder mode
  final String? displayValue;               // Viewer mode
  final bool isEditable;
  final int maxLines;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onEditComplete;       // Triggers auto-save
  
  const InlineEditableField({
    required this.label,
    this.controller,
    this.displayValue,
    this.isEditable = false,
    this.maxLines = 1,
    this.hint,
    this.validator,
    this.onEditComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    if (!isEditable) {
      // Read-only display
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          SizedBox(height: 4),
          Text(displayValue ?? '', style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
    }
    
    // Editable mode
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      maxLines: maxLines,
      validator: validator,
      onEditingComplete: onEditComplete,
    );
  }
}
```



### Section-Level Reuse:

```dart
/// Example: PrepareSection — used in both builder Prepare tab and viewer Prepare tab
class PrepareSection extends StatelessWidget {
  final Prepare? prepare;                    // Viewer mode data
  final VersionFormState? versionState;      // Builder mode state
  final bool isEditable;
  final ActivityCategory? activityCategory;
  final VoidCallback? onGenerateAI;
  final VoidCallback? onChanged;             // Triggers auto-save
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          if (isEditable && onGenerateAI != null)
            _buildAIGenerateButton(context),
          
          SectionCard(
            title: 'Travel Insurance',
            icon: Icons.health_and_safety,
            children: [
              InlineEditableField(
                label: 'Recommendation',
                isEditable: isEditable,
                controller: versionState?.prepareInsuranceRecommendationCtrl,
                displayValue: prepare?.travelInsurance?.recommendation,
                onEditComplete: onChanged,
              ),
              // ... more fields
            ],
          ),
          
          SectionCard(
            title: 'Visa & Passport',
            // ...
          ),
          
          // Packing — inside Prepare tab now
          SectionCard(
            title: 'Packing',
            icon: Icons.backpack,
            children: [
              PackingSection(
                isEditable: isEditable,
                categories: isEditable 
                    ? null  // Uses versionState.packingCategories
                    : prepare?.packingCategories,
                versionState: versionState,
                onChanged: onChanged,
              ),
            ],
          ),
          
          // Transportation — inside Prepare tab now
          SectionCard(
            title: 'Transportation',
            icon: Icons.directions_car,
            children: [
              TransportationSection(
                isEditable: isEditable,
                options: isEditable
                    ? null
                    : prepare?.transportationOptions,
                versionState: versionState,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```



### Reuse Matrix:

| Component | Builder General | Builder Versions | Builder Prepare | Builder LocalTips | Builder Day | Builder Review | Viewer Overview | Viewer Prepare | Viewer LocalTips | Viewer Day | Trip ||-----------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|| SectionCard | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ || InlineEditableField | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ | ✅ | ✅ | ✅ | ✅ || InlineEditableDropdown | ✅ | | | | ✅ | | | | | | || InlineEditableChips | ✅ | | ✅ | | | | | | | | || InlineEditableImage | ✅ | | | | ✅ | | ✅ | | | ✅ | ✅ || VersionSelectorBar | | | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ || ActivityAwareBuilder | | | | | ✅ | | | | | ✅ | ✅ || PrepareSection | | | ✅ | | | | | ✅ | | | ✅ || LocalTipsSection | | | | ✅ | | | | | ✅ | | ✅ || PackingSection | | | ✅ | | | | ✅ | ✅ | | | ✅ || TransportationSection | | | ✅ | | | | ✅ | ✅ | | | ✅ || DayContentSection | | | | | ✅ | | | | | ✅ | ✅ || DayWaypointSection | | | | | ✅ | | | | | ✅ | ✅ || FAQSection | ✅ | | | | | | ✅ | | | | |---

## Phase 0: State Management Extraction

### 0a. Fix Known Bugs

| Bug | Fix ||-----|-----|| `ServiceCategory.*` in `LogisticsCategory` switch | Change to `LogisticsCategory.gear/transportation/food` || Food specialty matched by name | Use index-based: `updated[index] = FoodSpecialty(...) `|| `initialValue` doesn't update after AI gen | Add `key: ValueKey(value)` as interim fix (full fix in Phase 2) || Permits bypass `_savePrepareAndLocalTips` | Replace 3 direct `_saveAIGeneratedData` calls || `indexOf` O(n²) in save methods | Replace with `for (var i = 0; ...)` indexed loop || ~300 lines dead code | Remove unused methods, widgets, variables |

### 0b. State Classes — Full Definitions

#### AdventureFormState

```dart
/// Top-level form state — plan-level fields only
/// Prepare, LocalTips, Days are per-version (in VersionFormState)
class AdventureFormState extends ChangeNotifier {
  // --- Plan-level text fields ---
  final TextEditingController nameCtrl;
  final TextEditingController locationCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController heroImageUrlCtrl;
  final TextEditingController priceCtrl;
  
  // --- Location geocoding (extracted) ---
  final LocationSearchState locationSearch;
  
  // --- Plan-level selections ---
  ActivityCategory? _activityCategory;
  ActivityCategory? get activityCategory => _activityCategory;
  set activityCategory(ActivityCategory? value) {
    if (_activityCategory != value) {
      _activityCategory = value;
      notifyListeners();
    }
  }
  
  AccommodationType? accommodationType;
  List<SeasonRange> bestSeasons;
  bool isEntireYear;
  bool showPrices;
  
  // --- Cover image ---
  Uint8List? coverImageBytes;
  String? coverImageExtension;
  bool _uploadingCoverImage = false;
  bool get uploadingCoverImage => _uploadingCoverImage;
  set uploadingCoverImage(bool value) {
    if (_uploadingCoverImage != value) {
      _uploadingCoverImage = value;
      notifyListeners();
    }
  }
  
  // --- Publish status ---
  bool _isPublished = true;
  bool get isPublished => _isPublished;
  set isPublished(bool value) {
    if (_isPublished != value) {
      _isPublished = value;
      notifyListeners();
    }
  }
  
  // --- FAQ items (plan-level) ---
  final List<FAQFormState> faqItems;
  
  // --- Versions ---
  final List<VersionFormState> versions;
  int _activeVersionIndex = 0;
  int get activeVersionIndex => _activeVersionIndex;
  set activeVersionIndex(int value) {
    if (_activeVersionIndex != value && value >= 0 && value < versions.length) {
      _activeVersionIndex = value;
      notifyListeners();
    }
  }
  
  /// Active version shortcut
  VersionFormState get activeVersion => versions[_activeVersionIndex];
  
  // --- Editing state ---
  Plan? editingPlan;
  
  // --- AI generation state (triggers are plan-level, but results go to version) ---
  bool _isGeneratingInfo = false;
  bool get isGeneratingInfo => _isGeneratingInfo;
  set isGeneratingInfo(bool value) {
    if (_isGeneratingInfo != value) {
      _isGeneratingInfo = value;
      notifyListeners();
    }
  }
  
  // --- Save state ---
  bool _isSaving = false;
  bool get isSaving => _isSaving;
  set isSaving(bool value) {
    if (_isSaving != value) { _isSaving = value; notifyListeners(); }
  }
  
  DateTime? lastSavedAt;
  
  String _saveStatus = '';
  String get saveStatus => _saveStatus;
  set saveStatus(String value) {
    if (_saveStatus != value) { _saveStatus = value; notifyListeners(); }
  }
  
  // --- Validation ---
  bool get isGeneralInfoValid => 
    nameCtrl.text.trim().isNotEmpty &&
    locationCtrl.text.trim().isNotEmpty &&
    descriptionCtrl.text.trim().isNotEmpty &&
    locationSearch.selectedLocation != null;
  
  // --- Activity type helpers ---
  bool get isOutdoorActivity {
    const outdoor = {
      ActivityCategory.hiking, ActivityCategory.biking,
      ActivityCategory.climbing, ActivityCategory.skiing,
    };
    return _activityCategory != null && outdoor.contains(_activityCategory);
  }
  
  bool get isCityActivity {
    const city = {
      ActivityCategory.cityTrip, ActivityCategory.tour,
    };
    return _activityCategory != null && city.contains(_activityCategory);
  }
  
  // --- Factories ---
  factory AdventureFormState.initial() {
    return AdventureFormState(
      nameCtrl: TextEditingController(),
      locationCtrl: TextEditingController(),
      descriptionCtrl: TextEditingController(),
      heroImageUrlCtrl: TextEditingController(),
      priceCtrl: TextEditingController(text: '2.00'),
      locationSearch: LocationSearchState.initial(),
      faqItems: [],
      versions: [VersionFormState.initial()],
    );
  }
  
  factory AdventureFormState.fromPlan(Plan plan) {
    // ~120 lines: maps all Plan fields to controllers
    // Hydrates versions via VersionFormState.fromVersion()
    // Hydrates FAQ items via FAQFormState.fromModel()
    // Sets location search state if plan has coordinates
  }
  
  // --- Dispose ---
  @override
  void dispose() {
    nameCtrl.dispose();
    locationCtrl.dispose();
    descriptionCtrl.dispose();
    heroImageUrlCtrl.dispose();
    priceCtrl.dispose();
    locationSearch.dispose();
    for (final faq in faqItems) { faq.dispose(); }
    for (final version in versions) { version.dispose(); }
    super.dispose();
  }
}
```



#### VersionFormState

```dart
/// Form state for one version — owns Prepare, LocalTips, and Days
class VersionFormState extends ChangeNotifier {
  final String tempId;
  final TextEditingController nameCtrl;
  final TextEditingController durationCtrl;
  
  // --- Prepare (per-version) ---
  Prepare? _generatedPrepare;
  Prepare? get generatedPrepare => _generatedPrepare;
  set generatedPrepare(Prepare? value) {
    _generatedPrepare = value;
    notifyListeners();
  }
  
  // Prepare sub-field controllers (populated when AI generates or when loading)
  // Travel Insurance
  final TextEditingController prepareInsuranceRecommendationCtrl;
  final TextEditingController prepareInsuranceUrlCtrl;
  final TextEditingController prepareInsuranceNoteCtrl;
  // Visa
  final TextEditingController prepareVisaRequirementCtrl;
  final TextEditingController prepareVisaUrlCtrl;
  final TextEditingController prepareVisaNoteCtrl;
  // Passport
  final TextEditingController preparePassportValidityCtrl;
  final TextEditingController preparePassportNoteCtrl;
  // Permits (list — managed as List<PermitFormState>)
  final List<PermitFormState> permits;
  // Vaccines
  final TextEditingController prepareVaccinesRequiredCtrl;
  final TextEditingController prepareVaccinesRecommendedCtrl;
  final TextEditingController prepareVaccinesNoteCtrl;
  // Climate
  final TextEditingController prepareClimateDescriptionCtrl;
  final TextEditingController prepareClimateBestTimeCtrl;
  
  // --- Packing (per-version, inside Prepare tab) ---
  final List<PackingCategoryFormState> packingCategories;
  
  // --- Transportation (per-version, inside Prepare tab) ---
  final List<TransportationFormState> transportationOptions;
  
  // --- Local Tips (per-version) ---
  LocalTips? _generatedLocalTips;
  LocalTips? get generatedLocalTips => _generatedLocalTips;
  set generatedLocalTips(LocalTips? value) {
    _generatedLocalTips = value;
    notifyListeners();
  }
  
  // Local Tips sub-field controllers
  final List<FoodSpecialtyFormState> foodSpecialties;
  final List<EtiquetteFormState> etiquetteItems;
  final TextEditingController localTipsLanguageCtrl;
  final TextEditingController localTipsCurrencyCtrl;
  final TextEditingController localTipsEmergencyPoliceCtrl;
  final TextEditingController localTipsEmergencyAmbulanceCtrl;
  final TextEditingController localTipsEmergencyFireCtrl;
  final TextEditingController localTipsEmergencyTouristCtrl;
  final TextEditingController localTipsEmergencyNoteCtrl;
  
  // --- Days (per-version, lazy) ---
  final Map<int, DayFormState> _days = {};
  
  int get daysCount => int.tryParse(durationCtrl.text) ?? 0;
  
  DayFormState getDayState(int dayNum) {
    return _days.putIfAbsent(dayNum, () => DayFormState(dayNum: dayNum));
  }
  
  // --- Factories ---
  factory VersionFormState.initial() {
    return VersionFormState(
      tempId: const Uuid().v4(),
      nameCtrl: TextEditingController(),
      durationCtrl: TextEditingController(text: '1'),
      // ... initialize all controllers empty
    );
  }
  
  /// Copy Prepare and LocalTips from another version as starting point
  factory VersionFormState.copyFrom(VersionFormState source) {
    final copy = VersionFormState.initial();
    // Copy Prepare controllers
    copy.prepareInsuranceRecommendationCtrl.text = source.prepareInsuranceRecommendationCtrl.text;
    // ... copy all Prepare sub-field controllers
    // Copy LocalTips controllers
    for (final food in source.foodSpecialties) {
      copy.foodSpecialties.add(FoodSpecialtyFormState(
        nameCtrl: TextEditingController(text: food.nameCtrl.text),
        descriptionCtrl: TextEditingController(text: food.descriptionCtrl.text),
      ));
    }
    // ... copy all LocalTips sub-field controllers
    // Copy packing categories and transportation
    for (final cat in source.packingCategories) {
      copy.packingCategories.add(/* deep copy */);
    }
    for (final trans in source.transportationOptions) {
      copy.transportationOptions.add(/* deep copy */);
    }
    return copy;
  }
  
  factory VersionFormState.fromVersion(PlanVersion version) {
    // Hydrates all controllers from version data
    // Hydrates Prepare sub-controllers from version.prepare
    // Hydrates LocalTips sub-controllers from version.localTips
    // Hydrates day states from version.days
  }
  
  // --- Dispose ---
  @override
  void dispose() {
    nameCtrl.dispose();
    durationCtrl.dispose();
    // Dispose all prepare controllers
    prepareInsuranceRecommendationCtrl.dispose();
    prepareInsuranceUrlCtrl.dispose();
    prepareInsuranceNoteCtrl.dispose();
    prepareVisaRequirementCtrl.dispose();
    prepareVisaUrlCtrl.dispose();
    prepareVisaNoteCtrl.dispose();
    preparePassportValidityCtrl.dispose();
    preparePassportNoteCtrl.dispose();
    for (final p in permits) { p.dispose(); }
    prepareVaccinesRequiredCtrl.dispose();
    prepareVaccinesRecommendedCtrl.dispose();
    prepareVaccinesNoteCtrl.dispose();
    prepareClimateDescriptionCtrl.dispose();
    prepareClimateBestTimeCtrl.dispose();
    // Dispose packing & transportation
    for (final p in packingCategories) { p.dispose(); }
    for (final t in transportationOptions) { t.dispose(); }
    // Dispose local tips controllers
    for (final f in foodSpecialties) { f.dispose(); }
    for (final e in etiquetteItems) { e.dispose(); }
    localTipsLanguageCtrl.dispose();
    localTipsCurrencyCtrl.dispose();
    localTipsEmergencyPoliceCtrl.dispose();
    localTipsEmergencyAmbulanceCtrl.dispose();
    localTipsEmergencyFireCtrl.dispose();
    localTipsEmergencyTouristCtrl.dispose();
    localTipsEmergencyNoteCtrl.dispose();
    // Dispose days
    for (final day in _days.values) { day.dispose(); }
    super.dispose();
  }
}
```



#### DayFormState

```dart
/// Form state for a single day
/// All controllers exist regardless of activity type — UI handles visibility
class DayFormState extends ChangeNotifier {
  final int dayNum;
  
  // --- Common fields (all activity types) ---
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController timeCtrl;        // Estimated time
  final TextEditingController stayUrlCtrl;
  final TextEditingController stayCostCtrl;
  
  // --- Outdoor-specific fields (hidden for city trips) ---
  final TextEditingController distanceCtrl;    // Distance in km
  final TextEditingController elevationCtrl;   // Elevation gain in m
  final TextEditingController komootLinkCtrl;
  final TextEditingController allTrailsLinkCtrl;
  
  // --- Coordinates ---
  ll.LatLng? start;
  ll.LatLng? end;
  
  // --- Route data (outdoor: polyline + GPX; city: markers only) ---
  DayRoute? route;
  RouteInfo? routeInfo;        // Surface type, difficulty — outdoor only
  GpxRoute? gpxRoute;          // GPX data — outdoor only
  
  // --- POIs (all activity types) ---
  final List<AccommodationFormState> accommodations;
  final List<RestaurantFormState> restaurants;
  final List<ActivityFormState> activities;
  
  // --- Images ---
  Uint8List? dayImageBytes;
  String? dayImageExtension;
  String? existingDayImageUrl;
  
  // --- Link previews ---
  LinkPreviewData? stayMeta;
  
  // --- Ordering helpers (no separate state — uses RouteWaypoint.order) ---
  List<RouteWaypoint> getOrderedWaypoints() {
    if (route == null) return const [];
    final waypoints = route!.poiWaypoints
        .map((json) => RouteWaypoint.fromJson(json))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return waypoints;
  }
  
  DayRoute? moveWaypointUp(String waypointId) {
    if (route == null) return null;
    final waypoints = getOrderedWaypoints();
    final index = waypoints.indexWhere((w) => w.id == waypointId);
    if (index <= 0) return null;
    final current = waypoints[index];
    final previous = waypoints[index - 1];
    final tempOrder = current.order;
    waypoints[index] = current.copyWith(order: previous.order);
    waypoints[index - 1] = previous.copyWith(order: tempOrder);
    route = route!.copyWith(
      poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
    );
    notifyListeners();
    return route;
  }
  
  DayRoute? moveWaypointDown(String waypointId) {
    if (route == null) return null;
    final waypoints = getOrderedWaypoints();
    final index = waypoints.indexWhere((w) => w.id == waypointId);
    if (index < 0 || index >= waypoints.length - 1) return null;
    final current = waypoints[index];
    final next = waypoints[index + 1];
    final tempOrder = current.order;
    waypoints[index] = current.copyWith(order: next.order);
    waypoints[index + 1] = next.copyWith(order: tempOrder);
    route = route!.copyWith(
      poiWaypoints: waypoints.map((w) => w.toJson()).toList(),
    );
    notifyListeners();
    return route;
  }
  
  DayFormState({required this.dayNum})
    : titleCtrl = TextEditingController(),
      descCtrl = TextEditingController(),
      distanceCtrl = TextEditingController(),
      elevationCtrl = TextEditingController(),
      timeCtrl = TextEditingController(),
      stayUrlCtrl = TextEditingController(),
      stayCostCtrl = TextEditingController(),
      komootLinkCtrl = TextEditingController(),
      allTrailsLinkCtrl = TextEditingController(),
      accommodations = [],
      restaurants = [],
      activities = [];
  
  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    distanceCtrl.dispose();
    elevationCtrl.dispose();
    timeCtrl.dispose();
    stayUrlCtrl.dispose();
    stayCostCtrl.dispose();
    komootLinkCtrl.dispose();
    allTrailsLinkCtrl.dispose();
    for (final a in accommodations) { a.dispose(); }
    for (final r in restaurants) { r.dispose(); }
    for (final a in activities) { a.dispose(); }
    super.dispose();
  }
}
```



#### Sub-Form States

```dart
/// Packing category with items
class PackingCategoryFormState extends ChangeNotifier {
  final TextEditingController nameCtrl;
  final List<PackingItemFormState> items;
  
  factory PackingCategoryFormState.initial() => PackingCategoryFormState(
    nameCtrl: TextEditingController(),
    items: [],
  );
  
  @override
  void dispose() {
    nameCtrl.dispose();
    for (final item in items) { item.dispose(); }
    super.dispose();
  }
}

class PackingItemFormState {
  final TextEditingController nameCtrl;
  final TextEditingController descriptionCtrl;
  bool isEssential;
  
  void dispose() {
    nameCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

/// Transportation option
class TransportationFormState {
  final TextEditingController nameCtrl;
  final TextEditingController descriptionCtrl;
  TransportationType? type;
  
  void dispose() {
    nameCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

/// FAQ item
class FAQFormState {
  final TextEditingController questionCtrl;
  final TextEditingController answerCtrl;
  
  factory FAQFormState.fromModel(FAQItem item) => FAQFormState(
    questionCtrl: TextEditingController(text: item.question),
    answerCtrl: TextEditingController(text: item.answer),
  );
  
  void dispose() {
    questionCtrl.dispose();
    answerCtrl.dispose();
  }
}

/// Permit (in Prepare)
class PermitFormState {
  final TextEditingController nameCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController urlCtrl;
  
  void dispose() {
    nameCtrl.dispose();
    descriptionCtrl.dispose();
    urlCtrl.dispose();
  }
}

/// Food specialty (in Local Tips)
class FoodSpecialtyFormState {
  final TextEditingController nameCtrl;
  final TextEditingController descriptionCtrl;
  
  void dispose() {
    nameCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

/// Etiquette item (in Local Tips)
class EtiquetteFormState {
  final TextEditingController tipCtrl;
  
  void dispose() {
    tipCtrl.dispose();
  }
}

/// Accommodation (in Day)
class AccommodationFormState {
  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;
  final TextEditingController costCtrl;
  AccommodationType? type;
  
  void dispose() {
    nameCtrl.dispose();
    urlCtrl.dispose();
    costCtrl.dispose();
  }
}

/// Restaurant (in Day)
class RestaurantFormState {
  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;
  final TextEditingController costCtrl;
  MealType? mealType;
  
  void dispose() {
    nameCtrl.dispose();
    urlCtrl.dispose();
    costCtrl.dispose();
  }
}

/// Activity/POI (in Day)
class ActivityFormState {
  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;
  final TextEditingController costCtrl;
  final TextEditingController durationCtrl;
  
  void dispose() {
    nameCtrl.dispose();
    urlCtrl.dispose();
    costCtrl.dispose();
    durationCtrl.dispose();
  }
}
```



#### LocationSearchState

```dart
class LocationSearchState extends ChangeNotifier {
  static const Duration searchCooldown = Duration(milliseconds: 1500);
  static const Duration debounceDelay = Duration(milliseconds: 1000);
  static const int minQueryLength = 4;
  
  ll.LatLng? selectedLocation;
  String selectedLocationName;
  List<PlacePrediction> suggestions;
  bool _isSearching = false;
  bool get isSearching => _isSearching;
  set isSearching(bool value) {
    if (_isSearching != value) { _isSearching = value; notifyListeners(); }
  }
  
  String lastQuery;
  DateTime? lastSearchTime;
  Timer? _debounceTimer;
  Future<List<PlacePrediction>>? searchFuture;
  FocusNode focusNode;
  
  bool get canSearch {
    if (lastSearchTime == null) return true;
    return DateTime.now().difference(lastSearchTime!) > searchCooldown;
  }
  
  void cancelSearch() {
    _debounceTimer?.cancel();
    searchFuture = null;
  }
  
  factory LocationSearchState.initial() => LocationSearchState(
    selectedLocation: null,
    selectedLocationName: '',
    suggestions: [],
    lastQuery: '',
    focusNode: FocusNode(),
  );
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    focusNode.dispose();
    super.dispose();
  }
}
```



### 0c. Save Service

```dart
class AdventureSaveService {
  final PlanService _planService;
  final StorageService _storageService;
  final UserService _userService;
  
  Timer? _autoSaveTimer;
  
  Future<SaveResult> saveDraft(AdventureFormState state) async {
    // Indexed loop (not indexOf)
    // Handles image uploads
    // Preserves version IDs
    // Saves per-version Prepare/LocalTips
  }
  
  Future<SaveResult> saveAndValidate(AdventureFormState state) async {
    final errors = validate(state);
    if (errors.isNotEmpty) return SaveResult.validationFailed(errors);
    return saveDraft(state);
  }
  
  Future<SaveResult> saveAIData(
    String planId, 
    int versionIndex,
    Prepare prepare, 
    LocalTips localTips,
  ) async {
    // Single unified save path
    // Saves to specific version
  }
  
  Future<List<DayItinerary>> composeDays(
    VersionFormState version, 
    String planId,
    ActivityCategory? activityCategory,
    {List<DayItinerary> existing = const []}
  ) async {
    // Parallel image uploads via Future.wait
    final uploadFutures = <Future<String?>>[];
    for (int i = 1; i <= version.daysCount; i++) {
      final day = version.getDayState(i);
      if (day.dayImageBytes != null) {
        uploadFutures.add(_uploadDayImage(planId, i, day));
      } else {
        uploadFutures.add(Future.value(day.existingDayImageUrl));
      }
    }
    final imageUrls = await Future.wait(uploadFutures);
    
    // Assemble days — write ALL controller data regardless of activity type
    // Activity type filtering is UI-only (ActivityAwareBuilder)
    // This preserves data when switching activity types (hiking → city → hiking)
    final days = <DayItinerary>[];
    for (int i = 1; i <= version.daysCount; i++) {
      final day = version.getDayState(i);
      days.add(DayItinerary(
        dayNumber: i,
        title: day.titleCtrl.text,
        description: day.descCtrl.text,
        distance: double.tryParse(day.distanceCtrl.text),  // May be null for city trips
        elevation: int.tryParse(day.elevationCtrl.text),  // May be null for city trips
        time: day.timeCtrl.text,
        stayUrl: day.stayUrlCtrl.text,
        stayCost: day.stayCostCtrl.text,
        komootLink: day.komootLinkCtrl.text,
        allTrailsLink: day.allTrailsLinkCtrl.text,
        route: day.route,
        routeInfo: day.routeInfo,  // May be null for city trips
        gpxRoute: day.gpxRoute,    // May be null for city trips
        imageUrl: imageUrls[i - 1],
        accommodations: day.accommodations.map((a) => /* ... */).toList(),
        restaurants: day.restaurants.map((r) => /* ... */).toList(),
        activities: day.activities.map((a) => /* ... */).toList(),
      ));
    }
    return days;
  }
  
  void scheduleAutoSave(AdventureFormState state) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (state.editingPlan != null) {
        saveDraft(state);
      }
    });
  }
  
  List<String> validate(AdventureFormState state) {
    final errors = <String>[];
    if (state.nameCtrl.text.trim().isEmpty) errors.add('Name required');
    if (state.locationSearch.selectedLocation == null) errors.add('Location required');
    if (state.descriptionCtrl.text.trim().isEmpty) errors.add('Description required');
    if (state.versions.isEmpty) errors.add('At least one version required');
    for (final v in state.versions) {
      if (v.daysCount <= 0) errors.add('Version "${v.nameCtrl.text}" needs at least one day');
    }
    return errors;
  }
  
  void dispose() {
    _autoSaveTimer?.cancel();
  }
}

class SaveResult {
  final bool success;
  final String? planId;
  final List<String> errors;
  
  SaveResult.ok(this.planId) : success = true, errors = const [];
  SaveResult.failed(String error) : success = false, planId = null, errors = [error];
  SaveResult.validationFailed(this.errors) : success = false, planId = null;
}
```



### 0d. Data Model Updates

**CRITICAL:** Prepare and LocalTips must move from `Plan` to `PlanVersion` in the data model:

```dart
// Before (current):
class Plan {
  Prepare? prepare;      // ❌ Plan-level
  LocalTips? localTips;  // ❌ Plan-level
  List<PlanVersion> versions;
}

// After (new):
class Plan {
  // prepare and localTips removed
  List<PlanVersion> versions;
}

class PlanVersion {
  Prepare? prepare;      // ✅ Per-version
  LocalTips? localTips; // ✅ Per-version
  List<DayItinerary> days;
  // ... other version fields
}
```

Update Firestore schema references in `PlanService` and any serialization code. Since only 2 plans exist, they can be manually re-saved through the new builder if needed.

### 0e. Verify

Manual testing checklist:

- [ ] Create new plan → fill all fields → publish
- [ ] Edit existing plan → modify fields → save
- [ ] Add/remove versions (new versions copy Prepare/LocalTips from active)
- [ ] Add/remove days, waypoints
- [ ] AI generation → fields update visually
- [ ] GPX upload → map updates
- [ ] Save indicator shows correct status (ListenableBuilder pattern)
- [ ] Switch between versions → correct data displayed
- [ ] Switch activity category (hiking → city) → outdoor fields hidden but data preserved
- [ ] Switch back (city → hiking) → outdoor fields reappear with data intact
- [ ] Version selector appears/disappears correctly on tab swipe (AnimatedBuilder)
- [ ] No console errors

---

## Phase 1: Unified Screen (Viewer Mode)

### Screen Shell

```dart
class AdventureDetailScreen extends StatefulWidget {
  final AdventureMode mode;
  final AdventureData? adventureData;
  final String? editPlanId;
  
  const AdventureDetailScreen({
    super.key,
    required this.mode,
    this.adventureData,
    this.editPlanId,
  });
}

class _AdventureDetailScreenState extends State<AdventureDetailScreen> {
  AdventureFormState? _formState;
  AdventureSaveService? _saveService;
  AdventureData? _adventureData;
  
  bool get isBuilder => widget.mode == AdventureMode.builder;
  
  int get _dayCount {
    if (isBuilder) {
      return _formState?.activeVersion.daysCount ?? 0;
    }
    return _adventureData?.dayCount ?? 0;
  }
  
  ActivityCategory? get _activityCategory {
    if (isBuilder) return _formState?.activityCategory;
    return _adventureData?.activityCategory;
  }
  
  @override
  Widget build(BuildContext context) {
    final tabs = _getTabsForMode(widget.mode, _dayCount);
    
    return DefaultTabController(
      key: ValueKey('tabs-${tabs.length}-${_formState?.activeVersionIndex ?? 0}'),
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isBuilder 
              ? 'Edit Adventure' 
              : _adventureData?.displayName ?? ''),
          bottom: TabBar(
            isScrollable: true,
            tabs: tabs.map((t) => Tab(
              icon: Icon(t.icon, size: 18), 
              text: t.label,
            )).toList(),
          ),
          actions: isBuilder ? [_buildSaveIndicator()] : null,
        ),
        body: Column(
          children: [
            // Version selector (shown on version-dependent tabs)
            _buildVersionSelector(),
            
            // Tab content
            Expanded(
              child: TabBarView(
                children: tabs.map((tab) => _buildTabContent(tab)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildVersionSelector() {
    // Only show on version-dependent tabs
    // Use AnimatedBuilder to listen to TabController for tab-change reactivity
    // Hide on General, Versions, Review tabs in builder mode
    // Hide on Overview tab in viewer mode
    return AnimatedBuilder(
      animation: DefaultTabController.of(context),
      builder: (context, _) {
        final tabController = DefaultTabController.of(context);
        final tabIndex = tabController.index;
        final isVersionDependent = _isVersionDependentTab(tabIndex);
        if (!isVersionDependent) return SizedBox.shrink();
        
        return isBuilder
            ? VersionSelectorBar.fromFormStates(
                versions: _formState!.versions,
                activeIndex: _formState!.activeVersionIndex,
                onChanged: _onVersionChanged,
                isEditable: false,
              )
            : VersionSelectorBar.fromPlanVersions(
                versions: _adventureData!.plan!.versions,
                activeIndex: _getViewerVersionIndex(),
                onChanged: _onVersionChanged,
                isEditable: false,
              );
      },
    );
  }
  
  Widget _buildSaveIndicator() {
    // Shows save status using ListenableBuilder on formState
    return ListenableBuilder(
      listenable: _formState!,
      builder: (context, _) {
        if (_formState!.isSaving) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (_formState!.saveStatus.isNotEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              _formState!.saveStatus == 'saved' 
                  ? Icons.check_circle 
                  : Icons.error,
              size: 20,
            ),
          );
        }
        return SizedBox.shrink();
      },
    );
  }
}
```



### Viewer Tabs

All use reusable components with `isEditable: false`:

```dart
Widget _buildOverviewTab() {
  return SingleChildScrollView(
    child: Column(
      children: [
        // Hero image
        InlineEditableImage(
          isEditable: false,
          imageUrl: _adventureData!.displayImage,
        ),
        // General info
        SectionCard(
          title: 'About',
          children: [
            InlineEditableField(isEditable: false, label: 'Name', 
                displayValue: _adventureData!.displayName),
            InlineEditableField(isEditable: false, label: 'Location', 
                displayValue: _adventureData!.location),
            InlineEditableField(isEditable: false, label: 'Description', 
                displayValue: _adventureData!.plan?.description),
          ],
        ),
        // FAQ
        FAQSection(isEditable: false, items: _adventureData!.faqItems),
        // Reviews, stats, etc.
      ],
    ),
  );
}

Widget _buildPrepareTab() {
  return PrepareSection(
    isEditable: false,
    prepare: _adventureData!.prepare,
    activityCategory: _activityCategory,
  );
}

Widget _buildLocalTipsTab() {
  return LocalTipsSection(
    isEditable: false,
    localTips: _adventureData!.localTips,
  );
}

Widget _buildDayTab(int dayIndex) {
  return DayContentSection(
    isEditable: false,
    day: _adventureData!.days[dayIndex],
    activityCategory: _activityCategory,
  );
}
```

---

## Phase 2: Builder Mode

### 2a: General Tab

Uses reusable components with `isEditable: true`:

```dart
Widget _buildGeneralTab() {
  return SingleChildScrollView(
    child: Column(
      children: [
        InlineEditableImage(
          isEditable: true,
          imageUrl: _formState!.heroImageUrlCtrl.text,
          imageBytes: _formState!.coverImageBytes,
          onImagePicked: _onCoverImagePicked,
        ),
        SectionCard(
          title: 'Basic Info',
          children: [
            InlineEditableField(
              isEditable: true, label: 'Name',
              controller: _formState!.nameCtrl,
              onEditComplete: () => _saveService!.scheduleAutoSave(_formState!),
            ),
            InlineEditableField(
              isEditable: true, label: 'Location',
              controller: _formState!.locationCtrl,
              // LocationSearchState handles autocomplete
            ),
            InlineEditableField(
              isEditable: true, label: 'Description',
              controller: _formState!.descriptionCtrl,
              maxLines: 5,
              onEditComplete: () => _saveService!.scheduleAutoSave(_formState!),
            ),
          ],
        ),
        SectionCard(
          title: 'Activity Type',
          children: [
            InlineEditableDropdown<ActivityCategory>(
              isEditable: true,
              label: 'Activity Category',
              value: _formState!.activityCategory,
              items: ActivityCategory.values,
              onChanged: (v) {
                _formState!.activityCategory = v;
                _saveService!.scheduleAutoSave(_formState!);
              },
            ),
          ],
        ),
        FAQSection(
          isEditable: true,
          faqStates: _formState!.faqItems,
          onChanged: () => _saveService!.scheduleAutoSave(_formState!),
        ),
      ],
    ),
  );
}
```



### 2b: Versions Tab

```dart
Widget _buildVersionsTab() {
  return ListenableBuilder(
    listenable: _formState!,
    builder: (context, _) => VersionsEditor(
      versions: _formState!.versions,
      activeIndex: _formState!.activeVersionIndex,
      onActiveChanged: (i) => _formState!.activeVersionIndex = i,
      onDurationChanged: () => setState(() {}), // Rebuilds tabs via key change
      onAdd: _addVersion,
      onRemove: _removeVersion,
    ),
  );
}
```



### 2c: Prepare Tab (includes packing + transportation)

```dart
Widget _buildBuilderPrepareTab() {
  final version = _formState!.activeVersion;
  return PrepareSection(
    isEditable: true,
    versionState: version,
    activityCategory: _formState!.activityCategory,
    onGenerateAI: () => _generatePrepareAI(version),
    onChanged: () => _saveService!.scheduleAutoSave(_formState!),
  );
  // PrepareSection internally renders:
  // - Travel insurance, visa, passport, permits, vaccines, climate
  // - PackingSection (packing categories editor)
  // - TransportationSection (transportation options editor)
}
```



### 2d: Local Tips Tab

```dart
Widget _buildBuilderLocalTipsTab() {
  final version = _formState!.activeVersion;
  return LocalTipsSection(
    isEditable: true,
    versionState: version,
    onGenerateAI: () => _generateLocalTipsAI(version),
    onChanged: () => _saveService!.scheduleAutoSave(_formState!),
  );
}
```



### 2e: Day Tabs (activity-aware)

```dart
Widget _buildBuilderDayTab(int dayNum) {
  final version = _formState!.activeVersion;
  final dayState = version.getDayState(dayNum);
  
  return DayContentSection(
    isEditable: true,
    dayState: dayState,
    activityCategory: _formState!.activityCategory,
    onEditRoute: () => _pushRouteBuilder(dayNum),
    onChanged: () => _saveService!.scheduleAutoSave(_formState!),
  );
  // DayContentSection internally uses ActivityAwareBuilder to show/hide:
  // - GPX upload (outdoor only)
  // - Distance/elevation fields (outdoor only)
  // - Komoot/AllTrails links (outdoor only)
  // - Route info (outdoor only)
  // - Accommodation, restaurants, activities (always)
  // - Day image (always)
}
```



### 2f: Review Tab

Summary + publish overlay.---

## Phase 3: Trip Integration

Uses `AdventureData.fromTrip()` and reusable components with `isEditable: false` plus trip-specific overlays.---

## Phase 4: Cleanup

- Deprecate `builder_screen.dart`, `plan_details_screen.dart`
- Update `nav.dart` routes
- Remove dead code
- No data migration needed

---

## Key Files

### New (Phase 0):

```javascript
lib/state/adventure_form_state.dart
lib/state/version_form_state.dart  
lib/state/day_form_state.dart
lib/state/location_search_state.dart
lib/state/sub_form_states.dart          # PackingCategory, Transportation, FAQ, etc.
lib/services/adventure_save_service.dart
```



### New (Phase 1+):

```javascript
lib/presentation/unified/adventure_detail_screen.dart
lib/models/adventure_data_wrapper.dart
lib/components/unified/section_card.dart
lib/components/unified/inline_editable_field.dart
lib/components/unified/inline_editable_dropdown.dart
lib/components/unified/inline_editable_chips.dart
lib/components/unified/inline_editable_image.dart
lib/components/unified/inline_editable_link.dart
lib/components/unified/version_selector_bar.dart
lib/components/unified/activity_aware_builder.dart
lib/components/unified/prepare_section.dart
lib/components/unified/local_tips_section.dart
lib/components/unified/packing_section.dart
lib/components/unified/transportation_section.dart
lib/components/unified/day_content_section.dart
lib/components/unified/day_waypoint_section.dart
lib/components/unified/faq_section.dart
lib/components/unified/publish_overlay.dart
lib/services/adventure_permission_service.dart
```



### Kept Separate:

```javascript
lib/components/builder/route_builder_screen.dart  (too complex to inline)
```



### Deprecated (Phase 4):

```javascript
lib/presentation/builder/builder_screen.dart
lib/presentation/plans/plan_details_screen.dart


```