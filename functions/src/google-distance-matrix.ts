import {onCall, HttpsError} from "firebase-functions/v2/https";
import axios from "axios";

// 🔒 SECURITY: API key stored as environment variable
function getGoogleMapsKey(): string {
  const key = process.env.GOOGLE_PLACES_KEY; // Reuse same key (includes Distance Matrix API)
  if (!key) {
    throw new Error("GOOGLE_PLACES_KEY environment variable not set");
  }
  return key;
}

const DISTANCE_MATRIX_URL = "https://maps.googleapis.com/maps/api/distancematrix/json";

// Rate limiting
const RATE_LIMITS = {
  distanceMatrix: {max: 100, windowMs: 5 * 60 * 1000}, // 100 per 5 minutes
};

// Server-side cache
const matrixCache = new Map<string, {data: any; timestamp: number}>();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

interface RateLimitData {
  count: number;
  timestamp: number;
}

const rateLimitStore = new Map<string, RateLimitData>();

function getCacheKey(data: any): string {
  return JSON.stringify(data);
}

function getFromCache(key: string): any | null {
  const cached = matrixCache.get(key);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data;
  }
  matrixCache.delete(key);
  return null;
}

function setCache(key: string, data: any): void {
  matrixCache.set(key, {data, timestamp: Date.now()});
  
  // Cleanup old cache entries (keep last 200)
  if (matrixCache.size > 200) {
    const oldestKey = matrixCache.keys().next().value;
    matrixCache.delete(oldestKey);
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

interface DistanceMatrixRequest {
  origins: Array<{lat: number; lng: number}>;
  destinations: Array<{lat: number; lng: number}>;
  travelMode: "driving" | "walking" | "bicycling" | "transit";
}

/**
 * 🔒 SECURE: Get distance and duration matrix using Google Distance Matrix API
 * Implements rate limiting, caching, and authentication
 * 
 * This is optimized for calculating travel between consecutive waypoints
 */
export const googleDistanceMatrix = onCall(
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
    const data = request.data as DistanceMatrixRequest;

    // Validate input
    if (!data.origins || data.origins.length === 0) {
      throw new HttpsError("invalid-argument", "At least one origin is required");
    }
    if (!data.destinations || data.destinations.length === 0) {
      throw new HttpsError("invalid-argument", "At least one destination is required");
    }

    // Check cache BEFORE rate limiting (saves quota)
    const cacheKey = getCacheKey(data);
    const cachedResult = getFromCache(cacheKey);
    if (cachedResult) {
      console.log(`📦 Cache hit for distance matrix request`);
      return cachedResult;
    }

    // Rate limiting
    if (!checkRateLimit(userId, "distanceMatrix")) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many distance matrix requests. Please wait a few moments and try again."
      );
    }

    try {
      const apiKey = getGoogleMapsKey();
      const {origins, destinations, travelMode} = data;

      // Build origins and destinations strings
      const originsStr = origins.map((o) => `${o.lat},${o.lng}`).join("|");
      const destinationsStr = destinations.map((d) => `${d.lat},${d.lng}`).join("|");

      // Build URL
      let url = `${DISTANCE_MATRIX_URL}?origins=${encodeURIComponent(originsStr)}`;
      url += `&destinations=${encodeURIComponent(destinationsStr)}`;
      url += `&mode=${travelMode}`;
      url += `&key=${apiKey}`;

      console.log(`📏 Calling Google Distance Matrix API: ${origins.length} origins, ${destinations.length} destinations, mode: ${travelMode}`);

      const response = await axios.get(url, {
        timeout: 8000,
      });

      if (response.data.status !== "OK") {
        throw new Error(`Google Distance Matrix API error: ${response.data.status}`);
      }

      // Parse response
      const rows = response.data.rows;
      if (!rows || rows.length === 0) {
        throw new Error("No distance matrix data returned");
      }

      // Extract distance and duration for each origin-destination pair
      const results = rows.map((row: any, originIndex: number) => {
        return row.elements.map((element: any, destIndex: number) => {
          if (element.status !== "OK") {
            return null;
          }
          return {
            distance: element.distance.value, // meters
            duration: element.duration.value, // seconds
          };
        });
      });

      const result = {
        rows: results,
      };

      // Cache the result
      setCache(cacheKey, result);

      console.log(`✅ Distance matrix calculated`);
      return result;
    } catch (error: any) {
      console.error("❌ Distance Matrix API error:", error.message);
      
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
            "Distance Matrix API access denied. Please check API key configuration."
          );
        }
      }

      throw new HttpsError(
        "internal",
        `Failed to calculate distance matrix: ${error.message}`
      );
    }
  }
);

