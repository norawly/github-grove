import Foundation

public enum DesktopGrid {
    public struct Point: Equatable { public let x: Double; public let y: Double }

    /// Complete widget slots anchored at the display's top-left.
    /// WidgetKit placement is separately managed by macOS.
    public static func snap(x: Double, y: Double, widgetWidth: Double, widgetHeight: Double,
                            screenX: Double, screenY: Double, screenWidth: Double, screenHeight: Double) -> Point {
        let inset = 24.0, gap = 16.0
        let left = screenX + min(inset, max(0, (screenWidth - widgetWidth) / 2))
        let top = screenY + screenHeight - widgetHeight - min(inset, max(0, (screenHeight - widgetHeight) / 2))
        let column = max(0, ((x - left) / (widgetWidth + gap)).rounded())
        let row = max(0, ((top - y) / (widgetHeight + gap)).rounded())
        let maxColumns = max(0, floor((screenWidth - 2 * inset - widgetWidth) / (widgetWidth + gap)))
        let maxRows = max(0, floor((screenHeight - 2 * inset - widgetHeight) / (widgetHeight + gap)))
        return Point(x: left + min(column, maxColumns) * (widgetWidth + gap),
                     y: top - min(row, maxRows) * (widgetHeight + gap))
    }
}
