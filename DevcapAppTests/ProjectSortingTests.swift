import XCTest
@testable import DevcapApp

final class ProjectSortingTests: XCTestCase {
    private func commit(_ hash: String, timestamp: String) -> Commit {
        Commit(hash: hash, message: "feat: x", commitType: "feat",
               timestamp: timestamp, relativeTime: "1h ago", url: nil, diffStat: nil)
    }

    private func project(_ name: String, commits: [Commit]) -> ProjectLog {
        ProjectLog(project: name, path: "/tmp/\(name)", origin: nil, remoteUrl: nil,
                   branches: [BranchLog(name: "main", url: nil, commits: commits, diffStat: nil)],
                   diffStat: nil)
    }

    func testSortsByLatestTimestampDescending() {
        let old = project("alpha", commits: [commit("a", timestamp: "2026-01-01T00:00:00Z")])
        let new = project("beta", commits: [commit("b", timestamp: "2026-06-01T00:00:00Z")])

        let result = ProjectSorting.sorted([old, new], order: "time")

        XCTAssertEqual(result.map(\.project), ["beta", "alpha"])
    }

    func testSortsByNameCaseInsensitive() {
        let items = [project("Zebra", commits: []), project("apple", commits: []), project("Mango", commits: [])]

        let result = ProjectSorting.sorted(items, order: "name")

        XCTAssertEqual(result.map(\.project), ["apple", "Mango", "Zebra"])
    }

    func testSortsByCommitCountDescending() {
        let few = project("few", commits: [commit("a", timestamp: "2026-01-01T00:00:00Z")])
        let many = project("many", commits: [
            commit("b", timestamp: "2026-01-01T00:00:00Z"),
            commit("c", timestamp: "2026-01-02T00:00:00Z"),
        ])

        let result = ProjectSorting.sorted([few, many], order: "commits")

        XCTAssertEqual(result.map(\.project), ["many", "few"])
    }

    func testUnknownOrderFallsBackToTime() {
        let old = project("alpha", commits: [commit("a", timestamp: "2026-01-01T00:00:00Z")])
        let new = project("beta", commits: [commit("b", timestamp: "2026-06-01T00:00:00Z")])

        let result = ProjectSorting.sorted([old, new], order: "bogus")

        XCTAssertEqual(result.map(\.project), ["beta", "alpha"])
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertTrue(ProjectSorting.sorted([], order: "time").isEmpty)
    }
}

final class ProjectLogAggregateTests: XCTestCase {
    private func commit(_ hash: String, timestamp: String) -> Commit {
        Commit(hash: hash, message: "x", commitType: nil,
               timestamp: timestamp, relativeTime: "", url: nil, diffStat: nil)
    }

    func testTotalCommitsDeduplicatesHashesAcrossBranches() {
        let shared = commit("shared", timestamp: "2026-01-01T00:00:00Z")
        let onlyMain = commit("main-only", timestamp: "2026-01-02T00:00:00Z")
        let onlyDev = commit("dev-only", timestamp: "2026-01-03T00:00:00Z")

        let log = ProjectLog(
            project: "p", path: "/tmp/p", origin: nil, remoteUrl: nil,
            branches: [
                BranchLog(name: "main", url: nil, commits: [shared, onlyMain], diffStat: nil),
                BranchLog(name: "dev", url: nil, commits: [shared, onlyDev], diffStat: nil),
            ],
            diffStat: nil
        )

        // shared counted once → 3 unique, not 4
        XCTAssertEqual(log.totalCommits, 3)
    }

    func testLatestTimestampReturnsMaximum() {
        let log = ProjectLog(
            project: "p", path: "/tmp/p", origin: nil, remoteUrl: nil,
            branches: [
                BranchLog(name: "main", url: nil, commits: [
                    commit("a", timestamp: "2026-01-01T00:00:00Z"),
                    commit("b", timestamp: "2026-03-01T00:00:00Z"),
                ], diffStat: nil),
            ],
            diffStat: nil
        )

        XCTAssertEqual(log.latestTimestamp, "2026-03-01T00:00:00Z")
    }
}
