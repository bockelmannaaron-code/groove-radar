// Groove Radar for macOS: a native window around the Groove Radar website.
//
// - Loads the live site (https://drfeelpoo.uk) so gigs are always today's.
// - With no internet, it falls back to the copy of the site bundled inside the app
//   (served from app://local/ so data.json loads just like on the web).
// - Ticket and shop links open in the default browser, not inside the app.
// - Updates itself from GitHub releases (see Updater.swift) and shows a change log (Changelog.swift).
//
// Built by macos/build-app.sh with swiftc (no Xcode project needed).
import AppKit
import WebKit

let liveURL = URL(string: "https://drfeelpoo.uk/")!
let liveHost = "drfeelpoo.uk"
let bundledURL = URL(string: "app://local/index.html")!

/// Serves the site copy in Contents/Resources/site for app://local/... requests.
final class BundledSite: NSObject, WKURLSchemeHandler {
    let root = Bundle.main.resourceURL!.appendingPathComponent("site", isDirectory: true)

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let file = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
        guard file.path.hasPrefix(root.standardizedFileURL.path), let data = try? Data(contentsOf: file) else {
            let res = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: [:])!
            task.didReceive(res)
            task.didReceive(Data())
            task.didFinish()
            return
        }
        let types = ["html": "text/html; charset=utf-8", "json": "application/json; charset=utf-8",
                     "css": "text/css", "js": "text/javascript", "svg": "image/svg+xml",
                     "png": "image/png", "woff2": "font/woff2"]
        let type = types[file.pathExtension.lowercased()] ?? "application/octet-stream"
        let res = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                  headerFields: ["Content-Type": type, "Content-Length": "\(data.count)"])!
        task.didReceive(res)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    var window: NSWindow!
    var web: WKWebView!
    var usingBundled = false
    let updater = Updater()
    let changelog = Changelog()

    func applicationDidFinishLaunching(_ note: Notification) {
        buildMenu()

        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundledSite(), forURLScheme: "app")
        config.websiteDataStore = .default()  // keeps the page's saved settings between launches

        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.setValue(false, forKey: "drawsBackground")  // no white flash before the page paints

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 860),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Groove Radar"
        window.titlebarAppearsTransparent = true  // navy title bar that blends into the page
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 3 / 255, green: 32 / 255, blue: 61 / 255, alpha: 1)
        window.minSize = NSSize(width: 380, height: 520)
        window.contentView = web
        window.setFrameAutosaveName("GrooveRadarMain")
        if !window.setFrameUsingName("GrooveRadarMain") { window.center() }
        window.makeKeyAndOrderFront(nil)

        loadLive()
        NSApp.activate(ignoringOtherApps: true)
        updater.start()
        changelog.showIfUpdated(currentVersion: updater.currentVersion)
    }

    func applicationWillTerminate(_ note: Notification) { updater.install(relaunch: false) }

    @objc func checkForUpdates() { updater.check(userInitiated: true) }

    @objc func showChangelog() { changelog.show() }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    @objc func loadLive() {
        usingBundled = false
        web.load(URLRequest(url: liveURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 15))
    }

    @objc func reload() { if usingBundled { loadLive() } else { web.reload() } }

    // MARK: Navigation

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        let scheme = url.scheme?.lowercased() ?? ""
        let inApp = ["app", "about", "blob", "data"].contains(scheme)
            || (scheme == "https" && (url.host == liveHost || url.host == "www." + liveHost))
        if inApp || action.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
        } else {
            openExternally(url)  // tickets, Beatport, maps: the user's browser
            decisionHandler(.cancel)
        }
    }

    // Links with target="_blank" ask for a new window: open them in the browser instead.
    func webView(_ webView: WKWebView, createWebViewWith config: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { openExternally(url) }
        return nil
    }

    /// Hands a page link to macOS only when it is a plain web link. Any other scheme
    /// (file:, smb:, ssh:, x-apple.systempreferences:, ...) is dropped, so a link in the
    /// gig data can never make the Mac open a local app, a network share or a settings pane.
    private func openExternally(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        NSWorkspace.shared.open(url)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError error: Error) {
        fallBack(error)
    }

    func webView(_ webView: WKWebView, didFail nav: WKNavigation!, withError error: Error) {
        fallBack(error)
    }

    private func fallBack(_ error: Error) {
        let code = (error as NSError).code
        if code == NSURLErrorCancelled || usingBundled { return }
        usingBundled = true  // offline or site down: show the copy shipped with the app
        web.load(URLRequest(url: bundledURL))
    }

    // MARK: Menu

    private func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Groove Radar", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "What's New", action: #selector(showChangelog), keyEquivalent: "").target = self
        appMenu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Groove Radar", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Groove Radar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let viewItem = NSMenuItem()
        let view = NSMenu(title: "View")
        view.addItem(withTitle: "Reload", action: #selector(reload), keyEquivalent: "r").target = self
        view.addItem(.separator())
        let fs = view.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fs.keyEquivalentModifierMask = [.command, .control]
        viewItem.submenu = view
        main.addItem(viewItem)

        let winItem = NSMenuItem()
        let win = NSMenu(title: "Window")
        win.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winItem.submenu = win
        main.addItem(winItem)
        NSApp.windowsMenu = win

        NSApp.mainMenu = main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
