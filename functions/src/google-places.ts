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

// Rate limiting: 100 requests per hour per user per endpoint
const RATE_LIMIT_MAX = 100;
const RATE_LIMIT_WINDOW = 3600000; // 1 hour in milliseconds

/**
 * Check rate limit for a user on a specific endpoint
 */
async function checkRateLimit(userId: string, endpoint: string): Promise<boolean> {
  const db = getFirestore();
  const now = Date.now();
  const docId = `${userId}_${endpoint}`;
  const rateLimitRef = db.collection("rate_limits").doc(docId);

  try {
    const doc = await rateLimitRef.get();
    const data = doc.data();

    // Check if rate limit exceeded
    if (data && data.count >= RATE_LIMIT_MAX && now - data.timestamp < RATE_LIMIT_WINDOW) {
      return false;
    }

    // Reset or increment counter
    await rateLimitRef.set({
      count: data && now - data.timestamp < RATE_LIMIT_WINDOW ? data.count + 1 : 1,
      timestamp: data && now - data.timestamp < RATE_LIMIT_WINDOW ? data.timestamp : now,
    });

    return true;
  } catch (error) {
    console.error("Rate limit check failed:", error);
    // Allow request if rate limit check fails
    return true;
  }
}

interface PlacesSearchRequest {
  query: string;
  proximity?: { lat: number; lng: number };
  types?: string[];
}

/**
 * 🔒 SECURE: Search places using Google Places API (New)
 * Implements autocomplete search with rate limiting and authentication
 */
export const placesSearch = onCall({
  region: "us-central1",
}, async (request) => {
  // Enforce authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const userId = request.auth.uid;
  const data = request.data as PlacesSearchRequest;

  // Rate limiting
  if (!await checkRateLimit(userId, "search")) {
    throw new HttpsError("resource-exhausted", "Rate limit exceeded. Please try again in a few minutes.");
  }

  try {
    const {query, proximity, types} = data;
    const apiKey = getGooglePlacesKey();

    // Validate input
    if (!query || query.trim().length < 2) {
      throw new HttpsError("invalid-argument", "Query must be at least 2 characters");
    }

    // Build request body
    const requestBody: any = {
      input: query,
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
    // Google Places API (New) has different type names than legacy API
    if (types && types.length > 0) {
      // Filter out any potentially invalid types
      const validTypes = types.filter((t) => t && t.length > 0);
      if (validTypes.length > 0) {
        requestBody.includedPrimaryTypes = validTypes;
      }
    }

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

    return {predictions};
  } catch (error: any) {
    // Log detailed error information for debugging
    if (error.response) {
      console.error("Places API error:", {
        status: error.response.status,
        statusText: error.response.statusText,
        data: error.response.data,
        request: requestBody,
      });
    } else {
      console.error("Places search failed:", error.message);
    }
    
    // Return more helpful error message
    if (error.response?.status === 400) {
      throw new HttpsError("invalid-argument", "Invalid search parameters. Some place types may not be supported.");
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
