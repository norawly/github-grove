import Foundation

public struct ContributionClient {
    public init() {}

    public func fetch(username: String) async throws -> ContributionSnapshot {
        guard let name = GitHubUsername.normalized(username) else { throw ContributionError.invalidUsername }
        let url = URL(string: "https://github.com/users/\(name)/contributions")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Grove/1.0 (macOS desktop contribution calendar)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForResource = 45
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ContributionError.unavailable }
        guard http.url?.host == "github.com" else { throw ContributionError.unavailable }
        switch http.statusCode {
        case 200: break
        case 404: throw ContributionError.notFound
        case 403, 429: throw ContributionError.rateLimited
        default: throw ContributionError.unavailable
        }
        guard data.count <= 2_000_000 else { throw ContributionError.tooLarge }
        guard let html = String(data: data, encoding: .utf8) else { throw ContributionError.invalidCalendar }
        let snapshot = try ContributionParser.parse(html, username: name)
        guard let last = snapshot.days.last.flatMap({ GitHubDate.parse($0.date) }) else {
            throw ContributionError.invalidCalendar
        }
        let age = GitHubDate.calendar.dateComponents([.day], from: last, to: Date()).day ?? 100
        guard (-1...2).contains(age) else { throw ContributionError.invalidCalendar }
        return snapshot
    }
}
