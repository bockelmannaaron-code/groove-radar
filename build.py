#!/usr/bin/env python3
"""Build the public Groove Radar website (drfeelpoo.uk) into ./site.

- site/index.html   from groove-radar.html (the one source of truth), with the
                    claude.ai database loader swapped for a fetch of data.json
                    and Google Fonts swapped for self-hosted fonts.
- site/data.json    from the database export in ./.export
                    (gigs/, music/, updates/, meta/run.json), written by the morning task.
- site/privacy.html, terms.html, cookies.html from ./legal, with owner details from site.json.
- site/fonts/       from ./fonts-src (Anton, Inter, Yellowtail; SIL Open Font License).

Run:  python3 build.py
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent
SRC = ROOT / "groove-radar.html"
EXPORT = ROOT / ".export"
LEGAL = ROOT / "legal"
FONTS = ROOT / "fonts-src"
SITE = ROOT / "site"
OWNER = json.loads((ROOT / "site.json").read_text(encoding="utf-8"))
GEO = {k: v for k, v in json.loads((ROOT / "geo.json").read_text(encoding="utf-8")).items() if not k.startswith("_")}

LATIN = "U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD"
LATIN_EXT = "U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F, U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C4, U+2113, U+2C60-2C7F, U+A720-A7FF"


def font_faces():
    rules = []
    for family, stem, weight in [("Schibsted Grotesk", "schibsted-grotesk", "400 900")]:
        for subset, rng in [("latin-ext", LATIN_EXT), ("latin", LATIN)]:
            rules.append(f'@font-face {{ font-family: "{family}"; font-style: normal; font-weight: {weight}; font-display: swap; '
                         f'src: url("fonts/{stem}-{subset}.woff2") format("woff2"); unicode-range: {rng}; }}')
    return "\n".join(rules)


DESC = "Every European gig and new release from our tech house artists, refreshed every morning."


def head(title, extra=""):
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{title}</title>
<meta name="description" content="{DESC}">
<meta name="theme-color" content="#03203D">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{DESC}">
<meta property="og:type" content="website">
<meta property="og:url" content="https://drfeelpoo.uk/">
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<link rel="preload" href="fonts/schibsted-grotesk-latin.woff2" as="font" type="font/woff2" crossorigin>
<style>
{font_faces()}
body {{ margin: 0; }} [hidden] {{ display: none !important; }}
</style>
{extra}"""


LOADER = """(async () => {
  const notice = $("notice");
  try {
    const r = await fetch("data.json?v=" + Date.now(), { cache: "no-store" });
    if (!r.ok) throw new Error("HTTP " + r.status);
    const d = await r.json();
    gigs = d.gigs || [];
    loadState = "ready";
    places = d.places || {};
    try {
      const ctl = new AbortController(); const t = setTimeout(() => ctl.abort(), 2500);
      const w = await (await fetch("/api/where", { cache: "no-store", signal: ctl.signal })).json(); clearTimeout(t);
      if (typeof w.lat === "number" && w.continent === "EU") { autoHere = { lat: w.lat, lon: w.lon, label: w.city || w.country || "your area", source: "auto" }; here = autoHere; }
    } catch (e) { /* no location: near stays the Munich and Rheingau home zones */ }
    if (location.hash.includes("@") || store.get("near")) readHash();
    music = {}; (d.music || []).forEach(m => { music[nkey(m.name)] = m; });
    updates = (d.updates || []).sort((a, b) => b.date.localeCompare(a.date)).slice(0, 14);
    meta = d.meta || null;
    const up = upcoming();
    if (up.length && !up.some(g => g.date === selDay)) { selDay = up[0].date; const dd = parseKey(up[0].date); cursor = new Date(dd.getFullYear(), dd.getMonth(), 1); }
    render(); renderNews();
    if (meta && meta.lastRun) {
      const t = new Date(meta.lastRun);
      if (!isNaN(t)) document.querySelector("footer p").append(" Last updated " + t.toLocaleString("en-GB", { weekday: "long", day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" }) + ".");
    }
  } catch (e) {
    loadState = "error"; render();
    notice.hidden = false;
    notice.textContent = "The gig list couldn't be loaded. Check your connection, then try again. ";
    const again = document.createElement("button"); again.className = "cta ghost"; again.textContent = "Try again"; again.onclick = () => location.reload(); notice.append(again);
  }
})();
</script>"""


def build_index():
    src = SRC.read_text(encoding="utf-8")
    start = src.index("(async () => {\n  const db = await claude.use(\"db\");")
    end = src.index("})();\n</script>", start) + len("})();\n</script>")
    page = src[:start] + LOADER + src[end:]
    body_start = page.index('<a class="skip"')
    head_bits = page[:body_start]
    head_bits = re.sub(r'<meta name="claude:[^>]*>\n?', "", head_bits)
    head_bits = re.sub(r'<link rel="preconnect"[^>]*>\n?', "", head_bits)
    head_bits = re.sub(r'<link rel="stylesheet" href="https://fonts\.googleapis\.com[^>]*>\n?', "", head_bits)
    head_bits = re.sub(r"<title>[^<]*</title>\n?", "", head_bits)
    html = head("Groove Radar") + head_bits + "</head>\n<body>\n" + page[body_start:] + "\n</body>\n</html>\n"
    if "googleapis" in html or "gstatic" in html or "claude.use" in html:
        sys.exit("Build check failed: index.html still references Google Fonts or claude.ai.")
    # Device storage goes only through the `store` helper, and every key it uses must be listed on the cookie page.
    if html.count("localStorage") != 3:
        sys.exit("Build check failed: localStorage is used outside the store helper.")
    cookie_page = (LEGAL / "cookies.html").read_text(encoding="utf-8")
    missing = [k for k in set(re.findall(r'store\.(?:get|set)\("([a-z-]+)"', html)) if f"gr-{k}" not in cookie_page]
    if missing:
        sys.exit(f"Build check failed: stored keys not listed on the cookie page: {', '.join(sorted(missing))}")
    return html


LEGAL_CSS = """<style>
/* The legal pages wear the main page's system (groove-radar.html): same tokens, drifting lights, glass nav,
   glass reading panel, section heads and footer. Keep these in step with the main page when it changes. */
:root {
  --ground: #03203D; --ink: #EEF4FA; --ink-2: #639CC5; --muted: #8DB6D6; --line: rgba(99, 156, 197, 0.3);
  --stone: #639CC5; --accent: #FF2E88; --accent-ink: #FF5CA2; --on-accent: #03203D;
  --display: "Schibsted Grotesk", "Helvetica Neue", Arial, sans-serif; --body: var(--display);
  --fs-label: 0.75rem; --fs-meta: 0.8125rem; --fs-ui: 0.875rem; --fs-body: 1rem; --fs-subtitle: 1.25rem;
  --fs-title: clamp(1.375rem, 3vw, 1.875rem); --fs-figure: clamp(2rem, 4vw, 2.5rem);
  --fs-headline: clamp(2.25rem, 5.4vw, 4rem); --fs-wordmark: clamp(3.5rem, 13vw, 11.875rem);
  --r: 6px; --r-nav: 18px; --r-panel: 20px;
  color-scheme: dark;
}
html { scrollbar-color: var(--ink-2) var(--ground); }
@media (prefers-reduced-motion: no-preference) { html { scroll-behavior: smooth; } } /* section list and skip link glide */
body { background: var(--ground); color: var(--ink); font-family: var(--body); font-size: var(--fs-body); line-height: 1.6; -webkit-font-smoothing: antialiased; }
::selection { background: var(--accent); color: var(--on-accent); }
a { color: var(--accent-ink); text-underline-offset: 3px; text-decoration-thickness: 1.5px; }
a:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; }
.cap { text-transform: uppercase; letter-spacing: 0.06em; font-size: var(--fs-label); font-weight: 600; }
.skip { position: absolute; left: 12px; top: -60px; z-index: 20; background: var(--accent); color: var(--on-accent); padding: 10px 14px; border-radius: var(--r); font-size: var(--fs-ui); font-weight: 600; text-decoration: none; }
.skip:focus { top: 12px; }
.page { position: relative; z-index: 1; max-width: 1240px; margin: 0 auto; padding-block: 18px 40px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); display: flex; flex-direction: column; gap: 44px; }
h2[id] { scroll-margin-top: 96px; }

/* Drifting lights behind the glass */
.amb { position: fixed; inset: 0; z-index: 0; pointer-events: none; overflow: hidden; }
.amb i { position: absolute; border-radius: 50%; opacity: 0.2; }
.amb i:nth-child(1) { width: 62vmax; height: 62vmax; left: -18vmax; top: -16vmax; background: radial-gradient(circle, #639CC5 0%, rgba(99, 156, 197, 0) 66%); animation: amb-a 34s ease-in-out infinite alternate; }
.amb i:nth-child(2) { width: 46vmax; height: 46vmax; right: -14vmax; top: 34vh; background: radial-gradient(circle, #FF2E88 0%, rgba(255, 46, 136, 0) 64%); opacity: 0.13; animation: amb-b 41s ease-in-out infinite alternate; }
.amb i:nth-child(3) { width: 50vmax; height: 50vmax; left: -10vmax; bottom: -22vmax; background: radial-gradient(circle, #639CC5 0%, rgba(99, 156, 197, 0) 66%); opacity: 0.14; animation: amb-c 47s ease-in-out infinite alternate; }
@keyframes amb-a { to { transform: translate(9vmax, 6vmax) scale(1.08); } }
@keyframes amb-b { to { transform: translate(-7vmax, -9vmax) scale(0.94); } }
@keyframes amb-c { to { transform: translate(8vmax, -5vmax) scale(1.06); } }
@media (prefers-reduced-motion: reduce) { .amb i { animation: none; } html { scroll-behavior: auto; } }

/* Glass, exactly as on the main page */
nav.top, .doc {
  --gl-bg: rgba(16, 52, 88, 0.42); position: relative;
  background: linear-gradient(150deg, rgba(238, 244, 250, 0.11), rgba(238, 244, 250, 0.02) 46%, rgba(238, 244, 250, 0.05)), var(--gl-bg);
  -webkit-backdrop-filter: blur(22px) saturate(1.8) brightness(1.06); backdrop-filter: blur(22px) saturate(1.8) brightness(1.06);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.24), inset 0 -1px 0 rgba(255, 255, 255, 0.05), inset 0 0 0 1px rgba(238, 244, 250, 0.1), 0 18px 40px -22px rgba(0, 6, 20, 0.7);
}
nav.top::before, .doc::before {
  content: ""; position: absolute; inset: 0; border-radius: inherit; padding: 1px; pointer-events: none;
  background: linear-gradient(135deg, rgba(255, 255, 255, 0.5), rgba(255, 255, 255, 0) 32%, rgba(255, 255, 255, 0) 68%, rgba(255, 46, 136, 0.28));
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0); -webkit-mask-composite: xor; mask: linear-gradient(#fff 0 0) content-box exclude, linear-gradient(#fff 0 0); }
@supports not ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) { nav.top, .doc { --gl-bg: #0D2E52; } }

/* Nav */
nav.top { position: sticky; top: 8px; z-index: 10; display: flex; align-items: center; justify-content: space-between; gap: 10px 18px; flex-wrap: wrap; padding: 11px 18px; margin-inline: -8px; border-radius: var(--r-nav); }
.brand { font-family: var(--display); font-size: var(--fs-subtitle); font-weight: 600; letter-spacing: -0.03em; color: var(--ink); text-decoration: none; }
.brand span { color: var(--stone); }
.navlinks { display: flex; gap: 6px 26px; flex-wrap: wrap; align-items: center; }
.navlinks a { padding: 4px 0; font-size: var(--fs-ui); font-weight: 500; color: var(--ink); text-decoration: none; border-bottom: 2px solid transparent; }
.navlinks a[aria-current="page"] { border-bottom-color: var(--accent); }
.navlinks a:hover { color: var(--muted); }
.navlinks .back { padding-left: 26px; box-shadow: inset 1px 0 0 var(--line); }
.navlinks .short { display: none; }

/* Section head, as on the main page */
.shead { border-bottom: 1px solid var(--line); padding-bottom: 10px; margin-top: 12px; }
.shead h1 { margin: 0; font-family: var(--display); font-weight: 500; letter-spacing: -0.035em; font-size: var(--fs-headline); line-height: 1; text-wrap: balance; }
.shead h1 em { font-style: normal; color: var(--stone); font-weight: 400; }

/* Reading panel: the date and section list on the left, the text on the right (like What's new) */
.doc { display: grid; grid-template-columns: 220px minmax(0, 1fr); gap: 20px 32px; margin-top: 24px; padding: 26px; border-radius: var(--r-panel); }
.doc aside { display: flex; flex-direction: column; gap: 6px; }
.doc aside .cap { color: var(--muted); }
.doc aside b { font-family: var(--display); font-weight: 500; letter-spacing: -0.035em; font-size: var(--fs-figure); line-height: 1; }
.doc aside .yr { font-size: var(--fs-ui); font-weight: 500; color: var(--muted); }
.toc { position: sticky; top: 96px; margin-top: 22px; padding-top: 14px; border-top: 1px solid var(--line); display: flex; flex-direction: column; gap: 2px; }
.toc .cap { margin-bottom: 6px; }
.toc a { padding: 4px 0; font-size: var(--fs-ui); font-weight: 500; line-height: 1.35; color: var(--ink); text-decoration: none; }
.toc a:hover { color: var(--muted); }
.text { min-width: 0; }
.text > :first-child { margin-top: 0; }
.text h2 { font-family: var(--display); font-weight: 500; letter-spacing: -0.035em; font-size: var(--fs-title); line-height: 1.15; margin: 36px 0 10px; padding-top: 16px; border-top: 1px solid var(--line); text-wrap: balance; }
.text > h2:first-child { padding-top: 0; border-top: 0; }
.text p, .text li { max-width: 68ch; text-wrap: pretty; }
.text p { margin: 0 0 12px; }
.text ul { margin: 0 0 12px; padding-left: 1.2em; }
.text li { margin-bottom: 6px; }
.text li::marker { color: var(--stone); }
.text strong { font-weight: 600; }

/* Footer, as on the main page */
footer { border-top: 1px solid var(--line); padding-top: 16px; display: flex; flex-direction: column; gap: 10px; }
footer .word { font-family: var(--display); font-weight: 500; letter-spacing: -0.035em; font-size: var(--fs-wordmark); line-height: 0.9; overflow-wrap: anywhere; }
footer .word .r { color: var(--stone); }
footer p { margin: 0; font-size: var(--fs-ui); line-height: 1.5; color: var(--ink-2); max-width: 62ch; }
footer .legal { display: flex; flex-wrap: wrap; gap: 6px 22px; }
footer .legal a { display: inline-block; padding: 6px 0; color: var(--ink); font-size: var(--fs-ui); font-weight: 500; }
footer .legal a[aria-current="page"] { text-decoration-color: var(--accent); }

@media (max-width: 860px) {
  .doc { grid-template-columns: 1fr; padding: 22px 18px; }
  .doc aside { flex-direction: row; align-items: baseline; flex-wrap: wrap; gap: 4px 10px; }
  .doc aside b { font-size: var(--fs-subtitle); letter-spacing: -0.02em; }
  .toc { display: none; }
}
@media (max-width: 640px) {
  nav.top { top: 6px; padding: 10px 14px; }
  .navlinks { order: 3; width: 100%; flex-wrap: nowrap; gap: 20px; }
  .navlinks a { white-space: nowrap; display: inline-flex; align-items: center; min-height: 44px; padding: 0; }
  .navlinks .long { display: none; }
  .navlinks .short { display: inline; }
  .navlinks .back { margin-left: auto; padding-left: 20px; }
  h2[id] { scroll-margin-top: 120px; }
  footer .legal a { display: inline-flex; align-items: center; min-height: 44px; padding: 0; }
}
</style>"""

LEGAL_LINKS = [("privacy.html", "Privacy policy", "Privacy"), ("terms.html", "Terms and conditions", "Terms"), ("cookies.html", "Cookie policy", "Cookies")]
FOOT_TEXT = ("Every European gig and new release from our tech house artists, refreshed every morning from Songkick, "
             "venue and ticket sites, and Beatport. Ticket status changes quickly, so check the ticket page before you buy.")


def build_legal(path):
    text = path.read_text(encoding="utf-8")
    title = re.search(r"<!-- title: (.*?) -->", text).group(1)
    text = re.sub(r"<!-- title: .*? -->\n?", "", text)
    text = text.replace("{{OWNER_NAME}}", OWNER["ownerName"]).replace("{{OWNER_EMAIL}}", OWNER["ownerEmail"])
    # The heading and date move into the page frame; the rest of the file is the reading text.
    text = re.sub(r"<h1>.*?</h1>\n?", "", text)
    m = re.search(r'<p class="updated">Last updated (\d{1,2}) (\w+) (\d{4})</p>\n?', text)
    if not m:
        sys.exit(f"Build check failed: {path.name} needs a 'Last updated D Month YYYY' line.")
    text = text.replace(m.group(0), "")
    day, month, year = m.groups()
    # Every section head gets an id so the section list can link to it.
    toc = []
    def anchor(h):
        label = re.sub(r"<[^>]+>", "", h.group(1))
        slug = re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-")
        toc.append((slug, label))
        return f'<h2 id="{slug}">{h.group(1)}</h2>'
    text = re.sub(r"<h2>(.*?)</h2>", anchor, text)
    words = title.rsplit(" ", 1)
    heading = f"{words[0]} <em>{words[1]}</em>" if len(words) == 2 else title
    cur = lambda h: ' aria-current="page"' if h == path.name else ""
    nav = "".join(f'<a href="{h}"{cur(h)}><span class="long">{t}</span><span class="short">{s}</span></a>' for h, t, s in LEGAL_LINKS)
    foot = "".join(f'<a href="{h}"{cur(h)}>{t}</a>' for h, t, _ in LEGAL_LINKS)
    toc_html = "".join(f'<a href="#{slug}">{label}</a>' for slug, label in toc)
    return (head(f"{title} | Groove Radar", LEGAL_CSS) + "</head>\n<body>\n"
            '<a class="skip" href="#text">Skip to the text</a>\n'
            '<div class="amb" aria-hidden="true"><i></i><i></i><i></i></div>\n<div class="page">\n'
            f'<nav class="top" aria-label="Groove Radar"><a class="brand" href="./">Groove <span>Radar</span></a>'
            f'<div class="navlinks">{nav}<a class="back" href="./"><span class="long">Back to the gigs</span><span class="short">Gigs</span></a></div></nav>\n'
            f'<main>\n<header class="shead"><h1>{heading}</h1></header>\n'
            f'<div class="doc">\n<aside><span class="cap">Last updated</span><b>{day} {month[:3]}</b><span class="yr">{year}</span>'
            f'<nav class="toc" aria-label="On this page"><span class="cap">On this page</span>{toc_html}</nav></aside>\n'
            f'<div class="text" id="text">\n{text}</div>\n</div>\n</main>\n'
            f'<footer>\n<div class="word" aria-hidden="true">Groove <span class="r">Radar</span></div>\n<p>{FOOT_TEXT}</p>\n'
            f'<nav class="legal" aria-label="Legal">{foot}</nav>\n</footer>\n</div>\n</body>\n</html>\n')


def no_em_dashes(value):
    if isinstance(value, str):
        # No em dashes and no arrow symbols or emoji in stored text: the page draws its own link icons.
        return re.sub(r"\s*[\u2190-\u21FF\u2794-\u27BF\u2B00-\u2BFF\uFE0F\U0001F000-\U0001FAFF]+", "", value.replace(" — ", ", ").replace("—", ", "))
    if isinstance(value, list):
        return [no_em_dashes(v) for v in value]
    if isinstance(value, dict):
        return {k: no_em_dashes(v) for k, v in value.items()}
    return value


def read_dir(name):
    d = EXPORT / name
    if not d.is_dir():
        return []
    out = []
    for f in sorted(d.glob("*.json")):
        doc = json.loads(f.read_text(encoding="utf-8"))
        if isinstance(doc, dict) and "data" in doc and "id" in doc:  # tolerate {id, data} shape
            doc = {"id": doc["id"], **doc["data"]}
        doc.setdefault("id", f.stem)
        out.append(doc)
    return out


def build_data():
    gigs = read_dir("gigs")
    if not gigs:
        sys.exit("No gigs found in .export/gigs: refusing to publish an empty calendar.")
    meta = read_dir("meta")
    missing = set()
    for g in gigs:  # coordinates for "near you" from any visitor; a gig's own lat/lon wins
        if isinstance(g.get("lat"), (int, float)) and isinstance(g.get("lon"), (int, float)):
            continue
        key = f'{g.get("city")}|{g.get("country")}'
        if key in GEO:
            g["lat"], g["lon"] = GEO[key]
        else:
            missing.add(key)
    if missing:
        print("No coordinates for: " + ", ".join(sorted(missing)) + " (add them to geo.json)")
    return no_em_dashes({
        "places": GEO,
        "gigs": gigs,
        "music": read_dir("music"),
        "updates": read_dir("updates"),
        "meta": next((m for m in meta if m["id"] == "run"), None),
    })


FAVICON = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="#03203D"/><circle cx="32" cy="32" r="18" fill="none" stroke="#639CC5" stroke-width="4"/><circle cx="32" cy="32" r="8" fill="none" stroke="#639CC5" stroke-width="4"/><circle cx="44" cy="22" r="6" fill="#FF2E88"/></svg>"""


def touch_icon():
    """180px PNG for iPhone home screens (Safari ignores SVG there). Rendered with macOS Quick Look."""
    png = ROOT / "apple-touch-icon.png"
    if not png.exists():
        tmp = ROOT / ".icon-tmp"
        tmp.mkdir(exist_ok=True)
        svg = tmp / "icon.svg"
        svg.write_text(FAVICON.replace('rx="14" ', ""), encoding="utf-8")  # iOS rounds the corners itself
        subprocess.run(["qlmanage", "-t", "-s", "180", "-o", str(tmp), str(svg)], capture_output=True)
        made = tmp / "icon.svg.png"
        if made.exists():
            shutil.move(str(made), png)
        shutil.rmtree(tmp, ignore_errors=True)
    if png.exists():
        shutil.copy(png, SITE / "apple-touch-icon.png")


def main():
    if SITE.exists():
        shutil.rmtree(SITE)
    SITE.mkdir()
    (SITE / "index.html").write_text(build_index(), encoding="utf-8")
    for page in ["privacy", "terms", "cookies"]:
        (SITE / f"{page}.html").write_text(build_legal(LEGAL / f"{page}.html"), encoding="utf-8")
    data = build_data()
    (SITE / "data.json").write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    shutil.copytree(FONTS, SITE / "fonts")
    (SITE / "favicon.svg").write_text(FAVICON, encoding="utf-8")
    touch_icon()
    (SITE / "_headers").write_text(
        "/data.json\n  Cache-Control: no-cache\n"
        "/fonts/*\n  Cache-Control: public, max-age=31536000, immutable\n"
        "/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n"
        "  Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()\n"
        "  Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; "
        "font-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'none'\n",
        encoding="utf-8")
    print(f"Built site/: {len(data['gigs'])} gigs, {len(data['music'])} artists, {len(data['updates'])} updates, 3 legal pages")


if __name__ == "__main__":
    main()
