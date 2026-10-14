import AppKit
import GroveCore

enum Theme: String, CaseIterable, Codable {
    case system, light, dark
    var title: String { self == .system ? "Follow macOS" : rawValue.capitalized }
}

struct Preferences: Codable {
    var username = ""
    var theme: Theme = .system
    var scale: Double = 1
    var locked = false
    var companion = false
    var originX: Double?
    var originY: Double?
    var screenID: UInt32?
}

final class LocalStore {
    let directory: URL

    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Grove", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
    }

    func loadPreferences() -> Preferences {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("settings.json")),
              var settings = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        settings.username = GitHubUsername.normalized(settings.username) ?? ""
        if ![0.8, 1, 1.2, 1.4].contains(settings.scale) { settings.scale = 1 }
        if settings.originX?.isFinite == false || settings.originY?.isFinite == false {
            settings.originX = nil; settings.originY = nil
        }
        return settings
    }

    func save(_ settings: Preferences) { write(settings, to: "settings.json") }

    func snapshot(for username: String) -> ContributionSnapshot? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("calendar.json")),
              let snapshot = try? JSONDecoder().decode(ContributionSnapshot.self, from: data),
              snapshot.username == username, (try? snapshot.validate()) != nil else { return nil }
        return snapshot
    }

    func save(_ snapshot: ContributionSnapshot) { write(snapshot, to: "calendar.json") }
    func clearSnapshot() { try? FileManager.default.removeItem(at: directory.appendingPathComponent("calendar.json")) }

    private func write<T: Encodable>(_ value: T, to filename: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let url = directory.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
