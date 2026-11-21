// Groove Radar on Cloudflare: serves the static site, plus two small endpoints.
//
// GET /api/where returns the visitor's approximate location (city level) as Cloudflare
// already works it out from the connection, so the page can measure "near you" from there.
// Nothing is stored or logged here (request logging is off in wrangler.jsonc), and no
// third-party service is called. Everything else is the static site in ./site.
//
// POST /api/chat is the "Ask Groove Radar" assistant (see chat.js). It is the only endpoint
// that calls a third party (Anthropic), and only with what the visitor typed, the gig data
// and their approximate location.
//
// Every request runs through here first (assets.run_worker_first in wrangler.jsonc), so plain
// http:// is always sent to https://, and HTTPS responses tell the browser to never use
// http:// for this site again (HSTS, one year).
import { handleChat } from "./chat.js";

const HSTS = "max-age=31536000";

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const local = env.LOCAL_DEV === "1";  // set only in .dev.vars for `wrangler dev`
    if (url.protocol === "http:" && !local) {
      url.protocol = "https:";
      return Response.redirect(url.toString(), 301);
    }
    const res = await handle(request, env, url, ctx);
    const out = new Response(res.body, res);
    if (!local) out.headers.set("strict-transport-security", HSTS);
    return out;
  },
};

function where(request) {
  const cf = request.cf || {};
  const lat = Number(cf.latitude), lon = Number(cf.longitude);
  return Number.isFinite(lat) && Number.isFinite(lon)
    ? { lat: Math.round(lat * 100) / 100, lon: Math.round(lon * 100) / 100, city: cf.city || null, country: cf.country || null, continent: cf.continent || null }
    : {};
}

function handle(request, env, url, ctx) {
  if (url.pathname === "/api/where") {
    return new Response(JSON.stringify(where(request)), {
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "private, no-store",
        "x-content-type-options": "nosniff",
      },
    });
  }
  if (url.pathname === "/api/chat") return handleChat(request, env, ctx, url, where(request));
  return env.ASSETS.fetch(request);
}
