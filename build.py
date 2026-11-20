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
    if (location.hash.includes("@")) readHash();
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
    if "googleapis" in html or "gstatic" in html or "claude.use" in html or "localStorage" in html:
        sys.exit("Build check failed: index.html still references Google Fonts, claude.ai or localStorage.")
    return html


LEGAL_CSS = """<style>
:root { --ground: #03203D; --ink: #EEF4FA; --ink-2: #8DB6D6; --line: rgba(99, 156, 197, 0.3); --plum: #639CC5; --accent: #FF2E88; --accent-ink: #FF5CA2; color-scheme: dark; }
body { background: var(--ground); color: var(--ink); font-family: "Schibsted Grotesk", "Helvetica Neue", Arial, sans-serif; font-size: 1rem; line-height: 1.6; -webkit-font-smoothing: antialiased; }
::selection { background: var(--accent); color: #03203D; }
.wrap { max-width: 720px; margin: 0 auto; padding: 18px max(16px, env(safe-area-inset-left, 0px)) 56px; }
.top { display: flex; justify-content: space-between; align-items: center; gap: 12px; padding-bottom: 12px; border-bottom: 1px solid var(--line); }
.brand { font-size: 1.25rem; font-weight: 600; letter-spacing: -0.03em; color: var(--ink); text-decoration: none; }
.brand span { color: var(--plum); }
.back { font-size: 0.875rem; font-weight: 500; color: var(--ink); }
h1 { font-size: clamp(2.25rem, 5.4vw, 4rem); text-wrap: balance; font-weight: 500; letter-spacing: -0.035em; line-height: 1; margin: 40px 0 10px; }
h2 { font-size: clamp(1.375rem, 3vw, 1.875rem); font-weight: 500; letter-spacing: -0.035em; line-height: 1.2; margin: 36px 0 8px; }
.updated { font-size: 0.875rem; font-weight: 500; color: var(--ink-2); margin: 0 0 8px; }
p, li { max-width: 68ch; text-wrap: pretty; }
ul { padding-left: 1.2em; }
a { color: var(--accent-ink); text-underline-offset: 3px; text-decoration-thickness: 1.5px; }
a:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; }
footer { margin-top: 48px; padding-top: 14px; border-top: 1px solid var(--line); }
footer nav { display: flex; flex-wrap: wrap; gap: 4px 24px; }
footer a { display: inline-block; padding: 6px 0; color: var(--ink); font-size: 0.875rem; font-weight: 500; }
footer a[aria-current="page"] { text-decoration-color: var(--accent); }
</style>"""


def build_legal(path):
    text = path.read_text(encoding="utf-8")
    title = re.search(r"<!-- title: (.*?) -->", text).group(1)
    text = re.sub(r"<!-- title: .*? -->\n?", "", text)
    text = text.replace("{{OWNER_NAME}}", OWNER["ownerName"]).replace("{{OWNER_EMAIL}}", OWNER["ownerEmail"])
    links = [("privacy.html", "Privacy policy"), ("terms.html", "Terms and conditions"), ("cookies.html", "Cookie policy")]
    current = ' aria-current="page"'
    foot = "".join(f'<a href="{h}"{current if h == path.name else ""}>{t}</a>' for h, t in links)
    return (head(f"{title} | Groove Radar", LEGAL_CSS) + "</head>\n<body>\n<div class=\"wrap\">\n"
            '<header class="top"><a class="brand" href="./">Groove <span>Radar</span></a><a class="back" href="./">Back to the gigs</a></header>\n'
            f"<main>\n{text}</main>\n<footer><nav aria-label=\"Legal\">{foot}</nav></footer>\n</div>\n</body>\n</html>\n")


def no_em_dashes(value):
    if isinstance(value, str):
        return value.replace(" — ", ", ").replace("—", ", ")
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
