import AppKit
import CoreGraphics
import ServiceManagement
import GroveCore

final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = LocalStore()
    private var preferences: Preferences
    private let calendarView = CalendarView(frame: NSRect(origin: .zero, size: CalendarView.cardSize))
    private var desktop: DesktopWindow?
    private var settings: SettingsController?
    private var refreshTimer: Timer?
    private var animationTimer: Timer?
    private var request: Task<Void, Never>?
    private var sleeping = false
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastAttempt = Date.distantPast

    override init() {
        preferences = store.loadPreferences()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let identifier = Bundle.main.bundleIdentifier ?? "dev.norawly.grove"
        if NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.accessory)
        calendarView.preferences = preferences
        calendarView.snapshot = store.snapshot(for: preferences.username)
        let window = DesktopWindow(contentRect: NSRect(origin: .zero, size: widgetSize), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.contentView = calendarView
        window.delegate = self
        window.setAccessibilityLabel("Grove desktop widget")
        desktop = window
        restorePosition()
        calendarView.settingsAction = { [weak self] in self?.showSettings() }
        calendarView.menuAction = { [weak self] in self?.makeMenu() ?? NSMenu() }
        calendarView.positionChanged = { [weak self] in self?.savePosition() }
        window.orderFrontRegardless()
        installObservers()
        startRefreshTimer()
        updateAnimation()
        if preferences.username.isEmpty { showSettings() } else { refreshIfNeeded() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(); return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        request?.cancel(); refreshTimer?.invalidate(); animationTimer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        savePosition()
    }

    private var widgetSize: NSSize {
        NSSize(width: CalendarView.cardSize.width * preferences.scale, height: CalendarView.cardSize.height * preferences.scale)
    }

    private func installObservers() {
        let center = NotificationCenter.default
        for name in [NSApplication.didChangeScreenParametersNotification, NSWindow.didChangeOcclusionStateNotification,
                     Notification.Name.NSProcessInfoPowerStateDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    if name == NSApplication.didChangeScreenParametersNotification { self?.restorePosition() }
                    self?.updateAnimation()
                }
            })
        }
        // Accessibility notifications are also delivered by the workspace notification center.
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.updateAnimation() } })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.sleeping = true; self.request?.cancel(); self.request = nil
                    self.calendarView.busy = false; self.refreshTimer?.invalidate(); self.updateAnimation()
                }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.sleeping = false; self.startRefreshTimer(); self.refreshIfNeeded(); self.updateAnimation()
                }
            })
        }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 600
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func refreshIfNeeded() {
        if calendarView.snapshot == nil || Date().timeIntervalSince(calendarView.snapshot!.fetchedAt) >= 3600 {
            if Date().timeIntervalSince(lastAttempt) > 60 { refresh() }
        } else { updateSavedStatus() }
    }

    private func refresh() {
        guard !preferences.username.isEmpty, !sleeping, request == nil else { return }
        // Manual refresh is throttled too; no request storm from menu clicks or wake events.
        guard Date().timeIntervalSince(lastAttempt) >= 60 else { return }
        lastAttempt = Date()
        calendarView.busy = true
        let username = preferences.username
        request = Task { [weak self] in
            do {
                let snapshot = try await ContributionClient().fetch(username: username)
                guard !Task.isCancelled, let self, self.preferences.username == username else { return }
                self.store.save(snapshot)
                self.calendarView.snapshot = snapshot
                self.calendarView.offline = false
                self.calendarView.busy = false
                self.updateSavedStatus()
                self.request = nil
            } catch {
                guard !Task.isCancelled, let self, self.preferences.username == username else { return }
                self.calendarView.busy = false
                self.calendarView.offline = self.calendarView.snapshot != nil
                self.calendarView.status = error.localizedDescription
                self.request = nil
            }
        }
    }

    private func updateSavedStatus() {
        guard let snapshot = calendarView.snapshot else { calendarView.status = ""; return }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium; formatter.timeStyle = .short
        calendarView.status = "Updated \(formatter.string(from: snapshot.fetchedAt))"
    }

    private func updateAnimation() {
        animationTimer?.invalidate(); animationTimer = nil
        guard preferences.companion, !sleeping,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              !ProcessInfo.processInfo.isLowPowerModeEnabled,
              desktop?.occlusionState.contains(.visible) == true else { return }
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.calendarView.companionFrame += 1 }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func currentScreen() -> NSScreen? {
        let id = preferences.screenID
        return NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id }
            ?? NSScreen.screens.first
    }

    private func restorePosition(reset: Bool = false) {
        guard let desktop, let screen = currentScreen() else { return }
        let area = screen.visibleFrame
        // Keep the complete calendar on smaller screens by falling back to the 80% size.
        if widgetSize.width > area.width - 24 || widgetSize.height > area.height - 24 { preferences.scale = 0.8 }
        desktop.setContentSize(widgetSize)
        calendarView.preferences = preferences
        let x = reset ? area.minX + 24 : preferences.originX ?? area.minX + 24
        let y = reset ? area.maxY - widgetSize.height - 24 : preferences.originY ?? area.maxY - widgetSize.height - 24
        desktop.setFrameOrigin(NSPoint(x: min(max(x, area.minX + 12), area.maxX - widgetSize.width - 12),
                                       y: min(max(y, area.minY + 12), area.maxY - widgetSize.height - 12)))
        savePosition()
    }

    private func savePosition() {
        if let desktop {
            preferences.originX = desktop.frame.origin.x; preferences.originY = desktop.frame.origin.y
            preferences.screenID = (desktop.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        }
        store.save(preferences)
    }

    @objc func showSettings() {
        if settings == nil {
            settings = SettingsController(preferences: preferences) { [weak self] updated in self?.apply(updated) }
        }
        settings?.update(preferences)
        settings?.show()
    }

    private func apply(_ updated: Preferences) {
        let usernameChanged = updated.username != preferences.username
        let scaleChanged = updated.scale != preferences.scale
        preferences = updated
        calendarView.preferences = preferences
        if usernameChanged {
            request?.cancel(); request = nil; lastAttempt = .distantPast
            calendarView.busy = false; calendarView.offline = false; calendarView.status = ""
            calendarView.snapshot = nil; store.clearSnapshot()
            refresh()
        }
        if scaleChanged { restorePosition() }
        savePosition(); updateAnimation()
    }

    func windowDidMove(_ notification: Notification) { calendarView.updateAccessibilityCells() }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("Settings…", action: #selector(showSettings)))
        let refreshItem = item("Refresh calendar", action: #selector(refreshClicked))
        refreshItem.isEnabled = request == nil && !preferences.username.isEmpty && Date().timeIntervalSince(lastAttempt) >= 60
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        let themes = NSMenu()
        for (index, theme) in Theme.allCases.enumerated() {
            let entry = item(theme.title, action: #selector(themeClicked(_:)))
            entry.tag = index; entry.state = preferences.theme == theme ? .on : .off; themes.addItem(entry)
        }
        let theme = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: ""); theme.submenu = themes; menu.addItem(theme)
        let sizes = NSMenu()
        for (index, scale) in [0.8, 1, 1.2, 1.4].enumerated() {
            let entry = item("\(Int(scale * 100))%", action: #selector(scaleClicked(_:)))
            entry.tag = index; entry.state = preferences.scale == scale ? .on : .off; sizes.addItem(entry)
        }
        let size = NSMenuItem(title: "Size", action: nil, keyEquivalent: ""); size.submenu = sizes; menu.addItem(size)
        let lock = item("Lock position", action: #selector(lockClicked)); lock.state = preferences.locked ? .on : .off; menu.addItem(lock)
        menu.addItem(item("Move to top left", action: #selector(resetPosition)))
        let companion = item("Pixel companion", action: #selector(companionClicked)); companion.state = preferences.companion ? .on : .off; menu.addItem(companion)
        menu.addItem(.separator())
        let profile = item("Open GitHub profile", action: #selector(openProfile)); profile.isEnabled = !preferences.username.isEmpty; menu.addItem(profile)
        menu.addItem(item("Quit Grove", action: #selector(quit)))
        menu.autoenablesItems = false
        return menu
    }

    private func item(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; return item
    }
    @objc private func refreshClicked() { refresh() }
    @objc private func themeClicked(_ item: NSMenuItem) { var updated = preferences; updated.theme = Theme.allCases[item.tag]; apply(updated) }
    @objc private func scaleClicked(_ item: NSMenuItem) { var updated = preferences; updated.scale = [0.8, 1, 1.2, 1.4][item.tag]; apply(updated) }
    @objc private func lockClicked() { var updated = preferences; updated.locked.toggle(); apply(updated) }
    @objc private func companionClicked() { var updated = preferences; updated.companion.toggle(); apply(updated) }
    @objc private func resetPosition() { restorePosition(reset: true) }
    @objc private func openProfile() { if let url = URL(string: "https://github.com/\(preferences.username)") { NSWorkspace.shared.open(url) } }
    @objc private func quit() { NSApp.terminate(nil) }
}
