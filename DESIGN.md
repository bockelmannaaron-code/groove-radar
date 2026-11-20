---
name: Groove Radar
description: Every European gig from our tech house artists, on a night-blue field with one exotic pink signal.
colors:
  egyptian-blue: "#03203D"
  egyptian-blue-raised: "#0A2C50"
  frost: "#EEF4FA"
  stone-blue: "#639CC5"
  stone-blue-light: "#8DB6D6"
  hairline: "rgba(99, 156, 197, 0.3)"
  exotic-pink: "#FF2E88"
  exotic-pink-text: "#FF5CA2"
typography:
  display:
    fontFamily: "Schibsted Grotesk, Helvetica Neue, Arial, sans-serif"
    fontSize: "clamp(40px, 6.2vw, 88px)"
    fontWeight: 500
    lineHeight: 1
    letterSpacing: "-0.035em"
  headline:
    fontFamily: "Schibsted Grotesk, Helvetica Neue, Arial, sans-serif"
    fontSize: "clamp(36px, 5.4vw, 64px)"
    fontWeight: 500
    lineHeight: 1
    letterSpacing: "-0.035em"
  title:
    fontFamily: "Schibsted Grotesk, Helvetica Neue, Arial, sans-serif"
    fontSize: "clamp(22px, 3vw, 30px)"
    fontWeight: 500
    lineHeight: 1.05
    letterSpacing: "-0.035em"
  body:
    fontFamily: "Schibsted Grotesk, Helvetica Neue, Arial, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Schibsted Grotesk, Helvetica Neue, Arial, sans-serif"
    fontSize: "11.5px"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "0.06em"
rounded:
  sm: "6px"
  nav: "18px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "18px"
  lg: "24px"
  xl: "44px"
components:
  button-primary:
    backgroundColor: "{colors.exotic-pink}"
    textColor: "{colors.egyptian-blue}"
    rounded: "{rounded.sm}"
    padding: "13px 20px"
  button-primary-hover:
    backgroundColor: "{colors.frost}"
    textColor: "{colors.egyptian-blue}"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.frost}"
    rounded: "{rounded.sm}"
    padding: "13px 20px"
  chip:
    backgroundColor: "transparent"
    textColor: "{colors.frost}"
    rounded: "{rounded.sm}"
    padding: "7px 14px"
  chip-selected:
    backgroundColor: "{colors.frost}"
    textColor: "{colors.egyptian-blue}"
  tag-near:
    backgroundColor: "{colors.exotic-pink}"
    textColor: "{colors.egyptian-blue}"
    rounded: "{rounded.sm}"
    padding: "6px 12px"
  calendar-day-selected:
    backgroundColor: "{colors.frost}"
    textColor: "{colors.egyptian-blue}"
---

# Design System: Groove Radar

## Overview

**Creative North Star: "Night Radar"**

A screen you check late at night or first thing in the morning: a deep Egyptian Blue field, calm Stone Blue structure, and one exotic pink signal that lights up only for what matters, a gig near you or a ticket you can buy. It should feel like a radar display, not a poster: quiet until something is found.

Type is a single modern grotesk (Schibsted Grotesk) in big, tight, sentence-case headlines with small supporting text. Panels are Liquid Glass: frosted, edge-lit sheets floating over a few very faint drifting lights (two Stone Blue, one pink, kept apart so they never mix into purple). There are no photos, no illustrations and no colour gradients beyond those soft lights and the glass's own sheen. The palette comes from the Egyptian Blue / Stone Blue reference (`c2982341aeef401191bc52803749c2ee.MP4`), with its Scarlet Red replaced by Exotic Pink at the owner's request.

**Key Characteristics:**
- Dark Egyptian Blue for everyone; there is no light theme.
- Exotic Pink is the only warm colour and always means "near you", "new" or "act now".
- Stone Blue carries structure: the second headline line, rules, secondary text.
- One typeface, big sentence-case headlines, small tracked labels for metadata only.
- Liquid Glass panels (nav, hero panel, What's new, calendar, filters, artist cards, secondary buttons) over faint drifting light.
- Soft motion only: slow light drift, gentle fade-ups, a sliding filter highlight, a sheen on pink buttons.

## Colors

Two blues and one pink, at roughly 75 / 20 / 5.

### Primary
- **Exotic Pink** (`exotic-pink`): filled buttons, the "Near you" tag, "New" badges, near-you markers in the calendar, the radar blip, focus rings. Text on it is Egyptian Blue (white on this pink fails contrast).
- **Exotic Pink Text** (`exotic-pink-text`): pink used as text at small sizes (links, "near you" notes, the today date), lifted slightly so it reads on raised surfaces.

### Secondary
- **Stone Blue** (`stone-blue`): second headline line, the "Radar" in the wordmark, rules under facts, radar rings, secondary text.
- **Stone Blue Light** (`stone-blue-light`): small muted text such as notes and footnotes.

### Neutral
- **Egyptian Blue** (`egyptian-blue`): the page.
- **Egyptian Blue Raised** (`egyptian-blue-raised`): hover fills.
- **Frost** (`frost`): primary text, selected states, ghost-button outlines.
- **Hairline** (`hairline`): every divider and grid line.

### Named Rules
**The One Signal Rule.** Pink appears only on what someone should act on or notice: near you, new, on sale, focus. Anything else is a blue.

**The Three Colours Rule.** Egyptian Blue, Stone Blue and Exotic Pink (plus Frost for text). No fourth hue, no gradients.

## Typography

**Font:** Schibsted Grotesk (variable, self-hosted), with Helvetica Neue and Arial as fallbacks.

**Character:** Precise and modern; personality comes from scale and tight tracking, not from a second face.

### Hierarchy
- **Display** (500, clamp(40px, 6.2vw, 88px), 1): the hero verdict, two lines, second line in Stone Blue.
- **Headline** (500, clamp(36px, 5.4vw, 64px)): section heads and the calendar month; a Stone Blue word may follow ("What's new today").
- **Title** (500, clamp(22px, 3vw, 30px)): artist names in rows and cards, big dates, fact values.
- **Body** (400, 15 to 17px, 1.5): descriptions, news items, notes; keep under 70ch.
- **Label** (600, 11.5px, 0.06em, uppercase): metadata only, such as weekday names, fact labels, tags and status. Buttons, chips and navigation are sentence case.

### Named Rules
**The Sentence Case Rule.** Headlines, buttons and navigation are sentence case. Capitals are for tiny metadata labels only.

## Layout

One centred column (max 1240px, 16px side gutter respecting safe areas), sections 44px apart: sticky nav, hero, what's new, main view (calendar, list or artists), footer with legal links.

- The hero is a morning verdict: a two-line headline ("Quiet near home" / "7 changes today", second line Stone Blue) beside a glass card for the next near-you gig (tag, event, date, venue, distance, ticket and calendar buttons); one column under 760px. Near means zone munich or rheingau (up to ~150 km), everywhere.
- What's new shows the latest 3 changes with a "Show all" disclosure.
- Gig rows are full width, divided by hairlines: date on the left, details in the middle, status and ticket button on the right.
- The calendar is a 7-column hairline grid; on phones days shrink and events become dots (round pink dots for near you).
- Spacing steps: 8, 12, 18, 24 and 44px.

## Elevation & Depth

Depth is Liquid Glass. Panels are translucent Egyptian Blue (`rgba(16, 52, 88, 0.42)` with a faint white sheen) behind a 22px backdrop blur with 1.8 saturation, lit by a 1px edge highlight that is bright at the top-left and fades to a hint of pink at the bottom-right, plus an inset top highlight and a soft drop shadow. Behind everything, three large, very faint lights drift over 34 to 47 seconds. Where backdrop blur is unsupported, panels fall back to solid `#0D2E52`.

Glass is used for: the sticky nav, the hero's description-and-tickets panel, the What's new panel, the calendar grid, the filter control, artist cards, month buttons and ghost buttons. Dense lists (gig rows, news items) stay flat inside their panel.

### Motion
- Ease: `cubic-bezier(0.16, 1, 0.3, 1)` for everything soft.
- Sections fade up 28px once as they enter the viewport; views fade up 10px when switched; the selected day's gigs fade in with a small stagger.
- The filter control has a Frost highlight that slides to the chosen option (0.5s).
- Pink buttons lift 2px with a soft pink shadow and a light sheen sweeps across on hover; buttons press to 0.97.
- With reduced motion, the lights stop and everything appears without movement.

### Named Rules
**The Glass Over Light Rule.** Glass always sits over the faint drifting lights so it has something to refract; never glass on glass, never glass behind body text that isn't inside its own panel.

## Shapes

Controls and tags have softly rounded corners (6px); the navigation bar is the only larger radius (18px). Layout (sections, rows, calendar grid) is square. Rules are 1px hairlines; emphasis rules are 2 to 3px in Stone Blue.

## Components

### Buttons
- **Primary:** Exotic Pink with Egyptian Blue text, 15px 600, 13px × 20px. Hover turns it Frost.
- **Ghost:** transparent with a 1.5px Frost outline; hover turns outline and text pink.
- **Focus:** 2px pink outline, 3px offset.

### Chips
Filters (All gigs, Near me, On sale): 1.5px Frost outline, sentence case; selected chips fill Frost with Egyptian Blue text.

### Status tags
On sale: solid Frost. Sold out: muted outline, struck through. Unknown: Frost outline. New: solid pink.

### Navigation
Sticky Liquid Glass bar: wordmark ("Groove" in Frost, "Radar" in Stone Blue), view links with a 2px pink underline on the current view, gig count on the right. On phones the links scroll sideways in one row.

### Intro (signature)
"Every gig ● near you" builds letter by letter on Egyptian Blue with a pink dot dropping between the words; the words slide away, the dot ripples out into the Stone Blue radar rings, the pink blip pops and "Groove Radar" rises beside it, then the view flies through the ring into the page. About 2 seconds, skipped by any tap, click, scroll or key, never shown with reduced motion.

## Do's and Don'ts

### Do:
- **Do** keep the page Egyptian Blue for everyone.
- **Do** use Exotic Pink only for near you, new, on sale, primary actions and focus.
- **Do** put Egyptian Blue text on pink fills.
- **Do** write headlines, buttons and navigation in sentence case.
- **Do** mark near-you gigs with shape as well as colour (thick line, round dot).

### Don't:
- **Don't** use photos, illustrations, a fourth colour or decorative gradients (the faint background lights and the glass sheen are the only ones).
- **Don't** put white text on Exotic Pink.
- **Don't** stack glass on glass or let the background lights get bright enough to cut body-text contrast.
- **Don't** use all-caps for headlines or buttons.
