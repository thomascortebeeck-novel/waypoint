# Testing Checklist - Activity Type First with Multi-Location Implementation

This checklist covers all phases of the implementation. Test each scenario systematically.

## Phase 1: Data Model (LocationInfo)

### ✅ LocationInfo Class
- [ ] Create a new plan and verify `LocationInfo` is saved correctly
- [ ] Edit an existing plan with old `location` string format
- [ ] Verify migration from old `location` string to `LocationInfo` list works
- [ ] Check that `shortName` and `fullAddress` are parsed correctly from Google Places
- [ ] Verify `toJson()` includes both new fields and backward-compatible `name` field

### ✅ Plan Model
- [ ] Verify `Plan.locations` list is saved to Firestore
- [ ] Verify old plans with `location` string still load correctly
- [ ] Check that `Plan.copyWith()` includes `locations` parameter
- [ ] Verify `PlanMeta` migration works correctly

## Phase 2: Activity Configuration

### ✅ ActivityConfig Pattern
- [ ] Verify all activity types have configurations
- [ ] Test `getActivityConfig()` returns correct config for each activity type
- [ ] Verify `allowsMultipleLocations()` returns correct values
- [ ] Check that `locationOrderMatters` is set correctly for road trips and tours

## Phase 3: Form State

### ✅ AdventureFormState Extensions
- [ ] Test `addLocation()` adds location to list
- [ ] Test `removeLocation()` removes location from list
- [ ] Test `reorderLocations()` changes order correctly
- [ ] Test `setLocations()` replaces entire list
- [ ] Verify `isLocationStepValid` validates correctly:
  - [ ] Single location required for city trips
  - [ ] Multiple locations allowed for road trips/tours
  - [ ] At least one location required for all activities
- [ ] Test `AdventureFormState.fromPlan()` loads locations correctly

## Phase 4: Builder Steps Restructure

### ✅ Step 0: Activity Type
- [ ] Activity type selection displays all categories
- [ ] Selected activity type is highlighted
- [ ] Activity type is saved when proceeding to next step
- [ ] Activity type persists when navigating back

### ✅ Step 1: Locations
- [ ] Location input appears after activity type is selected
- [ ] Single location input for city trips
- [ ] Multiple location input for road trips/tours
- [ ] Location search works correctly
- [ ] Location chips display with short names
- [ ] Can remove locations
- [ ] Can reorder locations (for ordered activities)
- [ ] Validation prevents proceeding without locations

### ✅ Step 2: General Info (Renumbered)
- [ ] Activity category selector is removed
- [ ] Location search is removed
- [ ] Location summary displays (read-only)
- [ ] All other fields work as before

### ✅ Step Navigation
- [ ] All 8 steps are accessible
- [ ] Step labels are correct
- [ ] Navigation buttons work correctly
- [ ] Can navigate back and forth between steps
- [ ] Step validation prevents skipping required steps

## Phase 5: Breadcrumb Component

### ✅ Breadcrumb Display
- [ ] "Builder" always shown (not clickable)
- [ ] Activity type appears after selection
- [ ] Locations appear after adding (up to 2, then "first + count")
- [ ] Current step appears in breadcrumb
- [ ] Breadcrumb items are clickable (except current step)

### ✅ Breadcrumb Navigation
- [ ] Clicking breadcrumb item navigates to that step
- [ ] Breadcrumb updates when step changes
- [ ] Breadcrumb reflects activity type changes
- [ ] Breadcrumb reflects location changes

### ✅ Responsive Design
- [ ] Desktop: Full breadcrumb trail with labels
- [ ] Mobile: Scrollable horizontal icons (Steppers-lite)
- [ ] Mobile icons are clickable
- [ ] Mobile breadcrumb scrolls correctly

## Phase 6: Overview Page Enhancement

### ✅ Activity Type Card
- [ ] Card displays selected activity type
- [ ] Card shows empty state if no activity selected
- [ ] Card shows completion status
- [ ] "Edit" button navigates to Step 0
- [ ] Icon and display name are correct

### ✅ Locations Card
- [ ] Card displays all locations
- [ ] Card shows location count badge
- [ ] Card shows numbered badges for ordered activities
- [ ] Card shows empty state if no locations
- [ ] Card shows completion status
- [ ] "Edit" button navigates to Step 1
- [ ] Short names are displayed (not full addresses)

### ✅ Card Order
- [ ] Activity Type card is first
- [ ] Locations card is second
- [ ] General Info card is third
- [ ] Other cards follow in correct order

### ✅ Completion Check
- [ ] Activity Type validation works
- [ ] Locations validation works
- [ ] Other validations still work
- [ ] Overview shows correct completion status

## Phase 7: Save Service

### ✅ Location Saving
- [ ] New plans save locations list correctly
- [ ] Edited plans update locations correctly
- [ ] Backward compatibility: old plans with `location` string still work
- [ ] `PlanMeta.fromPlan()` includes locations
- [ ] Locations are saved to Firestore correctly

## Phase 8: Activity Type Change Warning

### ✅ Change Detection
- [ ] Warning appears when changing from multi-location to single-location activity
- [ ] Warning appears when changing from single-location to multi-location activity
- [ ] No warning when changing between activities with same constraints

### ✅ Waypoint Detection
- [ ] System detects waypoints in locations that will be deleted
- [ ] Haversine distance calculation works correctly (50km radius)
- [ ] Waypoint count is accurate
- [ ] Location count is accurate

### ✅ Warning Message
- [ ] Message includes number of locations to delete
- [ ] Message includes number of waypoints affected
- [ ] Message is clear and actionable
- [ ] "Cancel" button prevents change
- [ ] "Proceed" button applies change

### ✅ Change Handling
- [ ] When confirmed, only first location is kept
- [ ] Activity category is updated
- [ ] Previous activity category is tracked correctly
- [ ] Locations list is updated correctly

## Phase 9: SEO Optimization

### ✅ SEO Service
- [ ] `SeoService.updatePlanDetailMetaTags()` sets meta tags correctly
- [ ] `SeoService.clearSeoMetaTags()` clears meta tags correctly
- [ ] Meta tags include title, description, Open Graph, Twitter Cards
- [ ] Structured data (JSON-LD) is added correctly
- [ ] Canonical URL is set correctly
- [ ] Robots meta tag is set correctly (index for published, noindex for drafts)

### ✅ SEO Application
- [ ] SEO is applied only in viewer mode (plan detail page)
- [ ] SEO is NOT applied in builder mode
- [ ] SEO is NOT applied in trip mode
- [ ] SEO is cleared when navigating away from plan detail page

### ✅ robots.txt
- [ ] `/builder/` paths are disallowed
- [ ] `/trip/` paths are disallowed
- [ ] `/details/` paths are allowed
- [ ] Sitemap directive is present

## Phase 10: Integration Testing

### ✅ Empty State Test
- [ ] Select "Road Trip" but skip "Locations" step
- [ ] Overview should flag locations as incomplete
- [ ] Cannot publish without locations

### ✅ Deep Link Test
- [ ] Open a plan from 2024 (old format with `location` string)
- [ ] Verify `LocationInfo` migration fires before breadcrumb renders
- [ ] Plan loads correctly with migrated data
- [ ] Breadcrumb displays correctly

### ✅ Reorder Test
- [ ] Create road trip with multiple locations
- [ ] Reorder locations in Step 1
- [ ] Navigate to Step 6 (Days)
- [ ] Verify default days reflect new location order

### ✅ Waypoint Detection Test
- [ ] Create road trip with 3 locations
- [ ] Add waypoints in Days tab for all 3 locations
- [ ] Change activity type to "City Trip"
- [ ] Verify warning shows correct location and waypoint counts
- [ ] Verify waypoints within 50km are detected
- [ ] Verify waypoints outside 50km are not counted

### ✅ Migration Test
- [ ] Load old plan with `location` string
- [ ] Verify it converts to `LocationInfo` list
- [ ] Verify breadcrumb works with migrated data
- [ ] Verify overview page works with migrated data
- [ ] Verify saving preserves new format

### ✅ Multi-Location Activities
- [ ] Test hiking with multiple locations (cross-country)
- [ ] Test cycling with multiple locations
- [ ] Test road trip with ordered locations
- [ ] Test tour with ordered locations
- [ ] Test city trip with single location (enforced)

### ✅ Breadcrumb Edge Cases
- [ ] Test with 1 location (should show location name)
- [ ] Test with 2 locations (should show both)
- [ ] Test with 3+ locations (should show "first + count")
- [ ] Test breadcrumb on very small screens
- [ ] Test breadcrumb navigation from any step

### ✅ Activity Type Constraints
- [ ] Test changing from road trip (5 locations) to city trip (1 location)
- [ ] Test changing from city trip (1 location) to road trip (multiple allowed)
- [ ] Test changing between activities with same constraints (no warning)

## Browser/Device Testing

### ✅ Desktop
- [ ] Chrome
- [ ] Firefox
- [ ] Safari
- [ ] Edge

### ✅ Mobile
- [ ] iOS Safari
- [ ] Android Chrome
- [ ] Responsive design works correctly
- [ ] Touch interactions work correctly

## Performance Testing

### ✅ Load Times
- [ ] Plan with many locations loads quickly
- [ ] Breadcrumb renders quickly
- [ ] Overview page loads quickly
- [ ] SEO meta tags update quickly

### ✅ Memory
- [ ] No memory leaks when navigating between steps
- [ ] Form state is cleaned up correctly
- [ ] Images are disposed correctly

## Accessibility Testing

### ✅ Screen Readers
- [ ] Breadcrumb is readable
- [ ] Activity type selection is accessible
- [ ] Location input is accessible
- [ ] Warning dialogs are accessible

### ✅ Keyboard Navigation
- [ ] Can navigate breadcrumb with keyboard
- [ ] Can select activity type with keyboard
- [ ] Can add locations with keyboard
- [ ] Can navigate all steps with keyboard

## Error Handling

### ✅ Edge Cases
- [ ] Handle plan with no activity type
- [ ] Handle plan with no locations
- [ ] Handle plan with invalid location data
- [ ] Handle network errors during save
- [ ] Handle invalid Google Places data

## Documentation

### ✅ Code Comments
- [ ] All new functions have comments
- [ ] Complex logic is explained
- [ ] Migration logic is documented

### ✅ User-Facing
- [ ] Activity type descriptions are clear
- [ ] Location input hints are helpful
- [ ] Warning messages are clear
- [ ] Error messages are actionable

---

## Notes

- Test with both new plans and existing plans
- Test with published and draft plans
- Test with plans that have waypoints and plans without
- Test with plans that have multiple versions
- Test with plans that have multiple days

## Known Issues

(Add any issues found during testing here)

---

**Last Updated:** [Current Date]
**Tested By:** [Your Name]
**Status:** [In Progress / Complete]

