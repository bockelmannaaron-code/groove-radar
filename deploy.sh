#!/bin/sh
# Build the Groove Radar website and upload it to Cloudflare (Workers static assets, settings in wrangler.jsonc).
# Wrangler is pinned to 4.40.0: 4.165.0 fails after every deploy with "This Worker does not exist" (code 10007).
# One-time setup: `npx wrangler login` (opens your browser to sign in to Cloudflare), and for Ask Groove Radar
# `npx wrangler@4.40.0 secret put ANTHROPIC_API_KEY` (paste the key from console.anthropic.com when asked).
set -e
cd "$(dirname "$0")"
python3 build.py
npm ci --no-audit --no-fund --silent  # the Worker's dependencies (Anthropic SDK for chat.js), bundled by wrangler
npx --yes wrangler@4.40.0 deploy
