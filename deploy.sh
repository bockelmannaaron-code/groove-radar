#!/bin/sh
# Build the Groove Radar website and upload it to Cloudflare (Workers static assets, settings in wrangler.jsonc).
# Wrangler is pinned to 4.40.0: 4.165.0 fails after every deploy with "This Worker does not exist" (code 10007).
# One-time setup: `npx wrangler login` (opens your browser to sign in to Cloudflare).
set -e
cd "$(dirname "$0")"
python3 build.py
npx --yes wrangler@4.40.0 deploy
