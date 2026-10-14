import Foundation

// A dependency-free test runner so that Command Line Tools is sufficient.
// Every failed expectation returns a nonzero process exit status, including in CI.
var failures = 0
func recordFailure(_ message: String, file: StaticString, line: UInt) {
    failures += 1
    print("FAIL \(file):\(line): \(message)")
}
func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: StaticString = #fileID, line: UInt = #line) {
    if a != b { recordFailure("\(a) != \(b). \(message)", file: file, line: line) }
}
func expectNil<T>(_ value: T?, _ message: String = "", file: StaticString = #fileID, line: UInt = #line) {
    if value != nil { recordFailure("Expected nil. \(message)", file: file, line: line) }
}
func expectTrue(_ value: Bool, file: StaticString = #fileID, line: UInt = #line) {
    if !value { recordFailure("Expected true", file: file, line: line) }
}
func expectFalse(_ value: Bool, file: StaticString = #fileID, line: UInt = #line) {
    if value { recordFailure("Expected false", file: file, line: line) }
}
func expectAtLeast<T: Comparable>(_ a: T, _ b: T, file: StaticString = #fileID, line: UInt = #line) {
    if a < b { recordFailure("\(a) is less than \(b)", file: file, line: line) }
}
func expectThrows(_ expression: @autoclosure () throws -> Any, file: StaticString = #fileID, line: UInt = #line) {
    do { _ = try expression(); recordFailure("Expected an error", file: file, line: line) } catch {}
}
func expectNoThrow(_ expression: @autoclosure () throws -> Any, file: StaticString = #fileID, line: UInt = #line) {
    do { _ = try expression() } catch { recordFailure(error.localizedDescription, file: file, line: line) }
}

let suite = CalendarTests()
let checks: [(String, () throws -> Void)] = [
    ("Username validation", suite.testUsernamesRejectPathsAndInjection),
    ("Unordered HTML and single quotes", suite.testParserSortsRealHTMLAttributeOrderAndSingleQuotes),
    ("SVG and double quotes", suite.testOldSVGMarkupAndDoubleQuotes),
    ("Error pages fail closed", suite.testMissingCalendarFailsInsteadOfShowingZeroActivity),
    ("Duplicate, missing and invalid dates", suite.testDuplicateMissingAndInvalidDaysFailClosed),
    ("UTC and leap years", suite.testDatesUseUTCAndHandleLeapDay),
    ("Today and yesterday streak", suite.testCurrentStreakIncludesTodayAndGracesUnfinishedDay),
    ("Streak gaps and calendar boundary", suite.testStreakStopsAtGapsAndMarksRollingWindowLimit),
    ("Full calendar layout", suite.testLayoutPreservesEveryDayAndSundayFirstOrientation),
    ("54th column retained", suite.testLayoutRetains54thColumnWhenNecessary),
    ("Cache validation and round trip", suite.testCacheRoundTripAndInvalidCacheValidation)
]
for (name, check) in checks {
    let before = failures
    do { try check() } catch { recordFailure("\(name): \(error)", file: #fileID, line: #line) }
    if before == failures { print("PASS \(name)") }
}
print("\(checks.count) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
