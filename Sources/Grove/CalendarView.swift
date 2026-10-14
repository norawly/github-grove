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

    static let dark = Palette(background: color(0x151B18, alpha: 0.97), border: color(0x39433C, alpha: 0.8),
                              text: color(0xA5B1A8), subtle: color(0x7F8E83),
                              levels: [color(0x28332B), color(0x2B593B), color(0x3C8552), color(0x70B96B), color(0xB6E88C)])
    static let light = Palette(background: color(0xF6F8F2, alpha: 0.97), border: color(0xD8DED2),
                               text: color(0x5E6D60), subtle: color(0x798574),
                               levels: [color(0xE2E8DC), color(0xB6D6A0), color(0x80B975), color(0x4E945B), color(0x28633E)])
}

/// One native drawing surface, no web view and no continuous rendering loop.
final class CalendarView: NSView {
    static let cardSize = NSSize(width: 680, height: 272)
    var preferences = Preferences() { didSet { needsDisplay = true } }
    var snapshot: ContributionSnapshot? {
        didSet { layout = CalendarLayout(days: snapshot?.days ?? []); updateTooltips(); needsDisplay = true }
    }
    private var layout = CalendarLayout(days: [])
    var status = "" {
        didSet {
            toolTip = status.isEmpty ? "Drag to move · Double-click for settings · Right-click for options" : status
            needsDisplay = true
        }
    }
    var offline = false { didSet { needsDisplay = true } }
    var busy = false { didSet { needsDisplay = true } }
    var companionFrame = 0 { didSet { needsDisplay = true } }
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
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Grove GitHub contribution calendar")
        setAccessibilityHelp("Double-click to open settings. Right-click for the widget menu.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() { needsDisplay = true }

    private var factor: CGFloat { bounds.width / Self.cardSize.width }
    private var pitch: CGFloat { 584 / CGFloat(layout.columns) }

    private func cellRect(_ cell: CalendarLayout.Cell) -> NSRect {
        NSRect(x: 64 + CGFloat(cell.column) * pitch, y: 105 + CGFloat(cell.row) * pitch,
               width: pitch - 2.5, height: pitch - 2.5)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.scaleBy(x: factor, y: factor)
        drawCard()
        context.restoreGState()
    }

    private func drawCard() {
        let p = palette
        let shell = NSBezierPath(roundedRect: NSRect(origin: .zero, size: Self.cardSize).insetBy(dx: 0.5, dy: 0.5), xRadius: 24, yRadius: 24)
        p.background.setFill(); shell.fill()
        p.border.setStroke(); shell.lineWidth = 1; shell.stroke()

        // A quiet identity line. The graph is the visual focus.
        drawMark(at: NSPoint(x: 28, y: 31), color: p.subtle)
        let username = snapshot?.username ?? preferences.username
        let identity = username.isEmpty ? "your GitHub, quietly." : "@\(username)"
        text(identity, x: 50, y: 29, size: 12, color: p.text, weight: .medium)
        if let snapshot {
            let streak = snapshot.streak()
            let label = "\(streak.days)\(streak.isLowerBound ? "+" : "") day\(streak.days == 1 ? "" : "s") streak"
            let width = measure(identity, size: 12, weight: .medium)
            text("·", x: 60 + width, y: 29, size: 12, color: p.subtle)
            text(label, x: 73 + width, y: 30, size: 11, color: p.subtle)
        }
        if preferences.companion { drawCompanion(x: 602, y: 22, frame: companionFrame, palette: p) }
        else { text("G R O V E", x: 589, y: 32, size: 8, color: p.subtle) }

        p.border.withAlphaComponent(0.55).setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: 28, y: 67)); divider.line(to: NSPoint(x: 652, y: 67)); divider.lineWidth = 0.6; divider.stroke()

        if snapshot != nil {
            for month in layout.months {
                text(month.label, x: 64 + CGFloat(month.column) * pitch, y: 83, size: 9.5, color: p.subtle)
            }
            for (row, label) in [(1, "Mon"), (3, "Wed"), (5, "Fri")] {
                text(label, x: 28, y: 104 + CGFloat(row) * pitch, size: 9, color: p.subtle)
            }
            for cell in layout.cells {
                let path = NSBezierPath(roundedRect: cellRect(cell), xRadius: 2.4, yRadius: 2.4)
                p.levels[cell.day.level].setFill(); path.fill()
            }
        } else {
            // Placeholder cells are explicitly labelled, never presented as real data.
            for column in 0..<53 { for row in 0..<7 {
                let rect = NSRect(x: 64 + CGFloat(column) * pitch, y: 105 + CGFloat(row) * pitch,
                                  width: pitch - 2.5, height: pitch - 2.5)
                p.levels[0].withAlphaComponent(0.45).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 2.4, yRadius: 2.4).fill()
            } }
            let message = busy ? "Loading your calendar…" : (preferences.username.isEmpty ? "Double-click to connect your GitHub" : "Calendar unavailable · right-click to retry")
            let w = measure(message, size: 12, weight: .medium)
            p.background.setFill()
            NSBezierPath(roundedRect: NSRect(x: 340 - w / 2 - 16, y: 128, width: w + 32, height: 32), xRadius: 12, yRadius: 12).fill()
            text(message, x: 340 - w / 2, y: 137, size: 12, color: p.text, weight: .medium)
        }

        text("LAST 12 MONTHS", x: 28, y: 225, size: 8, color: p.subtle)
        text("Less", x: 470, y: 224, size: 8.5, color: p.subtle)
        for level in 0...4 {
            p.levels[level].setFill()
            NSBezierPath(roundedRect: NSRect(x: 500 + CGFloat(level) * 11, y: 225, width: 8, height: 8), xRadius: 2, yRadius: 2).fill()
        }
        text("More", x: 558, y: 224, size: 8.5, color: p.subtle)
        let state = busy ? "updating" : offline ? "saved · offline" : snapshot != nil ? "synced" : "setup"
        text(state, x: 652 - measure(state, size: 8.5), y: 224, size: 8.5, color: p.subtle)
        // Errors remain visible on the card and have the full text in a tooltip.
        if !status.isEmpty {
            let short = String(status.prefix(96))
            text(short, x: 28, y: 247, size: 8.5, color: p.subtle)
        }
    }

    private func drawMark(at origin: NSPoint, color: NSColor) {
        color.setStroke()
        let line = NSBezierPath()
        line.lineWidth = 1.2
        line.move(to: NSPoint(x: origin.x + 4, y: origin.y + 3)); line.line(to: NSPoint(x: origin.x + 4, y: origin.y + 13))
        line.move(to: NSPoint(x: origin.x + 4, y: origin.y + 8)); line.curve(to: NSPoint(x: origin.x + 11, y: origin.y + 2), controlPoint1: NSPoint(x: origin.x + 11, y: origin.y + 8), controlPoint2: NSPoint(x: origin.x + 11, y: origin.y + 6))
        line.stroke()
        color.setFill()
        for point in [NSPoint(x: origin.x + 4, y: origin.y + 2), NSPoint(x: origin.x + 11, y: origin.y + 1), NSPoint(x: origin.x + 4, y: origin.y + 14)] {
            NSBezierPath(ovalIn: NSRect(x: point.x - 1.7, y: point.y - 1.7, width: 3.4, height: 3.4)).fill()
        }
    }

    /// Original pixel sprout, unrelated to any GitHub or Claude mascot.
    func drawCompanion(x: CGFloat, y: CGFloat, frame: Int, palette p: Palette) {
        let pixels = [
            "    aa      aa    ", "     aa    aa     ", "      aaaaaa      ", "        aa        ",
            "     bbbbbbbb     ", "    bbbbbbbbbb    ", "    bccbbbbccb    ", "    bccbbbbccb    ",
            "    bbbbbbbbbb    ", "     bbbbbbbb     ", "       bbbb       ", "      bb  bb      "
        ]
        let shift: CGFloat = frame % 4 == 1 ? -1 : frame % 4 == 3 ? 1 : 0
        let blink = frame % 12 == 10
        for (row, line) in pixels.enumerated() {
            for (column, pixel) in line.enumerated() {
                guard pixel != " " else { continue }
                let color = pixel == "a" ? p.levels[3] : pixel == "b" ? p.levels[2] : (blink && row == 6 ? p.levels[2] : p.background)
                color.setFill()
                NSRect(x: x + CGFloat(column) * 2, y: y + CGFloat(row) * 2 + shift, width: 2, height: 2).fill()
            }
        }
    }

    private func text(_ string: String, x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
        (string as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
    }
    private func measure(_ string: String, size: CGFloat, weight: NSFont.Weight = .regular) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
    }

    private func updateTooltips() {
        removeAllToolTips()
        let descriptions = ["No contributions", "Low activity", "Moderate activity", "High activity", "Very high activity"]
        for cell in layout.cells {
            let rect = cellRect(cell)
            let scaled = NSRect(x: rect.minX * factor, y: rect.minY * factor, width: rect.width * factor, height: rect.height * factor)
            addToolTip(scaled, owner: "\(cell.day.date) · \(descriptions[cell.day.level])" as NSString, userData: nil)
        }
        toolTip = status.isEmpty ? "Drag to move · Double-click for settings · Right-click for options" : status
        if let snapshot {
            let streak = snapshot.streak()
            setAccessibilityValue("@\(snapshot.username), \(streak.days) day streak. \(snapshot.days.count) days in the calendar.")
        } else {
            setAccessibilityValue("No calendar loaded. Double-click to open settings.")
        }
        updateAccessibilityCells()
    }

    func updateAccessibilityCells() {
        guard let window else { return }
        let descriptions = ["No contributions", "Low activity", "Moderate activity", "High activity", "Very high activity"]
        let elements = layout.cells.map { cell -> Any in
            let rect = cellRect(cell)
            let scaled = NSRect(x: rect.minX * factor, y: rect.minY * factor, width: rect.width * factor, height: rect.height * factor)
            return NSAccessibilityElement.element(withRole: .image,
                frame: window.convertToScreen(convert(scaled, to: nil)),
                label: "\(cell.day.date), \(descriptions[cell.day.level])", parent: self)
        }
        setAccessibilityChildren(elements)
    }

    override func setFrameSize(_ newSize: NSSize) { super.setFrameSize(newSize); updateTooltips() }
    override func viewDidMoveToWindow() { updateTooltips() }
    override func menu(for event: NSEvent) -> NSMenu? { menuAction?() }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { if let menu = menuAction?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }; return }
        if event.clickCount == 2 { settingsAction?(); return }
        guard !preferences.locked, let window else { return }
        dragStart = NSEvent.mouseLocation
        windowStart = window.frame.origin
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
