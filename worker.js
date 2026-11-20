// Groove Radar on Cloudflare: serves the static site, plus one tiny endpoint.
//
// GET /api/where returns the visitor's approximate location (city level) as Cloudflare
// already works it out from the connection, so the page can measure "near you" from there.
// Nothing is stored or logged here (request logging is off in wrangler.jsonc), and no
// third-party service is called. Everything else is the static site in ./site.
//
// Every request runs through here first (assets.run_worker_first in wrangler.jsonc), so plain
// http:// is always sent to https://, and HTTPS responses tell the browser to never use
// http:// for this site again (HSTS, one year).
const HSTS = "max-age=31536000";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.protocol === "http:") {
      url.protocol = "https:";
      return Response.redirect(url.toString(), 301);
    }
    const res = await handle(request, env, url);
    const out = new Response(res.body, res);
    out.headers.set("strict-transport-security", HSTS);
    return out;
  },
};

function handle(request, env, url) {
  if (url.pathname === "/api/where") {
    const cf = request.cf || {};
    const lat = Number(cf.latitude), lon = Number(cf.longitude);
    const body = Number.isFinite(lat) && Number.isFinite(lon)
      ? { lat: Math.round(lat * 100) / 100, lon: Math.round(lon * 100) / 100, city: cf.city || null, country: cf.country || null, continent: cf.continent || null }
      : {};
    return new Response(JSON.stringify(body), {
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "private, no-store",
        "x-content-type-options": "nosniff",
      },
    });
  }
  return env.ASSETS.fetch(request);
}
