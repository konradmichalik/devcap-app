import XCTest
@testable import DevcapApp

final class DevcapURLTests: XCTestCase {
    private func isShow(_ string: String) -> Bool {
        URL(string: string).map(DevcapURL.isShow) ?? false
    }

    func testShowIsRecognised() {
        XCTAssertTrue(isShow("devcap://show"))
    }

    func testShowIgnoresCaseAndTrailingSlash() {
        XCTAssertTrue(isShow("DEVCAP://Show/"))
    }

    func testUnknownHostIsRejected() {
        XCTAssertFalse(isShow("devcap://toggle"))
    }

    func testExtraPathIsRejected() {
        XCTAssertFalse(isShow("devcap://show/settings"))
    }

    func testQueryAndFragmentAreRejected() {
        XCTAssertFalse(isShow("devcap://show?x=1"))
        XCTAssertFalse(isShow("devcap://show#x"))
    }

    func testOtherSchemeIsRejected() {
        XCTAssertFalse(isShow("https://show"))
    }
}
