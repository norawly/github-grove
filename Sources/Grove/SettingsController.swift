import AppKit
import ServiceManagement
import GroveCore

@MainActor
final class SettingsController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let username = NSTextField(string: "")
    private let theme = NSPopUpButton()
    private let size = NSPopUpButton()
    private let companion = NSButton(checkboxWithTitle: "Slow pixel companion", target: nil, action: nil)
    private let lock = NSButton(checkboxWithTitle: "Lock widget position", target: nil, action: nil)
    private let launch = NSButton(checkboxWithTitle: "Start Grove when I log in", target: nil, action: nil)
    private let error = NSTextField(wrappingLabelWithString: "")
    private var preferences: Preferences
    private let onSave: (Preferences) -> Void

    init(preferences: Preferences, onSave: @escaping (Preferences) -> Void) {
        self.preferences = preferences
        self.onSave = onSave
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 430, height: 560),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "Grove"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.auxiliary, .fullScreenNone]
        window.delegate = self
        buildForm()
        update(preferences)
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func update(_ preferences: Preferences) {
        self.preferences = preferences
        username.stringValue = preferences.username
        theme.selectItem(at: Theme.allCases.firstIndex(of: preferences.theme) ?? 0)
        size.selectItem(at: [0.8, 1, 1.2, 1.4].firstIndex(of: preferences.scale) ?? 1)
        companion.state = preferences.companion ? .on : .off
        lock.state = preferences.locked ? .on : .off
        launch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        error.stringValue = ""
    }

    private func buildForm() {
        guard let content = window.contentView else { return }
        let title = NSTextField(labelWithString: "A little space for your green squares.")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        let description = NSTextField(wrappingLabelWithString: "Your complete GitHub calendar, quietly on your desktop. Enter a username. No sign-in or token needed.")
        description.font = .systemFont(ofSize: 12); description.textColor = .secondaryLabelColor
        username.placeholderString = "GitHub username"
        username.font = .systemFont(ofSize: 14)
        username.setAccessibilityLabel("GitHub username")
        theme.addItems(withTitles: Theme.allCases.map(\.title))
        size.addItems(withTitles: ["80% · Compact", "100% · Default", "120% · Large", "140% · Extra large"])
        companion.toolTip = "One frame every 1.5 seconds. Pauses when hidden, asleep, in Low Power Mode, or Reduce Motion is on."
        launch.toolTip = "macOS may ask you to allow Grove in Login Items."
        let hint = NSTextField(wrappingLabelWithString: "Drag the card to move it. Right-click for options, or open Grove again for settings. Updates hourly; the last calendar is kept offline.")
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor
        error.font = .systemFont(ofSize: 11); error.textColor = .systemRed
        let save = NSButton(title: "Save & show calendar", target: self, action: #selector(saveClicked))
        save.bezelStyle = .rounded; save.keyEquivalent = "\r"
        let quit = NSButton(title: "Quit Grove", target: self, action: #selector(quitClicked))
        quit.bezelStyle = .rounded
        let buttons = NSStackView(views: [quit, NSView(), save]); buttons.distribution = .fill
        let stack = NSStackView(views: [title, description, row("Username", username), row("Appearance", theme),
                                      row("Size", size), companion, lock, launch, hint, error, buttons])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            description.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hint.widthAnchor.constraint(equalTo: stack.widthAnchor),
            error.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func row(_ label: String, _ control: NSView) -> NSStackView {
        let title = NSTextField(labelWithString: label)
        title.font = .systemFont(ofSize: 12); title.widthAnchor.constraint(equalToConstant: 84).isActive = true
        control.widthAnchor.constraint(equalToConstant: 258).isActive = true
        let row = NSStackView(views: [title, control]); row.orientation = .horizontal; row.spacing = 12
        return row
    }

    @objc private func saveClicked() {
        guard let name = GitHubUsername.normalized(username.stringValue) else {
            error.stringValue = ContributionError.invalidUsername.localizedDescription; return
        }
        preferences.username = name
        preferences.theme = Theme.allCases[max(0, theme.indexOfSelectedItem)]
        preferences.scale = [0.8, 1, 1.2, 1.4][max(0, size.indexOfSelectedItem)]
        preferences.companion = companion.state == .on
        preferences.locked = lock.state == .on
        let requestedLaunch = launch.state == .on
        do {
            if requestedLaunch && SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            else if !requestedLaunch && SMAppService.mainApp.status != .notRegistered { try SMAppService.mainApp.unregister() }
            onSave(preferences)
            if requestedLaunch && SMAppService.mainApp.status == .requiresApproval {
                error.stringValue = "Settings saved. Allow Grove in System Settings → General → Login Items."
            } else { window.close() }
        } catch {
            // Save the calendar independently of macOS login-item approval.
            onSave(preferences)
            self.error.stringValue = "Calendar saved. Login item could not be changed: \(error.localizedDescription)"
        }
    }

    @objc private func quitClicked() { NSApp.terminate(nil) }
}
