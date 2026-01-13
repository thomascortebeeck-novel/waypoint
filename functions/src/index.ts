// Initialize Firebase Admin SDK before any usage of Firestore/Storage
// This fixes: "FirebaseAppError: The default Firebase app does not exist."
import {initializeApp} from "firebase-admin/app";
initializeApp();

import {onCall} from "firebase-functions/v2/https";
export {getDirections, matchRoute, getElevationProfile} from "./mapbox";
export {placesSearch, placeDetails, geocodeAddress, placePhoto} from "./google-places";

// Simple callable function to fetch OpenGraph/Twitter meta tags for a given URL.
// Returns: { title, description, image, siteName }
export const fetchMeta = onCall({region: "us-central1"}, async (request) => {
  try {
    const urlRaw = (request.data && (request.data as any).url) ?? "";
    const url = String(urlRaw).trim();
    if (!url) {
      return {title: null, description: null, image: null, siteName: null};
    }

    const res = await fetch(url, {
      redirect: "follow",
      headers: {
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36",
        "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
    });

    const html = await res.text();

    const pick = (re: RegExp) => (html.match(re)?.[1] || "").trim() || null;
    const get = (name: string) =>
      pick(new RegExp(`<meta[^>]+(?:property|name)=["']${name}["'][^>]*content=["']([^"']*)["']`, "i")) ||
      pick(new RegExp(`<meta[^>]+content=["']([^"']*)["'][^>]*(?:property|name)=["']${name}["']`, "i"));

    const title = get("og:title") || get("twitter:title") || pick(/<title[^>]*>(.*?)<\/title>/is);
    const description = get("og:description") || get("twitter:description") || get("description");
    const image = get("og:image") || get("twitter:image");
    const siteName = get("og:site_name");

    return {title, description, image, siteName};
  } catch (e) {
    console.error("fetchMeta failed", e);
    return {title: null, description: null, image: null, siteName: null};
  }
});