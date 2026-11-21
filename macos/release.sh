#!/bin/sh
# Publish a new Groove Radar for Mac release. Installed apps find it within 6 hours (or at their
# next launch), download it in the background and offer to restart.
#
#   sh macos/release.sh 1.0.2
#
# The release notes (and the app's What's New window) come from macos/changelog.json:
# add the new version at the top of it first.
#
# Commit and push first: the release is tagged at the current commit.
set -e
cd "$(dirname "$0")/.."
VERSION="$1"
[ -n "$VERSION" ] || { echo "usage: sh macos/release.sh <version>  (add the version to macos/changelog.json first)"; exit 1; }
NOTES="$(python3 -c 'import json,sys; e=[x for x in json.load(open("macos/changelog.json")) if x["version"]==sys.argv[1]]; sys.exit("Add version "+sys.argv[1]+" to macos/changelog.json first.") if not e else print("### What\x27s new\n" + "\n".join("- "+c for c in e[0]["changes"]))' "$VERSION")"
[ -z "$(git status --porcelain)" ] || { echo "Commit your changes first."; exit 1; }
git push -q
VERSION="$VERSION" sh macos/build-app.sh
gh release create "v$VERSION" "dist/Groove-Radar-$VERSION.dmg" dist/update.json \
  --target "$(git rev-parse HEAD)" --title "Groove Radar $VERSION for Mac" \
  --notes "$NOTES

**New here?** Download Groove-Radar-$VERSION.dmg, open it and drag Groove Radar onto Applications. The first time, macOS asks you to allow it: see \"How to open Groove Radar.txt\" in the DMG.

**Already installed?** Nothing to do: Groove Radar updates itself and asks to restart.

SHA-256: \`$(shasum -a 256 "dist/Groove-Radar-$VERSION.dmg" | cut -d' ' -f1)\`"
echo "Published v$VERSION"
