# Groove Radar for macOS

A native Mac app (`Groove Radar.app`) shipped as a drag-to-Applications DMG.

- Opens the live site (drfeelpoo.uk), so gigs are always current, with no app update needed.
- With no internet, it shows the copy of the site bundled inside the app instead.
- Ticket, Beatport and other outside links open in the user's default browser.
- Universal (Apple silicon + Intel), macOS 13 Ventura or later, about 350 KB.
- Users install nothing else: everything the app needs is inside it.

## Build

```sh
sh macos/build-app.sh
```

This writes `dist/Groove-Radar-1.0.0.dmg`. It only needs Apple's Command Line Tools (`xcode-select --install`), not Xcode. Set `VERSION=1.1.0` to change the version number.

A build without signing works on your own Mac. **On anyone else's Mac, macOS will block it** ("Apple could not verify..."), and they'd have to allow it in System Settings → Privacy & Security. For a public download you need to sign and notarize it.

## Signing and notarizing (one-time setup)

1. Join the Apple Developer Program at https://developer.apple.com/programs/ ($99/year). Required for any Mac app that strangers download without warnings, even a free one.
2. Install Xcode from the App Store, open **Xcode → Settings → Accounts**, add your Apple ID, then **Manage Certificates → + → Developer ID Application**.
3. Check the certificate is in your keychain and copy its name:
   ```sh
   security find-identity -v -p codesigning
   ```
4. Create an app-specific password at https://account.apple.com (Sign-In and Security → App-Specific Passwords), then save it for the notary tool:
   ```sh
   xcrun notarytool store-credentials groove-radar --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID
   ```

Then every release is one command:

```sh
SIGN_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=groove-radar sh macos/build-app.sh
```

It signs the app, sends the DMG to Apple, waits for approval (usually a few minutes) and staples the approval to the DMG, so it opens cleanly even offline.

## Giving it out

Upload the DMG anywhere people can download it: your site (for example `site/download/`), GitHub Releases, or a file host. Users open the DMG and drag Groove Radar onto Applications.
