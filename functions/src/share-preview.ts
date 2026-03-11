/**
 * Share preview: serve Open Graph / Twitter Card meta for /join/:code and /trip/:id
 * so WhatsApp, Messenger, etc. show trip title and cover image in link previews.
 *
 * Best practices applied:
 * - Absolute URLs for og:image (required by WhatsApp/Facebook).
 * - og:title, og:description, og:url, og:type, og:site_name.
 * - twitter:card summary_large_image for a large image in Twitter/Slack.
 *
 * - Crawler (WhatsApp, Facebook, Telegram, etc.): return minimal HTML with og:* meta.
 * - Normal user: proxy to index.html so the SPA loads (same URL).
 */

import {getFirestore} from "firebase-admin/firestore";
import {onRequest} from "firebase-functions/v2/https";

const CRAWLER_UA_PATTERNS = [
  "whatsapp",
  "facebookexternalhit",
  "facebot",
  "telegrambot",
  "slackbot",
  "discordbot",
  "twitterbot",
  "linkedinbot",
  "pinterest",
  "slurp", // Yahoo
  "googlebot",
  "bingbot",
  "applebot",
  "embedly",
  "quora link preview",
  "outbrain",
  "pinterest/",
  "developers.google.com/+/web/snippet",
  "vkshare",
  "w3c_validator",
];

function isCrawler(userAgent: string): boolean {
  const ua = userAgent.toLowerCase();
  return CRAWLER_UA_PATTERNS.some((p) => ua.includes(p));
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export const sharePreview = onRequest(
  {region: "us-central1", timeoutSeconds: 15},
  async (req: import("express").Request, res: import("express").Response): Promise<void> => {
    if (req.method !== "GET") {
      res.status(405).set("Allow", "GET").end();
      return;
    }

    const pathOnly = (req as any).path ?? (typeof req.url === "string" ? req.url.split("?")[0] : "");
    const pathname = pathOnly.startsWith("/") ? pathOnly : `/${pathOnly || ""}`;

    const pathParts = pathname.replace(/^\/+/, "").split("/");
    const isJoin = pathParts[0] === "join" && pathParts[1];
    const isTrip = pathParts[0] === "trip" && pathParts[1];
    const inviteCode = isJoin ? pathParts[1] : null;
    const tripId = isTrip ? pathParts[1] : null;

    const userAgent = (req.headers["user-agent"] as string) || "";
    const crawler = isCrawler(userAgent);

    if (!crawler) {
      // Not a crawler: serve the SPA so the app loads at the same URL
      try {
        const host = (req.headers["x-forwarded-host"] as string) || req.headers["host"] || "waypoint.tours";
        const proto = (req.headers["x-forwarded-proto"] as string) || "https";
        const origin = `${proto}://${host}`;
        const indexUrl = `${origin}/`;
        const indexRes = await fetch(indexUrl, {
          headers: {"User-Agent": userAgent || "WaypointPreview/1.0"},
        });
        if (indexRes.ok) {
          const html = await indexRes.text();
          res.status(200).set("Content-Type", "text/html").send(html);
          return;
        }
      } catch (e) {
        console.warn("[sharePreview] Fetch index failed:", e);
      }
      res.status(404).send("Not found");
      return;
    }

    // Crawler: resolve trip and return meta HTML
    let trip: FirebaseFirestore.DocumentSnapshot | null = null;
    const db = getFirestore();

    if (inviteCode) {
      const joinSnap = await db.collection("trips")
        .where("invite_code", "==", inviteCode)
        .where("invite_enabled", "==", true)
        .limit(1)
        .get();
      if (!joinSnap.empty) trip = joinSnap.docs[0];
    } else if (tripId) {
      trip = await db.collection("trips").doc(tripId).get();
      if (!trip.exists) trip = null;
    }

    if (!trip || !trip.exists) {
      res.status(404).set("Content-Type", "text/html").send(
        "<!DOCTYPE html><html><head><title>Waypoint</title></head><body><p>Trip not found.</p></body></html>"
      );
      return;
    }

    const tripData = trip.data();
    const planId = tripData?.plan_id as string | undefined;
    const title = (tripData?.title as string) || "Trip";
    const customImages = tripData?.customImages as Record<string, string> | undefined;
    const usePlanImage = tripData?.usePlanImage !== false;

    let imageUrl: string | null = null;
    if (customImages && !usePlanImage) {
      imageUrl = (customImages.medium || customImages.large || customImages.thumbnail || customImages.original) ?? null;
    }
    if (!imageUrl && planId) {
      const planSnap = await db.collection("plans").doc(planId).get();
      if (planSnap.exists) {
        const planData = planSnap.data();
        const hero = planData?.hero_image_url as string | undefined;
        if (hero) imageUrl = hero;
      }
    }

    const host = (req.headers["x-forwarded-host"] as string) || req.headers["host"] || "waypoint.tours";
    const proto = (req.headers["x-forwarded-proto"] as string) || "https";
    const canonicalUrl = `${proto}://${host}${pathname}`;
    const description = `Join this trip on Waypoint – plan your next adventure together.`;

    const meta = {
      "og:title": title,
      "og:description": description,
      "og:url": canonicalUrl,
      "og:type": "website",
      "og:site_name": "Waypoint",
      "twitter:card": "summary_large_image",
      "twitter:title": title,
      "twitter:description": description,
    } as Record<string, string>;
    if (imageUrl) {
      meta["og:image"] = imageUrl;
      meta["twitter:image"] = imageUrl;
      meta["og:image:secure_url"] = imageUrl.startsWith("https") ? imageUrl : imageUrl;
    }

    const metaTags = Object.entries(meta)
      .map(([k, v]) => `<meta property="${escapeHtml(k)}" content="${escapeHtml(v)}">`)
      .join("\n    ");

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)} – Waypoint</title>
  ${metaTags}
  <style>body{font-family:system-ui,sans-serif;margin:2rem;}</style>
</head>
<body>
  <h1>${escapeHtml(title)}</h1>
  <p>${escapeHtml(description)}</p>
  <p><a href="${escapeHtml(canonicalUrl)}">Open in Waypoint</a></p>
</body>
</html>`;

    res.status(200).set("Content-Type", "text/html").send(html);
  }
);
