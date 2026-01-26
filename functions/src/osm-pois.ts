import axios from "axios";
import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

/**
 * Fetches outdoor Points of Interest (POIs) from OpenStreetMap via Overpass API
 * 
 * Supported POI types:
 * - campsite: tourism=camp_site
 * - hut: tourism=wilderness_hut or alpine_hut
 * - viewpoint: tourism=viewpoint
 * - water: amenity=drinking_water or natural=spring
 * - shelter: amenity=shelter
 * - parking: amenity=parking (excluding private)
 * - trailhead: highway=trailhead
 * - picnicSite: tourism=picnic_site
 * - toilets: amenity=toilets
 * - informationBoard: tourism=information + information=board
 * - peakSummit: natural=peak
 * - waterfall: natural=waterfall
 * - cave: natural=cave_entrance
 * - bench: amenity=bench
 * - rangerStation: amenity=ranger_station
 * - emergencyPhone: emergency=phone
 * - guidepost: information=guidepost
 * 
 * Returns GeoJSON FeatureCollection with Point features
 */
export const getOutdoorPOIs = onCall(
  {region: "europe-west1", cors: true, timeoutSeconds: 30},
  async (request) => {
    try {
      const data = (request.data || {}) as any;
      const bounds = data.bounds as {south: number; west: number; north: number; east: number};
      const poiTypes = (data.poiTypes || []) as string[];
      const maxResults = Number(data.maxResults ?? 500);

      // Validate inputs
      if (!bounds || typeof bounds.south !== "number" || typeof bounds.north !== "number") {
        logger.warn("getOutdoorPOIs: invalid bounds", bounds);
        return {error: "bounds_invalid", features: []};
      }
      if (!Array.isArray(poiTypes) || poiTypes.length === 0) {
        logger.warn("getOutdoorPOIs: no POI types specified");
        return {error: "poi_types_required", features: []};
      }

      // Check bounds size (prevent queries > 100km²)
      const latDiff = Math.abs(bounds.north - bounds.south);
      const lngDiff = Math.abs(bounds.east - bounds.west);
      const approxAreaKm2 = latDiff * lngDiff * 111 * 111; // rough approximation
      if (approxAreaKm2 > 10000) { // 100x100 km
        logger.warn("getOutdoorPOIs: bounds too large", {approxAreaKm2});
        return {error: "bounds_too_large", features: []};
      }

      // Build Overpass query
      const query = buildOverpassQuery(bounds, poiTypes, maxResults);
      logger.info("getOutdoorPOIs: query built", {
        types: poiTypes,
        bounds: `${bounds.south.toFixed(3)},${bounds.west.toFixed(3)} to ${bounds.north.toFixed(3)},${bounds.east.toFixed(3)}`,
      });

      // Fetch from Overpass API with fallback
      const osmData = await fetchWithFallback(query);
      
      // Transform to GeoJSON
      const geojson = osmToGeoJSON(osmData);
      
      logger.info("getOutdoorPOIs: success", {
        resultCount: geojson.features.length,
        types: poiTypes,
      });

      return geojson;
    } catch (e: any) {
      logger.error("getOutdoorPOIs failed", e);
      if (e.response?.status === 429) {
        return {error: "rate_limited", features: []};
      }
      if (e.code === "ECONNABORTED" || e.message?.includes("timeout")) {
        return {error: "timeout", features: []};
      }
      return {error: "request_failed", features: []};
    }
  }
);

/**
 * Build Overpass QL query for requested POI types
 */
function buildOverpassQuery(
  bounds: {south: number; west: number; north: number; east: number},
  poiTypes: string[],
  limit: number
): string {
  // Map POI types to OSM tag queries
  const tagMap: Record<string, string> = {
    campsite: 'node["tourism"="camp_site"]',
    hut: 'node["tourism"~"wilderness_hut|alpine_hut"]',
    viewpoint: 'node["tourism"="viewpoint"]',
    water: '(node["amenity"="drinking_water"];node["natural"="spring"];)',
    shelter: 'node["amenity"="shelter"]',
    parking: 'node["amenity"="parking"]["access"!="private"]',
    trailhead: 'node["highway"="trailhead"]',
    picnicSite: 'node["tourism"="picnic_site"]',
    toilets: 'node["amenity"="toilets"]',
    informationBoard: 'node["tourism"="information"]["information"="board"]',
    peakSummit: 'node["natural"="peak"]',
    waterfall: 'node["natural"="waterfall"]',
    cave: 'node["natural"="cave_entrance"]',
    bench: 'node["amenity"="bench"]',
    rangerStation: 'node["amenity"="ranger_station"]',
    emergencyPhone: 'node["emergency"="phone"]',
    guidepost: 'node["information"="guidepost"]',
  };

  const bbox = `${bounds.south},${bounds.west},${bounds.north},${bounds.east}`;
  
  // Build node queries for each requested type
  const nodeQueries = poiTypes
    .filter((type) => tagMap[type]) // only include known types
    .map((type) => {
      const query = tagMap[type];
      // Add bbox to each query part
      if (query.startsWith("(")) {
        // Multiple queries wrapped in parentheses
        return query.replace(/node\[/g, `node[`).replace(/\];/g, `](${bbox});`);
      }
      return `${query}(${bbox});`;
    })
    .join("\n  ");

  return `
[out:json][timeout:25];
(
  ${nodeQueries}
);
out body qt ${limit};
  `.trim();
}

/**
 * Fetch from Overpass API with multiple endpoint fallbacks
 */
async function fetchWithFallback(query: string): Promise<any> {
  const endpoints = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.openstreetmap.fr/api/interpreter",
  ];

  let lastError: any;
  for (const endpoint of endpoints) {
    try {
      logger.info(`Trying Overpass endpoint: ${endpoint}`);
      const resp = await axios.post(
        endpoint,
        `data=${encodeURIComponent(query)}`,
        {
          headers: {"Content-Type": "application/x-www-form-urlencoded"},
          timeout: 25000,
        }
      );
      logger.info(`Overpass endpoint ${endpoint} succeeded`);
      return resp.data;
    } catch (e: any) {
      logger.warn(`Overpass endpoint ${endpoint} failed:`, e.message);
      lastError = e;
      // If it's the last endpoint, throw the error
      if (endpoint === endpoints[endpoints.length - 1]) {
        throw lastError;
      }
      // Otherwise try next endpoint
    }
  }
  throw lastError;
}

/**
 * Transform OSM data to GeoJSON FeatureCollection
 */
function osmToGeoJSON(osmData: any): any {
  const elements = osmData.elements || [];
  
  const features = elements
    .filter((element: any) => element.lat && element.lon) // only include nodes with coords
    .map((element: any) => {
      const poiType = detectPOIType(element.tags || {});
      const name = element.tags?.name || 
                   element.tags?.["name:en"] || 
                   element.tags?.["name:sv"] ||
                   "Unnamed";
      
      return {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [element.lon, element.lat], // [lng, lat] for GeoJSON
        },
        properties: {
          id: element.id.toString(),
          type: poiType,
          name: name,
          description: element.tags?.description || element.tags?.note || "",
          tags: element.tags || {},
        },
      };
    });

  return {
    type: "FeatureCollection",
    features,
  };
}

/**
 * Detect POI type from OSM tags
 */
function detectPOIType(tags: Record<string, string>): string {
  if (tags.tourism === "camp_site") return "campsite";
  if (tags.tourism === "wilderness_hut" || tags.tourism === "alpine_hut") return "hut";
  if (tags.tourism === "viewpoint") return "viewpoint";
  if (tags.amenity === "drinking_water" || tags.natural === "spring") return "water";
  if (tags.amenity === "shelter") return "shelter";
  if (tags.amenity === "parking") return "parking";
  if (tags.highway === "trailhead") return "trailhead";
  if (tags.tourism === "picnic_site") return "picnicSite";
  if (tags.amenity === "toilets") return "toilets";
  if (tags.tourism === "information" && tags.information === "board") return "informationBoard";
  if (tags.natural === "peak") return "peakSummit";
  if (tags.natural === "waterfall") return "waterfall";
  if (tags.natural === "cave_entrance") return "cave";
  if (tags.amenity === "bench") return "bench";
  if (tags.amenity === "ranger_station") return "rangerStation";
  if (tags.emergency === "phone") return "emergencyPhone";
  if (tags.information === "guidepost") return "guidepost";
  return "other";
}
