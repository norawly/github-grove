import Foundation
import GroveCore

final class CalendarTests {
    private func fixture(count: Int = 368) -> [ContributionDay] {
        let start = GitHubDate.parse("2025-10-12")!
        return (0..<count).map { ContributionDay(date: GitHubDate.key(GitHubDate.adding(days: $0, to: start)), level: $0 % 5) }
    }
    private func html(_ days: [ContributionDay]) -> String {
        // GitHub's HTML is row-major; sorting by date is necessary.
        let ordered = days.enumerated().sorted { ($0.offset % 7, $0.offset / 7) < ($1.offset % 7, $1.offset / 7) }
        return ordered.map { "<td data-level='\($0.element.level)' class='anything' data-date='\($0.element.date)'></td>" }.joined()
    }

    func testUsernamesRejectPathsAndInjection() {
        expectEqual(GitHubUsername.normalized(" @Octo-Cat "), "octo-cat")
        for invalid in ["", "-user", "user-", "user--name", "https://github.com/user", "../foo", "a/b", "a b", "foo?x=1", "日本", String(repeating: "a", count: 40)] {
            expectNil(GitHubUsername.normalized(invalid), invalid)
        }
    }

    func testParserSortsRealHTMLAttributeOrderAndSingleQuotes() throws {
        let days = fixture()
        let parsed = try ContributionParser.parse(html(days), username: "Octocat")
        expectEqual(parsed.days, days)
        expectEqual(parsed.username, "octocat")
    }

    func testOldSVGMarkupAndDoubleQuotes() throws {
        let html = fixture().map { "<rect data-date=\"\($0.date)\" data-level=\"\($0.level)\"/>" }.joined()
        expectEqual(try ContributionParser.parse(html, username: "octocat").days.count, 368)
    }

    func testMissingCalendarFailsInsteadOfShowingZeroActivity() {
        for page in ["<html>Not Found</html>", "<html>Please sign in</html>", "<td data-date='2026-10-14' data-level='0'>"] {
            expectThrows(try ContributionParser.parse(page, username: "octocat"))
        }
    }

    func testDuplicateMissingAndInvalidDaysFailClosed() {
        let days = fixture()
        expectThrows(try ContributionParser.parse(html(days + [days[0]]), username: "octocat"))
        var gap = days; gap.remove(at: 20)
        expectThrows(try ContributionParser.parse(html(gap), username: "octocat"))
        expectThrows(try ContributionParser.parse(html(days).replacingOccurrences(of: "data-level='4'", with: "data-level='7'"), username: "octocat"))
        expectThrows(try ContributionParser.parse(html(days).replacingOccurrences(of: "2025-10-12", with: "2025-02-30"), username: "octocat"))
    }

    func testDatesUseUTCAndHandleLeapDay() {
        expectNil(GitHubDate.parse("2025-02-29"))
        expectNil(GitHubDate.parse("2026-2-01"))
        expectEqual(GitHubDate.key(GitHubDate.adding(days: 1, to: GitHubDate.parse("2024-02-28")!)), "2024-02-29")
        expectEqual(GitHubDate.key(GitHubDate.adding(days: 1, to: GitHubDate.parse("2024-02-29")!)), "2024-03-01")
        expectEqual(GitHubDate.calendar.timeZone.secondsFromGMT(), 0)
    }

    func testCurrentStreakIncludesTodayAndGracesUnfinishedDay() {
        let now = GitHubDate.parse("2026-10-14")!
        let days = [ContributionDay(date: "2026-10-10", level: 0), ContributionDay(date: "2026-10-11", level: 1),
                    ContributionDay(date: "2026-10-12", level: 2), ContributionDay(date: "2026-10-13", level: 3)]
        let activeToday = ContributionSnapshot(username: "octocat", days: days + [ContributionDay(date: "2026-10-14", level: 1)])
        expectEqual(activeToday.streak(asOf: now).days, 4)
        expectFalse(activeToday.streak(asOf: now).isLowerBound)
        let emptyToday = ContributionSnapshot(username: "octocat", days: days + [ContributionDay(date: "2026-10-14", level: 0)])
        expectEqual(emptyToday.streak(asOf: now).days, 3)
        expectEqual(emptyToday.streak(asOf: GitHubDate.adding(days: 1, to: now)).days, 0)
    }

    func testStreakStopsAtGapsAndMarksRollingWindowLimit() {
        let days = [ContributionDay(date: "2026-10-12", level: 2), ContributionDay(date: "2026-10-13", level: 3)]
        let snapshot = ContributionSnapshot(username: "octocat", days: days)
        expectEqual(snapshot.streak(asOf: GitHubDate.parse("2026-10-14")!).days, 2)
        expectTrue(snapshot.streak(asOf: GitHubDate.parse("2026-10-14")!).isLowerBound)
        expectEqual(snapshot.streak(asOf: GitHubDate.parse("2026-10-20")!).days, 0)
    }

    func testLayoutPreservesEveryDayAndSundayFirstOrientation() {
        let layout = CalendarLayout(days: fixture())
        expectEqual(layout.cells.count, 368)
        expectEqual(layout.columns, 53)
        expectEqual(layout.cells[0].row, 0)
        expectEqual(layout.cells[6].row, 6)
        expectEqual(layout.cells[7].column, 1)
        expectEqual(layout.cells.last?.row, 3)
        expectEqual(layout.cells.last?.column, 52)
        expectTrue(layout.months.contains { $0.label == "Jan" })
        for pair in zip(layout.months, layout.months.dropFirst()) { expectAtLeast(pair.1.column - pair.0.column, 3) }
    }

    func testLayoutRetains54thColumnWhenNecessary() {
        let layout = CalendarLayout(days: fixture(count: 372))
        expectEqual(layout.columns, 54)
        expectEqual(layout.cells.last?.column, 53)
    }

    func testCacheRoundTripAndInvalidCacheValidation() throws {
        let snapshot = ContributionSnapshot(username: "octocat", days: fixture())
        let data = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(ContributionSnapshot.self, from: data)
        expectEqual(snapshot, restored)
        expectNoThrow(try restored.validate())
        expectThrows(try ContributionSnapshot(username: "../bad", days: fixture()).validate())
        expectThrows(try ContributionSnapshot(username: "octocat", days: []).validate())
    }
}
