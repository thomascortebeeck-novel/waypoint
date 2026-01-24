import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import axios from "axios";

// 🔒 SECURITY: API key stored as environment variable (.env.yaml)
// No special IAM permissions needed - simpler than Secret Manager
function getGooglePlacesKey(): string {
  const key = process.env.GOOGLE_PLACES_KEY;
  if (!key) {
    throw new Error("GOOGLE_PLACES_KEY environment variable not set");
  }
  return key;
}

const PLACES_BASE_URL = "https://places.googleapis.com/v1";
const GEOCODING_URL = "https://maps.googleapis.com/maps/api/geocode/json";

// Rate limiting: TEMPORARILY RELAXED until Flutter debouncing optimization is complete
// TODO: Restore to {max: 100, windowMs: 5 * 60 * 1000} once Flutter side is optimized
const RATE_LIMITS = {
  search: {max: 200, windowMs: 5 * 60 * 1000}, // 200 per 5 minutes (TEMPORARY)
  details: {max: 100, windowMs: 5 * 60 * 1000}, // 100 per 5 minutes (TEMPORARY)
  photo: {max: 150, windowMs: 5 * 60 * 1000}, // 150 per 5 minutes (TEMPORARY)
  geocode: {max: 50, windowMs: 5 * 60 * 1000}, // 50 per 5 minutes (TEMPORARY)
};

// Burst protection: TEMPORARILY DISABLED until Flutter debouncing is optimized
// TODO: Restore to 15 once Flutter side is optimized
const BURST_LIMIT = 50; // Relaxed (was 15)
const BURST_WINDOW = 10000; // 10 seconds

// Server-side cache (consider Redis/Memorystore for production)
const searchCache = new Map<string, {data: any; timestamp: number}>();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

interface RateLimitData {
  count: number;
  timestamp: number;
  burstCount: number;
  burstTimestamp: number;
}

function getCacheKey(data: any): string {
  return JSON.stringify(data);
}

function getFromCache(key: string): any | null {
  const cached = searchCache.get(key);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data;
  }
  searchCache.delete(key);
  return null;
}

function setCache(key: string, data: any): void {
  searchCache.set(key, {data, timestamp: Date.now()});
  
  // Limit cache size to prevent memory issues
  if (searchCache.size > 1000) {
    const firstKey = searchCache.keys().next().value;
    searchCache.delete(firstKey);
  }
}

/**
 * Check rate limit with burst protection using Firestore transactions
 * Prevents race conditions from multiple simultaneous requests
 */
async function checkRateLimit(
  userId: string,
  endpoint: keyof typeof RATE_LIMITS
): Promise<boolean> {
  const db = getFirestore();
  const now = Date.now();
  const docId = `${userId}_${endpoint}`;
  const rateLimitRef = db.collection("rate_limits").doc(docId);
  
  try {
    // Use transaction to prevent race conditions
    return await db.runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);
      const data = doc.data() as RateLimitData | undefined;
      const limit = RATE_LIMITS[endpoint];

      // Check burst limit (5 requests per 10 seconds)
      const burstExpired = !data || (now - data.burstTimestamp) > BURST_WINDOW;
      const currentBurstCount = burstExpired ? 1 : (data?.burstCount || 0) + 1;
      
      if (!burstExpired && currentBurstCount > BURST_LIMIT) {
        console.warn(`⚡ Burst limit exceeded for user ${userId} on ${endpoint}`);
        return false;
      }

      // Check main rate limit
      const windowExpired = !data || (now - data.timestamp) > limit.windowMs;
      const currentCount = windowExpired ? 1 : (data?.count || 0) + 1;
      
      if (!windowExpired && currentCount > limit.max) {
        console.warn(`🚫 Rate limit exceeded for user ${userId} on ${endpoint}: ${currentCount}/${limit.max}`);
        return false;
      }

      // Update rate limit data
      transaction.set(rateLimitRef, {
        count: currentCount,
        timestamp: windowExpired ? now : data!.timestamp,
        burstCount: currentBurstCount,
        burstTimestamp: burstExpired ? now : data!.burstTimestamp,
      });

      return true;
    });
  } catch (error) {
    console.error("❌ Rate limit check failed:", error);
    // Fail closed - deny request if rate limit check fails
    return false;
  }
}

interface PlacesSearchRequest {
  query: string;
  proximity?: { lat: number; lng: number };
  types?: string[];
}

/**
 * 🔒 SECURE: Search places using Google Places API (New)
 * Implements autocomplete search with rate limiting, caching, and burst protection
 */
export const placesSearch = onCall({
  region: "us-central1",
  memory: "256MiB",
  timeoutSeconds: 10,
}, async (request) => {
  // Enforce authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const userId = request.auth.uid;
  const data = request.data as PlacesSearchRequest;

  // Validate input early
  if (!data.query || data.query.trim().length < 2) {
    throw new HttpsError("invalid-argument", "Query must be at least 2 characters");
  }

  // Check cache BEFORE rate limiting (saves quota)
  const cacheKey = getCacheKey(data);
  const cachedResult = getFromCache(cacheKey);
  if (cachedResult) {
    console.log(`📦 Cache hit for query: "${data.query}"`);
    return cachedResult;
  }

  // Rate limiting (with burst protection)
  if (!await checkRateLimit(userId, "search")) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many searches. Please wait a few moments and try again."
    );
  }

  try {
    const {query, proximity, types} = data;
    const apiKey = getGooglePlacesKey();

    // Build request body
    const requestBody: any = {
      input: query.trim(),
    };

    if (proximity) {
      requestBody.locationBias = {
        circle: {
          center: {
            latitude: proximity.lat,
            longitude: proximity.lng,
          },
          radius: 50000.0, // 50km radius
        },
      };
    }

    // Only include types if they exist and are valid
    if (types && types.length > 0) {
      const validTypes = types.filter((t) => t && t.length > 0);
      if (validTypes.length > 0) {
        requestBody.includedPrimaryTypes = validTypes;
      }
    }

    console.log(`🔍 Calling Google Places API for: "${query}"`);

    // Call Google Places API (Autocomplete)
    const response = await axios.post(
      `${PLACES_BASE_URL}/places:autocomplete`,
      requestBody,
      {
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask": "suggestions.placePrediction.placeId,suggestions.placePrediction.text",
        },
        timeout: 5000, // 5 second timeout
      }
    );

    // Transform response
    const suggestions = response.data.suggestions || [];
    const predictions = suggestions
      .filter((s: any) => s.placePrediction)
      .map((s: any) => ({
        placeId: s.placePrediction.placeId,
        text: s.placePrediction.text.text,
      }))
      .slice(0, 5); // Limit to 5 results

    const result = {predictions};
    
    // Cache the result
    setCache(cacheKey, result);
    
    console.log(`✅ Search successful: ${predictions.length} results`);
    return result;
  } catch (error: any) {
    // Log detailed error information for debugging
    if (error.response) {
      console.error("❌ Places API error:", {
        status: error.response.status,
        statusText: error.response.statusText,
        data: error.response.data,
        query: data.query,
      });
      
      // Handle Google rate limiting (429)
      if (error.response.status === 429) {
        throw new HttpsError(
          "resource-exhausted",
          "Search service is temporarily busy. Please wait a minute and try again."
        );
      }
      
      // Handle bad requests
      if (error.response.status === 400) {
        throw new HttpsError("invalid-argument", "Invalid search parameters");
      }
    } else {
      console.error("❌ Places search failed:", error.message);
    }
    
    throw new HttpsError("internal", error.message || "Search failed");
  }
});

interface PlaceDetailsRequest {
  placeId: string;
}

/**
 * 🔒 SECURE: Get detailed place information
 */
export const placeDetails = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const userId = request.auth.uid;
  const data = request.data as PlaceDetailsRequest;

  if (!await checkRateLimit(userId, "details")) {
    throw new HttpsError("resource-exhausted", "Rate limit exceeded. Please try again in a few minutes.");
  }

  try {
    const {placeId} = data;
    const apiKey = getGooglePlacesKey();

    if (!placeId) {
      throw new HttpsError("invalid-argument", "Place ID required");
    }

    // Call Google Places API (Place Details)
    const response = await axios.get(
      `${PLACES_BASE_URL}/places/${placeId}`,
      {
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask": "id,displayName,formattedAddress,location,rating,websiteUri,nationalPhoneNumber,types,photos",
        },
      }
    );

    const place = response.data;

    // Transform response to match Flutter expectations
    return {
      placeId: place.id,
      name: place.displayName?.text || "",
      address: place.formattedAddress || null,
      latitude: place.location?.latitude || 0,
      longitude: place.location?.longitude || 0,
      rating: place.rating || null,
      website: place.websiteUri || null,
      phoneNumber: place.nationalPhoneNumber || null,
      types: place.types || [],
      photoReference: place.photos?.[0]?.name || null,
    };
  } catch (error: any) {
    console.error("Place details failed:", error.response?.data || error.message);
    throw new HttpsError("internal", error.message || "Details fetch failed");
  }
});

interface GeocodeRequest {
  address: string;
}

/**
 * 🔒 SECURE: Geocode address to coordinates
 */
export const geocodeAddress = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const userId = request.auth.uid;
  const data = request.data as GeocodeRequest;

  if (!await checkRateLimit(userId, "geocode")) {
    throw new HttpsError("resource-exhausted", "Rate limit exceeded. Please try again in a few minutes.");
  }

  try {
    const {address} = data;
    const apiKey = getGooglePlacesKey();

    if (!address) {
      throw new HttpsError("invalid-argument", "Address required");
    }

    // Call Google Geocoding API
    const response = await axios.get(GEOCODING_URL, {
      params: {
        address,
        key: apiKey,
      },
    });

    if (response.data.status !== "OK" || !response.data.results?.[0]) {
      return {latitude: null, longitude: null};
    }

    const location = response.data.results[0].geometry.location;

    return {
      latitude: location.lat,
      longitude: location.lng,
    };
  } catch (error: any) {
    console.error("Geocode failed:", error.response?.data || error.message);
    throw new HttpsError("internal", error.message || "Geocoding failed");
  }
});

interface PhotoRequest {
  photoReference: string;
  maxWidth: number;
  waypointId: string;
}

/**
 * 🔒 SECURE: Get place photo with Firebase Storage caching
 * Photos are fetched once from Google and cached permanently
 */
export const placePhoto = onCall({
  region: "us-central1",
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const userId = request.auth.uid;
  const data = request.data as PhotoRequest;

  if (!await checkRateLimit(userId, "photo")) {
    throw new HttpsError("resource-exhausted", "Rate limit exceeded. Please try again in a few minutes.");
  }

  try {
    const {photoReference, maxWidth, waypointId} = data;
    const apiKey = getGooglePlacesKey();

    if (!photoReference) {
      throw new HttpsError("invalid-argument", "Photo reference required");
    }

    // Extract photo ID from reference
    const photoId = photoReference.includes("/") ?
      photoReference.split("/").pop() :
      photoReference;

    if (!photoId) {
      throw new HttpsError("invalid-argument", "Invalid photo reference");
    }

    const bucket = getStorage().bucket();
    const filePath = `waypoint-photos/${photoId}.jpg`;
    const file = bucket.file(filePath);

    // Check if already cached
    const [exists] = await file.exists();
    if (exists) {
      const [url] = await file.getSignedUrl({
        action: "read",
        expires: "03-01-2500", // Far future expiry
      });
      return {url};
    }

    // Not cached - fetch from Google Places
    const photoUrl = `${PLACES_BASE_URL}/${photoReference}/media?maxWidthPx=${maxWidth || 800}&key=${apiKey}`;

    const response = await axios.get(photoUrl, {
      responseType: "arraybuffer",
    });

    // Upload to Firebase Storage
    await file.save(Buffer.from(response.data), {
      contentType: "image/jpeg",
      metadata: {
        cacheControl: "public, max-age=31536000", // 1 year cache
        metadata: {
          waypointId: waypointId || "",
          source: "google_places",
        },
      },
    });

    // Make file publicly accessible
    await file.makePublic();

    // Return public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filePath}`;

    return {url: publicUrl};
  } catch (error: any) {
    console.error("Photo fetch failed:", error.response?.data || error.message);
    throw new HttpsError("internal", error.message || "Photo fetch failed");
  }
});
