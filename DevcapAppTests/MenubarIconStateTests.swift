import XCTest
@testable import DevcapApp

final class MenubarIconStateTests: XCTestCase {
    func testScanningWinsOverEverything() {
        XCTAssertEqual(MenubarIconState.resolve(isLoading: true, hasProjects: true, hasUnseenChanges: true), .scanning)
        XCTAssertEqual(MenubarIconState.resolve(isLoading: true, hasProjects: false, hasUnseenChanges: false), .scanning)
    }

    func testUnseenChangesWinOverEmptyAndNormal() {
        XCTAssertEqual(MenubarIconState.resolve(isLoading: false, hasProjects: true, hasUnseenChanges: true), .fresh)
    }

    func testNoProjectsIsEmpty() {
        XCTAssertEqual(MenubarIconState.resolve(isLoading: false, hasProjects: false, hasUnseenChanges: false), .empty)
    }

    func testOtherwiseNormal() {
        XCTAssertEqual(MenubarIconState.resolve(isLoading: false, hasProjects: true, hasUnseenChanges: false), .normal)
    }
}
