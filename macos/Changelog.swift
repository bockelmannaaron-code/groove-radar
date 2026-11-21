// "What's New in Groove Radar": the change log, read from changelog.json inside the app.
// Opens from Groove Radar > What's New, and once by itself on the first launch after an update.
import AppKit
import WebKit

final class Changelog {
    private struct Entry: Decodable { let version: String; let date: String; let changes: [String] }
    private var window: NSWindow?

    private var entries: [Entry] {
        guard let url = Bundle.main.url(forResource: "changelog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    /// Shows the change log once after the app was updated (not on a fresh install).
    func showIfUpdated(currentVersion: String) {
        let key = "LastVersionSeen", defaults = UserDefaults.standard
        let last = defaults.string(forKey: key)
        defaults.set(currentVersion, forKey: key)
        if let last, Updater.isNewer(currentVersion, than: last) { show(since: last) }
    }

    /// Opens the window. With `since`, versions newer than it are marked as new.
    func show(since: String? = nil) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
                             styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.title = "What's New in Groove Radar"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden  // the page's own heading says it
            w.backgroundColor = NSColor(red: 3 / 255, green: 32 / 255, blue: 61 / 255, alpha: 1)
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 360, height: 320)
            let web = WKWebView(frame: .zero)
            web.setValue(false, forKey: "drawsBackground")
            w.contentView = web
            w.center()
            window = w
        }
        (window?.contentView as? WKWebView)?.loadHTMLString(html(since: since), baseURL: nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func html(since: String?) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        let fmtIn = DateFormatter(); fmtIn.dateFormat = "yyyy-MM-dd"; fmtIn.locale = Locale(identifier: "en_US_POSIX")
        let fmtOut = DateFormatter(); fmtOut.dateStyle = .long
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let body = entries.map { e -> String in
            let isNew = since.map { Updater.isNewer(e.version, than: $0) } ?? false
            let tag = e.version == current ? "<span class=tag>Installed</span>" : isNew ? "<span class=tag>New</span>" : ""
            let date = fmtIn.date(from: e.date).map { fmtOut.string(from: $0) } ?? e.date
            let items = e.changes.map { "<li>\(esc($0))</li>" }.joined()
            return "<section><h2>Version \(esc(e.version)) \(tag)</h2><p class=date>\(esc(date))</p><ul>\(items)</ul></section>"
        }.joined()
        return """
        <!doctype html><meta charset=utf-8><style>
        :root { color-scheme: dark; }
        body { margin: 0; padding: 8px 28px 32px; font: 14px/1.55 -apple-system, system-ui, sans-serif; color: #E6EEF6; background: transparent; }
        h1 { font-size: 26px; font-weight: 600; letter-spacing: -0.02em; margin: 4px 0 18px; }
        h1 em { font-style: normal; color: #639CC5; }
        section { padding: 16px 0; border-top: 1px solid rgba(230,238,246,0.14); }
        h2 { font-size: 17px; font-weight: 600; margin: 0; display: flex; align-items: center; gap: 10px; }
        .tag { font-size: 11px; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase; background: #FF2E88; color: #fff; border-radius: 6px; padding: 2px 7px; }
        .date { margin: 2px 0 8px; color: #8FA9C2; font-size: 13px; }
        ul { margin: 0; padding-left: 18px; } li { margin: 4px 0; }
        </style><h1>What's new in Groove <em>Radar</em></h1>\(body.isEmpty ? "<p>No change log in this build.</p>" : body)
        """
    }
}
