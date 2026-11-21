// "Ask Groove Radar": the chat assistant behind POST /api/chat.
//
// The page sends the conversation so far (text only) and the place the visitor measures
// "near" from. This calls Claude with the gig calendar (site/data.json) and web search, and
// streams the answer back as server-sent events:
//   data: {"t":"text","v":"..."}       a piece of the answer
//   data: {"t":"status","v":"..."}     what it is doing (e.g. searching the web)
//   data: {"t":"sources","v":[{title,url}]}  web pages the answer cites
//   data: {"t":"error","v":"..."}      something went wrong (shown to the visitor)
//   data: {"t":"done"}
//
// Setup: the Anthropic API key is a Worker secret (`npx wrangler secret put ANTHROPIC_API_KEY`),
// never in the page or the app. Costs are capped three ways: a per-visitor rate limit
// (CHAT_LIMIT in wrangler.jsonc), size limits on what can be sent, and the monthly spend
// limit set on the Anthropic account itself.
import Anthropic from "@anthropic-ai/sdk";

const MODEL = "claude-opus-5-5";
const MAX_MESSAGES = 16;        // turns kept from one conversation
const MAX_CHARS = 1500;         // per message the visitor types
const MAX_TOTAL_CHARS = 16000;  // whole conversation sent back
const MAX_SEARCHES = 4;         // web searches per answer

const INSTRUCTIONS = `You are the assistant inside Groove Radar, a calendar of every European gig by a hand-picked list of groovy, rolling UK and Irish style tech house DJs. People ask you about these artists' gigs, newly announced tours, bigger events and festivals worth travelling for, and how to plan a trip around them.

How to answer:
- Start from the gig calendar below. It is refreshed every morning from Songkick, venue and ticket sites. Each gig has date, artists, venue, city, country, ticket status and links.
- Use web search for anything the calendar can't answer: newly announced dates or tours, festival line-ups, events beyond the calendar, travel options. Prefer official artist, festival, venue and ticket sites, and Resident Advisor.
- Never invent gigs, dates, line-ups, prices or travel times. Say where each fact comes from: the calendar, or a page you found (link it). If you aren't sure, say so.
- Ticket status changes quickly: when someone wants to buy, tell them to check the ticket page.
- For trips, measure from the visitor's location given below unless they name another place. Give rough travel by train, car or plane only as an estimate, and suggest the dates or weekends with the most gigs within reach, with the reasoning in a line.
- "Near" on Groove Radar means within about 150 km of the visitor.
- Keep answers short and scannable: a sentence or two, then a short list if useful. Use plain Markdown only: **bold**, "- " bullet lists and [text](url) links. No tables, headings or emoji. Write dates like "Sat 12 Dec".
- Stay on topic (these artists, electronic music events, and travel to them). For anything else, say briefly that you only help with Groove Radar.`;

let cached = { key: null, text: null };

/** The calendar as compact JSON for the prompt. Reused while data.json is unchanged, so the prompt prefix stays cacheable. */
async function calendarText(env, origin) {
  const res = await env.ASSETS.fetch(new Request(origin + "/data.json"));
  if (!res.ok) throw new Error("data.json unavailable");
  const raw = await res.text();
  if (cached.key === raw.length + ":" + raw.slice(0, 64)) return cached.text;
  const data = JSON.parse(raw);
  const pick = (o, keys) => Object.fromEntries(keys.filter(k => o[k] != null && o[k] !== "").map(k => [k, o[k]]));
  const gigs = (data.gigs || [])
    .filter(g => g.date)
    .sort((a, b) => a.date.localeCompare(b.date))
    .map(g => pick(g, ["date", "artist", "event", "venue", "city", "country", "start", "end", "status", "lat", "lon", "ticketUrl", "sourceUrl", "note"]));
  const music = (data.music || []).map(m => ({ name: m.name, releases: (m.releases || []).slice(0, 3).map(r => pick(r, ["date", "title", "label", "url"])) }));
  const text = `Gig calendar (${gigs.length} gigs, last refreshed ${data.meta?.lastRun || "recently"}). Gigs dated before today have already happened.\n` +
    JSON.stringify(gigs) + `\n\nNewest releases per artist:\n` + JSON.stringify(music);
  cached = { key: raw.length + ":" + raw.slice(0, 64), text };
  return text;
}

function bad(status, message) {
  return new Response(JSON.stringify({ error: message }), {
    status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

/** Checks the request body; returns { messages, from } or an error string. */
function readBody(body) {
  if (!body || !Array.isArray(body.messages)) return "No messages.";
  const messages = body.messages.slice(-MAX_MESSAGES).map(m => ({
    role: m && m.role === "assistant" ? "assistant" : "user",
    content: typeof m?.content === "string" ? m.content.trim().slice(0, m.role === "assistant" ? 4 * MAX_CHARS : MAX_CHARS) : "",
  })).filter(m => m.content);
  while (messages.length && messages[0].role !== "user") messages.shift();
  if (!messages.length || messages[messages.length - 1].role !== "user") return "The last message must be a question.";
  if (messages.reduce((n, m) => n + m.content.length, 0) > MAX_TOTAL_CHARS) return "This conversation is too long. Start a new one.";
  let from = null;
  const f = body.from;
  if (f && Number.isFinite(f.lat) && Number.isFinite(f.lon) && Math.abs(f.lat) <= 90 && Math.abs(f.lon) <= 180) {
    from = { lat: Math.round(f.lat * 100) / 100, lon: Math.round(f.lon * 100) / 100, label: typeof f.label === "string" ? f.label.slice(0, 60) : null };
  }
  return { messages, from };
}

export async function handleChat(request, env, ctx, url, where) {
  // GET tells the page whether to show the Ask button at all (no key yet: no button).
  if (request.method === "GET") {
    return new Response(JSON.stringify({ ready: !!env.ANTHROPIC_API_KEY }), {
      headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
    });
  }
  if (request.method !== "POST") return bad(405, "Use POST.");
  // Only the site's own page (and the Mac app, which shows that page) may call this.
  const origin = request.headers.get("origin");
  if (origin && origin !== url.origin) return bad(403, "Not allowed.");
  if (!env.ANTHROPIC_API_KEY) return bad(503, "The assistant isn't set up yet.");
  if (env.CHAT_LIMIT) {
    const ip = request.headers.get("cf-connecting-ip") || "local";
    const { success } = await env.CHAT_LIMIT.limit({ key: ip });
    if (!success) return bad(429, "That's a lot of questions at once. Wait a minute and try again.");
  }
  let body;
  try { body = await request.json(); } catch { return bad(400, "Couldn't read the question."); }
  const input = readBody(body);
  if (typeof input === "string") return bad(400, input);

  let calendar;
  try { calendar = await calendarText(env, url.origin); } catch { return bad(503, "The gig calendar isn't available right now."); }

  const from = input.from || (where.lat != null ? { lat: where.lat, lon: where.lon, label: [where.city, where.country].filter(Boolean).join(", ") || null } : null);
  const today = new Date().toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric", timeZone: "Europe/Berlin" });
  const context = `Today is ${today}. ` + (from
    ? `The visitor's location: ${from.label || "unknown place"} (lat ${from.lat}, lon ${from.lon}); this is approximate.`
    : "The visitor's location is unknown; ask where they are travelling from if it matters.");

  const { readable, writable } = new TransformStream();
  const writer = writable.getWriter();
  const enc = new TextEncoder();
  const send = obj => writer.write(enc.encode(`data: ${JSON.stringify(obj)}\n\n`));

  const run = async () => {
    // ANTHROPIC_BASE_URL is only for local testing against a stand-in server (.dev.vars); unset in production.
    const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, baseURL: env.ANTHROPIC_BASE_URL || undefined });
    const messages = input.messages.map(m => ({ role: m.role, content: m.content }));
    const sources = new Map();
    try {
      for (let turn = 0; turn < 4; turn++) {
        const stream = client.beta.messages.stream({
          model: MODEL,
          max_tokens: 16000,
          output_config: { effort: "medium" },
          betas: ["server-side-fallback-2026-07-01"],
          fallbacks: "default",
          system: [
            { type: "text", text: INSTRUCTIONS + "\n\n" + calendar, cache_control: { type: "ephemeral" } },
            { type: "text", text: context },
          ],
          tools: [{ type: "web_search_20260209", name: "web_search", max_uses: MAX_SEARCHES }],
          messages,
        });
        for await (const event of stream) {
          if (event.type === "content_block_start" && event.content_block.type === "server_tool_use") {
            await send({ t: "status", v: "Searching the web…" });
          } else if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
            await send({ t: "text", v: event.delta.text });
          }
        }
        const message = await stream.finalMessage();
        for (const block of message.content) {
          if (block.type !== "text" || !block.citations) continue;
          for (const c of block.citations) if (c.url && !sources.has(c.url)) sources.set(c.url, c.title || c.url);
        }
        if (message.stop_reason === "pause_turn") {  // a long web search paused: send it back to continue
          messages.push({ role: "assistant", content: message.content });
          continue;
        }
        if (message.stop_reason === "refusal") await send({ t: "error", v: "The assistant can't help with that question." });
        else if (message.stop_reason === "max_tokens") await send({ t: "error", v: "The answer was cut short. Ask a narrower question." });
        break;
      }
      if (sources.size) await send({ t: "sources", v: [...sources].slice(0, 8).map(([url, title]) => ({ url, title })) });
    } catch (err) {
      const busy = err instanceof Anthropic.RateLimitError || (err instanceof Anthropic.APIError && err.status >= 500);
      await send({ t: "error", v: busy ? "The assistant is busy right now. Try again in a moment." : "Something went wrong. Try again." });
      console.error("chat failed", err instanceof Anthropic.APIError ? `${err.status} ${err.message}` : String(err));
    } finally {
      await send({ t: "done" });
      await writer.close();
    }
  };
  // Keep the Worker running until the answer is complete, while the response streams.
  ctx.waitUntil(run());

  return new Response(readable, {
    headers: {
      "content-type": "text/event-stream; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}
