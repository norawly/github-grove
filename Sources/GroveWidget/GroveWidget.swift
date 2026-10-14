import Foundation
import Darwin
import SwiftUI
import WidgetKit
import GroveCore

struct GroveEntry: TimelineEntry {
    let date: Date
    let username: String
    let theme: String
    let snapshot: ContributionSnapshot?
}

enum WidgetProfile {
    // The containing app owns this folder. The sandbox entitlement permits only
    // reading this folder, without App Groups or access to unrelated user files.
    static var directory: URL? {
        guard let record = getpwuid(getuid()), let home = record.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: home), isDirectory: true)
            .appendingPathComponent("Library/Application Support/Grove", isDirectory: true)
    }
    static func read() -> (username: String, theme: String, snapshot: ContributionSnapshot?) {
        guard let directory, let data = try? Data(contentsOf: directory.appendingPathComponent("settings.json")),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = settings["username"] as? String, let username = GitHubUsername.normalized(raw) else {
            return ("", "dark", nil)
        }
        let theme = settings["theme"] as? String ?? "system"
        var snapshot: ContributionSnapshot?
        if let data = try? Data(contentsOf: directory.appendingPathComponent("calendar.json")),
           let saved = try? JSONDecoder().decode(ContributionSnapshot.self, from: data),
           saved.username == username, (try? saved.validate()) != nil { snapshot = saved }
        return (username, theme, snapshot)
    }
    static func cached(for username: String) -> ContributionSnapshot? {
        guard let data = try? Data(contentsOf: cacheURL),
              let saved = try? JSONDecoder().decode(ContributionSnapshot.self, from: data),
              saved.username == username, (try? saved.validate()) != nil else { return nil }
        return saved
    }
    static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("grove-calendar.json")
    }
    static func save(_ snapshot: ContributionSnapshot) {
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: cacheURL, options: .atomic) }
    }
}

struct GroveProvider: TimelineProvider {
    func placeholder(in context: Context) -> GroveEntry { GroveEntry(date: Date(), username: "github", theme: "dark", snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (GroveEntry) -> Void) {
        let profile = WidgetProfile.read()
        completion(GroveEntry(date: Date(), username: profile.username, theme: profile.theme,
                              snapshot: profile.snapshot ?? WidgetProfile.cached(for: profile.username)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GroveEntry>) -> Void) {
        let profile = WidgetProfile.read()
        Task {
            var snapshot = WidgetProfile.cached(for: profile.username) ?? profile.snapshot
            if !profile.username.isEmpty, let fresh = try? await ContributionClient().fetch(username: profile.username) {
                snapshot = fresh; WidgetProfile.save(fresh)
            }
            let now = Date()
            let entry = GroveEntry(date: now, username: profile.username, theme: profile.theme, snapshot: snapshot)
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(3600))))
        }
    }
}

struct GroveWidgetView: View {
    let entry: GroveEntry
    @Environment(\.colorScheme) private var colorScheme
    private var dark: Bool { entry.theme == "dark" || (entry.theme == "system" && colorScheme == .dark) }
    private func color(_ hex: UInt32) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 255) / 255,
              green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
    var body: some View {
        GeometryReader { geometry in
            let layout = CalendarLayout(days: entry.snapshot?.days ?? [])
            let width = max(1, geometry.size.width - 28)
            let pitch = width / CGFloat(layout.columns)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(entry.username.isEmpty ? "Open Grove to set your username" : "@\(entry.username)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(color(dark ? GitHubColors.darkText : GitHubColors.lightText))
                    if let snapshot = entry.snapshot {
                        let streak = snapshot.streak(asOf: entry.date)
                        Text("\(streak.days)\(streak.isLowerBound ? "+" : "") day\(streak.days == 1 ? "" : "s") streak")
                            .font(.system(size: 10.5))
                            .foregroundStyle(color(dark ? GitHubColors.darkSecondary : GitHubColors.lightSecondary))
                    }
                    Spacer(minLength: 0)
                }
                Canvas { context, size in
                    let levels = dark ? GitHubColors.darkLevels : GitHubColors.lightLevels
                    if entry.snapshot != nil {
                        for cell in layout.cells {
                            let rect = CGRect(x: CGFloat(cell.column) * pitch, y: CGFloat(cell.row) * pitch,
                                              width: max(1, pitch - 1.3), height: max(1, pitch - 1.3))
                            context.fill(Path(roundedRect: rect, cornerRadius: min(1.8, pitch / 5)), with: .color(color(levels[cell.day.level])))
                        }
                    } else {
                        for column in 0..<53 { for row in 0..<7 {
                            let rect = CGRect(x: CGFloat(column) * pitch, y: CGFloat(row) * pitch, width: max(1, pitch - 1.3), height: max(1, pitch - 1.3))
                            context.fill(Path(roundedRect: rect, cornerRadius: min(1.8, pitch / 5)), with: .color(color(levels[0])))
                        } }
                    }
                }
                .frame(height: pitch * 7)
                .accessibilityLabel("GitHub contribution calendar, \(entry.snapshot?.days.count ?? 0) days")
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .containerBackground(for: .widget) { color(dark ? GitHubColors.darkBackground : GitHubColors.lightBackground) }
    }
}

struct GroveCalendarWidget: Widget {
    private var families: [WidgetFamily] {
        #if compiler(>=6.4)
        return [.systemMedium, .systemExtraLarge]
        #else
        return [.systemMedium]
        #endif
    }
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GroveContributionCalendar", provider: GroveProvider()) { entry in GroveWidgetView(entry: entry) }
            .configurationDisplayName("GitHub calendar")
            .description("Your username, streak, and complete contribution calendar.")
            .supportedFamilies(families)
            .contentMarginsDisabled()
            .containerBackgroundRemovable(false)
    }
}

@main
struct GroveWidgets: WidgetBundle {
    var body: some Widget { GroveCalendarWidget() }
}
