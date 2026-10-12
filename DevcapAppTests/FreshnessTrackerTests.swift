import XCTest
@testable import DevcapApp

final class FreshnessTrackerTests: XCTestCase {
    private func project(_ name: String, hashes: [String]) -> ProjectLog {
        let commits = hashes.map {
            Commit(hash: $0, message: "feat: x", commitType: "feat",
                   timestamp: "2026-10-14T09:00:00Z", committerTimestamp: "2026-10-14T09:00:00Z",
                   relativeTime: "1h ago", url: nil, diffStat: nil)
        }
        return ProjectLog(project: name, path: "/tmp/\(name)", origin: nil, remoteUrl: nil,
                          branches: [BranchLog(name: "main", url: nil, commits: commits, diffStat: nil)],
                          diffStat: nil)
    }

    func testFirstScanFlagsNothing() {
        var tracker = FreshnessTracker()

        XCTAssertTrue(tracker.fresh(in: [project("one", hashes: ["a"])], key: "~/Sites|7d").isEmpty)
    }

    func testSecondScanWithSameKeyFlagsNewCommits() {
        var tracker = FreshnessTracker()
        _ = tracker.fresh(in: [project("one", hashes: ["a"])], key: "~/Sites|7d")

        let fresh = tracker.fresh(in: [project("one", hashes: ["b", "a"])], key: "~/Sites|7d")

        XCTAssertEqual(fresh, ["/tmp/one"])
    }

    func testChangedKeyStartsOverInsteadOfFlaggingEverything() {
        var tracker = FreshnessTracker()
        _ = tracker.fresh(in: [project("one", hashes: ["a"])], key: "~/Sites|7d")

        let otherPath = tracker.fresh(in: [project("two", hashes: ["x"])], key: "~/Work|7d")
        let otherPeriod = tracker.fresh(in: [project("two", hashes: ["x"])], key: "~/Work|today")

        XCTAssertTrue(otherPath.isEmpty)
        XCTAssertTrue(otherPeriod.isEmpty)
    }

    func testUnchangedRescanFlagsNothing() {
        var tracker = FreshnessTracker()
        _ = tracker.fresh(in: [project("one", hashes: ["a"])], key: "k")

        XCTAssertTrue(tracker.fresh(in: [project("one", hashes: ["a"])], key: "k").isEmpty)
    }
}
