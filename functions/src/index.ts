// Initialize Firebase Admin SDK before any usage of Firestore/Storage
// This fixes: "FirebaseAppError: The default Firebase app does not exist."
import {initializeApp} from "firebase-admin/app";
initializeApp();

import {onCall} from "firebase-functions/v2/https";
export {getDirections, matchRoute, getElevationProfile} from "./mapbox";
export {placesSearch, placeDetails, geocodeAddress, placePhoto} from "./google-places";
export {getOutdoorPOIs} from "./osm-pois";

// Simple callable function to fetch OpenGraph/Twitter meta tags for a given URL.
// Returns: { title, description, image, siteName }
// Uses multiple strategies: direct fetch with browser-like headers, then fallback
export const fetchMeta = onCall({region: "us-central1", timeoutSeconds: 30}, async (request) => {
  const urlRaw = (request.data && (request.data as any).url) ?? "";
  const url = String(urlRaw).trim();
  if (!url) {
    console.log("[fetchMeta] No URL provided");
    return {title: null, description: null, image: null, siteName: null};
  }

  // URL validation & sanitization
  try {
    const urlObj = new URL(url);
    // Only allow http/https protocols
    if (!["http:", "https:"].includes(urlObj.protocol)) {
      console.log("[fetchMeta] Invalid protocol:", urlObj.protocol);
      return {title: null, description: null, image: null, siteName: null};
    }
  } catch {
    console.log("[fetchMeta] Invalid URL format:", url);
    return {title: null, description: null, image: null, siteName: null};
  }

  console.log("[fetchMeta] Fetching:", url);

  // Clean up title (remove redundant location/stars based on site)
  const cleanTitle = (title: string | null, siteName: string | null): string | null => {
    if (!title) return null;

    let cleaned = title;

    // Remove star ratings at the start (★★★★★ or ☆☆☆☆☆)
    cleaned = cleaned.replace(/^[★☆]+\s*/, "");

    // Site-specific cleaning
    const siteNameLower = (siteName || "").toLowerCase();
    
    if (siteNameLower.includes("booking.com") || siteNameLower === "booking.com") {
      // Remove ", City, Country" suffix for booking.com
      // e.g., "Hotel Name, Sevilla, Spanje" → "Hotel Name"
      cleaned = cleaned.replace(/,\s*[^,]+,\s*[^,]+$/, "");
    }

    // Remove trailing star ratings like "(4.5 stars)" or "- 4 stars"
    cleaned = cleaned.replace(/[-–]\s*\d+(\.\d+)?\s*stars?\s*$/i, "");
    cleaned = cleaned.replace(/\(\s*\d+(\.\d+)?\s*stars?\s*\)\s*$/i, "");

    // Remove common suffixes like "| Site Name" or "- Site Name" if site name is known
    if (siteName && cleaned.toLowerCase().endsWith(siteName.toLowerCase())) {
      cleaned = cleaned.replace(new RegExp(`\\s*[-|–]\\s*${siteName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*$`, "i"), "");
    }

    return cleaned.trim();
  };

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

  // Parse HTML for Open Graph meta tags
  const parseHtml = (html: string, sourceUrl: string): {title: string | null, description: string | null, image: string | null, siteName: string | null} => {
    // Multiple regex patterns to handle different meta tag formats
    const metaTags: Map<string, string> = new Map();
    
    // Pattern 1: property/name="..." content="..."
    const pattern1 = /<meta[^>]+(?:property|name)\s*=\s*["']([^"']+)["'][^>]*content\s*=\s*["']([^"']*)["'][^>]*>/gi;
    let match;
    while ((match = pattern1.exec(html)) !== null) {
      const key = match[1].toLowerCase();
      const value = match[2];
      if (value && !metaTags.has(key)) {
        metaTags.set(key, value);
      }
    }
    
    // Pattern 2: content="..." property/name="..." (reversed order)
    const pattern2 = /<meta[^>]+content\s*=\s*["']([^"']*)["'][^>]*(?:property|name)\s*=\s*["']([^"']+)["'][^>]*>/gi;
    while ((match = pattern2.exec(html)) !== null) {
      const key = match[2].toLowerCase();
      const value = match[1];
      if (value && !metaTags.has(key)) {
        metaTags.set(key, value);
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
        const urlObj = new URL(sourceUrl);
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

    // Apply title cleaning based on site
    const cleanedTitle = cleanTitle(title, siteName);

    return {title: cleanedTitle, description, image, siteName};
  };

  // Strategy 1: Direct fetch with browser-like headers
  try {
    console.log("[fetchMeta] Strategy 1: Direct fetch with browser headers");
    const res = await fetch(url, {
      redirect: "follow",
      headers: {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "Sec-Ch-Ua": '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
        "Sec-Ch-Ua-Mobile": "?0",
        "Sec-Ch-Ua-Platform": '"macOS"',
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "none",
        "Sec-Fetch-User": "?1",
        "Upgrade-Insecure-Requests": "1",
      },
    });

    console.log("[fetchMeta] Response status:", res.status);
    
    if (res.ok) {
      const html = await res.text();
      console.log("[fetchMeta] HTML length:", html.length);
      
      const result = parseHtml(html, url);
      
      // If we found meaningful data, return it
      if (result.title || result.description || result.image) {
        console.log("[fetchMeta] ✓ Strategy 1 (Desktop browser) succeeded - title:", result.title, "desc:", result.description?.substring(0, 50), "image:", result.image);
        return {...result, _strategy: 1};
      }
      console.log("[fetchMeta] Strategy 1: No meaningful metadata found in HTML");
    }
  } catch (e) {
    console.log("[fetchMeta] ✗ Strategy 1 failed:", e);
  }

  // Strategy 2: Try with a mobile User-Agent (some sites serve different content)
  try {
    console.log("[fetchMeta] Strategy 2: Mobile User-Agent");
    const res = await fetch(url, {
      redirect: "follow",
      headers: {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
      },
    });

    if (res.ok) {
      const html = await res.text();
      console.log("[fetchMeta] Strategy 2 HTML length:", html.length);
      
      const result = parseHtml(html, url);
      
      if (result.title || result.description || result.image) {
        console.log("[fetchMeta] ✓ Strategy 2 (Mobile User-Agent) succeeded - title:", result.title);
        return {...result, _strategy: 2};
      }
    }
  } catch (e) {
    console.log("[fetchMeta] ✗ Strategy 2 failed:", e);
  }

  // Strategy 3: Try as a bot/crawler (some sites specifically serve OG tags to bots)
  try {
    console.log("[fetchMeta] Strategy 3: Bot/crawler User-Agent");
    const res = await fetch(url, {
      redirect: "follow",
      headers: {
        "User-Agent": "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
        "Accept": "text/html",
      },
    });

    if (res.ok) {
      const html = await res.text();
      console.log("[fetchMeta] Strategy 3 HTML length:", html.length);
      
      const result = parseHtml(html, url);
      
      if (result.title || result.description || result.image) {
        console.log("[fetchMeta] ✓ Strategy 3 (Facebook bot) succeeded - title:", result.title);
        return {...result, _strategy: 3};
      }
    }
  } catch (e) {
    console.log("[fetchMeta] ✗ Strategy 3 failed:", e);
  }

  // Strategy 4: Construct title from URL as last resort
  try {
    console.log("[fetchMeta] Strategy 4: Extract from URL");
    const urlObj = new URL(url);
    const hostname = urlObj.hostname.replace("www.", "");
    const pathParts = urlObj.pathname.split("/").filter((p) => p && p.length > 2);
    
    // Try to build a readable title from path
    let title = hostname;
    if (pathParts.length > 0) {
      // Use the last meaningful path segment
      const lastSegment = pathParts[pathParts.length - 1]
        .replace(/[-_]/g, " ")
        .replace(/\.(html?|php|aspx?)$/i, "")
        .replace(/\b\w/g, (l) => l.toUpperCase());
      if (lastSegment.length > 3) {
        title = lastSegment;
      }
    }
    
    console.log("[fetchMeta] ✓ Strategy 4 (URL parsing fallback) used - title:", title);
    return {
      title: title,
      description: `Link from ${hostname}`,
      image: null,
      siteName: hostname,
      _strategy: 4,
    };
  } catch (e) {
    console.log("[fetchMeta] ✗ Strategy 4 failed:", e);
  }

  console.log("[fetchMeta] All strategies failed");
  return {title: null, description: null, image: null, siteName: null};
});
