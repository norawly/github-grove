import AppKit
import GroveCore

let arguments = Array(CommandLine.arguments.dropFirst())
func option(_ flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1)
}

// Headless developer commands must run before NSApplication is created. They do not
// show windows, register login items, write user preferences, or alter desktop state.
if arguments.first == "--fetch" {
    guard arguments.count == 2 else { fail("Usage: Grove --fetch USERNAME") }
    Task {
        do {
            let snapshot = try await ContributionClient().fetch(username: arguments[1])
            print("Fetched \(snapshot.days.count) days for @\(snapshot.username), \(snapshot.days.first!.date)…\(snapshot.days.last!.date). Calendar valid.")
            exit(0)
        } catch { fail(error.localizedDescription) }
    }
    dispatchMain()
} else if arguments.first == "--parse" {
    guard arguments.count == 3 else { fail("Usage: Grove --parse HTML_FILE USERNAME") }
    do {
        let snapshot = try ContributionParser.parse(String(contentsOfFile: arguments[1], encoding: .utf8), username: arguments[2])
        print("Parsed \(snapshot.days.count) contiguous days. Columns: \(CalendarLayout(days: snapshot.days).columns).")
    } catch { fail(error.localizedDescription) }
} else if arguments.first == "--render" {
    guard arguments.count >= 2 else { fail("Usage: Grove --render OUTPUT.png [--theme light|dark] [--html FILE --username NAME]") }
    do {
        let snapshot: ContributionSnapshot
        if let path = option("--cache") {
            snapshot = try JSONDecoder().decode(ContributionSnapshot.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            try snapshot.validate()
        } else if let path = option("--html") {
            guard let name = option("--username") else { fail("--html requires --username") }
            snapshot = try ContributionParser.parse(String(contentsOfFile: path, encoding: .utf8), username: name)
        } else { snapshot = Rendering.demo() }
        let theme = Theme(rawValue: option("--theme") ?? "dark") ?? .dark
        try Rendering.card(output: arguments[1], theme: theme, snapshot: snapshot)
        print("Rendered \(arguments[1]) without opening a window.")
    } catch { fail(error.localizedDescription) }
} else if arguments.first == "--icon" {
    guard arguments.count == 2 else { fail("Usage: Grove --icon OUTPUT.png") }
    do { try Rendering.icon(output: arguments[1]) } catch { fail(error.localizedDescription) }
} else if arguments.first == "--help" {
    print("Grove — GitHub on your desktop. Launch the .app for setup.\nDeveloper tools: --fetch USERNAME, --parse FILE USERNAME, --render PNG, --icon PNG.")
} else if !arguments.isEmpty { fail("Unknown command. Use --help.") }
else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let controller = AppController()
        app.delegate = controller
        app.run()
        withExtendedLifetime(controller) {}
    }
}
