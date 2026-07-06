import XCTest
@testable import DevcapApp

final class TerminalLauncherTests: XCTestCase {
    func testPathIsPassedAsSingleTrailingArgument() {
        let path = "/Users/dev/Sites/my-project"
        let args = TerminalLauncher.openArguments(for: path)

        XCTAssertEqual(args, ["-a", "Terminal", path])
        XCTAssertEqual(args.last, path)
        XCTAssertEqual(args.count, 3)
    }

    func testShellMetacharactersStayInsideOneArgument() {
        // A directory named like this used to break out of the AppleScript
        // `do script "cd …"` string and execute in Terminal's shell.
        let malicious = #"/tmp/$(touch /tmp/pwned)/`whoami`; rm -rf ~ #"#
        let args = TerminalLauncher.openArguments(for: malicious)

        // The whole path is exactly one argv element — nothing is split off,
        // so no shell can interpret the metacharacters.
        XCTAssertEqual(args.count, 3)
        XCTAssertEqual(args.last, malicious)
    }

    func testQuotesAndBackslashesArePreservedVerbatim() {
        let path = #"/tmp/weird "name"/with\backslash"#
        let args = TerminalLauncher.openArguments(for: path)

        XCTAssertEqual(args.last, path)
    }

    func testEmptyPathProducesEmptyTrailingArgument() {
        let args = TerminalLauncher.openArguments(for: "")

        XCTAssertEqual(args, ["-a", "Terminal", ""])
    }
}
