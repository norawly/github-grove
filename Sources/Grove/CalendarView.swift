import AppKit
import GroveCore

struct Palette {
    let background: NSColor
    let border: NSColor
    let text: NSColor
    let subtle: NSColor
    let levels: [NSColor]
    static func color(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: alpha)
    }
    static let dark = Palette(background: color(GitHubColors.darkBackground), border: color(GitHubColors.darkBorder),
        text: color(GitHubColors.darkText), subtle: color(GitHubColors.darkSecondary), levels: GitHubColors.darkLevels.map { color($0) })
    static let light = Palette(background: color(GitHubColors.lightBackground), border: color(GitHubColors.lightBorder),
        text: color(GitHubColors.lightText), subtle: color(GitHubColors.lightSecondary), levels: GitHubColors.lightLevels.map { color($0) })
}

final class CalendarView: NSView {
    static let cardSize = NSSize(width: 624, height: 126)
    var preferences = Preferences() { didSet { needsDisplay = true } }
    var snapshot: ContributionSnapshot? {
        didSet { layout = CalendarLayout(days: snapshot?.days ?? []); updateTooltips(); needsDisplay = true }
    }
    private var layout = CalendarLayout(days: [])
    private var tooltipLabels: [NSView.ToolTipTag: String] = [:]
    var status = "" { didSet { toolTip = status.isEmpty ? "Double-click for settings · Right-click for options" : status } }
    var offline = false
    var busy = false { didSet { needsDisplay = true } }
    var settingsAction: (() -> Void)?
    var menuAction: (() -> NSMenu)?
    var positionChanged: (() -> Void)?
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    var palette: Palette {
        switch preferences.theme {
        case .dark: return .dark
        case .light: return .light
        case .system: return effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
    }
    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true); setAccessibilityRole(.group)
        setAccessibilityLabel("Grove GitHub contribution calendar")
        setAccessibilityHelp("Double-click to open settings. Right-click for options.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidChangeEffectiveAppearance() { needsDisplay = true }
    private var factor: CGFloat { bounds.width / Self.cardSize.width }
    private var pitch: CGFloat { 596 / CGFloat(layout.columns) }
    private func cellRect(_ column: Int, _ row: Int) -> NSRect {
        NSRect(x: 14 + CGFloat(column) * pitch, y: 35 + CGFloat(row) * pitch, width: pitch - 1.6, height: pitch - 1.6)
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState(); context.scaleBy(x: factor, y: factor)
        let p = palette
        let shell = NSBezierPath(roundedRect: NSRect(origin: .zero, size: Self.cardSize).insetBy(dx: 0.5, dy: 0.5), xRadius: 16, yRadius: 16)
        p.background.setFill(); shell.fill()
        p.border.withAlphaComponent(0.6).setStroke(); shell.lineWidth = 0.6; shell.stroke()
        let username = snapshot?.username ?? preferences.username
        let identity = username.isEmpty ? "Set your GitHub username" : "@\(username)"
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: p.text]
        (identity as NSString).draw(at: NSPoint(x: 14, y: 12), withAttributes: attributes)
        if let snapshot {
            let streak = snapshot.streak()
            let label = "\(streak.days)\(streak.isLowerBound ? "+" : "") day\(streak.days == 1 ? "" : "s") streak"
            let width = (identity as NSString).size(withAttributes: attributes).width
            (label as NSString).draw(at: NSPoint(x: 26 + width, y: 12),
                withAttributes: [.font: NSFont.systemFont(ofSize: 10.5), .foregroundColor: p.subtle])
            for cell in layout.cells {
                p.levels[cell.day.level].setFill()
                NSBezierPath(roundedRect: cellRect(cell.column, cell.row), xRadius: 1.8, yRadius: 1.8).fill()
            }
        } else {
            for column in 0..<53 { for row in 0..<7 {
                p.levels[0].withAlphaComponent(0.5).setFill()
                NSBezierPath(roundedRect: cellRect(column, row), xRadius: 1.8, yRadius: 1.8).fill()
            } }
        }
        context.restoreGState()
    }
    private func updateTooltips() {
        removeAllToolTips(); tooltipLabels.removeAll()
        let descriptions = ["No contributions", "Low activity", "Moderate activity", "High activity", "Very high activity"]
        for cell in layout.cells {
            let rect = cellRect(cell.column, cell.row)
            let scaled = NSRect(x: rect.minX * factor, y: rect.minY * factor, width: rect.width * factor, height: rect.height * factor)
            // AppKit does not retain tooltip owners. Keep the view as owner and
            // retain labels instead of registering temporary NSString instances.
            let tag = addToolTip(scaled, owner: self, userData: nil)
            tooltipLabels[tag] = "\(cell.day.date) · \(descriptions[cell.day.level])"
        }
        setAccessibilityValue(snapshot.map { "@\($0.username), \($0.streak().days) day streak, \($0.days.count) calendar days" }
                              ?? "No calendar loaded. Double-click for settings.")
        updateAccessibilityCells()
    }
    @objc(view:stringForToolTip:point:userData:)
    func tooltipString(_ view: NSView, tag: NSView.ToolTipTag, point: NSPoint, userData: UnsafeMutableRawPointer?) -> String {
        tooltipLabels[tag] ?? ""
    }
    func updateAccessibilityCells() {
        guard let window else { return }
        let labels = ["No contributions", "Low activity", "Moderate activity", "High activity", "Very high activity"]
        setAccessibilityChildren(layout.cells.map { cell -> Any in
            let rect = cellRect(cell.column, cell.row)
            let scaled = NSRect(x: rect.minX * factor, y: rect.minY * factor, width: rect.width * factor, height: rect.height * factor)
            return NSAccessibilityElement.element(withRole: .image, frame: window.convertToScreen(convert(scaled, to: nil)),
                label: "\(cell.day.date), \(labels[cell.day.level])", parent: self)
        })
    }
    override func setFrameSize(_ newSize: NSSize) { super.setFrameSize(newSize); updateTooltips() }
    override func viewDidMoveToWindow() { updateTooltips() }
    override func menu(for event: NSEvent) -> NSMenu? { menuAction?() }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { if let menu = menuAction?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }; return }
        if event.clickCount == 2 { settingsAction?(); return }
        guard !preferences.locked, let window else { return }
        dragStart = NSEvent.mouseLocation; windowStart = window.frame.origin
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let origin = windowStart else { return }
        let point = NSEvent.mouseLocation
        window?.setFrameOrigin(NSPoint(x: origin.x + point.x - start.x, y: origin.y + point.y - start.y))
    }
    override func mouseUp(with event: NSEvent) {
        if dragStart != nil { positionChanged?(); updateAccessibilityCells() }
        dragStart = nil; windowStart = nil
    }
}
