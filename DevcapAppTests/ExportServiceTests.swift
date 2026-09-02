import XCTest
@testable import DevcapApp

final class ExportServiceTests: XCTestCase {
    private func commit(_ hash: String, timestamp: String) -> Commit {
        Commit(hash: hash, message: "feat: x", commitType: "feat",
               timestamp: timestamp, relativeTime: "1h ago", url: nil, diffStat: nil)
    }

    private func project(_ name: String, commits: [Commit]) -> ProjectLog {
        ProjectLog(project: name, path: "/tmp/\(name)", origin: nil, remoteUrl: nil,
                   branches: [BranchLog(name: "main", url: nil, commits: commits, diffStat: nil)],
                   diffStat: nil)
    }

    // MARK: - buildPayload

    func testBuildPayloadIncludesAllThreeViewsForEmptyInput() {
        let payload = ExportService.buildPayload(today: [], week: [], ttlSeconds: 1000)

        XCTAssertEqual(payload.views.map(\.id), ["today", "week", "top"])
        XCTAssertEqual(payload.views[0].value, "0")
        XCTAssertEqual(payload.views[0].state, .idle)
        XCTAssertEqual(payload.views[1].value, "0")
    }

    func testBuildPayloadComputesTodayAndWeekCommitCounts() {
        let today = [project("a", commits: [commit("1", timestamp: "2026-09-02T10:00:00Z")])]
        let week = [
            project("a", commits: [commit("1", timestamp: "2026-09-02T10:00:00Z")]),
            project("b", commits: [
                commit("2", timestamp: "2026-08-30T10:00:00Z"),
                commit("3", timestamp: "2026-08-31T10:00:00Z"),
            ]),
        ]

        let payload = ExportService.buildPayload(today: today, week: week, ttlSeconds: 1000)

        XCTAssertEqual(payload.views[0].value, "1")
        XCTAssertEqual(payload.views[1].value, "3")
    }

    func testBuildPayloadPicksTopProjectByWeekCommitCount() {
        let week = [
            project("few", commits: [commit("1", timestamp: "2026-08-30T10:00:00Z")]),
            project("many", commits: [
                commit("2", timestamp: "2026-08-30T10:00:00Z"),
                commit("3", timestamp: "2026-08-31T10:00:00Z"),
            ]),
        ]

        let payload = ExportService.buildPayload(today: [], week: week, ttlSeconds: 1000)

        let top = payload.views[2]
        XCTAssertEqual(top.value, "many")
        XCTAssertEqual(top.detail, "2 Commits")
    }

    func testBuildPayloadSetsSchemaFields() {
        let payload = ExportService.buildPayload(today: [], week: [], ttlSeconds: 1200)

        XCTAssertEqual(payload.schemaVersion, 1)
        XCTAssertEqual(payload.app, "devcap")
        XCTAssertEqual(payload.ttlSeconds, 1200)
        XCTAssertFalse(payload.updatedAt.isEmpty)
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
        let payload = ExportService.buildPayload(today: [], week: [], ttlSeconds: 1000)

        try ExportService.write(payload, to: dir)

        let target = dir.appendingPathComponent("data.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: target.path)
        XCTAssertEqual(attrs[.posixPermissions] as? Int, 0o600)
    }

    func testWriteLeavesNoLeftoverTempFile() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let payload = ExportService.buildPayload(today: [], week: [], ttlSeconds: 1000)

        try ExportService.write(payload, to: dir)

        let tmp = dir.appendingPathComponent("data.json.tmp")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path))
    }

    func testWriteOverwritesExistingFileContent() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = ExportService.buildPayload(today: [], week: [], ttlSeconds: 1000)
        let second = ExportService.buildPayload(today: [], week: [], ttlSeconds: 2000)

        try ExportService.write(first, to: dir)
        try ExportService.write(second, to: dir)

        let target = dir.appendingPathComponent("data.json")
        let data = try Data(contentsOf: target)
        let decoded = try JSONDecoder().decode(ExportPayload.self, from: data)
        XCTAssertEqual(decoded.ttlSeconds, 2000)
    }

    // MARK: - delete

    func testDeleteRemovesExistingFile() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try ExportService.write(ExportService.buildPayload(today: [], week: [], ttlSeconds: 1000), to: dir)

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
