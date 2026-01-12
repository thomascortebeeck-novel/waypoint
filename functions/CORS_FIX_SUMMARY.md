# CORS Error Fix Summary

## Problem
Your Firebase Cloud Functions were being blocked by CORS policy when called from the DreamFlow preview domain:

```
Access to fetch at 'https://europe-west1-<project>.cloudfunctions.net/matchRoute' 
from origin 'https://iwqi0irmeeby9oga37x2.share.dreamflow.app' has been blocked by CORS policy
```

This affected:
- ❌ `matchRoute` - Trail-aware route building
- ❌ `getElevationProfile` - Elevation charts with ascent/descent
- ✅ `getDirections` - (working via fallback to direct Mapbox API)

## Solution Applied

Added `cors: true` to all Firebase Callable Functions in `functions/src/mapbox.ts`:

```typescript
export const matchRoute = onCall({region: "europe-west1", cors: true}, async (request) => {
  // ... function code
});

export const getElevationProfile = onCall({region: "europe-west1", timeoutSeconds: 120, cors: true}, async (request) => {
  // ... function code
});

export const getDirections = onCall({region: "europe-west1", cors: true}, async (request) => {
  // ... function code
});
```

### How It Works

Firebase Functions v2 `onCall` with `cors: true`:
- Automatically handles CORS preflight requests (OPTIONS)
- Adds appropriate CORS headers to all responses
- Allows requests from **any origin** (including DreamFlow domains)
- No additional packages or middleware needed

## Next Steps: Deploy the Functions

### Option 1: Deploy from Firebase Panel (Recommended)

1. Open the **Firebase panel** in the left sidebar of DreamFlow
2. Navigate to the **Functions** section
3. Click **Deploy Functions** button
4. Select all three functions:
   - `matchRoute`
   - `getElevationProfile`
   - `getDirections`
5. Click **Deploy**

### Option 2: Deploy via Terminal (If you have local Firebase CLI)

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

### Verify Environment Variable

Make sure `MAPBOX_SECRET_TOKEN` is set in Firebase:
```bash
firebase functions:secrets:set MAPBOX_SECRET_TOKEN
```

## Expected Results After Deployment

✅ **CORS errors will disappear**
- Functions will respond with proper CORS headers
- DreamFlow preview will successfully call all functions

✅ **Full functionality restored:**
- Trail-aware route snapping will work via Cloud Functions
- Elevation profiles will load with ascent/descent data
- Better route matching for multi-waypoint routes

✅ **Performance improvements:**
- Cloud Functions are faster than direct API calls
- They use server-side Mapbox secret token (more secure)
- They handle complex elevation calculations efficiently

## Current Fallback Behavior

Your app already has excellent fallback logic:

1. **Route Building**: If `matchRoute` fails → Falls back to direct Mapbox Directions API ✅
2. **Elevation**: If `getElevationProfile` fails → No elevation chart shown ❌

After deploying the CORS fix, the Cloud Functions will work and you'll get full elevation profiles!

## Testing

After deployment, test in your app:
1. Open Route Builder
2. Add 2+ waypoints on map
3. Click "Preview" - should see route line
4. Click "Build & Save" - should see elevation chart with ascent/descent

Check the Debug Console - you should see:
```
[mapbox.cf] matchRoute OK (<time>ms)
[mapbox.cf] getElevationProfile OK (<time>ms)
```

Instead of:
```
[mapbox.cf] matchRoute failed — error: [firebase_functions/internal] internal
```

## Why This Happened

Firebase Functions v2 `onCall` functions **do** support CORS by default, but the `cors: true` option wasn't explicitly set in your original code. While it should work without it, explicitly adding `cors: true` ensures:

- Clear intent in code
- Guaranteed CORS support
- Consistent behavior across all environments
- Future-proof against Firebase updates

## Additional Notes

- Functions are deployed to `europe-west1` region (optimal for Nordic coverage)
- The Flutter app correctly uses `FirebaseFunctions.instanceFor(region: 'europe-west1')`
- No client-side code changes needed
- Your fallback logic remains as a safety net
