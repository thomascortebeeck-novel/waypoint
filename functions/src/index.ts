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
      console.log("[fetchMeta] No URL provided");
      return {title: null, description: null, image: null, siteName: null};
    }

    console.log("[fetchMeta] Fetching:", url);

    const res = await fetch(url, {
      redirect: "follow",
      headers: {
        "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "accept-language": "en-US,en;q=0.9",
        "cache-control": "no-cache",
        "pragma": "no-cache",
      },
    });

    console.log("[fetchMeta] Response status:", res.status);
    
    const html = await res.text();
    console.log("[fetchMeta] HTML length:", html.length);

    // Decode common HTML entities
    const decodeEntities = (str: string | null): string | null => {
      if (!str) return null;
      return str
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&apos;/g, "'")
        .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
        .replace(/&#(\d+);/g, (_, dec) => String.fromCharCode(parseInt(dec, 10)))
        .trim();
    };

    // Extract all meta tags for parsing
    const metaTagRegex = /<meta\s+([^>]*)>/gi;
    const metaTags: Map<string, string> = new Map();
    
    let match;
    while ((match = metaTagRegex.exec(html)) !== null) {
      const attrs = match[1];
      
      // Extract property or name attribute
      const propMatch = attrs.match(/(?:property|name)\s*=\s*["']([^"']+)["']/i);
      const contentMatch = attrs.match(/content\s*=\s*["']([^"']*)["']/i);
      
      if (propMatch && contentMatch) {
        const key = propMatch[1].toLowerCase();
        const value = contentMatch[1];
        if (value && !metaTags.has(key)) {
          metaTags.set(key, value);
        }
      }
    }

    console.log("[fetchMeta] Found meta tags:", Array.from(metaTags.keys()).join(", "));

    // Extract <title> tag as fallback
    const titleMatch = html.match(/<title[^>]*>([^<]*)<\/title>/i);
    const pageTitle = titleMatch ? titleMatch[1].trim() : null;

    // Build result with priority order
    const title = decodeEntities(
      metaTags.get("og:title") || 
      metaTags.get("twitter:title") || 
      pageTitle
    );
    
    const description = decodeEntities(
      metaTags.get("og:description") || 
      metaTags.get("twitter:description") || 
      metaTags.get("description")
    );
    
    let image = metaTags.get("og:image") || metaTags.get("twitter:image") || null;
    
    // Handle relative image URLs
    if (image && !image.startsWith("http")) {
      try {
        const urlObj = new URL(url);
        if (image.startsWith("//")) {
          image = urlObj.protocol + image;
        } else if (image.startsWith("/")) {
          image = urlObj.origin + image;
        } else {
          image = urlObj.origin + "/" + image;
        }
      } catch {
        // Keep as is if URL parsing fails
      }
    }
    
    const siteName = decodeEntities(
      metaTags.get("og:site_name") || 
      metaTags.get("application-name")
    );

    console.log("[fetchMeta] Extracted - title:", title, "desc:", description?.substring(0, 50), "image:", image);

    return {title, description, image, siteName};
  } catch (e) {
    console.error("[fetchMeta] Error:", e);
    return {title: null, description: null, image: null, siteName: null};
  }
});
