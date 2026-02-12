import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import axios from "axios";
import * as cheerio from "cheerio";

interface RouteMetadata {
  source: "komoot" | "alltrails";
  distance_km: number | null;
  elevation_m: number | null;
  estimated_time: string | null;
  difficulty: "easy" | "moderate" | "hard" | null;
  extraction_method: "json_ld" | "meta_tags" | "html_parsing" | "llm_fallback";
  sourceUrl: string;
}

// Normalize difficulty strings to standard values
function normalizeDifficulty(text: string | null): "easy" | "moderate" | "hard" | null {
  if (!text) return null;
  const lower = text.toLowerCase().trim();
  
  // English
  if (lower.includes("easy") || lower.includes("beginner")) return "easy";
  if (lower.includes("moderate") || lower.includes("intermediate") || lower.includes("medium")) return "moderate";
  if (lower.includes("hard") || lower.includes("difficult") || lower.includes("expert") || lower.includes("challenging")) return "hard";
  
  // Dutch
  if (lower.includes("makkelijk") || lower.includes("eenvoudig")) return "easy";
  if (lower.includes("gemiddeld") || lower.includes("normaal")) return "moderate";
  if (lower.includes("zwaar") || lower.includes("moeilijk")) return "hard";
  
  // German
  if (lower.includes("leicht") || lower.includes("einfach")) return "easy";
  if (lower.includes("mittelschwer") || lower.includes("mittel")) return "moderate";
  if (lower.includes("schwer") || lower.includes("schwierig")) return "hard";
  
  return null;
}

// Extract visible text from HTML (removes script/style tags)
function extractVisibleText(html: string): string {
  const $ = cheerio.load(html);
  $("script, style, noscript").remove();
  return $("body").text() || "";
}

// Parse time string like "06:43" or "6h 43m" or "4-4.5 hr" to minutes
function parseTimeToMinutes(timeStr: string): number | null {
  if (!timeStr) return null;
  
  // Format: "06:43" or "6:43"
  const hhmmMatch = timeStr.match(/^(\d{1,2}):(\d{2})$/);
  if (hhmmMatch) {
    const hours = parseInt(hhmmMatch[1], 10);
    const minutes = parseInt(hhmmMatch[2], 10);
    return hours * 60 + minutes;
  }
  
  // Format: "6h 43m" or "6h" or "43m"
  const hoursMatch = timeStr.match(/(\d+(?:\.\d+)?)\s*h(?:ours?|r)?/i);
  const minutesMatch = timeStr.match(/(\d+)\s*m(?:in(?:utes?)?)?/i);
  
  let totalMinutes = 0;
  if (hoursMatch) {
    totalMinutes += Math.round(parseFloat(hoursMatch[1]) * 60);
  }
  if (minutesMatch) {
    totalMinutes += parseInt(minutesMatch[1], 10);
  }
  
  // Format: "4-4.5 hr" (take average)
  const rangeMatch = timeStr.match(/(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)\s*h(?:ours?|r)?/i);
  if (rangeMatch) {
    const min = parseFloat(rangeMatch[1]);
    const max = parseFloat(rangeMatch[2]);
    totalMinutes = Math.round(((min + max) / 2) * 60);
  }
  
  return totalMinutes > 0 ? totalMinutes : null;
}

// Format minutes to "HH:MM" or "Xh Ym" format
function formatTime(minutes: number | null): string | null {
  if (minutes === null || minutes <= 0) return null;
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  if (hours > 0) {
    return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
  }
  return `${mins}m`;
}

// Priority 1: Extract from JSON-LD structured data
function extractFromJsonLd(html: string): Partial<RouteMetadata> | null {
  try {
    const jsonLdMatches = html.match(/<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi);
    if (!jsonLdMatches) return null;
    
    for (const match of jsonLdMatches) {
      try {
        const jsonContent = match.replace(/<script[^>]*>/, "").replace(/<\/script>/, "").trim();
        const parsed = JSON.parse(jsonContent);
        const data = Array.isArray(parsed) ? parsed[0] : parsed;
        
        if (!data || typeof data !== "object") continue;
        
        // Look for schema.org types: HikingTrail, Route, or generic Thing
        const type = data["@type"];
        if (!type || (!type.includes("Trail") && !type.includes("Route") && type !== "Thing")) continue;
        
        let distance: number | null = null;
        let elevation: number | null = null;
        let duration: string | null = null;
        let difficulty: "easy" | "moderate" | "hard" | null = null;
        
        // Distance (could be in distance, length, or distanceValue)
        if (data.distance) {
          const distStr = typeof data.distance === "string" ? data.distance : data.distance.value || data.distance;
          const distMatch = distStr.match(/(\d+(?:\.\d+)?)\s*(?:km|kilometer)/i);
          if (distMatch) distance = parseFloat(distMatch[1]);
        }
        if (data.length) {
          const lenStr = typeof data.length === "string" ? data.length : data.length.value || data.length;
          const lenMatch = lenStr.match(/(\d+(?:\.\d+)?)\s*(?:km|kilometer|m|meter)/i);
          if (lenMatch) {
            const val = parseFloat(lenMatch[1]);
            if (lenStr.toLowerCase().includes("km")) distance = val;
            else if (lenStr.toLowerCase().includes("m") && val > 100) distance = val / 1000; // Convert meters to km if > 100m
          }
        }
        
        // Elevation gain
        if (data.elevationGain || data.elevation) {
          const elevStr = typeof (data.elevationGain || data.elevation) === "string" 
            ? (data.elevationGain || data.elevation)
            : (data.elevationGain || data.elevation)?.value || (data.elevationGain || data.elevation);
          const elevMatch = elevStr.match(/(\d+(?:\.\d+)?)\s*(?:m|meter|meters)/i);
          if (elevMatch) elevation = Math.round(parseFloat(elevMatch[1]));
        }
        
        // Duration
        if (data.duration || data.timeRequired) {
          const durStr = typeof (data.duration || data.timeRequired) === "string"
            ? (data.duration || data.timeRequired)
            : (data.duration || data.timeRequired)?.value || (data.duration || data.timeRequired);
          duration = durStr;
        }
        
        // Difficulty
        if (data.difficulty || data.difficultyLevel) {
          difficulty = normalizeDifficulty(data.difficulty || data.difficultyLevel);
        }
        
        if (distance || elevation || duration || difficulty) {
          logger.info("[extractRouteMetadata] JSON-LD extraction found data", {distance, elevation, duration, difficulty});
          return {distance_km: distance, elevation_m: elevation, estimated_time: duration, difficulty};
        }
      } catch (e) {
        // Skip invalid JSON
        continue;
      }
    }
  } catch (e) {
    logger.warn("[extractRouteMetadata] JSON-LD parsing failed", e);
  }
  return null;
}

// Priority 2: Extract from Open Graph / meta tags
function extractFromMetaTags(html: string): Partial<RouteMetadata> | null {
  const metaTags: Map<string, string> = new Map();
  
  // Extract meta tags
  const pattern1 = /<meta[^>]+(?:property|name)\s*=\s*["']([^"']+)["'][^>]*content\s*=\s*["']([^"']*)["'][^>]*>/gi;
  let match;
  while ((match = pattern1.exec(html)) !== null) {
    const key = match[1].toLowerCase();
    const value = match[2];
    if (value && !metaTags.has(key)) {
      metaTags.set(key, value);
    }
  }
  
  // Check og:description which often contains summary like "14.2 km · 450 m elevation · Moderate"
  const ogDesc = metaTags.get("og:description") || metaTags.get("description");
  if (ogDesc) {
    let distance: number | null = null;
    let elevation: number | null = null;
    let difficulty: "easy" | "moderate" | "hard" | null = null;
    
    // Parse patterns like "14.2 km · 450 m elevation · Moderate"
    const distMatch = ogDesc.match(/(\d+(?:\.\d+)?)\s*km/i);
    if (distMatch) distance = parseFloat(distMatch[1]);
    
    const elevMatch = ogDesc.match(/(\d+(?:\.\d+)?)\s*m\s*(?:elevation|ascent|gain)/i);
    if (elevMatch) elevation = Math.round(parseFloat(elevMatch[1]));
    
    difficulty = normalizeDifficulty(ogDesc);
    
    if (distance || elevation || difficulty) {
      logger.info("[extractRouteMetadata] Meta tags extraction found data", {distance, elevation, difficulty});
      return {distance_km: distance, elevation_m: elevation, difficulty};
    }
  }
  
  return null;
}

// Priority 3: HTML text parsing (AllTrails patterns)
function extractFromAllTrailsHtml(html: string): Partial<RouteMetadata> | null {
  const $ = cheerio.load(html);
  const text = extractVisibleText(html);
  
  let distance: number | null = null;
  let elevation: number | null = null;
  let duration: string | null = null;
  let difficulty: "easy" | "moderate" | "hard" | null = null;
  
  // AllTrails patterns
  // "14.2 km Length"
  const lengthMatch = text.match(/(\d+(?:\.\d+)?)\s*km\s*(?:length|distance)/i);
  if (lengthMatch) distance = parseFloat(lengthMatch[1]);
  
  // "450 m Elevation gain"
  const elevMatch = text.match(/(\d+(?:\.\d+)?)\s*m\s*(?:elevation\s*gain|ascent)/i);
  if (elevMatch) elevation = Math.round(parseFloat(elevMatch[1]));
  
  // "4–4.5 hr Estimated time" or "4-4.5 hr"
  const timeMatch = text.match(/(\d+(?:\.\d+)?)\s*[-–]\s*(\d+(?:\.\d+)?)\s*h(?:r|ours?)?\s*(?:estimated\s*time)?/i) ||
                    text.match(/(\d+(?:\.\d+)?)\s*h(?:r|ours?)?\s*(?:estimated\s*time)?/i);
  if (timeMatch) {
    if (timeMatch[2]) {
      // Range format
      const min = parseFloat(timeMatch[1]);
      const max = parseFloat(timeMatch[2]);
      const avgMinutes = Math.round(((min + max) / 2) * 60);
      duration = formatTime(avgMinutes);
    } else {
      const hours = parseFloat(timeMatch[1]);
      duration = formatTime(Math.round(hours * 60));
    }
  }
  
  // Difficulty: Look for "Easy", "Moderate", "Hard" in text
  const difficultyMatch = text.match(/\b(easy|moderate|hard|intermediate|expert|challenging|beginner)\b/i);
  if (difficultyMatch) {
    difficulty = normalizeDifficulty(difficultyMatch[1]);
  }
  
  if (distance || elevation || duration || difficulty) {
    logger.info("[extractRouteMetadata] AllTrails HTML parsing found data", {distance, elevation, duration, difficulty});
    return {distance_km: distance, elevation_m: elevation, estimated_time: duration, difficulty};
  }
  
  return null;
}

// Priority 3: HTML text parsing (Komoot patterns)
function extractFromKomootHtml(html: string): Partial<RouteMetadata> | null {
  const text = extractVisibleText(html);
  
  let distance: number | null = null;
  let elevation: number | null = null;
  let duration: string | null = null;
  let difficulty: "easy" | "moderate" | "hard" | null = null;
  
  // Komoot patterns (note: locale-specific)
  // Distance: "25,6 km" or "25.6 km" (comma or dot as decimal separator)
  const distMatch = text.match(/(\d+(?:[,.]\d+)?)\s*km/i);
  if (distMatch) {
    distance = parseFloat(distMatch[1].replace(",", "."));
  }
  
  // Elevation: "210 m" or "210m"
  const elevMatch = text.match(/(\d+(?:\.\d+)?)\s*m\b/i);
  if (elevMatch) {
    elevation = Math.round(parseFloat(elevMatch[1]));
  }
  
  // Duration: "06:43" format
  const timeMatch = text.match(/\b(\d{1,2}):(\d{2})\b/);
  if (timeMatch) {
    const hours = parseInt(timeMatch[1], 10);
    const minutes = parseInt(timeMatch[2], 10);
    duration = formatTime(hours * 60 + minutes);
  }
  
  // Difficulty: Look for localized terms
  difficulty = normalizeDifficulty(text);
  
  if (distance || elevation || duration || difficulty) {
    logger.info("[extractRouteMetadata] Komoot HTML parsing found data", {distance, elevation, duration, difficulty});
    return {distance_km: distance, elevation_m: elevation, estimated_time: duration, difficulty};
  }
  
  return null;
}

// Priority 4: LLM fallback (simplified - just return null for now)
// In production, you could integrate with Claude API here
function extractFromLlm(text: string): Partial<RouteMetadata> | null {
  // For now, return null - LLM integration can be added later if needed
  // This would send first ~2000 chars to Claude API with a structured prompt
  logger.warn("[extractRouteMetadata] LLM fallback not implemented");
  return null;
}

export const extractRouteMetadata = onCall(
  {region: "europe-west1", timeoutSeconds: 30, cors: true},
  async (request) => {
    try {
      const urlRaw = (request.data && (request.data as any).url) ?? "";
      const url = String(urlRaw).trim();
      
      if (!url) {
        return {error: "No URL provided"};
      }
      
      // Validate URL
      try {
        const urlObj = new URL(url);
        if (!["http:", "https:"].includes(urlObj.protocol)) {
          return {error: "Invalid URL protocol"};
        }
        
        // Determine source
        const hostname = urlObj.hostname.toLowerCase();
        let source: "komoot" | "alltrails" = "komoot";
        if (hostname.includes("alltrails.com")) {
          source = "alltrails";
        } else if (!hostname.includes("komoot.com")) {
          return {error: "URL must be from Komoot or AllTrails"};
        }
      } catch (e) {
        return {error: "Invalid URL format"};
      }
      
      logger.info("[extractRouteMetadata] Fetching route metadata from", url);
      
      // Fetch HTML with proper User-Agent and browser-like headers
      // Try multiple strategies to bypass bot detection
      let html: string | null = null;
      let lastError: string | null = null;
      
      // Strategy 1: Standard browser headers
      const strategies = [
        {
          name: "Standard Chrome",
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            "DNT": "1",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-User": "?1",
            "Cache-Control": "max-age=0",
            "Referer": url.includes("alltrails.com") ? "https://www.alltrails.com/" : "https://www.komoot.com/",
          }
        },
        {
          name: "Mobile Safari",
          headers: {
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Referer": url.includes("alltrails.com") ? "https://www.alltrails.com/" : "https://www.komoot.com/",
          }
        },
        {
          name: "Google Bot",
          headers: {
            "User-Agent": "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
            "Accept": "text/html",
            "Referer": url.includes("alltrails.com") ? "https://www.alltrails.com/" : "https://www.komoot.com/",
          }
        }
      ];
      
      for (const strategy of strategies) {
        try {
          logger.info(`[extractRouteMetadata] Trying strategy: ${strategy.name}`);
          const response = await axios.get(url, {
            timeout: 10000,
            headers: strategy.headers,
            maxRedirects: 5,
            validateStatus: (status) => status < 500, // Accept 403, 404, etc. and try to parse
          });
          
          html = response.data;
          
          // Check if this is a bot detection page
          const htmlLower = html?.toLowerCase() || "";
          const isBotPage = htmlLower.includes("access denied") || 
                           htmlLower.includes("blocked") || 
                           htmlLower.includes("captcha") ||
                           htmlLower.includes("cloudflare") ||
                           htmlLower.includes("bot detection") ||
                           htmlLower.includes("please verify you are human") ||
                           htmlLower.includes("just a moment") ||
                           htmlLower.includes("checking your browser");
          
          if (response.status === 200 && !isBotPage && html && html.length > 1000) {
            logger.info(`[extractRouteMetadata] Strategy "${strategy.name}" succeeded`);
            break; // Success!
          }
          
          if (response.status === 403 || response.status === 401 || isBotPage) {
            logger.warn(`[extractRouteMetadata] Strategy "${strategy.name}" blocked (status: ${response.status}, botPage: ${isBotPage})`);
            lastError = `Blocked by site (${response.status})`;
            html = null; // Don't use this response
            continue; // Try next strategy
          }
          
          // If we got HTML but it's short, might still be useful
          if (html && html.length > 100) {
            logger.info(`[extractRouteMetadata] Strategy "${strategy.name}" returned HTML (${html.length} chars), will try to parse`);
            break; // Try to parse what we got
          }
        } catch (e: any) {
          logger.warn(`[extractRouteMetadata] Strategy "${strategy.name}" failed:`, e.message);
          lastError = e.message;
          continue; // Try next strategy
        }
      }
      
      // If all strategies failed
      if (!html || html.length < 100) {
        logger.error("[extractRouteMetadata] All strategies failed. Last error:", lastError);
        return {error: "Could not retrieve route info. AllTrails is blocking automated requests. Please enter the route details manually."};
      }
      
      // Try extraction methods in priority order
      let result: Partial<RouteMetadata> | null = null;
      let method: RouteMetadata["extraction_method"] = "html_parsing";
      
      // Priority 1: JSON-LD
      result = extractFromJsonLd(html);
      if (result && (result.distance_km || result.elevation_m || result.estimated_time || result.difficulty)) {
        method = "json_ld";
      } else {
        // Priority 2: Meta tags
        result = extractFromMetaTags(html);
        if (result && (result.distance_km || result.elevation_m || result.difficulty)) {
          method = "meta_tags";
        } else {
          // Priority 3: HTML parsing (source-specific)
          if (url.toLowerCase().includes("alltrails.com")) {
            result = extractFromAllTrailsHtml(html);
          } else {
            result = extractFromKomootHtml(html);
          }
          method = "html_parsing";
          
          // Priority 4: LLM fallback (if nothing found)
          if (!result || (!result.distance_km && !result.elevation_m && !result.estimated_time && !result.difficulty)) {
            const visibleText = extractVisibleText(html).substring(0, 2000);
            result = extractFromLlm(visibleText);
            if (result) method = "llm_fallback";
          }
        }
      }
      
      // Build response
      const source: "komoot" | "alltrails" = url.toLowerCase().includes("alltrails.com") ? "alltrails" : "komoot";
      const metadata: RouteMetadata = {
        source,
        sourceUrl: url,
        distance_km: result?.distance_km ?? null,
        elevation_m: result?.elevation_m ?? null,
        estimated_time: result?.estimated_time ?? null,
        difficulty: result?.difficulty ?? null,
        extraction_method: method,
      };
      
      // Return error if nothing was extracted
      if (!metadata.distance_km && !metadata.elevation_m && !metadata.estimated_time && !metadata.difficulty) {
        logger.warn("[extractRouteMetadata] No metadata extracted. HTML length:", html?.length || 0);
        // Log a sample to help debug
        if (html && html.length > 0) {
          const sample = html.substring(0, 1000);
          logger.info("[extractRouteMetadata] HTML sample for debugging:", sample);
        }
        return {error: "Could not extract route metadata. The page structure may have changed or the site is blocking access. You can enter it manually."};
      }
      
      logger.info("[extractRouteMetadata] Success", metadata);
      return metadata;
    } catch (e: any) {
      logger.error("[extractRouteMetadata] Error", e);
      return {error: "An error occurred while extracting route metadata. You can enter it manually."};
    }
  }
);

