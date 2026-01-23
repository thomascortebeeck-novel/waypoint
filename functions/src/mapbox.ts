import axios from "axios";
import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {defineString} from "firebase-functions/params";
import {PNG} from "pngjs";

// Prefer runtime param, fallback to functions:config() for older setups
const MAPBOX_TOKEN_PARAM = defineString("MAPBOX_SECRET_TOKEN");

// Callable function version (for Flutter SDK)
export const getDirections = onCall({region: "europe-west1", cors: true}, async (request) => {
  try {
    const data = (request.data || {}) as any;
    const waypoints = (data.waypoints || []) as Array<{lat: number; lng: number}>;
    const profile = (data.profile || "walking") as string;
    if (!Array.isArray(waypoints) || waypoints.length < 2) {
      return {error: "need at least two waypoints"};
    }
    const coords = waypoints.map((w) => `${w.lng},${w.lat}`).join(";");
    const token = MAPBOX_TOKEN_PARAM.value() || (process.env.MAPBOX_SECRET_TOKEN as string) || (process.env.MAPBOX_TOKEN as string) || "";
    const url = `https://api.mapbox.com/directions/v5/mapbox/${encodeURIComponent(profile)}/${coords}`;
    const params = {
      access_token: token,
      geometries: "geojson",
      overview: "full",
      steps: true,
      annotations: "distance,duration",
      // enable trail-aware walking/terrain routing when available
      // alternatives: false,
    } as Record<string, any>;
    const resp = await axios.get(url, {params});
    const route = resp.data?.routes?.[0];
    if (!route) return {error: "no_route"};
    return route; // includes geometry, distance, duration, legs
  } catch (e) {
    logger.error("getDirections failed", e);
    return {error: "request_failed"};
  }
});

// Callable function version (for Flutter SDK)
export const matchRoute = onCall({region: "europe-west1", cors: true}, async (request) => {
  try {
    const data = (request.data || {}) as any;
    const points = (data.points || []) as Array<{lat: number; lng: number}>;
    const snapToTrail = Boolean(data.snapToTrail ?? true);
    const profile = (data.profile || "walking") as string;
    if (!Array.isArray(points) || points.length < 2) {
      return {error: "need at least two points"};
    }
    if (!snapToTrail) {
      return {
        geometry: {type: "LineString", coordinates: points.map((p) => [p.lng, p.lat])},
        distance: null,
        duration: null,
      };
    }
    const token = MAPBOX_TOKEN_PARAM.value() || (process.env.MAPBOX_SECRET_TOKEN as string) || (process.env.MAPBOX_TOKEN as string) || "";
    const coords = points.map((p) => `${p.lng},${p.lat}`).join(";");
    const url = `https://api.mapbox.com/matching/v5/mapbox/${encodeURIComponent(profile)}/${coords}`;
    const params = {
      access_token: token,
      geometries: "geojson",
      tidy: true,
      annotations: "distance,duration",
    } as Record<string, any>;
    const resp = await axios.get(url, {params});
    const match = resp.data?.matchings?.[0];
    if (!match) return {error: "no_match"};
    return match; // includes geometry, distance, duration
  } catch (e) {
    logger.error("matchRoute failed", e);
    return {error: "request_failed"};
  }
});

// Converts lat/lng to XYZ tile coords at a given zoom.
function latLngToTile(lat: number, lng: number, zoom: number) {
  const latRad = (lat * Math.PI) / 180;
  const n = Math.pow(2, zoom);
  const xTile = Math.floor(((lng + 180) / 360) * n);
  const yTile = Math.floor((1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2 * n);
  return {x: xTile, y: yTile};
}

// Converts lat/lng to pixel coords inside a tile (0..255)
function latLngToPixelInTile(lat: number, lng: number, zoom: number, xTile: number, yTile: number) {
  const latRad = (lat * Math.PI) / 180;
  const n = Math.pow(2, zoom);
  const worldX = ((lng + 180) / 360) * n * 256;
  const worldY = (1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2 * n * 256;
  const px = Math.floor(worldX - xTile * 256);
  const py = Math.floor(worldY - yTile * 256);
  return {px, py};
}

function rgbToElevation(r: number, g: number, b: number) {
  return -10000 + ((r * 256 * 256 + g * 256 + b) * 0.1);
}

function haversineMeters(a: [number, number], b: [number, number]) {
  const toRad = (d: number) => d * Math.PI / 180;
  const R = 6371000; // meters
  const dLat = toRad(b[1] - a[1]);
  const dLon = toRad(b[0] - a[0]);
  const lat1 = toRad(a[1]);
  const lat2 = toRad(b[1]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// Callable function version (for Flutter SDK)
export const getElevationProfile = onCall({region: "europe-west1", timeoutSeconds: 120, cors: true}, async (request) => {
  try {
    const data = (request.data || {}) as any;
    const coords = (data.coordinates || []) as Array<[number, number]>; // [lng, lat]
    if (!Array.isArray(coords) || coords.length < 2) return {elevations: [], ascent: 0, descent: 0};

    const token = MAPBOX_TOKEN_PARAM.value() || (process.env.MAPBOX_SECRET_TOKEN as string) || (process.env.MAPBOX_TOKEN as string) || "";
    const zoom = Number(data.zoom ?? 15);
    const sampleEveryMeters = Number(data.sampleEveryMeters ?? 50);

    // Build a sampled path approximately every ~sampleEveryMeters
    const sampled: Array<[number, number]> = [];
    let accum = 0;
    sampled.push(coords[0]);
    for (let i = 1; i < coords.length; i++) {
      const prev = coords[i - 1];
      const cur = coords[i];
      const seg = haversineMeters(prev, cur);
      accum += seg;
      if (accum >= sampleEveryMeters) {
        sampled.push(cur);
        accum = 0;
      }
    }
    if (sampled[sampled.length - 1] !== coords[coords.length - 1]) sampled.push(coords[coords.length - 1]);

    // Cache tiles to avoid repeated fetches
    const tileCache = new Map<string, PNG>();
    async function fetchTile(x: number, y: number, z: number): Promise<PNG> {
      const key = `${z}/${x}/${y}`;
      const cached = tileCache.get(key);
      if (cached) return cached;
      const url = `https://api.mapbox.com/v4/mapbox.terrain-rgb/${z}/${x}/${y}.pngraw?access_token=${encodeURIComponent(token)}`;
      const resp = await axios.get<ArrayBuffer>(url, {responseType: "arraybuffer"});
      const png = PNG.sync.read(Buffer.from(resp.data));
      tileCache.set(key, png);
      return png;
    }

    const elevations: Array<{distance: number; elevation: number}> = [];
    let distanceAccum = 0;
    let last = sampled[0];
    for (let i = 0; i < sampled.length; i++) {
      const [lng, lat] = sampled[i];
      const {x, y} = latLngToTile(lat, lng, zoom);
      const {px, py} = latLngToPixelInTile(lat, lng, zoom, x, y);
      const tile = await fetchTile(x, y, zoom);
      const idx = (py * tile.width + px) * 4; // RGBA
      const r = tile.data[idx];
      const g = tile.data[idx + 1];
      const b = tile.data[idx + 2];
      const elevation = rgbToElevation(r, g, b);
      if (i > 0) distanceAccum += haversineMeters(last, sampled[i]);
      elevations.push({distance: distanceAccum, elevation});
      last = sampled[i];
    }

    // Compute ascent/descent
    let ascent = 0;
    let descent = 0;
    for (let i = 1; i < elevations.length; i++) {
      const diff = elevations[i].elevation - elevations[i - 1].elevation;
      if (diff > 0) ascent += diff; else descent += Math.abs(diff);
    }

    return {elevations, ascent, descent};
  } catch (e) {
    logger.error("getElevationProfile failed", e);
    return {elevations: [], ascent: 0, descent: 0};
  }
});
