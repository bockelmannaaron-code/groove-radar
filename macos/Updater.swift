// Automatic updates for Groove Radar on macOS, with no third-party framework.
//
// How it works:
// 1. At launch and every 6 hours, the app reads update.json from the newest GitHub release:
//    { "version": "1.0.2", "url": "<.dmg download URL>", "signature": "<base64>" }
// 2. If that version is newer, it downloads the DMG quietly in the background and checks its
//    Ed25519 signature against the public key built into the app (Info.plist GRUpdatePublicKey).
//    Only DMGs signed with the private key on the publisher's Mac are accepted, so a changed
//    release or download can never install code.
// 3. It copies the new app out of the DMG and installs it without asking:
//    - if Groove Radar isn't the app in front, it restarts into the new version straight away,
//      quietly in the background (no window jumps to the front);
//    - if it is in front, it waits until you switch to another app, then does the same;
//    - if you quit first, the new version is put in place as it quits.
//    After an update, the What's New window shows what changed (Changelog.swift).
//    Check for Updates… in the menu still asks before restarting, since you asked for it.
//
// The swap runs in a small shell script after the app exits: the old app is kept until the new
// one is copied in, and put back if the copy fails.
import AppKit
import CryptoKit

final class Updater {
    static let feed = URL(string: "https://github.com/bockelmannaaron-code/groove-radar/releases/latest/download/update.json")!
    static let releasesPage = URL(string: "https://github.com/bockelmannaaron-code/groove-radar/releases/latest")!

    private let publicKey: Curve25519.Signing.PublicKey?
    private var timer: Timer?
    private var busy = false
    private var staged: (app: URL, version: String, work: URL)?
    private var waitingForBackground: NSObjectProtocol?
    /// Reports each check's outcome (for the label in the window's corner).
    var onState: ((StatusLabel.State) -> Void)?

    /// True when this launch is the quiet restart after an automatic update.
    static let launchedByUpdate = CommandLine.arguments.contains("--updated")

    init() {
        if let b64 = Bundle.main.object(forInfoDictionaryKey: "GRUpdatePublicKey") as? String,
           let raw = Data(base64Encoded: b64) {
            publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: raw)
        } else {
            publicKey = nil
        }
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func start() {
        check(userInitiated: false)
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            self?.check(userInitiated: false)
        }
    }

    // MARK: Checking and downloading

    func check(userInitiated: Bool) {
        if let staged {
            if userInitiated { offerRestart(version: staged.version) }
            return
        }
        if busy { return }
        guard publicKey != nil else {
            onState?(.couldNotCheck)
            if userInitiated { tell("Updates are switched off in this build.", detail: "Download new versions from the releases page.") }
            return
        }
        busy = true
        if userInitiated { onState?(.checking) }
        Task {
            let result: Result<(URL, String, URL)?, Error>
            do { result = .success(try await self.fetchAndStage()) } catch { result = .failure(error) }
            await MainActor.run {
                self.busy = false
                switch result {
                case .success(let found?):
                    self.staged = (found.0, found.1, found.2)
                    self.onState?(.updateReady(found.1))
                    if userInitiated { self.offerRestart(version: found.1) } else { self.installWhenIdle() }
                case .success(nil):
                    self.onState?(.upToDate(Date()))
                    if userInitiated { self.tell("Groove Radar is up to date.", detail: "You have version \(self.currentVersion), the newest one.") }
                case .failure(let error):
                    self.onState?(.couldNotCheck)
                    if userInitiated { self.tell("Couldn't check for updates.", detail: error.localizedDescription) }
                }
            }
        }
    }

    private struct Manifest: Decodable { let version: String; let url: String; let signature: String }

    private enum UpdateError: LocalizedError {
        case bad(String)
        var errorDescription: String? { if case .bad(let s) = self { return s }; return nil }
    }

    /// Returns the verified new app (copied out of its DMG), or nil when already up to date.
    private func fetchAndStage() async throws -> (URL, String, URL)? {
        // For testing a release before publishing: defaults write uk.drfeelpoo.grooveradar UpdateFeedURL <url>
        let feed = UserDefaults.standard.string(forKey: "UpdateFeedURL").flatMap(URL.init(string:)) ?? Self.feed
        var req = URLRequest(url: feed, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        req.setValue("GrooveRadar/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, res) = try await URLSession.shared.data(for: req)
        guard (res as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.bad("The update server didn't answer.") }
        let m = try JSONDecoder().decode(Manifest.self, from: data)
        guard Self.isNewer(m.version, than: currentVersion) else { return nil }
        guard let dmgURL = URL(string: m.url), dmgURL.scheme == "https" || dmgURL.host == "localhost",
              let sig = Data(base64Encoded: m.signature) else { throw UpdateError.bad("The update information is damaged.") }

        let (tmpDMG, dres) = try await URLSession.shared.download(for: URLRequest(url: dmgURL, timeoutInterval: 300))
        guard (dres as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.bad("The update didn't download.") }
        let dmg = try Data(contentsOf: tmpDMG)
        guard let key = publicKey, key.isValidSignature(sig, for: dmg) else {
            throw UpdateError.bad("The downloaded update isn't signed by Groove Radar, so it wasn't installed.")
        }

        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("GrooveRadarUpdate-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        let dmgFile = work.appendingPathComponent("update.dmg")
        try dmg.write(to: dmgFile)
        let mount = work.appendingPathComponent("mnt")
        try run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path, dmgFile.path])
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", "-force", mount.path]) }

        let newApp = work.appendingPathComponent("Groove Radar.app")
        try run("/usr/bin/ditto", [mount.appendingPathComponent("Groove Radar.app").path, newApp.path])
        guard let info = Bundle(url: newApp)?.infoDictionary,
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              info["CFBundleShortVersionString"] as? String == m.version else {
            throw UpdateError.bad("The update doesn't match this app.")
        }
        return (newApp, m.version, work)
    }

    // MARK: Installing

    /// Installs as soon as Groove Radar isn't the app in use: now if it's in the background,
    /// otherwise the moment you switch away from it.
    private func installWhenIdle() {
        if !NSApp.isActive { install(relaunch: true, quietly: true); return }
        if waitingForBackground != nil { return }
        waitingForBackground = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if let o = self.waitingForBackground { NotificationCenter.default.removeObserver(o) }
            self.waitingForBackground = nil
            self.install(relaunch: true, quietly: true)
        }
    }

    private func offerRestart(version: String) {
        let a = NSAlert()
        a.messageText = "Groove Radar \(version) is ready"
        a.informativeText = "Restart to start using it. If you choose Later, it's installed when you quit."
        a.addButton(withTitle: "Restart Now")
        a.addButton(withTitle: "Later")
        if a.runModal() == .alertFirstButtonReturn { install(relaunch: true) }
    }

    /// Called on quit (relaunch false) or from "Restart Now" (relaunch true).
    func install(relaunch: Bool, quietly: Bool = false) {
        guard let staged else { return }
        let target = Bundle.main.bundleURL
        let parent = target.deletingLastPathComponent().path
        // An app opened straight from the DMG or Downloads runs from a read-only copy: send people to the download instead.
        guard !target.path.contains("/AppTranslocation/"), !target.path.hasPrefix("/Volumes/"),
              FileManager.default.isWritableFile(atPath: parent) else {
            if relaunch && !quietly {
                tell("Groove Radar can't update itself from here.",
                     detail: "Move Groove Radar into your Applications folder, or download version \(staged.version) from the releases page.")
                NSWorkspace.shared.open(Self.releasesPage)
            }
            return
        }
        self.staged = nil
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$2.old"
        if mv "$2" "$2.old" && /usr/bin/ditto "$3" "$2"; then
          rm -rf "$2.old"
        else
          rm -rf "$2"; mv "$2.old" "$2"
        fi
        /usr/bin/xattr -dr com.apple.quarantine "$2" 2>/dev/null
        [ "$4" = 1 ] && /usr/bin/open "$2"
        [ "$4" = 2 ] && /usr/bin/open -g "$2" --args --updated
        rm -rf "$5"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script, "groove-radar-update", String(ProcessInfo.processInfo.processIdentifier),
                       target.path, staged.app.path, relaunch ? (quietly ? "2" : "1") : "0", staged.work.path]
        try? p.run()
        if relaunch { NSApp.terminate(nil) }
    }

    // MARK: Helpers

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    @discardableResult
    private func run(_ tool: String, _ args: [String]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw UpdateError.bad("Couldn't open the update (\((tool as NSString).lastPathComponent) failed).") }
        return p.terminationStatus
    }

    private func tell(_ title: String, detail: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = detail
        a.runModal()
    }
}
