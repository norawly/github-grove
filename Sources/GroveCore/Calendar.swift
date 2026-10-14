import Foundation

public enum GitHubUsername {
    public static func normalized(_ input: String) -> String? {
        let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard name.count <= 39,
              name.range(of: #"^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$"#, options: .regularExpression) != nil else {
            return nil
        }
        return name.lowercased()
    }
}

public enum GitHubDate {
    public static var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)!
        result.locale = Locale(identifier: "en_US_POSIX")
        result.firstWeekday = 1
        return result
    }

    public static func parse(_ value: String) -> Date? {
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), key(date) == value else { return nil }
        return date
    }

    public static func key(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    public static func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }
}

public struct ContributionDay: Codable, Equatable, Sendable {
    public let date: String
    public let level: Int

    public init(date: String, level: Int) {
        self.date = date
        self.level = level
    }
}

public struct ContributionSnapshot: Codable, Equatable, Sendable {
    public let username: String
    public let days: [ContributionDay]
    public let fetchedAt: Date

    public init(username: String, days: [ContributionDay], fetchedAt: Date = Date()) {
        self.username = username
        self.days = days.sorted { $0.date < $1.date }
        self.fetchedAt = fetchedAt
    }

    /// UTC, matching GitHub. An unfinished zero-activity day does not end yesterday's streak.
    /// The visible rolling calendar limits the maximum streak we can know.
    public func streak(asOf now: Date = Date()) -> (days: Int, isLowerBound: Bool) {
        let levels = Dictionary(days.map { ($0.date, $0.level) }, uniquingKeysWith: { a, _ in a })
        var day = GitHubDate.calendar.startOfDay(for: now)
        if (levels[GitHubDate.key(day)] ?? 0) == 0 { day = GitHubDate.adding(days: -1, to: day) }
        var count = 0
        while (levels[GitHubDate.key(day)] ?? 0) > 0 {
            count += 1
            day = GitHubDate.adding(days: -1, to: day)
        }
        let reachesEdge = count > 0 && levels[GitHubDate.key(day)] == nil
        return (count, reachesEdge)
    }

    public func validate() throws {
        guard GitHubUsername.normalized(username) == username,
              (330...378).contains(days.count),
              let start = days.first.flatMap({ GitHubDate.parse($0.date) }),
              GitHubDate.calendar.component(.weekday, from: start) == 1 else {
            throw ContributionError.invalidCalendar
        }
        for (offset, day) in days.enumerated() {
            guard (0...4).contains(day.level),
                  day.date == GitHubDate.key(GitHubDate.adding(days: offset, to: start)) else {
                throw ContributionError.invalidCalendar
            }
        }
    }
}

public enum ContributionError: LocalizedError {
    case invalidUsername, notFound, rateLimited, unavailable, invalidCalendar, tooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidUsername: return "Enter a valid GitHub username, without a profile URL."
        case .notFound: return "This GitHub profile could not be found. Check the username."
        case .rateLimited: return "GitHub is limiting requests. Grove will try again later."
        case .unavailable: return "GitHub is unavailable. Grove will try again later."
        case .invalidCalendar: return "GitHub's calendar could not be read. Your saved calendar is kept."
        case .tooLarge: return "GitHub returned an unexpected response. Your saved calendar is kept."
        }
    }
}

public enum ContributionParser {
    /// GitHub serves the graph as an HTML fragment. Do not depend on attribute order,
    /// tooltips, CSS class names, or the order of cells (which is row-major in the HTML).
    public static func parse(_ html: String, username: String, fetchedAt: Date = Date()) throws -> ContributionSnapshot {
        guard let username = GitHubUsername.normalized(username) else { throw ContributionError.invalidUsername }
        let tags = try NSRegularExpression(pattern: #"<(?:td|rect)\b[^>]*>"#, options: [.caseInsensitive])
        let attributes = try NSRegularExpression(pattern: #"([\w-]+)\s*=\s*["']([^"']*)["']"#)
        let source = html as NSString
        var days: [ContributionDay] = []
        for match in tags.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            let tag = source.substring(with: match.range)
            let text = tag as NSString
            var values: [String: String] = [:]
            for attribute in attributes.matches(in: tag, range: NSRange(location: 0, length: text.length)) {
                values[text.substring(with: attribute.range(at: 1)).lowercased()] = text.substring(with: attribute.range(at: 2))
            }
            guard let date = values["data-date"] else { continue }
            guard GitHubDate.parse(date) != nil, let raw = values["data-level"], let level = Int(raw), (0...4).contains(level) else {
                throw ContributionError.invalidCalendar
            }
            days.append(ContributionDay(date: date, level: level))
        }
        let snapshot = ContributionSnapshot(username: username, days: days, fetchedAt: fetchedAt)
        try snapshot.validate()
        return snapshot
    }
}

public struct CalendarLayout {
    public struct Cell {
        public let day: ContributionDay
        public let column: Int
        public let row: Int
    }
    public struct Month {
        public let label: String
        public let column: Int
    }
    public let cells: [Cell]
    public let months: [Month]
    public let columns: Int

    public init(days: [ContributionDay]) {
        guard let first = days.first, let start = GitHubDate.parse(first.date) else {
            cells = []; months = []; columns = 53; return
        }
        let calendar = GitHubDate.calendar
        let sunday = GitHubDate.adding(days: -(calendar.component(.weekday, from: start) - 1), to: start)
        var cells: [Cell] = []
        var months: [Month] = []
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var previousMonth = -1
        for day in days {
            guard let date = GitHubDate.parse(day.date) else { continue }
            let offset = calendar.dateComponents([.day], from: sunday, to: date).day!
            let column = offset / 7
            cells.append(Cell(day: day, column: column, row: offset % 7))
            let month = calendar.component(.month, from: date)
            if month != previousMonth {
                // Skip a tiny leading partial month rather than overlapping two labels.
                if months.last.map({ column - $0.column < 3 }) == true { months.removeLast() }
                months.append(Month(label: names[month - 1], column: column))
                previousMonth = month
            }
        }
        self.cells = cells
        self.months = months
        columns = max(53, (cells.last?.column ?? 52) + 1)
    }
}
