import AppKit
import GroveCore

enum Rendering {
    /// Renders the actual widget view to a file without creating a window or running NSApplication.
    static func card(output: String, theme: Theme, snapshot: ContributionSnapshot?, companion: Bool = true) throws {
        let size = CalendarView.cardSize
        let view = CalendarView(frame: NSRect(origin: .zero, size: size))
        var preferences = Preferences()
        preferences.theme = theme; preferences.companion = companion
        view.preferences = preferences; view.snapshot = snapshot
        if let snapshot {
            let format = DateFormatter(); format.dateFormat = "MMM d, yyyy"; format.timeZone = GitHubDate.calendar.timeZone
            view.status = "Updated \(format.string(from: snapshot.fetchedAt)) · \(snapshot.username == "demo" ? "illustrative preview" : "public GitHub data")"
        }
        try bitmap(output: output, size: size, scale: 2) { view.draw(view.bounds) }
    }

    static func icon(output: String) throws {
        try bitmap(output: output, size: NSSize(width: 1024, height: 1024), scale: 1) {
            let p = Palette.dark
            let shell = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 204, yRadius: 204)
            let gradient = NSGradient(starting: Palette.color(0x243E2B), ending: Palette.color(0x121D16))!
            gradient.draw(in: shell, angle: 90)
            Palette.color(0x597C53, alpha: 0.5).setStroke(); shell.lineWidth = 3; shell.stroke()
            let levels = [[0,1,2,0,0,0,0], [1,2,3,1,0,0,0], [2,3,4,2,1,0,0], [1,2,3,4,2,1,0],
                          [0,1,2,3,4,2,1], [0,0,1,2,3,4,2], [0,0,0,1,2,3,4]]
            for x in 0..<7 { for y in 0..<7 {
                p.levels[levels[x][y]].setFill()
                NSBezierPath(roundedRect: NSRect(x: 215 + x * 86, y: 215 + y * 86, width: 65, height: 65), xRadius: 16, yRadius: 16).fill()
            } }
        }
    }

    private static func bitmap(output: String, size: NSSize, scale: Int, drawing: () -> Void) throws {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale,
            pixelsHigh: Int(size.height) * scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw NSError(domain: "Grove", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create image"])
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        graphics.cgContext.translateBy(x: 0, y: size.height)
        graphics.cgContext.scaleBy(x: 1, y: -1)
        // Tell AppKit text drawing that this is a flipped canvas too.
        NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
        drawing()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ContributionError.unavailable }
        try png.write(to: URL(fileURLWithPath: output), options: .atomic)
    }

    static func demo() -> ContributionSnapshot {
        let end = GitHubDate.parse("2026-10-14")!
        let start = GitHubDate.parse("2025-10-12")!
        let count = GitHubDate.calendar.dateComponents([.day], from: start, to: end).day! + 1
        let days = (0..<count).map { index -> ContributionDay in
            let date = GitHubDate.adding(days: index, to: start)
            let weekday = GitHubDate.calendar.component(.weekday, from: date)
            let noise = (index * 19 + index / 7 * 13) % 17
            let level = index >= count - 5 ? 3 : (weekday == 1 || weekday == 7) ? (noise < 4 ? 1 : 0) : (noise < 3 ? 0 : 1 + noise % 4)
            return ContributionDay(date: GitHubDate.key(date), level: level)
        }
        return ContributionSnapshot(username: "demo", days: days, fetchedAt: end)
    }
}
