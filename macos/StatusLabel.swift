// The small label in the window's bottom-right corner: which version is running, when it was
// published, and when the app last confirmed it's up to date, e.g.
//   "Version 1.0.4 · published 21 Nov, 7:42 pm · up to date at 8:05 pm"
// Times are in the Mac's own time zone, 12-hour with am/pm.
// Clicking it checks for updates. The publish time is written into Info.plist (GRPublished)
// by build-app.sh; the "up to date" time comes from the updater's last successful check.
import AppKit

final class StatusLabel: NSView {
    private let text = NSTextField(labelWithString: "")
    var onClick: (() -> Void)?

    static let published: Date? = {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "GRPublished") as? String else { return nil }
        return ISO8601DateFormatter().date(from: s)
    }()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 3 / 255, green: 32 / 255, blue: 61 / 255, alpha: 0.82).cgColor
        layer?.cornerRadius = 9
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(red: 99 / 255, green: 156 / 255, blue: 197 / 255, alpha: 0.3).cgColor
        text.font = .systemFont(ofSize: 11, weight: .medium)
        text.textColor = NSColor(red: 141 / 255, green: 182 / 255, blue: 214 / 255, alpha: 1)
        text.translatesAutoresizingMaskIntoConstraints = false
        addSubview(text)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            text.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            text.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        toolTip = "Click to check for updates"
        setAccessibilityRole(.button)
        update(state: .checking)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    enum State { case checking, upToDate(Date), updateReady(String), couldNotCheck }

    func update(state: State) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        // The Mac's current time zone (DateFormatter's default), 12-hour clock with lowercase am/pm.
        func formatter(_ format: String) -> DateFormatter {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_GB")
            f.timeZone = .current
            f.dateFormat = format
            f.amSymbol = "am"; f.pmSymbol = "pm"
            return f
        }
        let stamp = formatter("d MMM, h:mm a"), time = formatter("h:mm a")
        var parts = ["Version \(version)"]
        if let p = Self.published { parts.append("published \(stamp.string(from: p))") }
        switch state {
        case .checking: parts.append("checking for updates…")
        case .upToDate(let d):
            parts.append(Calendar.current.isDateInToday(d) ? "up to date at \(time.string(from: d))" : "up to date on \(stamp.string(from: d))")
        case .updateReady(let v): parts.append("version \(v) installs when you switch away")
        case .couldNotCheck: parts.append("couldn't check for updates")
        }
        text.stringValue = parts.joined(separator: " · ")
        setAccessibilityLabel(text.stringValue)
    }

    override func mouseDown(with event: NSEvent) { onClick?() }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

/// The "Change log" button next to the version label: opens the change log window.
final class PillButton: NSView {
    private let text: NSTextField
    var onClick: (() -> Void)?

    init(title: String, help: String) {
        text = NSTextField(labelWithString: title)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 3 / 255, green: 32 / 255, blue: 61 / 255, alpha: 0.82).cgColor
        layer?.cornerRadius = 9
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(red: 99 / 255, green: 156 / 255, blue: 197 / 255, alpha: 0.3).cgColor
        text.font = .systemFont(ofSize: 11, weight: .semibold)
        text.textColor = NSColor(red: 238 / 255, green: 244 / 255, blue: 250 / 255, alpha: 1)
        text.translatesAutoresizingMaskIntoConstraints = false
        addSubview(text)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            text.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            text.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        toolTip = help
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func mouseDown(with event: NSEvent) { onClick?() }
    override func accessibilityPerformPress() -> Bool { onClick?(); return true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}
