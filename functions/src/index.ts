// Initialize Firebase Admin SDK before any usage of Firestore/Storage
// This fixes: "FirebaseAppError: The default Firebase app does not exist."
import {initializeApp} from "firebase-admin/app";
initializeApp();

import {onCall} from "firebase-functions/v2/https";
export {getDirections, matchRoute, getElevationProfile, geocodeAddressMapbox} from "./mapbox";
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
    return {title: null, description: null, image: null, siteName: null, latitude: null, longitude: null, address: null};
  }

  // URL validation & sanitization
  try {
    const urlObj = new URL(url);
    // Only allow http/https protocols
    if (!["http:", "https:"].includes(urlObj.protocol)) {
      console.log("[fetchMeta] Invalid protocol:", urlObj.protocol);
      return {title: null, description: null, image: null, siteName: null, latitude: null, longitude: null, address: null};
    }
  } catch {
    console.log("[fetchMeta] Invalid URL format:", url);
    return {title: null, description: null, image: null, siteName: null, latitude: null, longitude: null, address: null};
  }

  console.log("[fetchMeta] Processing URL:", url);

  // Strategy 0: URL Parsing - Extract data from URL structure (safety fallback)
  const parseUrlForMetadata = (urlString: string): {
    title: string | null, 
    description: string | null, 
    image: string | null, 
    siteName: string | null,
    latitude: number | null,
    longitude: number | null,
    address: {
      street?: string;
      locality?: string;
      region?: string;
      postalCode?: string;
      country?: string;
      formatted?: string;
    } | null
  } => {
    try {
      const urlObj = new URL(urlString);
      const hostname = urlObj.hostname.toLowerCase();
      let title: string | null = null;
      let siteName: string | null = null;

      // Booking.com hotel URL parsing
      // Example: https://www.booking.com/hotel/se/stf-abisko.nl.html
      // Path: /hotel/se/stf-abisko.nl.html
      // pathParts: ["hotel", "se", "stf-abisko.nl.html"]
      if (hostname.includes("booking.com")) {
        siteName = "Booking.com";
        const pathParts = urlObj.pathname.split("/").filter(p => p && p.length > 0);
        
        // Find the segment that ends with .html (this is the hotel identifier)
        // NOT the segment after "hotel" (that's the country code!)
        const htmlSegment = pathParts.find(p => p.endsWith(".html"));
        if (htmlSegment) {
          // Remove language code and .html suffix
          // "stf-abisko.nl.html" → "stf-abisko"
          // "hotel-name.en-gb.html" → "hotel-name"
          const hotelId = htmlSegment
            .replace(/\.[a-z]{2}(-[a-z]{2})?\.html$/i, "")  // Remove .nl.html, .en-gb.html, etc.
            .replace(/\.html$/i, "");  // Fallback: just remove .html
          
          if (hotelId && hotelId.length > 2) {
            // Convert to readable name: "stf-abisko" → "STF Abisko"
            title = hotelId
              .split("-")
              .map(word => word.charAt(0).toUpperCase() + word.slice(1))
              .join(" ");
            
            // Handle common abbreviations
            title = title.replace(/\bStf\b/g, "STF");
            title = title.replace(/\bHtl\b/gi, "Hotel");
            
            console.log("[fetchMeta] Strategy 0: Extracted title from Booking.com URL:", title);
          }
        }
      }

      return {title, description: null, image: null, siteName, latitude: null, longitude: null, address: null};
    } catch (e) {
      console.log("[fetchMeta] Strategy 0: URL parsing failed:", e);
      return {title: null, description: null, image: null, siteName: null, latitude: null, longitude: null, address: null};
    }
  };

  // Get Strategy 0 data as fallback
  const strategy0Data = parseUrlForMetadata(url);

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

  // Parse HTML for Open Graph meta tags and location data
  const parseHtml = (html: string, sourceUrl: string): {
    title: string | null, 
    description: string | null, 
    image: string | null, 
    siteName: string | null,
    latitude: number | null,
    longitude: number | null,
    address: {
      street?: string;
      locality?: string;
      region?: string;
      postalCode?: string;
      country?: string;
      formatted?: string;
    } | null
  } => {
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

    // Try to extract JSON-LD structured data (used by many sites including Booking.com)
    let jsonLdData: any = null;
    try {
      const jsonLdMatches = html.match(/<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi);
      if (jsonLdMatches) {
        for (const match of jsonLdMatches) {
          try {
            const jsonContent = match.replace(/<script[^>]*>/, "").replace(/<\/script>/, "").trim();
            const parsed = JSON.parse(jsonContent);
            // Handle both single objects and arrays
            const data = Array.isArray(parsed) ? parsed[0] : parsed;
            if (data && (data["@type"] === "Hotel" || data["@type"] === "LodgingBusiness" || data.name)) {
              jsonLdData = data;
              console.log("[fetchMeta] Found JSON-LD data:", data["@type"], data.name);
              break;
            }
          } catch (e) {
            // Skip invalid JSON
          }
        }
      }
    } catch (e) {
      // JSON-LD parsing failed, continue with meta tags
    }

    // Extract <title> tag as fallback
    const titleMatch = html.match(/<title[^>]*>([^<]*)<\/title>/i);
    const pageTitle = titleMatch ? titleMatch[1].trim() : null;

    // Build result with priority order (JSON-LD takes precedence for structured data)
    const title = decodeEntities(
      jsonLdData?.name ||
      metaTags.get("og:title") || 
      metaTags.get("twitter:title") || 
      pageTitle
    );
    
    const description = decodeEntities(
      jsonLdData?.description ||
      metaTags.get("og:description") || 
      metaTags.get("twitter:description") || 
      metaTags.get("description")
    );
    
    let image = jsonLdData?.image || 
                (typeof jsonLdData?.image === "object" && jsonLdData?.image?.url ? jsonLdData.image.url : null) ||
                metaTags.get("og:image") || 
                metaTags.get("twitter:image") || 
                null;
    
    // Decode HTML entities in image URL
    if (image) {
      image = decodeEntities(image);
    }
    
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

    // Filter out low-quality descriptions
    const filterDescription = (desc: string | null): string | null => {
      if (!desc) return null;
      
      const trimmed = desc.trim();
      
      // Skip if description is too short
      if (trimmed.length < 20) {
        console.log("[fetchMeta] Filtering description (too short):", trimmed.substring(0, 50));
        return null;
      }
      
      // Skip if description is mostly punctuation/special characters
      const letterCount = (trimmed.match(/[a-zA-Z]/g) || []).length;
      if (letterCount < trimmed.length * 0.3) {
        console.log("[fetchMeta] Filtering description (mostly punctuation):", trimmed.substring(0, 50));
        return null;
      }
      
      // Skip if description starts with warning/note patterns
      const lowerTrimmed = trimmed.toLowerCase();
      if (lowerTrimmed.startsWith("let op:") || 
          lowerTrimmed.startsWith("note:") || 
          lowerTrimmed.startsWith("warning:") ||
          lowerTrimmed.startsWith("attention:") ||
          lowerTrimmed.startsWith("important:")) {
        console.log("[fetchMeta] Filtering description (warning/note pattern):", trimmed.substring(0, 50));
        return null;
      }
      
      // Skip if description looks like a disclaimer or terms text
      if (lowerTrimmed.includes("terms and conditions") ||
          lowerTrimmed.includes("privacy policy") ||
          lowerTrimmed.startsWith("by using") ||
          lowerTrimmed.startsWith("please note")) {
        console.log("[fetchMeta] Filtering description (disclaimer pattern):", trimmed.substring(0, 50));
        return null;
      }
      
      return trimmed;
    };

    const filteredDescription = filterDescription(description);

    // Extract location data from JSON-LD and meta tags
    let latitude: number | null = null;
    let longitude: number | null = null;
    let address: {
      street?: string;
      locality?: string;
      region?: string;
      postalCode?: string;
      country?: string;
      formatted?: string;
    } | null = null;

    // Priority 1: Extract from JSON-LD structured data (schema.org)
    if (jsonLdData) {
      // Check for geo coordinates (schema.org/GeoCoordinates)
      if (jsonLdData.geo) {
        if (typeof jsonLdData.geo.latitude === "number") latitude = jsonLdData.geo.latitude;
        if (typeof jsonLdData.geo.longitude === "number") longitude = jsonLdData.geo.longitude;
        // Also check for string format
        if (!latitude && typeof jsonLdData.geo.latitude === "string") {
          const lat = parseFloat(jsonLdData.geo.latitude);
          if (!isNaN(lat)) latitude = lat;
        }
        if (!longitude && typeof jsonLdData.geo.longitude === "string") {
          const lng = parseFloat(jsonLdData.geo.longitude);
          if (!isNaN(lng)) longitude = lng;
        }
      }

      // Check for PostalAddress (schema.org/PostalAddress)
      if (jsonLdData.address) {
        const addr: any = typeof jsonLdData.address === "string" ? {streetAddress: jsonLdData.address} : jsonLdData.address;
        address = {
          street: addr.streetAddress || addr.addressLocality || undefined,
          locality: addr.addressLocality || undefined,
          region: addr.addressRegion || addr.addressState || undefined,
          postalCode: addr.postalCode || undefined,
          country: addr.addressCountry || (typeof addr.addressCountry === "object" ? addr.addressCountry?.name : undefined) || undefined,
          formatted: addr.streetAddress || addr.addressLocality || (typeof jsonLdData.address === "string" ? jsonLdData.address : undefined),
        };
        // Build formatted address if not provided
        if (!address.formatted && (address.street || address.locality)) {
          const parts: string[] = [];
          if (address.street) parts.push(address.street);
          if (address.locality) parts.push(address.locality);
          if (address.region) parts.push(address.region);
          if (address.postalCode) parts.push(address.postalCode);
          if (address.country) parts.push(address.country);
          address.formatted = parts.join(", ");
        }
      }
    }

    // Priority 2: Extract from meta tags (place:location, geo.position, ICBM)
    if (!latitude || !longitude) {
      // place:location:latitude / place:location:longitude (Facebook/Open Graph)
      const placeLat = metaTags.get("place:location:latitude");
      const placeLng = metaTags.get("place:location:longitude");
      if (placeLat && placeLng) {
        const lat = parseFloat(placeLat);
        const lng = parseFloat(placeLng);
        if (!isNaN(lat) && !isNaN(lng)) {
          latitude = lat;
          longitude = lng;
        }
      }

      // geo.position (format: "lat;lng")
      if (!latitude || !longitude) {
        const geoPos = metaTags.get("geo.position");
        if (geoPos) {
          const parts = geoPos.split(";");
          if (parts.length === 2) {
            const lat = parseFloat(parts[0].trim());
            const lng = parseFloat(parts[1].trim());
            if (!isNaN(lat) && !isNaN(lng)) {
              latitude = lat;
              longitude = lng;
            }
          }
        }
      }

      // ICBM (older format: "lat, lng")
      if (!latitude || !longitude) {
        const icbm = metaTags.get("icbm");
        if (icbm) {
          const parts = icbm.split(",");
          if (parts.length === 2) {
            const lat = parseFloat(parts[0].trim());
            const lng = parseFloat(parts[1].trim());
            if (!isNaN(lat) && !isNaN(lng)) {
              latitude = lat;
              longitude = lng;
            }
          }
        }
      }
    }

    // Log location extraction results
    if (latitude && longitude) {
      console.log("[fetchMeta] Extracted coordinates:", latitude, longitude);
    }
    if (address && address.formatted) {
      console.log("[fetchMeta] Extracted address:", address.formatted);
    }

    return {title: cleanedTitle, description: filteredDescription, image, siteName, latitude, longitude, address};
  };

  // Track best result so far (accumulate across strategies)
  let bestResult: {
    title: string | null, 
    description: string | null, 
    image: string | null, 
    siteName: string | null,
    latitude: number | null,
    longitude: number | null,
    address: {
      street?: string;
      locality?: string;
      region?: string;
      postalCode?: string;
      country?: string;
      formatted?: string;
    } | null,
    _strategy: number
  } = {
    ...strategy0Data,
    latitude: null,
    longitude: null,
    address: null,
    _strategy: 0
  };

  // Helper to merge results (prefer non-null values, keep best)
  const mergeResults = (
    current: typeof bestResult, 
    newData: {
      title: string | null, 
      description: string | null, 
      image: string | null, 
      siteName: string | null,
      latitude: number | null,
      longitude: number | null,
      address: {
        street?: string;
        locality?: string;
        region?: string;
        postalCode?: string;
        country?: string;
        formatted?: string;
      } | null
    }, 
    strategy: number
  ) => {
    const merged = {...current};
    // Prefer fetched title over URL-parsed title (usually more accurate)
    if (newData.title && newData.title.length > 3) {
      merged.title = newData.title;
      merged._strategy = strategy;
    }
    if (newData.description && !merged.description) {
      merged.description = newData.description;
    }
    // Always prefer an image if we find one
    if (newData.image && !merged.image) {
      merged.image = newData.image;
      if (!merged.title) merged._strategy = strategy;
    }
    if (newData.siteName && !merged.siteName) {
      merged.siteName = newData.siteName;
    }
    // Always prefer coordinates if we find them (more reliable than address alone)
    if (newData.latitude != null && newData.longitude != null) {
      merged.latitude = newData.latitude;
      merged.longitude = newData.longitude;
    }
    // Prefer address if we don't have one yet, or if new one is more complete
    if (newData.address && (!merged.address || (!merged.address.formatted && newData.address.formatted))) {
      merged.address = newData.address;
    }
    return merged;
  };

  // Strategy 1: Direct fetch with browser-like headers (attempt to get og:image)
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
    
    const html = await res.text();
    const htmlLength = html.length;
    console.log("[fetchMeta] HTML length:", htmlLength);
    
    // Check for bot detection / blocking responses
    const isBlocked = res.status === 202 || res.status === 403 || htmlLength < 5000;
    
    if (isBlocked) {
      console.log("[fetchMeta] Strategy 1: Blocked or insufficient content (status:", res.status, ", length:", htmlLength, "), will try other strategies");
      // Still try to extract any image from the blocked response
      if (htmlLength > 100) {
        const imageMatch = html.match(/<meta[^>]+property=["']og:image["'][^>]*content=["']([^"']+)["']/i) ||
                           html.match(/<meta[^>]+content=["']([^"']+)["'][^>]*property=["']og:image["']/i);
        if (imageMatch && imageMatch[1]) {
          const image = decodeEntities(imageMatch[1]);
          console.log("[fetchMeta] Found og:image in blocked response:", image);
          bestResult.image = image;
        }
      }
      // DON'T return early - continue to try other strategies!
    } else if (res.ok) {
      const result = parseHtml(html, url);
      
      if (result.title || result.description || result.image) {
        console.log("[fetchMeta] ✓ Strategy 1 (Desktop browser) succeeded - title:", result.title, "image:", result.image ? "yes" : "no");
        bestResult = mergeResults(bestResult, result, 1);
        
        // If we have complete data (title + image), we're done
        if (bestResult.title && bestResult.image) {
          return bestResult;
        }
      }
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

    if (res.ok || res.status === 202) {
      const html = await res.text();
      console.log("[fetchMeta] Strategy 2 HTML length:", html.length);
      
      if (html.length > 3000) {
        const result = parseHtml(html, url);
        
        if (result.title || result.description || result.image) {
          console.log("[fetchMeta] ✓ Strategy 2 (Mobile User-Agent) found data - title:", result.title, "image:", result.image ? "yes" : "no");
          bestResult = mergeResults(bestResult, result, 2);
          
          // If we have complete data, we're done
          if (bestResult.title && bestResult.image) {
            return bestResult;
          }
        }
      }
    }
  } catch (e) {
    console.log("[fetchMeta] ✗ Strategy 2 failed:", e);
  }

  // Strategy 3: Try as Facebook bot/crawler (sites often serve OG tags to social crawlers)
  // This is KEY for sites like Booking.com that block regular requests but serve OG to Facebook!
  try {
    console.log("[fetchMeta] Strategy 3: Facebook bot User-Agent (social crawler)");
    const res = await fetch(url, {
      redirect: "follow",
      headers: {
        "User-Agent": "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
        "Accept": "text/html",
      },
    });

    console.log("[fetchMeta] Strategy 3 response status:", res.status);
    
    if (res.ok || res.status === 202) {
      const html = await res.text();
      console.log("[fetchMeta] Strategy 3 HTML length:", html.length);
      
      // Even small responses might contain OG tags for social crawlers
      if (html.length > 500) {
        const result = parseHtml(html, url);
        
        if (result.title || result.description || result.image) {
          console.log("[fetchMeta] ✓ Strategy 3 (Facebook bot) found data - title:", result.title, "image:", result.image ? "yes" : "no");
          bestResult = mergeResults(bestResult, result, 3);
          
          // If we have complete data, we're done
          if (bestResult.title && bestResult.image) {
            return bestResult;
          }
        }
      }
    }
  } catch (e) {
    console.log("[fetchMeta] ✗ Strategy 3 failed:", e);
  }

  // Strategy 4: Try as Twitter bot (another social crawler that might get different treatment)
  try {
    console.log("[fetchMeta] Strategy 4: Twitter bot User-Agent");
    const res = await fetch(url, {
      redirect: "follow",
      headers: {
        "User-Agent": "Twitterbot/1.0",
        "Accept": "text/html",
      },
    });

    console.log("[fetchMeta] Strategy 4 response status:", res.status);
    
    if (res.ok || res.status === 202) {
      const html = await res.text();
      console.log("[fetchMeta] Strategy 4 HTML length:", html.length);
      
      if (html.length > 500) {
        const result = parseHtml(html, url);
        
        if (result.title || result.description || result.image) {
          console.log("[fetchMeta] ✓ Strategy 4 (Twitter bot) found data - title:", result.title, "image:", result.image ? "yes" : "no");
          bestResult = mergeResults(bestResult, result, 4);
          
          // If we have complete data, we're done
          if (bestResult.title && bestResult.image) {
            return bestResult;
          }
        }
      }
    }
  } catch (e) {
    console.log("[fetchMeta] ✗ Strategy 4 failed:", e);
  }

  // Strategy 5: Try as Google bot
  try {
    console.log("[fetchMeta] Strategy 5: Google bot User-Agent");
    const res = await fetch(url, {
      redirect: "follow",
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        "Accept": "text/html",
      },
    });

    console.log("[fetchMeta] Strategy 5 response status:", res.status);
    
    if (res.ok) {
      const html = await res.text();
      console.log("[fetchMeta] Strategy 5 HTML length:", html.length);
      
      if (html.length > 500) {
        const result = parseHtml(html, url);
        
        if (result.title || result.description || result.image) {
          console.log("[fetchMeta] ✓ Strategy 5 (Google bot) found data - title:", result.title, "image:", result.image ? "yes" : "no");
          bestResult = mergeResults(bestResult, result, 5);
        }
      }
    }
  } catch (e) {
    console.log("[fetchMeta] ✗ Strategy 5 failed:", e);
  }

  // Return best result we have
  if (bestResult.title || bestResult.image) {
    console.log("[fetchMeta] Returning best result - title:", bestResult.title, "image:", bestResult.image ? "yes" : "no", "strategy:", bestResult._strategy);
    return bestResult;
  }

  // Strategy 6: Construct title from URL as absolute last resort (if Strategy 0 failed)
  if (!bestResult.title) {
    try {
      console.log("[fetchMeta] Strategy 6: Generic URL parsing fallback");
      const urlObj = new URL(url);
      const hostname = urlObj.hostname.replace("www.", "");
      const pathParts = urlObj.pathname.split("/").filter((p) => p && p.length > 2);
      
      let title = hostname;
      if (pathParts.length > 0) {
        const lastSegment = pathParts[pathParts.length - 1]
          .replace(/[-_]/g, " ")
          .replace(/\.(html?|php|aspx?)$/i, "")
          .replace(/\b\w/g, (l) => l.toUpperCase());
        if (lastSegment.length > 3) {
          title = lastSegment;
        }
      }
      
      console.log("[fetchMeta] ✓ Strategy 6 (URL parsing fallback) used - title:", title);
      return {
        title: title,
        description: `Link from ${hostname}`,
        image: bestResult.image,
        siteName: hostname,
        latitude: bestResult.latitude,
        longitude: bestResult.longitude,
        address: bestResult.address,
        _strategy: 6,
      };
    } catch (e) {
      console.log("[fetchMeta] ✗ Strategy 6 failed:", e);
    }
  }

  console.log("[fetchMeta] All strategies completed, returning best result");
  return bestResult;
});

