# Fixing Your Custom Mapbox Style

## The Problem

Your custom style `cmkzt3kvv003701r11e0w1rkl` is failing with:
```
Bare objects invalid. Use ["literal", {...}] instead.
Secondary image variant is not a string.
```

This means your style JSON contains syntax that Mapbox GL JS v3.4.0+ no longer accepts.

## Solution: Fix in Mapbox Studio

### Step 1: Open Your Style in Mapbox Studio
1. Go to https://studio.mapbox.com/
2. Navigate to **Styles** → Find your style `cmkzt3kvv003701r11e0w1rkl`
3. Click **Edit** to open the style editor

### Step 2: Check for Common Issues

#### Issue A: Bare Objects in Filters
**Find:** Any layer with a `filter` property that looks like:
```json
"filter": {"key": "value"}
```

**Fix:** Convert to expression format:
```json
"filter": ["literal", {"key": "value"}]
```

#### Issue B: Image Variant Syntax
**Find:** Any layer using `icon-image` or `*-image` with a variant that's not a string:
```json
"icon-image": {"property": "icon", "type": "identity"}
```

**Fix:** Ensure image references are strings or use proper expressions:
```json
"icon-image": ["get", "icon"]
```

#### Issue C: Outdated Expression Syntax
**Find:** Any property using old object syntax instead of array expressions.

**Fix:** Use Mapbox expressions (arrays starting with operator names):
```json
// OLD (invalid):
"text-color": {"r": 255, "g": 0, "b": 0}

// NEW (valid):
"text-color": ["rgb", 255, 0, 0]
```

### Step 3: Use Mapbox Studio's Validation
1. In Mapbox Studio, click **Settings** (gear icon)
2. Look for any **warnings** or **errors** shown
3. Mapbox Studio will highlight problematic layers

### Step 4: Quick Fix Option - Start Fresh
If fixing the style is too complex:

1. **Create a new style from a template:**
   - In Mapbox Studio, click **New style**
   - Choose **Outdoors** or **Standard** template
   - Customize colors/branding to match your Waypoint theme
   - Save the new style

2. **Update your code:**
   - Copy the new style ID
   - Update `_waypointStyleId` in `lib/integrations/mapbox_config.dart`

### Step 5: Test the Fixed Style
1. Save your changes in Mapbox Studio
2. Wait 1-2 minutes for Mapbox to propagate the changes
3. Hot restart your Flutter app (press `R` in terminal)
4. Hard refresh browser (`Ctrl+Shift+R`)

## Alternative: Temporarily Use a Working Style

If you need the app working immediately while fixing the style:

1. Update `mapbox_config.dart` to use a known-good style:
```dart
// Temporarily use the working outdoors style
const _waypointStyleId = 'cmkwpnibk001201r4cwe2flf7'; // Your working outdoors style
```

2. Or use Mapbox's standard outdoors:
```dart
const _waypointStyleId = 'outdoors-v12'; // Mapbox standard
String get _styleUri => 'mapbox://styles/mapbox/$_waypointStyleId';
```

## Verification

After fixing, check your console logs. You should see:
```
✅ [MapboxWeb] Map "load" event fired
✅ Map loaded successfully at zoom: 12 (using custom style)
```

Instead of:
```
🔄 [MapboxWeb] Style error detected, switching to fallback...
```

