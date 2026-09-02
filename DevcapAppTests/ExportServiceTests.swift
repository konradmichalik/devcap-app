import XCTest
@testable import DevcapApp

final class ExportServiceTests: XCTestCase {
    /// Wednesday, 2 September 2026, noon in Berlin — the reference "now" for
    /// every derivation test. In UTC this is still the same calendar day, so a
    /// test that disagrees between the two zones is telling us about the
    /// commit's timestamp, not about `now`.
    private static let noon = "2026-09-02T12:00:00+02:00"

    // MARK: - Fixtures

    /// `committer` defaults to `timestamp`, the ordinary case of a commit that
    /// was never rewritten. Pass it explicitly to model a rebase or cherry-pick.
    private func commit(_ hash: String, timestamp: String, committer: String? = nil) -> Commit {
        Commit(hash: hash, message: "feat: x", commitType: "feat",
               timestamp: timestamp, committerTimestamp: committer ?? timestamp,
               relativeTime: "1h ago", url: nil, diffStat: nil)
    }

    private func branch(_ name: String, _ commits: [Commit]) -> BranchLog {
        BranchLog(name: name, url: nil, commits: commits, diffStat: nil)
    }

    private func project(_ name: String, branches: [BranchLog]) -> ProjectLog {
        ProjectLog(project: name, path: "/tmp/\(name)", origin: nil, remoteUrl: nil,
                   branches: branches, diffStat: nil)
    }

    private func project(_ name: String, commits: [Commit]) -> ProjectLog {
        project(name, branches: [branch("main", commits)])
    }

    private func date(_ iso: String) -> Date {
        guard let date = ISO8601DateFormatter().date(from: iso) else {
            preconditionFailure("invalid fixture timestamp: \(iso)")
        }
        return date
    }

    private func calendar(_ identifier: String) -> Calendar {
        guard let zone = TimeZone(identifier: identifier) else {
            preconditionFailure("unknown time zone: \(identifier)")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    private func payload(
        week: [ProjectLog],
        now: String = ExportServiceTests.noon,
        timeZone: String = "Europe/Berlin",
        ttlSeconds: Int = 1000
    ) -> ExportPayload {
        ExportService.buildPayload(
            ttlSeconds: ttlSeconds,
            now: date(now),
            calendar: calendar(timeZone)
        ) { _ in week }
    }

    // MARK: - Scan count

    func testBuildPayloadPerformsExactlyOneWeekScan() {
        var periods: [String] = []

        _ = ExportService.buildPayload(
            ttlSeconds: 1000,
            now: date(Self.noon),
            calendar: calendar("Europe/Berlin")
        ) { period in
            periods.append(period)
            return []
        }

        XCTAssertEqual(periods, ["week"])
    }

    // MARK: - Today derivation

    func testBuildPayloadDerivesTodayFromWeekResult() {
        let week = [
            project("a", commits: [
                commit("1", timestamp: "2026-09-02T09:00:00+02:00"),
                commit("2", timestamp: "2026-08-31T09:00:00+02:00"),
            ]),
        ]

        let result = payload(week: week)

        XCTAssertEqual(result.views[0].value, "1")
        XCTAssertEqual(result.views[1].value, "2")
    }

    func testBuildPayloadUsesLocalDayBoundaryNotUTC() {
        // 00:30 in Berlin is still 22:30 of the previous day in UTC.
        let week = [project("a", commits: [commit("1", timestamp: "2026-09-02T00:30:00+02:00")])]

        let berlin = payload(week: week, timeZone: "Europe/Berlin")
        let utc = payload(week: week, timeZone: "UTC")

        XCTAssertEqual(berlin.views[0].value, "1")
        XCTAssertEqual(utc.views[0].value, "0")
    }

    func testBuildPayloadCountsOnlyProjectsWithCommitsToday() {
        let week = [
            project("active", commits: [commit("1", timestamp: "2026-09-02T09:00:00+02:00")]),
            project("stale", commits: [commit("2", timestamp: "2026-08-31T09:00:00+02:00")]),
        ]

        let result = payload(week: week)

        XCTAssertEqual(result.views[0].value, "1")
        XCTAssertEqual(result.views[0].detail, "1 Projekte")
    }

    func testBuildPayloadIgnoresUnparsableTimestamp() {
        let week = [
            project("a", commits: [
                commit("1", timestamp: "2026-09-02T09:00:00+02:00"),
                commit("2", timestamp: "2026-09-02T09:00:00+02:00", committer: "not-a-timestamp"),
            ]),
        ]

        let result = payload(week: week)

        XCTAssertEqual(result.views[0].value, "1")
        XCTAssertEqual(result.views[1].value, "2")
    }

    // MARK: - Author date vs committer date

    /// A commit authored two weeks ago but rebased into history today is exactly
    /// what the scan's own `git log --after` filter selected, so the derivation
    /// has to count it. Filtering on the author date instead undercounted the
    /// real tree by 32 %, which is what sank the first attempt at this change.
    func testBuildPayloadCountsRebasedCommitByCommitterDate() {
        let week = [
            project("a", commits: [
                commit("1", timestamp: "2026-08-17T17:12:42+02:00",
                       committer: "2026-09-02T14:12:50+02:00"),
            ]),
        ]

        let result = payload(week: week)

        XCTAssertEqual(result.views[0].value, "1")
        XCTAssertEqual(result.views[0].detail, "1 Projekte")
    }

    /// The mirror image: authored today, but it entered history yesterday. A
    /// dedicated `today` scan would not have returned it, so neither may the
    /// derivation.
    func testBuildPayloadExcludesCommitAuthoredTodayButCommittedEarlier() {
        let week = [
            project("a", commits: [
                commit("1", timestamp: "2026-09-02T09:00:00+02:00",
                       committer: "2026-09-01T09:00:00+02:00"),
            ]),
        ]

        let result = payload(week: week)

        XCTAssertEqual(result.views[0].value, "0")
        XCTAssertEqual(result.views[0].state, .idle)
    }

    func testBuildPayloadDedupsCommitHashAcrossBranchesForToday() {
        let shared = commit("1", timestamp: "2026-09-02T09:00:00+02:00")
        let week = [
            project("a", branches: [
                branch("main", [shared]),
                branch("feature", [shared, commit("2", timestamp: "2026-09-02T10:00:00+02:00")]),
            ]),
        ]

        let result = payload(week: week)

        XCTAssertEqual(result.views[0].value, "2")
    }

    func testBuildPayloadMarksTodayIdleWhenNothingCommittedToday() {
        let week = [project("a", commits: [commit("1", timestamp: "2026-08-31T09:00:00+02:00")])]

        let result = payload(week: week)

        XCTAssertEqual(result.views[0].value, "0")
        XCTAssertEqual(result.views[0].state, .idle)
        XCTAssertEqual(result.views[1].state, .ok)
    }

    // MARK: - Payload shape

    func testBuildPayloadIncludesAllThreeViewsForEmptyInput() {
        let result = payload(week: [])

        XCTAssertEqual(result.views.map(\.id), ["today", "week", "top"])
        XCTAssertEqual(result.views[0].value, "0")
        XCTAssertEqual(result.views[0].state, .idle)
        XCTAssertEqual(result.views[1].value, "0")
        XCTAssertEqual(result.views[2].state, .idle)
    }

    func testBuildPayloadPicksTopProjectByWeekCommitCount() {
        let week = [
            project("few", commits: [commit("1", timestamp: "2026-08-31T10:00:00+02:00")]),
            project("many", commits: [
                commit("2", timestamp: "2026-08-31T10:00:00+02:00"),
                commit("3", timestamp: "2026-09-01T10:00:00+02:00"),
            ]),
        ]

        let result = payload(week: week)

        let top = result.views[2]
        XCTAssertEqual(top.value, "many")
        XCTAssertEqual(top.detail, "2 Commits")
    }

    func testBuildPayloadSetsSchemaFields() {
        let result = payload(week: [], ttlSeconds: 1200)

        XCTAssertEqual(result.schemaVersion, 1)
        XCTAssertEqual(result.app, "devcap")
        XCTAssertEqual(result.ttlSeconds, 1200)
        XCTAssertFalse(result.updatedAt.isEmpty)
    }

    // MARK: - write

    private func makeTempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testWriteCreatesFileWithRestrictedPermissions() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        try ExportService.write(payload(week: []), to: dir)

        let target = dir.appendingPathComponent("data.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: target.path)
        XCTAssertEqual(attrs[.posixPermissions] as? Int, 0o600)
    }

    func testWriteLeavesNoLeftoverTempFile() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        try ExportService.write(payload(week: []), to: dir)

        let tmp = dir.appendingPathComponent("data.json.tmp")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path))
    }

    func testWriteOverwritesExistingFileContent() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        try ExportService.write(payload(week: [], ttlSeconds: 1000), to: dir)
        try ExportService.write(payload(week: [], ttlSeconds: 2000), to: dir)

        let target = dir.appendingPathComponent("data.json")
        let data = try Data(contentsOf: target)
        let decoded = try JSONDecoder().decode(ExportPayload.self, from: data)
        XCTAssertEqual(decoded.ttlSeconds, 2000)
    }

    // MARK: - delete

    func testDeleteRemovesExistingFile() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try ExportService.write(payload(week: []), to: dir)

        try ExportService.delete(from: dir)

        let target = dir.appendingPathComponent("data.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }

    func testDeleteIsNoOpWhenFileMissing() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertNoThrow(try ExportService.delete(from: dir))
    }

    // MARK: - applicationSupportURL

    func testApplicationSupportURLCreatesBundleSubdirectory() throws {
        let base = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let dir = try ExportService.applicationSupportURL(baseDirectory: base, bundleIdentifier: "com.example.test")

        XCTAssertEqual(dir, base.appendingPathComponent("com.example.test", isDirectory: true))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
    }
}
