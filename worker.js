// Groove Radar on Cloudflare: serves the static site, plus one tiny endpoint.
//
// GET /api/where returns the visitor's approximate location (city level) as Cloudflare
// already works it out from the connection, so the page can measure "near you" from there.
// Nothing is stored or logged here (request logging is off in wrangler.jsonc), and no
// third-party service is called. Everything else is the static site in ./site.

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
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
  },
};
