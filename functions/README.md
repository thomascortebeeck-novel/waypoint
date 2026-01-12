# Waypoint Firebase Cloud Functions

This directory contains Firebase Cloud Functions for the Waypoint hiking app, providing server-side Mapbox API integration for route building and elevation profiles.

## Functions

### 1. `matchRoute`
- **Purpose**: Trail-aware route matching for multi-waypoint routes
- **Region**: `europe-west1`
- **API**: Mapbox Map Matching API (walking profile)
- **Input**: Array of lat/lng points, snapToTrail flag
- **Output**: GeoJSON geometry, distance (m), duration (s)

### 2. `getElevationProfile`
- **Purpose**: Generate elevation profiles from route coordinates
- **Region**: `europe-west1`
- **Timeout**: 120 seconds
- **API**: Mapbox Terrain-RGB tiles
- **Input**: Array of [lng, lat] coordinates
- **Output**: Elevation points, total ascent, total descent

### 3. `getDirections`
- **Purpose**: Calculate walking directions between waypoints
- **Region**: `europe-west1`
- **API**: Mapbox Directions API (walking profile)
- **Input**: Array of waypoints, profile type
- **Output**: Route geometry, distance, duration, steps

## Technology Stack

- **Runtime**: Node.js 18
- **Framework**: Firebase Functions v2
- **Language**: TypeScript
- **Key Dependencies**:
  - `firebase-functions`: ^4.4.1
  - `firebase-admin`: ^12.0.0
  - `axios`: ^1.6.7 (HTTP requests)
  - `pngjs`: ^7.0.0 (Terrain-RGB tile parsing)

## CORS Configuration

All functions use `cors: true` in their `onCall` configuration, enabling:
- Automatic CORS header handling
- Support for all origins (including DreamFlow preview domains)
- Preflight OPTIONS request handling

## Environment Variables

### Required Secret
- `MAPBOX_SECRET_TOKEN`: Your Mapbox secret token (set via Firebase Secrets)

Set it using:
```bash
firebase functions:secrets:set MAPBOX_SECRET_TOKEN
```

## Development

### Install Dependencies
```bash
npm install
```

### Build TypeScript
```bash
npm run build
```

### Run Locally (with Firebase Emulator)
```bash
npm run serve
```

### Deploy to Production
```bash
npm run deploy
# or
firebase deploy --only functions
```

### Deploy Specific Function
```bash
firebase deploy --only functions:matchRoute
```

## Architecture Notes

### Why Cloud Functions?

1. **Security**: Mapbox secret token stays server-side
2. **Performance**: Server-to-server API calls are faster
3. **Complex Processing**: Elevation profiles require parsing PNG tiles
4. **Cost Control**: Centralized API usage monitoring

### Elevation Profile Algorithm

1. **Sampling**: Route coordinates are sampled every ~50-100m
2. **Tile Fetching**: Mapbox Terrain-RGB tiles fetched at zoom 15
3. **Pixel Extraction**: Lat/lng converted to tile pixel coordinates
4. **Elevation Calculation**: RGB values decoded to elevation in meters
5. **Ascent/Descent**: Calculated from elevation differences

Formula: `elevation = -10000 + ((R * 256 * 256 + G * 256 + B) * 0.1)`

### Map Matching

- Uses Mapbox Map Matching API to snap GPS traces to roads/trails
- Walking profile optimized for hiking trails
- Returns clean geometries suitable for display

## Client Integration

Flutter app uses Firebase Callable Functions:

```dart
final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
final callable = functions.httpsCallable('matchRoute');
final response = await callable.call({
  'points': points,
  'snapToTrail': true,
});
```

## Error Handling

Functions return error objects when issues occur:

```typescript
{error: "need at least two points"}
{error: "no_match"}
{error: "request_failed"}
```

Client code should handle these gracefully with fallbacks.

## Performance

- **matchRoute**: ~200-500ms for typical routes
- **getElevationProfile**: ~1-3s depending on route length and complexity
- **getDirections**: ~200-400ms for typical routes

## Monitoring

View logs in Firebase Console:
```bash
firebase functions:log
```

Or via CLI:
```bash
firebase functions:log --only matchRoute
```

## Future Improvements

- [ ] Add caching for frequently requested routes
- [ ] Implement rate limiting per user
- [ ] Add support for cycling and driving profiles
- [ ] Optimize elevation sampling for very long routes
- [ ] Add route optimization (shortest/fastest path)

## Troubleshooting

### CORS Errors
- Ensure `cors: true` is set in `onCall` options
- Redeploy functions after changes

### Token Issues
- Verify `MAPBOX_SECRET_TOKEN` is set: `firebase functions:secrets:access MAPBOX_SECRET_TOKEN`
- Check token permissions in Mapbox account

### Timeout Issues
- `getElevationProfile` has 120s timeout
- For very long routes, consider reducing sampling frequency
- Check Mapbox API rate limits

### Cold Starts
- First request after deploy may take 5-10s
- Subsequent requests are much faster (~200-500ms)

## License

Private - Part of Waypoint hiking app
