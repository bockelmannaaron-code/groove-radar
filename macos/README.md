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

## Releasing an update

1. Add the new version at the top of `macos/changelog.json` (it becomes the app's What's New window and the release notes).
2. Commit and push, then run:
   ```sh
   sh macos/release.sh 1.0.2
   ```

Installed apps (1.0.1 and later) check GitHub at launch and every 6 hours, download the update in the background, check its signature, and ask to restart. If people choose Later, it installs when they quit. Gig data never needs a release: the app shows the live website.

**The update signing key** is `~/.groove-radar/update-signing-key`, created by the first build. Back it up (for example in your password manager). Never commit it. If it's lost, installed apps can't update themselves any more and everyone has to download the app again.

## Releases are unsigned (the current choice)

Groove Radar is sold without an Apple Developer ID, so it isn't notarized. The first time a customer opens it, macOS shows "Groove Radar Not Opened: Apple could not verify..." and they have to allow it once:

- **macOS 15 Sequoia and later:** System Settings → Privacy & Security → **Open Anyway**, then their Mac password.
- **macOS 13–14:** right-click the app → **Open** → **Open**.

The DMG includes `How to open Groove Radar.txt` with these steps (from `macos/How to open Groove Radar.txt`). Put the same steps on the sales page, so buyers know before they pay.

## Signing and notarizing (optional, if the warning ever becomes a problem)

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

Then every release is one command. The script finds the "Developer ID Application: Aaron Bockelmann" certificate in your keychain by itself (set `SIGN_ID` to use a different one):

```sh
NOTARY_PROFILE=groove-radar sh macos/build-app.sh
```

It signs the app, sends the DMG to Apple, waits for approval (usually a few minutes) and staples the approval to the DMG, so it opens cleanly even offline.

## Giving it out

Upload the DMG anywhere people can download it: your site (for example `site/download/`), GitHub Releases, or a file host. Users open the DMG and drag Groove Radar onto Applications.
