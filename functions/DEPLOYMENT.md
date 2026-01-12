# Firebase Functions Deployment Guide

## CORS Fix Applied ✅

The Firebase Cloud Functions have been updated to enable CORS for all origins by adding the `cors: true` option to each `onCall` function definition.

### Changes Made:

**Added `cors: true` to all callable functions:**
- `getDirections` - Route directions with multiple waypoints
- `matchRoute` - Map matching for trail snapping
- `getElevationProfile` - Elevation data for routes

This uses Firebase Functions v2's built-in CORS support, which automatically handles:
- Preflight OPTIONS requests
- CORS headers for all origins
- No additional dependencies needed

## Deployment Instructions

### Prerequisites
- Firebase CLI installed: `npm install -g firebase-tools`
- Logged in: `firebase login`
- Project selected: `firebase use <project-id>`

### Deploy Functions

1. **Navigate to functions directory:**
   ```bash
   cd functions
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Build TypeScript:**
   ```bash
   npm run build
   ```

4. **Deploy to Firebase:**
   ```bash
   firebase deploy --only functions
   ```

   Or deploy specific functions:
   ```bash
   firebase deploy --only functions:matchRoute,functions:getElevationProfile,functions:getDirections
   ```

### Set Required Environment Variables

Make sure the `MAPBOX_SECRET_TOKEN` parameter is set:

```bash
firebase functions:secrets:set MAPBOX_SECRET_TOKEN
```

When prompted, paste your Mapbox secret token.

## Testing

After deployment, test the functions using the Firebase Console or by using the app. The CORS errors should be resolved.

## Troubleshooting

### If CORS errors persist:

1. **Verify deployment:**
   ```bash
   firebase functions:log
   ```

2. **Check function status in Firebase Console:**
   - Go to Firebase Console > Functions
   - Verify all three functions are deployed and healthy

3. **Verify the correct region:**
   - Functions are deployed to `europe-west1`
   - The Flutter app should use `FirebaseFunctions.instanceFor(region: 'europe-west1')`

4. **Check authentication:**
   - Callable functions require Firebase Authentication
   - User must be signed in when calling these functions

### Alternative: Use Direct Mapbox API

The app already has a fallback mechanism that uses the direct Mapbox Directions API when Cloud Functions fail. This fallback is working correctly as noted in the logs.

If Cloud Functions continue to have issues, the app will automatically use the fallback, though elevation profiles won't be available.

## Notes

- Firebase Callable Functions (`onCall`) automatically handle CORS when `cors: true` is set
- The `cors` package was added for potential future HTTP functions
- All functions are deployed to the `europe-west1` region for optimal performance in the Nordic region
