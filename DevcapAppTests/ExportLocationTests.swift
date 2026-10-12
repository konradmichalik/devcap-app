import XCTest
@testable import DevcapApp

final class ExportLocationTests: XCTestCase {
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testLocationURLPointsIntoTheBundleFolderWithoutCreatingIt() throws {
        let base = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let location = try ExportService.locationURL(baseDirectory: base, bundleIdentifier: "com.example.app")

        XCTAssertEqual(location.lastPathComponent, "com.example.app")
        XCTAssertFalse(FileManager.default.fileExists(atPath: location.path))
    }

    func testApplicationSupportURLCreatesTheSameLocation() throws {
        let base = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }

        let location = try ExportService.locationURL(baseDirectory: base, bundleIdentifier: "com.example.app")
        let created = try ExportService.applicationSupportURL(baseDirectory: base, bundleIdentifier: "com.example.app")

        XCTAssertEqual(created, location)
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.path))
    }
}
