# Breadcrumb Research for Builder Page - Activity Type & Location Selection

## Executive Summary

This document provides research and recommendations for implementing optimal breadcrumbs on the builder page, specifically addressing the relationship between activity types and location selection, where activity types have different location requirements (single vs. multiple locations).

## Current State Analysis

### Existing Builder Structure
- **Current Steps**: ['General Info', 'Versions', 'Prepare', 'Local Tips', 'Days', 'Overview']
- **Activity Types Available**:
  - 🥾 Hiking (can be cross-country or city)
  - 🚴 Cycling (can be cross-country)
  - ⛷️ Skiing (can be cross-country)
  - 🧗 Climbing
  - 🏙️ City Trips (should be one city)
  - 🌏 Tours (can be cross-city or country)
  - 🚗 Road Tripping (can be cross-city or country)

### Current Location Handling
- Currently uses a **single location field** (`location: String`) in the Plan model
- Location is selected via Google Places API autocomplete
- Location is shown in "General Info" step (Step 1)

## Activity Type → Location Requirements

### Location Constraint Matrix

| Activity Type | Location Type | Max Locations | Examples |
|--------------|---------------|---------------|----------|
| **Hiking** | Flexible | Multiple | Cross-country trail, city hike |
| **Cycling** | Cross-country | Multiple | Multi-day bike tour |
| **Skiing** | Cross-country | Multiple | Ski resort hopping |
| **Climbing** | Single/Multiple | Multiple | Climbing areas |
| **City Trips** | Single city | **1 (Required)** | Paris, Tokyo |
| **Tours** | Cross-city/country | Multiple | European tour, Asia tour |
| **Road Tripping** | Cross-city/country | Multiple | Route 66, Pacific Coast Highway |

## Research Findings: Breadcrumb Patterns for Conditional Multi-Step Forms

### 1. Dynamic Breadcrumb Structure

**Principle**: Breadcrumbs should reflect the actual navigation hierarchy and adapt based on user selections.

**Recommended Hierarchy**:
```
Home > Activity Type > Location(s) > [Additional Steps]
```

**Example Flows**:
- **City Trip**: `Builder > City Trip > Paris > General Info`
- **Road Trip**: `Builder > Road Trip > New York > Philadelphia > Boston > General Info`
- **Hike**: `Builder > Hiking > Rocky Mountains > General Info`
- **Multi-Location Tour**: `Builder > Tour > London > Paris > Rome > General Info`

### 2. Location Input Strategies

#### Option A: Progressive Multi-Location Selection (Recommended)
**Approach**: Allow users to add locations one at a time, with clear indication of how many are allowed.

**Pros**:
- Clear visual feedback
- Easy to understand
- Works well with breadcrumbs
- Prevents confusion about location limits

**Cons**:
- More clicks for multi-location activities
- Requires UI space for location list

**Implementation**:
- Show location input field
- After selecting first location, show "Add Another Location" button (if activity type allows)
- Display selected locations as chips/tags
- For City Trips, hide "Add Another" button after first selection

#### Option B: Single Field with Comma-Separated Values
**Approach**: Allow users to type multiple locations in one field.

**Pros**:
- Faster input for experienced users
- Less UI complexity

**Cons**:
- Ambiguous for users (how to format?)
- Harder to validate
- Poor UX for autocomplete
- Doesn't work well with breadcrumbs

#### Option C: Location Picker with Map
**Approach**: Allow users to select multiple locations on a map.

**Pros**:
- Visual and intuitive
- Good for route planning

**Cons**:
- Complex implementation
- Harder to search for specific cities
- May not work well on mobile

**Recommendation**: **Option A (Progressive Multi-Location Selection)**

### 3. Breadcrumb Implementation Strategies

#### Strategy 1: Conditional Breadcrumb Steps
**Approach**: Show different breadcrumb paths based on activity type.

**Structure**:
```
Step 1: Activity Type Selection
Step 2: Location Selection (single or multiple based on activity type)
Step 3: General Info (name, description, etc.)
Step 4: Versions
Step 5: Prepare
Step 6: Local Tips
Step 7: Days
Step 8: Overview
```

**Breadcrumb Display**:
- **City Trip**: `Activity Type > Location > Current Step`
- **Multi-Location**: `Activity Type > Location 1 > Location 2 > ... > Current Step`
- **Single Location**: `Activity Type > Location > Current Step`

#### Strategy 2: Collapsed Location Breadcrumb
**Approach**: Show locations as a single breadcrumb item that expands on hover/click.

**Example**:
```
Builder > Road Trip > [3 Locations ▼] > General Info
```

On click/hover:
```
Builder > Road Trip > 
  • New York
  • Philadelphia  
  • Boston
> General Info
```

**Pros**:
- Keeps breadcrumb compact
- Still shows all locations
- Good for many locations

**Cons**:
- Requires interaction to see all locations
- May be less discoverable

#### Strategy 3: Location Tags in Breadcrumb
**Approach**: Show locations as tags/chips within the breadcrumb.

**Example**:
```
Builder > Road Trip > [NY] [PA] [MA] > General Info
```

**Pros**:
- All locations visible at once
- Compact representation
- Modern UI pattern

**Cons**:
- Can get cluttered with many locations
- May need truncation for long lists

**Recommendation**: **Strategy 1 (Conditional Breadcrumb Steps)** with **Strategy 3 (Location Tags)** as a fallback for activities with many locations.

### 4. UX Best Practices

#### Progressive Disclosure
- Only show location input after activity type is selected
- Show location constraints (e.g., "Select one city" for City Trips) clearly
- Disable "Add Another Location" for City Trips after first selection

#### Visual Feedback
- Show checkmarks on completed breadcrumb steps
- Highlight current step
- Show location count (e.g., "2 of 5 locations added")
- Use icons for activity types in breadcrumbs

#### Validation & Error Handling
- Prevent proceeding if City Trip has multiple locations
- Show clear error messages
- Allow editing locations at any time
- Show which locations are required vs. optional

#### Accessibility
- Use semantic HTML (`<nav>` with ARIA labels)
- Ensure keyboard navigation works
- Screen reader friendly breadcrumb labels
- High contrast for breadcrumb links

## Recommended Implementation

### Step Flow Restructure

**New Step Order**:
1. **Activity Type** (new first step)
2. **Location(s)** (conditional based on activity type)
3. **General Info** (name, description, cover image)
4. **Versions**
5. **Prepare**
6. **Local Tips**
7. **Days**
8. **Overview**

### Location Selection UI

**For Single Location Activities (City Trips)**:
```
┌─────────────────────────────────────┐
│ Location *                          │
│ ┌─────────────────────────────────┐ │
│ │ Search a city...                │ │
│ └─────────────────────────────────┘ │
│ ℹ️ City trips require one city      │
└─────────────────────────────────────┘
```

**For Multi-Location Activities**:
```
┌─────────────────────────────────────┐
│ Locations *                          │
│ ┌─────────────────────────────────┐ │
│ │ Search a location...            │ │
│ └─────────────────────────────────┘ │
│                                      │
│ Selected Locations:                  │
│ [New York ×] [Philadelphia ×]        │
│                                      │
│ [+ Add Another Location]             │
│                                      │
│ ℹ️ You can add multiple locations    │
└─────────────────────────────────────┘
```

### Breadcrumb Component Design

**Visual Design**:
```
[🏠 Builder] > [🥾 Hiking] > [📍 Rocky Mountains] > [📝 General Info]
```

**Interactive States**:
- **Completed**: Green checkmark, clickable to navigate back
- **Current**: Highlighted with primary color, bold text
- **Upcoming**: Gray, disabled

**Responsive Behavior**:
- Desktop: Full breadcrumb trail
- Tablet: Show first, current, and last steps
- Mobile: Show "Back to [Previous Step]" button

### Data Model Changes

**Current Model**:
```dart
final String location; // Single location string
```

**Recommended Model**:
```dart
final List<LocationInfo> locations; // Multiple locations
final ActivityCategory? activityCategory; // Already exists

class LocationInfo {
  final String name; // Display name
  final double? latitude;
  final double? longitude;
  final String? placeId; // Google Places ID
}
```

**Migration Strategy**:
- Keep `location` field for backward compatibility
- Add `locations` field as new primary field
- Migrate existing plans: `locations = [LocationInfo(name: location)]`

## Implementation Checklist

### Phase 1: Data Model & State
- [ ] Add `LocationInfo` class
- [ ] Update `Plan` model to support `List<LocationInfo> locations`
- [ ] Update form state to handle multiple locations
- [ ] Add migration logic for existing plans

### Phase 2: Activity Type Step
- [ ] Create new "Activity Type" step (Step 0)
- [ ] Move activity category selection to first step
- [ ] Update step navigation logic

### Phase 3: Location Selection Step
- [ ] Create location selection UI component
- [ ] Implement single vs. multiple location logic
- [ ] Add location validation based on activity type
- [ ] Implement location chips/tags display
- [ ] Add "Add Another Location" functionality

### Phase 4: Breadcrumb Component
- [ ] Create breadcrumb widget component
- [ ] Implement conditional breadcrumb rendering
- [ ] Add location tags/chips to breadcrumb
- [ ] Implement breadcrumb navigation
- [ ] Add responsive breadcrumb behavior

### Phase 5: Integration
- [ ] Update builder screen to use new step order
- [ ] Update step progress indicator
- [ ] Update validation logic
- [ ] Update save/publish logic
- [ ] Test all activity types

### Phase 6: Polish
- [ ] Add animations/transitions
- [ ] Improve error messages
- [ ] Add loading states
- [ ] Accessibility audit
- [ ] Mobile responsiveness testing

## References

1. [Breadcrumbs In Web Design: Examples And Best Practices](https://smashingmagazine.com/2009/03/breadcrumbs-in-web-design-examples-and-best-practices)
2. [Breadcrumb Pattern | UX Patterns for Developers](https://uxpatterns.dev/en/patterns/navigation/breadcrumb)
3. [Building a breadcrumbs component](https://web.dev/articles/building/a-breadcrumbs-component)

## Questions to Consider

1. **Should users be able to change activity type after selecting locations?**
   - If yes, need to validate/clear locations that don't match new type
   - If no, show warning when attempting to change

2. **How to handle location ordering?**
   - For multi-location activities, does order matter?
   - Should users be able to reorder locations?

3. **Location display in breadcrumb:**
   - Show all locations or just first/last?
   - How to handle many locations (5+)? Truncate?

4. **Backward compatibility:**
   - How to handle existing plans with single `location` string?
   - Should we migrate all at once or on-demand?

## Next Steps

1. Review this document with the team
2. Decide on location input strategy (recommend Option A)
3. Decide on breadcrumb strategy (recommend Strategy 1)
4. Create detailed UI mockups
5. Begin Phase 1 implementation


