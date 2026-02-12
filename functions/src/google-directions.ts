import {onCall, HttpsError} from "firebase-functions/v2/https";
import axios from "axios";

// 🔒 SECURITY: API key stored as environment variable
function getGoogleMapsKey(): string {
  const key = process.env.GOOGLE_PLACES_KEY; // Reuse same key (includes Directions API)
  if (!key) {
    throw new Error("GOOGLE_PLACES_KEY environment variable not set");
  }
  return key;
}

const DIRECTIONS_BASE_URL = "https://maps.googleapis.com/maps/api/directions/json";

// Rate limiting
const RATE_LIMITS = {
  directions: {max: 100, windowMs: 5 * 60 * 1000}, // 100 per 5 minutes
};

// Server-side cache
const routeCache = new Map<string, {data: any; timestamp: number}>();
const CACHE_TTL = 10 * 60 * 1000; // 10 minutes (routes change less frequently)

interface RateLimitData {
  count: number;
  timestamp: number;
}

const rateLimitStore = new Map<string, RateLimitData>();

function getCacheKey(data: any): string {
  return JSON.stringify(data);
}

function getFromCache(key: string): any | null {
  const cached = routeCache.get(key);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data;
  }
  routeCache.delete(key);
  return null;
}

function setCache(key: string, data: any): void {
  routeCache.set(key, {data, timestamp: Date.now()});
  
  // Cleanup old cache entries (keep last 200)
  if (routeCache.size > 200) {
    const oldestKey = routeCache.keys().next().value;
    routeCache.delete(oldestKey);
  }
}

function checkRateLimit(userId: string, endpoint: string): boolean {
  const key = `${userId}:${endpoint}`;
  const now = Date.now();
  const limit = RATE_LIMITS[endpoint as keyof typeof RATE_LIMITS];
  
  if (!limit) return true;
  
  const data = rateLimitStore.get(key);
  
  if (!data || now - data.timestamp > limit.windowMs) {
    rateLimitStore.set(key, {count: 1, timestamp: now});
    return true;
  }
  
  if (data.count >= limit.max) {
    return false;
  }
  
  data.count++;
  return true;
}

interface DirectionsRequest {
  waypoints: Array<{lat: number; lng: number}>;
  travelMode: "driving" | "walking" | "bicycling" | "transit";
  optimizeWaypoints?: boolean;
}

/**
 * 🔒 SECURE: Get directions using Google Directions API
 * Implements rate limiting, caching, and authentication
 */
export const googleDirections = onCall(
  {
    region: "us-central1",
    memory: "256MiB",
    timeoutSeconds: 10,
  },
  async (request) => {
    // Enforce authentication
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const userId = request.auth.uid;
    const data = request.data as DirectionsRequest;

    // Validate input
    if (!data.waypoints || data.waypoints.length < 2) {
      throw new HttpsError(
        "invalid-argument",
        "At least 2 waypoints are required"
      );
    }

    // Check cache BEFORE rate limiting (saves quota)
    const cacheKey = getCacheKey(data);
    const cachedResult = getFromCache(cacheKey);
    if (cachedResult) {
      console.log(`📦 Cache hit for directions request`);
      return cachedResult;
    }

    // Rate limiting
    if (!checkRateLimit(userId, "directions")) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many route requests. Please wait a few moments and try again."
      );
    }

    try {
      const apiKey = getGoogleMapsKey();
      const {waypoints, travelMode, optimizeWaypoints} = data;

      // Build waypoints string for Google Directions API
      const origin = `${waypoints[0].lat},${waypoints[0].lng}`;
      const destination = `${waypoints[waypoints.length - 1].lat},${waypoints[waypoints.length - 1].lng}`;
      
      // Intermediate waypoints (if any)
      let waypointsParam = "";
      if (waypoints.length > 2) {
        const intermediate = waypoints.slice(1, -1);
        waypointsParam = intermediate
          .map((w) => `${w.lat},${w.lng}`)
          .join("|");
        if (optimizeWaypoints) {
          waypointsParam = `optimize:true|${waypointsParam}`;
        }
      }

      // Build URL
      let url = `${DIRECTIONS_BASE_URL}?origin=${origin}&destination=${destination}`;
      if (waypointsParam) {
        url += `&waypoints=${encodeURIComponent(waypointsParam)}`;
      }
      url += `&mode=${travelMode}`;
      url += `&key=${apiKey}`;

      console.log(`🗺️ Calling Google Directions API: ${waypoints.length} waypoints, mode: ${travelMode}`);

      const response = await axios.get(url, {
        timeout: 8000,
      });

      // Handle different API response statuses
      if (response.data.status === "ZERO_RESULTS") {
        // ZERO_RESULTS is a valid response - just means no route found
        // This can happen for various reasons (points too far, no road connection, etc.)
        console.log(`⚠️ No route found between waypoints (ZERO_RESULTS)`);
        return null;
      }

      if (response.data.status !== "OK") {
        // Other statuses (like OVER_QUERY_LIMIT, REQUEST_DENIED, etc.) are actual errors
        throw new Error(`Google Directions API error: ${response.data.status}`);
      }

      // Parse response
      const route = response.data.routes[0];
      if (!route) {
        // This shouldn't happen if status is OK, but handle it gracefully
        console.log(`⚠️ No route found in response`);
        return null;
      }

      const leg = route.legs[0];
      const overviewPolyline = route.overview_polyline.points;

      // Decode polyline to coordinates
      const coordinates = decodePolyline(overviewPolyline);

      const result = {
        geometry: coordinates,
        distance: leg.distance.value, // meters
        duration: leg.duration.value, // seconds
        polyline: overviewPolyline,
      };

      // Cache the result
      setCache(cacheKey, result);

      console.log(`✅ Directions calculated: ${(leg.distance.value / 1000).toFixed(2)}km, ${Math.round(leg.duration.value / 60)}min`);
      return result;
    } catch (error: any) {
      console.error("❌ Directions API error:", error.message);
      
      if (error.response) {
        const status = error.response.status;
        if (status === 429) {
          throw new HttpsError(
            "resource-exhausted",
            "Rate limit exceeded. Please try again in a few minutes."
          );
        }
        if (status === 403) {
          throw new HttpsError(
            "permission-denied",
            "Directions API access denied. Please check API key configuration."
          );
        }
      }

      throw new HttpsError(
        "internal",
        `Failed to calculate route: ${error.message}`
      );
    }
  }
);

/**
 * Decode Google polyline string to coordinates
 * Simple implementation - for production, consider using a library
 */
function decodePolyline(encoded: string): Array<[number, number]> {
  const coordinates: Array<[number, number]> = [];
  let index = 0;
  const len = encoded.length;
  let lat = 0;
  let lng = 0;

  while (index < len) {
    let shift = 0;
    let result = 0;
    let byte: number;

    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    const deltaLat = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
    lat += deltaLat;

    shift = 0;
    result = 0;

    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    const deltaLng = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
    lng += deltaLng;

    coordinates.push([lng / 1e5, lat / 1e5]);
  }

  return coordinates;
}

