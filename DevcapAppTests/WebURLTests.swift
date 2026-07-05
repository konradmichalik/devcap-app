import XCTest
@testable import DevcapApp

final class WebURLTests: XCTestCase {
    func testAcceptsHTTPS() {
        XCTAssertEqual(WebURL.from("https://github.com/foo/bar")?.absoluteString,
                       "https://github.com/foo/bar")
    }

    func testAcceptsHTTP() {
        XCTAssertNotNil(WebURL.from("http://example.com"))
    }

    func testIsCaseInsensitiveOnScheme() {
        XCTAssertNotNil(WebURL.from("HTTPS://example.com"))
    }

    func testRejectsFileScheme() {
        XCTAssertNil(WebURL.from("file:///etc/passwd"))
    }

    func testRejectsCustomAppScheme() {
        XCTAssertNil(WebURL.from("x-devtool://run?cmd=rm"))
    }

    func testRejectsJavascriptScheme() {
        XCTAssertNil(WebURL.from("javascript:alert(1)"))
    }

    func testRejectsSSHRemote() {
        // A raw git SSH remote must not be treated as an openable web URL.
        XCTAssertNil(WebURL.from("git@github.com:foo/bar.git"))
    }

    func testRejectsNil() {
        XCTAssertNil(WebURL.from(nil))
    }

    func testRejectsEmptyString() {
        XCTAssertNil(WebURL.from(""))
    }
}
