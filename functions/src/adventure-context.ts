import {onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";

// Define the OpenRouter API key as a secret (Firebase Functions v2)
// Falls back to environment variable for local development
const openRouterApiKeySecret = defineSecret("OPENROUTER_API_KEY");

// 🔒 SECURITY: API key stored as Firebase secret or environment variable
// Never commit to git - use .env file for local development
function getOpenRouterApiKey(): string {
  // Try Firebase secret first (production)
  try {
    const secretValue = openRouterApiKeySecret.value();
    if (secretValue) {
      return secretValue;
    }
  } catch (e) {
    // Secret not available (e.g., local development)
  }
  
  // Fallback to environment variable (local development)
  const envKey = process.env.OPENROUTER_API_KEY;
  if (envKey) {
    return envKey;
  }
  
  throw new Error("OPENROUTER_API_KEY not set. Set it as a Firebase secret or environment variable.");
}

// Type definitions for OpenRouter API response
interface OpenRouterMessage {
  content: string;
}

interface OpenRouterChoice {
  message: OpenRouterMessage;
}

interface OpenRouterResponse {
  choices?: OpenRouterChoice[];
}

const SYSTEM_PROMPT = `You are the Waypoint Travel Context API. You generate structured travel information for adventure plans.

## Your Role
You receive adventure context (location, activity type, accommodation type, title, description) and return a JSON object with essential travel information for that destination. You MUST research and base all responses on official sources and well-established travel guidance for the given country/location.

## Input Format
You receive a JSON object:
{
  "location": "string — city/region, country",
  "title": "string — adventure name",
  "description": "string — short description of the plan",
  "activity_type": "string — e.g. hiking, biking, road_trip, city_trip, multi_activity",
  "accommodation_type": "string — e.g. camping, hotel, hostel, hut, mixed"
}

## Rules
- All text must be SHORT and concise. Max 1-2 sentences per field unless specified otherwise.
- Use official and well-established sources: government travel advisories, embassy websites, WHO, local tourism boards.
- For visa requirements: give general guidance and note that requirements vary by nationality.
- For permits: only include if relevant based on activity_type, location, and description context.
- For vaccines: only list vaccines officially required or strongly recommended by WHO/CDC for that destination.
- For camping rules: only include if accommodation_type involves camping/tent/bivouac.
- Never invent information. If unsure, say "Verify with local authorities before travel."
- Return ONLY valid JSON. No markdown, no explanation, no wrapping.

## Output JSON Structure — TWO SECTIONS ONLY: "prepare" and "local_tips"

{
  "prepare": {
    "travel_insurance": {
      "recommendation": "string — one recommended insurer name for this activity type",
      "url": "string — direct URL to their relevant product page",
      "note": "string — one sentence why this one fits"
    },
    "visa": {
      "requirement": "string — general visa info for this country",
      "medical_insurance_required_for_visa": "boolean",
      "note": "string — any extra detail, e.g. ETIAS, Schengen rules"
    },
    "passport": {
      "validity_requirement": "string — e.g. 'Must be valid for at least 6 months beyond entry date'",
      "blank_pages_required": "string — e.g. 'At least 1 blank page'"
    },
    "permits": [
      {
        "type": "string — e.g. 'National Park Entry'",
        "details": "string — short description",
        "how_to_obtain": "string — where/how to get it",
        "cost": "string | null"
      }
    ],
    "vaccines": {
      "required": ["string — only officially required vaccines"],
      "recommended": ["string — CDC/WHO recommended vaccines"],
      "note": "string | null"
    },
    "climate": {
      "location": "string",
      "data": [
        {
          "month": "string",
          "avg_temp_high_c": "number",
          "avg_temp_low_c": "number",
          "avg_rain_mm": "number",
          "avg_rain_days": "number",
          "avg_daylight_hours": "number"
        }
      ]
    }
  },
  "local_tips": {
    "emergency": {
      "general_emergency": "string",
      "police": "string",
      "ambulance": "string",
      "fire": "string",
      "mountain_rescue": "string | null — only if relevant to activity_type"
    },
    "messaging_app": {
      "name": "string — most used app e.g. WhatsApp",
      "note": "string — one sentence"
    },
    "etiquette": [
      "string — max 5 short etiquette tips"
    ],
    "tipping": {
      "practice": "string",
      "restaurant": "string",
      "taxi": "string",
      "hotel": "string"
    },
    "basic_phrases": [
      {
        "english": "string",
        "local": "string",
        "pronunciation": "string"
      }
    ],
    "food_specialties": [
      {
        "name": "string",
        "description": "string — one sentence"
      }
    ],
    "food_warnings": [
      "string — e.g. 'Tap water is safe to drink'"
    ]
  }
}`;

export const generateAdventureContext = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 60,
    cors: true,
    secrets: [openRouterApiKeySecret],
  },
  async (request) => {
    const {location, title, description, activity_type, accommodation_type} = request.data as {
      location?: string;
      title?: string;
      description?: string;
      activity_type?: string;
      accommodation_type?: string;
    };

    // Validate required fields
    if (!location || !title || !description) {
      return {error: "Missing required fields: location, title, and description are required"};
    }

    try {
      console.log(`[generateAdventureContext] Generating context for: ${title} in ${location}`);

      // Build the input JSON for the AI
      const inputJson = JSON.stringify({
        location,
        title,
        description,
        activity_type: activity_type || "multi_activity",
        accommodation_type: accommodation_type || "mixed",
      });

      // Call OpenRouter API
      const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${getOpenRouterApiKey()}`,
          "HTTP-Referer": "https://waypoint.app", // Optional: for OpenRouter analytics
          "X-Title": "Waypoint Adventure Context Generator", // Optional: for OpenRouter analytics
        },
        body: JSON.stringify({
          model: "anthropic/claude-sonnet-4-20250514",
          messages: [
            {role: "system", content: SYSTEM_PROMPT},
            {role: "user", content: inputJson},
          ],
          temperature: 0.3,
          max_tokens: 4000,
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`[generateAdventureContext] OpenRouter API error: ${response.status} - ${errorText}`);
        return {error: `API request failed: ${response.status}`};
      }

      const responseData = await response.json() as OpenRouterResponse;
      const content = responseData.choices?.[0]?.message?.content;

      if (!content) {
        console.error("[generateAdventureContext] No content in response");
        return {error: "No content in API response"};
      }

      // Strip markdown code fences if present
      let jsonString = content.trim();
      if (jsonString.startsWith("```json")) {
        jsonString = jsonString.replace(/^```json\s*/, "").replace(/\s*```$/, "");
      } else if (jsonString.startsWith("```")) {
        jsonString = jsonString.replace(/^```\s*/, "").replace(/\s*```$/, "");
      }

      // Parse JSON
      let parsed: any;
      try {
        parsed = JSON.parse(jsonString);
      } catch (parseError) {
        console.error("[generateAdventureContext] JSON parse error:", parseError);
        console.error("[generateAdventureContext] Content:", jsonString.substring(0, 500));
        return {error: "Failed to parse JSON response"};
      }

      // Validate structure
      if (!parsed.prepare || !parsed.local_tips) {
        console.error("[generateAdventureContext] Missing required keys in response");
        return {error: "Invalid response structure: missing 'prepare' or 'local_tips'"};
      }

      console.log("[generateAdventureContext] Successfully generated context");
      return parsed;
    } catch (error: any) {
      console.error("[generateAdventureContext] Unexpected error:", error);
      return {error: error.message || "Internal server error"};
    }
  }
);

