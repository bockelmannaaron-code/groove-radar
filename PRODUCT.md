# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Primarily the owner, a tech house fan based around Munich and the Rheingau, plus a few friends who go to gigs with them. It is a personal, shared tracker, not a public product: the artist list and "near" zones are the owner's own.

## Product Purpose

Groove Radar keeps track of every European gig (and new release) from a hand-picked list of tech house artists, refreshed every morning, so nobody in the group misses a show worth going to.

Success means:

- **Catching gigs nearby:** no show near Munich or the Rheingau is missed, and tickets are bought before they sell out.
- **Planning trips abroad:** gigs elsewhere in Europe that are worth travelling for are easy to spot.
- **A daily glance:** a quick morning check shows what changed since yesterday.

## Positioning

A single view built around one group's own artists and home base. Gigs are pulled from several sources at once (Songkick, venue and ticket sites, Beatport) and ranked by how close they are, instead of one platform's catalogue for every user.

## Operating Context

- Opened as a published Claude Artifact (`groove-radar.html`) on claude.ai. Viewers must be signed in to claude.ai for the data to load.
- Data lives in the artifact's shared database (`gigs`, `music`, `updates`, `meta/run` collections) and is refreshed every morning by a scheduled job.
- Typical use: a short check in the morning, then sometimes a deeper look when planning a weekend or a trip.
- Ticket status changes quickly; the page tells people to check the ticket page before buying.

## Capabilities and Constraints

- Views: month calendar, list of all gigs, and per-artist view; a "What's new" feed of recent changes.
- Filters: all gigs, near me, on sale.
- "Near" is a fixed set of zones (`munich`, `rheingau`) with a distance in km; near gigs are prioritised in sorting and in the hero.
- Gig status: available, sold out, or unknown. Gigs added in the last 3 days count as new.
- New releases link out to Beatport, Bandcamp, Traxsource and Juno searches. This is a secondary feature, not one of the core jobs above.
- The artist list is hard-coded in the page.
- Single self-contained HTML file; fonts from Google Fonts; no build step.
- Undecided: whether friends should get their own near zones or artist lists.

## Brand Commitments

- Name: **Groove Radar**.

## Evidence on Hand

- `groove-radar.html`: the current working page.
- `c2982341aeef401191bc52803749c2ee.MP4`: a 21-second portrait video the owner uses as a design reference.
- No testimonials, user numbers or press exist; do not invent any.

## Product Principles

1. Near beats far: gigs the group can actually get to come first everywhere.
2. Make every state honest: sold out, unknown and stale data are shown plainly, never hidden.
3. Glanceable first, deep second: the morning check takes seconds; planning detail is one tap away.
4. Built for a small group, not for scale: personal choices (artists, zones) are fine to hard-code.
