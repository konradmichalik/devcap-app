import XCTest
@testable import DevcapApp

final class ActivityMetricsTests: XCTestCase {
    /// Wednesday, 14 October 2026, noon UTC.
    private static let now = "2026-10-14T12:00:00Z"

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ iso: String) -> Date {
        guard let date = ISO8601DateFormatter().date(from: iso) else {
            preconditionFailure("invalid fixture timestamp: \(iso)")
        }
        return date
    }

    private func commit(_ hash: String, _ timestamp: String) -> Commit {
        Commit(hash: hash, message: "feat: x", commitType: "feat",
               timestamp: timestamp, committerTimestamp: timestamp,
               relativeTime: "1h ago", url: nil, diffStat: nil)
    }

    private func project(_ name: String, branches: [[Commit]]) -> ProjectLog {
        ProjectLog(project: name, path: "/tmp/\(name)", origin: nil, remoteUrl: nil,
                   branches: branches.enumerated().map {
                       BranchLog(name: "b\($0.offset)", url: nil, commits: $0.element, diffStat: nil)
                   },
                   diffStat: nil)
    }

    // MARK: - compactCount

    func testCompactCountKeepsSmallNumbersLiteral() {
        XCTAssertEqual(ActivityMetrics.compactCount(0), "0")
        XCTAssertEqual(ActivityMetrics.compactCount(999), "999")
    }

    func testCompactCountUsesOneDecimalBelowTenThousand() {
        XCTAssertEqual(ActivityMetrics.compactCount(1000), "1k")
        XCTAssertEqual(ActivityMetrics.compactCount(1063), "1.1k")
        XCTAssertEqual(ActivityMetrics.compactCount(9999), "10k")
    }

    func testCompactCountRoundsToWholeThousandsAndMillions() {
        XCTAssertEqual(ActivityMetrics.compactCount(10000), "10k")
        XCTAssertEqual(ActivityMetrics.compactCount(687_679), "688k")
        XCTAssertEqual(ActivityMetrics.compactCount(1_500_000), "1.5M")
    }

    // MARK: - pluralized

    func testPluralizedUsesSingularOnlyForOne() {
        XCTAssertEqual(ActivityMetrics.pluralized(0, "commit"), "0 commits")
        XCTAssertEqual(ActivityMetrics.pluralized(1, "commit"), "1 commit")
        XCTAssertEqual(ActivityMetrics.pluralized(2, "project"), "2 projects")
    }

    // MARK: - bucketDays

    func testSevenDayPeriodYieldsSevenDaysEndingToday() {
        let days = ActivityMetrics.bucketDays(period: "7d", now: date(Self.now), calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, date("2026-10-08T00:00:00Z"))
        XCTAssertEqual(days.last, date("2026-10-14T00:00:00Z"))
    }

    func testWeekPeriodStartsOnMondayEvenWhenCalendarStartsOnSunday() {
        let days = ActivityMetrics.bucketDays(period: "week", now: date(Self.now), calendar: calendar)
        XCTAssertEqual(days, [
            date("2026-10-12T00:00:00Z"),
            date("2026-10-13T00:00:00Z"),
            date("2026-10-14T00:00:00Z"),
        ])
    }

    func testSingleDayPeriodsHaveNoBuckets() {
        XCTAssertTrue(ActivityMetrics.bucketDays(period: "today", now: date(Self.now), calendar: calendar).isEmpty)
        XCTAssertTrue(ActivityMetrics.bucketDays(period: "yesterday", now: date(Self.now), calendar: calendar).isEmpty)
    }

    // MARK: - dailyCounts

    func testDailyCountsDedupeHashesAcrossBranchesAndBucketByAuthorDay() {
        let shared = commit("a", "2026-10-13T09:00:00Z")
        let projects = [
            project("one", branches: [
                [shared, commit("b", "2026-10-14T08:00:00Z")],
                [shared],
            ]),
            project("two", branches: [[commit("c", "2026-10-14T10:00:00Z")]]),
        ]

        let counts = ActivityMetrics.dailyCounts(projects, period: "7d", now: date(Self.now), calendar: calendar)

        XCTAssertEqual(counts, [0, 0, 0, 0, 0, 1, 2])
    }

    func testDailyCountsDropCommitsOutsideTheWindow() {
        let projects = [project("one", branches: [[commit("old", "2026-09-01T09:00:00Z")]])]

        let counts = ActivityMetrics.dailyCounts(projects, period: "7d", now: date(Self.now), calendar: calendar)

        XCTAssertEqual(counts, Array(repeating: 0, count: 7))
    }

    // MARK: - dayGroups

    func testDayGroupsLabelTodayYesterdayAndWeekday() {
        let commits = [
            commit("a", "2026-10-14T09:00:00Z"),
            commit("b", "2026-10-14T08:00:00Z"),
            commit("c", "2026-10-13T20:00:00Z"),
            commit("d", "2026-10-10T20:00:00Z"),
        ]

        let groups = ActivityMetrics.dayGroups(commits, now: date(Self.now), calendar: calendar)

        XCTAssertEqual(groups.map(\.label), ["Today", "Yesterday", "Saturday"])
        XCTAssertEqual(groups.map(\.commits.count), [2, 1, 1])
    }

    func testDayGroupsKeepUnparsableTimestampsInThePreviousGroup() {
        let commits = [commit("a", "2026-10-14T09:00:00Z"), commit("b", "garbage")]

        let groups = ActivityMetrics.dayGroups(commits, now: date(Self.now), calendar: calendar)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.commits.count, 2)
    }

    func testDayGroupsLabelAnUnparsableFirstCommitAsEarlier() {
        let groups = ActivityMetrics.dayGroups([commit("a", "garbage")], now: date(Self.now), calendar: calendar)

        XCTAssertEqual(groups.map(\.label), ["Earlier"])
    }

    // MARK: - latestActivity

    func testLatestActivityIsTheNewestCommitAcrossBranches() {
        let older = Commit(hash: "a", message: "x", commitType: nil, timestamp: "2026-10-14T08:00:00Z",
                           committerTimestamp: "2026-10-14T08:00:00Z", relativeTime: "4h ago", url: nil, diffStat: nil)
        let newer = Commit(hash: "b", message: "x", commitType: nil, timestamp: "2026-10-14T11:00:00Z",
                           committerTimestamp: "2026-10-14T11:00:00Z", relativeTime: "1h ago", url: nil, diffStat: nil)

        XCTAssertEqual(project("one", branches: [[older], [newer]]).latestActivity, "1h ago")
    }

    // MARK: - freshProjectIDs

    func testFreshProjectsAreEmptyOnFirstLoad() {
        let current = [project("one", branches: [[commit("a", "2026-10-14T09:00:00Z")]])]

        XCTAssertTrue(ActivityMetrics.freshProjectIDs(previous: [], current: current).isEmpty)
    }

    func testFreshProjectsFlagNewCommitsAndNewProjects() {
        let old = commit("a", "2026-10-14T09:00:00Z")
        let previous = [project("one", branches: [[old]]), project("two", branches: [[commit("x", "2026-10-14T07:00:00Z")]])]
        let current = [
            project("one", branches: [[commit("b", "2026-10-14T11:00:00Z"), old]]),
            project("two", branches: [[commit("x", "2026-10-14T07:00:00Z")]]),
            project("three", branches: [[commit("n", "2026-10-14T11:30:00Z")]]),
        ]

        let fresh = ActivityMetrics.freshProjectIDs(previous: previous, current: current)

        XCTAssertEqual(fresh, ["/tmp/one", "/tmp/three"])
    }
}
