#!/bin/sh
# Build "Groove Radar.app" and a drag-to-Applications DMG in ./dist.
#
# Needs only Apple's Command Line Tools (swiftc, hdiutil, iconutil): no Xcode, no other dependencies.
# The app is a universal binary (Apple silicon + Intel) for macOS 13 Ventura and later.
#
#   sh macos/build-app.sh                       unsigned build (fine for testing on this Mac)
#
# For a public download, sign with your Developer ID and notarize with Apple, so people can open
# it without a security warning (see macos/README.md for the one-time setup):
#
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=groove-radar sh macos/build-app.sh
#
# Optional: VERSION=1.2.0 (default 1.0.0).
set -e
cd "$(dirname "$0")/.."
ROOT="$PWD"
VERSION="${VERSION:-1.0.0}"
BUILD_NUM="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
NAME="Groove Radar"
BUNDLE_ID="uk.drfeelpoo.grooveradar"
OUT="$ROOT/dist"
WORK="$OUT/work"
APP="$OUT/$NAME.app"
DMG="$OUT/Groove-Radar-$VERSION.dmg"

rm -rf "$OUT"
mkdir -p "$WORK" "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "1/6 Building the website copy that ships inside the app"
python3 build.py
cp -R site "$APP/Contents/Resources/site"
rm -f "$APP/Contents/Resources/site/_headers"

echo "2/6 Compiling (Apple silicon + Intel)"
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" -framework AppKit -framework WebKit \
    macos/main.swift -o "$WORK/GrooveRadar-$arch"
done
lipo -create "$WORK/GrooveRadar-arm64" "$WORK/GrooveRadar-x86_64" -output "$APP/Contents/MacOS/GrooveRadar"

echo "3/6 Making the app icon"
python3 - "$WORK/icon.svg" <<'PY'
import sys, importlib.util, pathlib
spec = importlib.util.spec_from_file_location("b", "build.py"); b = importlib.util.module_from_spec(spec); spec.loader.exec_module(b)
# macOS icon grid: artwork inset to 824/1024 with rounded corners
svg = b.FAVICON.replace('viewBox="0 0 64 64"', 'viewBox="-7.75 -7.75 79.5 79.5" width="1024" height="1024"')
pathlib.Path(sys.argv[1]).write_text(svg)
PY
qlmanage -t -s 1024 -o "$WORK" "$WORK/icon.svg" >/dev/null 2>&1
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$WORK/icon.svg.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$WORK/icon.svg.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "4/6 Writing Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>GrooveRadar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUM</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>© $(date +%Y) Groove Radar</string>
</dict>
</plist>
PLIST

echo "5/6 Signing"
if [ -n "$SIGN_ID" ]; then
  cat > "$WORK/entitlements.plist" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.network.client</key><true/>
</dict></plist>
ENT
  codesign --force --options runtime --timestamp --entitlements "$WORK/entitlements.plist" --sign "$SIGN_ID" "$APP"
else
  echo "   No SIGN_ID: ad-hoc signing. Fine on this Mac; other Macs will warn before opening it."
  codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"

echo "6/6 Making the DMG"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$NAME" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
if [ -n "$SIGN_ID" ]; then
  codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
fi
if [ -n "$SIGN_ID" ] && [ -n "$NOTARY_PROFILE" ]; then
  echo "   Sending to Apple for notarization (usually a few minutes)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi
rm -rf "$WORK"

echo
echo "Done: $DMG ($(du -h "$DMG" | cut -f1))"
